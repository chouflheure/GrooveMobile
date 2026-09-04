import 'package:equatable/equatable.dart';

class ClubEventModel extends Equatable {
  final String id;
  final String clubId;
  final String clubName;
  final String title;
  final String description;
  final DateTime date;
  final String address;
  final List<String> courtNames;
  final List<String> participantIds;
  final DateTime createdAt;

  const ClubEventModel({
    required this.id,
    required this.clubId,
    required this.clubName,
    required this.title,
    required this.description,
    required this.date,
    required this.address,
    this.courtNames = const [],
    this.participantIds = const [],
    required this.createdAt,
  });

  factory ClubEventModel.fromJson(Map<String, dynamic> json) => ClubEventModel(
    id: json['id'] as String,
    clubId: json['clubId'] as String,
    clubName: json['clubName'] as String? ?? '',
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    date: DateTime.parse(json['date'] as String),
    address: json['address'] as String? ?? '',
    courtNames: json['courtNames'] != null
        ? List<String>.from(json['courtNames'] as List)
        : const [],
    participantIds: json['participantIds'] != null
        ? List<String>.from(json['participantIds'] as List)
        : const [],
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clubId': clubId,
    'clubName': clubName,
    'title': title,
    'description': description,
    'date': date.toIso8601String(),
    'address': address,
    'courtNames': courtNames,
    'participantIds': participantIds,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, clubId, title, date];
}
