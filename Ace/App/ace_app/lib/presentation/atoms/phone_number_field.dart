import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

class CountryCode {
  final String name;
  final String dialCode;
  final String flag;

  const CountryCode({
    required this.name,
    required this.dialCode,
    required this.flag,
  });
}

const List<CountryCode> kCountryCodes = [
  CountryCode(name: 'France', dialCode: '+33', flag: '🇫🇷'),
  CountryCode(name: 'Belgique', dialCode: '+32', flag: '🇧🇪'),
  CountryCode(name: 'Suisse', dialCode: '+41', flag: '🇨🇭'),
  CountryCode(name: 'Luxembourg', dialCode: '+352', flag: '🇱🇺'),
  CountryCode(name: 'Monaco', dialCode: '+377', flag: '🇲🇨'),
  CountryCode(name: 'Royaume-Uni', dialCode: '+44', flag: '🇬🇧'),
  CountryCode(name: 'Allemagne', dialCode: '+49', flag: '🇩🇪'),
  CountryCode(name: 'Espagne', dialCode: '+34', flag: '🇪🇸'),
  CountryCode(name: 'Italie', dialCode: '+39', flag: '🇮🇹'),
  CountryCode(name: 'Portugal', dialCode: '+351', flag: '🇵🇹'),
  CountryCode(name: 'Maroc', dialCode: '+212', flag: '🇲🇦'),
  CountryCode(name: 'Algérie', dialCode: '+213', flag: '🇩🇿'),
  CountryCode(name: 'Tunisie', dialCode: '+216', flag: '🇹🇳'),
  CountryCode(name: 'États-Unis / Canada', dialCode: '+1', flag: '🇺🇸'),
];

/// Owns both the selected dial code and the raw local-number text, so a
/// screen using [PhoneNumberField] only ever needs to read [e164] when it's
/// ready to send the number to Firebase — the user just types the number
/// the way they normally would (e.g. "0611223344").
class PhoneInputController extends ChangeNotifier {
  PhoneInputController({CountryCode? country})
    : _country = country ?? kCountryCodes.first;

  CountryCode _country;
  CountryCode get country => _country;
  set country(CountryCode value) {
    _country = value;
    notifyListeners();
  }

  final TextEditingController localController = TextEditingController();

  /// The number in E.164 form (e.g. "0611223344" + France → "+33611223344").
  /// A single leading "0" — the national trunk prefix — is dropped, since
  /// the dial code already replaces it.
  String get e164 {
    final digitsOnly = localController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final local = digitsOnly.startsWith('0')
        ? digitsOnly.substring(1)
        : digitsOnly;
    return '${_country.dialCode}$local';
  }

  @override
  void dispose() {
    localController.dispose();
    super.dispose();
  }
}

class PhoneNumberField extends StatelessWidget {
  final PhoneInputController controller;
  final String hint;

  const PhoneNumberField({
    super.key,
    required this.controller,
    this.hint = '0611223344',
  });

  void _showCountryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _CountryPickerSheet(
        selected: controller.country,
        onSelect: (c) {
          controller.country = c;
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          children: [
            GestureDetector(
              onTap: () => _showCountryPicker(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      controller.country.flag,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      controller.country.dialCode,
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: controller.localController,
                keyboardType: TextInputType.phone,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: AppTypography.bodySmall,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CountryPickerSheet extends StatelessWidget {
  final CountryCode selected;
  final ValueChanged<CountryCode> onSelect;

  const _CountryPickerSheet({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.xxxl),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Indicatif', style: AppTypography.headlineLarge),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: kCountryCodes.length,
              itemBuilder: (_, i) {
                final c = kCountryCodes[i];
                final isSelected =
                    c.dialCode == selected.dialCode && c.name == selected.name;
                return ListTile(
                  onTap: () => onSelect(c),
                  leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(c.name, style: AppTypography.bodyMedium),
                  trailing: Text(
                    c.dialCode,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: AppColors.primaryContainer,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
