import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import 'manager_view_model.dart';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Aggregated occupancy stats — per court and per hour-of-day — over a
/// rolling window ending today. Pure client-side aggregation of
/// `ManagerViewModel`'s already-loaded `courts`/`allBookings`, same data
/// source as `AdminScheduleScreen`, just summed over several days instead
/// of shown for one.
class OccupancyStatsScreen extends ConsumerStatefulWidget {
  const OccupancyStatsScreen({super.key});

  @override
  ConsumerState<OccupancyStatsScreen> createState() =>
      _OccupancyStatsScreenState();
}

class _OccupancyStatsScreenState extends ConsumerState<OccupancyStatsScreen> {
  int _periodDays = 7;
  DateTimeRange? _customRange;

  List<DateTime> get _days {
    final range = _customRange;
    if (range != null) {
      final span = range.end.difference(range.start).inDays;
      return List.generate(
        span + 1,
        (i) => DateTime(range.start.year, range.start.month, range.start.day)
            .add(Duration(days: i)),
      );
    }
    final today = AppConstants.today();
    return List.generate(
      _periodDays,
      (i) => today.subtract(Duration(days: _periodDays - 1 - i)),
    );
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
    );
    if (picked == null) return;
    setState(() => _customRange = picked);
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _fmtLong(DateTime d) =>
      '${_fmt(d)}/${d.year}';

