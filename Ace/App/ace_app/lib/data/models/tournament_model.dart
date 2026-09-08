import 'package:equatable/equatable.dart';

enum TournamentStatus { registration, inProgress, completed }

extension TournamentStatusJson on TournamentStatus {
  String get jsonValue => name;

  static TournamentStatus fromJson(String? value) =>
      TournamentStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => TournamentStatus.registration,
      );
}

/// One slot in a single-elimination bracket. `round` is 1-indexed (1 = first
/// round); `position` is this match's index within its round, and is what
/// bracket advancement math (`position ~/ 2` in the next round) is based on.
class TournamentMatch extends Equatable {
  final int round;
  final int position;
  final String? playerAId;
  final String? playerBId;
  final String? winnerId;
  // Scheduling — unset until the admin assigns a court/date/time. Creating
  // that assignment also creates a real two-player `BookingModel` (so both
  // players see it and get the usual "you were added to this match" push);
  // `bookingId` is just the resulting reference back to it.
  final String? courtId;
  final String? courtName;
  final DateTime? date;
  final String? startTime;
  final String? bookingId;

  const TournamentMatch({
    required this.round,
    required this.position,
    this.playerAId,
    this.playerBId,
    this.winnerId,
    this.courtId,
    this.courtName,
    this.date,
    this.startTime,
    this.bookingId,
  });

  bool get isBye =>
      (playerAId == null) != (playerBId == null) && winnerId != null;
  bool get isReadyToPlay => playerAId != null && playerBId != null;
  bool get isScheduled => courtId != null;
  bool get isPlayed => winnerId != null;

  TournamentMatch copyWith({
    Object? playerAId = _sentinel,
    Object? playerBId = _sentinel,
    Object? winnerId = _sentinel,
    Object? courtId = _sentinel,
    Object? courtName = _sentinel,
    Object? date = _sentinel,
    Object? startTime = _sentinel,
    Object? bookingId = _sentinel,
  }) {
    return TournamentMatch(
      round: round,
      position: position,
      playerAId: playerAId == _sentinel ? this.playerAId : playerAId as String?,
      playerBId: playerBId == _sentinel ? this.playerBId : playerBId as String?,
      winnerId: winnerId == _sentinel ? this.winnerId : winnerId as String?,
      courtId: courtId == _sentinel ? this.courtId : courtId as String?,
      courtName: courtName == _sentinel ? this.courtName : courtName as String?,
      date: date == _sentinel ? this.date : date as DateTime?,
      startTime: startTime == _sentinel ? this.startTime : startTime as String?,
      bookingId: bookingId == _sentinel ? this.bookingId : bookingId as String?,
    );
  }

  factory TournamentMatch.fromJson(Map<String, dynamic> json) =>
      TournamentMatch(
        round: json['round'] as int,
        position: json['position'] as int,
        playerAId: json['playerAId'] as String?,
        playerBId: json['playerBId'] as String?,
        winnerId: json['winnerId'] as String?,
        courtId: json['courtId'] as String?,
        courtName: json['courtName'] as String?,
        date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
        startTime: json['startTime'] as String?,
        bookingId: json['bookingId'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'round': round,
    'position': position,
    'playerAId': playerAId,
    'playerBId': playerBId,
    'winnerId': winnerId,
    'courtId': courtId,
    'courtName': courtName,
    'date': date?.toIso8601String(),
    'startTime': startTime,
    'bookingId': bookingId,
  };

  @override
  List<Object?> get props => [
    round,
    position,
    playerAId,
    playerBId,
    winnerId,
    courtId,
    date,
    startTime,
    bookingId,
  ];
}

class TournamentModel extends Equatable {
  final String id;
  final String clubId;
  final String clubName;
  final String title;
  final String description;
  final TournamentStatus status;
  final List<String> participantIds;
  // Empty until the admin closes registration and draws the bracket.
  final List<TournamentMatch> matches;
  final DateTime createdAt;

  const TournamentModel({
    required this.id,
    required this.clubId,
    required this.clubName,
    required this.title,
    this.description = '',
    this.status = TournamentStatus.registration,
    this.participantIds = const [],
    this.matches = const [],
    required this.createdAt,
  });

  int get roundCount =>
      matches.isEmpty ? 0 : matches.map((m) => m.round).reduce((a, b) => a > b ? a : b);

  List<TournamentMatch> matchesInRound(int round) =>
      matches.where((m) => m.round == round).toList()
        ..sort((a, b) => a.position.compareTo(b.position));

  TournamentModel copyWith({
    TournamentStatus? status,
    List<String>? participantIds,
    List<TournamentMatch>? matches,
  }) {
    return TournamentModel(
      id: id,
      clubId: clubId,
      clubName: clubName,
      title: title,
      description: description,
      status: status ?? this.status,
      participantIds: participantIds ?? this.participantIds,
      matches: matches ?? this.matches,
      createdAt: createdAt,
    );
  }

  factory TournamentModel.fromJson(Map<String, dynamic> json) =>
      TournamentModel(
        id: json['id'] as String,
        clubId: json['clubId'] as String,
        clubName: json['clubName'] as String? ?? '',
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        status: TournamentStatusJson.fromJson(json['status'] as String?),
        participantIds: json['participantIds'] != null
            ? List<String>.from(json['participantIds'] as List)
            : const [],
        matches: json['matches'] != null
            ? (json['matches'] as List)
                  .map((m) => TournamentMatch.fromJson(m as Map<String, dynamic>))
                  .toList()
            : const [],
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clubId': clubId,
    'clubName': clubName,
    'title': title,
    'description': description,
    'status': status.jsonValue,
    'participantIds': participantIds,
    'matches': matches.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, clubId, title, status, participantIds, matches];
}

const _sentinel = Object();
