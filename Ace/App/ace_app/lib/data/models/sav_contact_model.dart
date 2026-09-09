import 'package:equatable/equatable.dart';

/// A support ("SAV") contact — read-only from the app's side. Documents in
/// the `SAV` Firestore collection are entered by hand in the console (not
/// created through the app), which is why the field names are French,
/// unlike the rest of the app's models.
class SavContactModel extends Equatable {
  final String id;
  final String nom;
  final String prenom;
  final String? numero;
  final String? mail;

  const SavContactModel({
    required this.id,
    required this.nom,
    required this.prenom,
    this.numero,
    this.mail,
  });

  factory SavContactModel.fromJson(Map<String, dynamic> json) =>
      SavContactModel(
        id: json['id'] as String,
        nom: json['nom'] as String? ?? '',
        prenom: json['prenom'] as String? ?? '',
        numero: json['numero'] as String?,
        mail: json['mail'] as String?,
      );

  @override
  List<Object?> get props => [id, nom, prenom, numero, mail];
}
