import 'package:equatable/equatable.dart';

class ClubModel extends Equatable {
  final String id;
  final String name;
  final String location;
  final String? imageUrl;

  const ClubModel({
    required this.id,
    required this.name,
    required this.location,
    this.imageUrl,
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) => ClubModel(
        id: json['id'] as String,
        name: json['name'] as String,
        location: json['location'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'imageUrl': imageUrl,
      };

  @override
  List<Object?> get props => [id, name, location];
}