  Future<void> _exportPdf({
    required List<DateTime> days,
    required List<({CourtModel court, double rate, int booked, int offered, double revenue})>
    courtStats,
    required double totalRevenue,
    required int totalBooked,
  }) async {
    final periodLabel = days.length == 1
        ? _fmtLong(days.first)
        : '${_fmtLong(days.first)} → ${_fmtLong(days.last)}';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Statistiques d\'occupation',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Période : $periodLabel'),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Chiffre d\'affaires : ${totalRevenue.toInt()}€',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Réservations : $totalBooked',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: [
                'Terrain',
                'Réservations',
                'Occupation',
                'Chiffre d\'affaires',
              ],
              data: courtStats
                  .map(
                    (s) => [
                      s.court.name,
                      '${s.booked} / ${s.offered}',
                      '${(s.rate * 100).round()}%',
                      '${s.revenue.toInt()}€',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFE8F5EA),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Généré le ${_fmtLong(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(managerViewModelProvider);
    final days = _days;

    final bookingsInPeriod = state.allBookings.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      if (b.isEventBlock) return false;
      return days.any((d) => _isSameDay(d, b.date));
    }).toList();

    final courtStats = state.courts.map((court) {
      var offered = 0;
      for (final day in days) {
        if (court.isClosedOn(day)) continue;
        offered += court.availableSlots.length;
      }
      final courtBookings = bookingsInPeriod
          .where((b) => b.courtId == court.id)
          .toList();
      final booked = courtBookings.length;
      final revenue = courtBookings.fold<double>(0, (sum, b) => sum + b.price);
      final rate = offered == 0 ? 0.0 : (booked / offered).clamp(0.0, 1.0);
      return (
        court: court,
        rate: rate,
        booked: booked,
        offered: offered,
        revenue: revenue,
      );
    }).toList()..sort((a, b) => b.rate.compareTo(a.rate));

    final totalRevenue = bookingsInPeriod.fold<double>(
      0,
      (sum, b) => sum + b.price,
    );

    final hourlyRate = <String, double>{};
    for (final t in AppConstants.timeSlots) {
      var offered = 0;
      for (final court in state.courts) {
        if (!court.availableSlots.any((s) => s.time == t)) continue;
        for (final day in days) {
          if (!court.isClosedOn(day)) offered++;
        }
      }
      final booked = bookingsInPeriod.where((b) => b.startTime == t).length;
      hourlyRate[t] = offered == 0 ? 0.0 : (booked / offered).clamp(0.0, 1.0);
    }

    final dailyRate = days.map((day) {
      var offered = 0;
      for (final court in state.courts) {
        if (court.isClosedOn(day)) continue;
        offered += court.availableSlots.length;
      }
      final booked = bookingsInPeriod
          .where((b) => _isSameDay(b.date, day))
          .length;
      final rate = offered == 0 ? 0.0 : (booked / offered).clamp(0.0, 1.0);
      return (day: day, rate: rate);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Statistiques d\'occupation'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: () =>
                _exportPdf(days: days, courtStats: courtStats, totalRevenue: totalRevenue, totalBooked: bookingsInPeriod.length),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Exporter en PDF',
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: _PeriodButton(
                  label: '7 jours',
                  isSelected: _customRange == null && _periodDays == 7,
                  onTap: () => setState(() {
                    _periodDays = 7;
                    _customRange = null;
                  }),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _PeriodButton(
                  label: '30 jours',
                  isSelected: _customRange == null && _periodDays == 30,
                  onTap: () => setState(() {
                    _periodDays = 30;
                    _customRange = null;
                  }),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: _customRange != null ? AppColors.primary : null,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: _customRange != null
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: IconButton(
                  onPressed: _pickCustomRange,
                  icon: Icon(
                    Icons.calendar_month_rounded,
                    color: _customRange != null
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (_customRange != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_fmt(_customRange!.start)} – ${_fmt(_customRange!.end)}',
              style: AppTypography.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chiffre d\'affaires',
                        style: AppTypography.bodySmall,
                      ),
                      Text(
                        '${totalRevenue.toInt()}€',
                        style: AppTypography.headlineMedium,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Réservations', style: AppTypography.bodySmall),
                    Text(
                      '${bookingsInPeriod.length}',
                      style: AppTypography.headlineMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Par jour', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Occupation cumulée sur tous les terrains, jour par jour.",
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dailyRate.length,
              separatorBuilder: (_, _) => const SizedBox(width: 2),
              itemBuilder: (_, i) {
                final d = dailyRate[i];
                return _RateCell(label: _fmt(d.day), rate: d.rate);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Par terrain', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          if (courtStats.isEmpty)
            Text(
              'Aucun terrain pour le moment.',
              style: AppTypography.bodySmall,
            )
          else
            ...courtStats.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _CourtOccupancyRow(
                  name: s.court.name,
                  rate: s.rate,
                  booked: s.booked,
                  offered: s.offered,
                  revenue: s.revenue,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          Text('Par heure', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Occupation cumulée sur tous les terrains — utile pour ajuster "
            "les heures creuses/pleines d'un scénario.",
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: AppConstants.timeSlots.length,
              separatorBuilder: (_, _) => const SizedBox(width: 2),
              itemBuilder: (_, i) {
                final t = AppConstants.timeSlots[i];
                return _RateCell(label: t, rate: hourlyRate[t] ?? 0);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primary : null,
        foregroundColor: isSelected ? Colors.white : AppColors.textSecondary,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Text(label),
    );
  }
}

class _CourtOccupancyRow extends StatelessWidget {
  final String name;
  final double rate;
  final int booked;
  final int offered;
  final double revenue;

  const _CourtOccupancyRow({
    required this.name,
    required this.rate,
    required this.booked,
    required this.offered,
    required this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(name, style: AppTypography.bodyMedium),
            ),
            Text(
              '${(rate * 100).round()}%',
              style: AppTypography.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Container(height: 8, color: AppColors.surfaceVariant),
                Container(
                  height: 8,
                  width: constraints.maxWidth * rate,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$booked / $offered créneaux réservés · ${revenue.toInt()}€',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _RateCell extends StatelessWidget {
  final String label;
  final double rate;

  const _RateCell({required this.label, required this.rate});

  @override
  Widget build(BuildContext context) {
    // Sequential encoding — one hue (primary), light to dark with
    // intensity — never a red/green pair, since this is a magnitude
    // (how booked), not a good/bad judgment.
    final background = rate == 0
        ? AppColors.surfaceVariant
        : AppColors.primary.withValues(alpha: 0.15 + rate * 0.75);
    final textColor = rate > 0.55 ? Colors.white : AppColors.textSecondary;
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: textColor),
          ),
          const SizedBox(height: 2),
          Text(
            '${(rate * 100).round()}%',
            style: AppTypography.labelSmall.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}
