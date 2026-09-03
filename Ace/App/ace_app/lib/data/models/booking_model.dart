import 'package:equatable/equatable.dart';

enum BookingStatus { pending, confirmed, cancelled }

enum BookingResult { win, loss }

extension BookingStatusJson on BookingStatus {
  String get jsonValue => name;

  static BookingStatus fromJson(String value) =>
      BookingStatus.values.firstWhere((s) => s.name == value);
}

extension BookingResultJson on BookingResult {
  String get jsonValue => name;

  static BookingResult fromJson(String value) =>
      BookingResult.values.firstWhere((r) => r.name == value);
}

class BookingModel extends Equatable {
  final String id;
  final String courtId;
  final String courtName;
  final String userId;
  final String? partnerId;
  final String? partnerName;
  final DateTime date;
  final String startTime;
  final String endTime;
  final BookingStatus status;
  final BookingResult? result;
  final String? score;
  final double price;
  final DateTime createdAt;
  final bool isAdminBooking;
  final String? gateCode;
  final String? courtAddress;
  // Optional label an admin can attach when creating a booking through
  // Manager (e.g. "Tournoi interne", "Cours particulier").
  final String? title;

  const BookingModel({
    required this.id,
    required this.courtId,
    required this.courtName,
    required this.userId,
    this.partnerId,
    this.partnerName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.result,
    this.score,
    required this.price,
    required this.createdAt,
    this.isAdminBooking = false,
    this.gateCode,
    this.courtAddress,
    this.title,
  });

  bool get isConfirmed => status == BookingStatus.confirmed;

  DateTime _timeOn(String hhmm) {
    final parts = hhmm.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  /// A booking stays "upcoming" for its whole duration, not just until its
  /// start time — otherwise a match in progress would flip to "history"
  /// the moment it starts.
  bool get isPast => _timeOn(endTime).isBefore(DateTime.now());

  bool get isUpcoming => !isPast && status != BookingStatus.cancelled;
  bool get hasPartner => partnerId != null;

  DateTime get startDateTime => _timeOn(startTime);

  /// Cancellation is blocked once the slot is within 5 minutes of starting
  /// (or already under way) — cancelling a booking that's about to happen
  /// or happening isn't meaningful.
  bool get canCancel =>
      DateTime.now().isBefore(_timeOn(startTime).subtract(const Duration(minutes: 5)));

  /// Groups bookings by court + day + start time so Firestore can enforce
  /// "one booking per slot" via a deterministic document id.
  String get slotKey =>
      '${courtId}_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}_$startTime';

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'] as String,
        courtId: json['courtId'] as String,
        courtName: json['courtName'] as String,
        userId: json['userId'] as String,
        partnerId: json['partnerId'] as String?,
        partnerName: json['partnerName'] as String?,
        date: DateTime.parse(json['date'] as String),
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
        status: BookingStatusJson.fromJson(json['status'] as String),
        result: json['result'] == null
            ? null
            : BookingResultJson.fromJson(json['result'] as String),
        score: json['score'] as String?,
        price: (json['price'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        isAdminBooking: json['isAdminBooking'] as bool? ?? false,
        gateCode: json['gateCode'] as String?,
        courtAddress: json['courtAddress'] as String?,
        title: json['title'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'courtId': courtId,
        'courtName': courtName,
        'userId': userId,
        'partnerId': partnerId,
        'partnerName': partnerName,
        'date': date.toIso8601String(),
        'startTime': startTime,
        'endTime': endTime,
        'status': status.jsonValue,
        'result': result?.jsonValue,
        'score': score,
        'price': price,
        'createdAt': createdAt.toIso8601String(),
        'isAdminBooking': isAdminBooking,
        'gateCode': gateCode,
        'courtAddress': courtAddress,
        'title': title,
      };

  BookingModel copyWith({
    String? id,
    String? courtId,
    String? courtName,
    String? userId,
    Object? partnerId = _sentinel,
    Object? partnerName = _sentinel,
    DateTime? date,
    String? startTime,
    String? endTime,
    BookingStatus? status,
    Object? result = _sentinel,
    Object? score = _sentinel,
    double? price,
    DateTime? createdAt,
    bool? isAdminBooking,
    Object? gateCode = _sentinel,
    Object? courtAddress = _sentinel,
    Object? title = _sentinel,
  }) {
    return BookingModel(
      id: id ?? this.id,
      courtId: courtId ?? this.courtId,
      courtName: courtName ?? this.courtName,
      userId: userId ?? this.userId,
      partnerId: partnerId == _sentinel ? this.partnerId : partnerId as String?,
      partnerName: partnerName == _sentinel ? this.partnerName : partnerName as String?,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      result: result == _sentinel ? this.result : result as BookingResult?,
      score: score == _sentinel ? this.score : score as String?,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      isAdminBooking: isAdminBooking ?? this.isAdminBooking,
      gateCode: gateCode == _sentinel ? this.gateCode : gateCode as String?,
      courtAddress: courtAddress == _sentinel ? this.courtAddress : courtAddress as String?,
      title: title == _sentinel ? this.title : title as String?,
    );
  }

  @override
  List<Object?> get props => [id, courtId, userId, date, startTime];
}

const _sentinel = Object();
