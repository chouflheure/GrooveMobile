import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sav_contact_model.dart';

/// Read-only — the `SAV` collection is populated by hand in the Firebase
/// console (see `SavContactModel`), the app never writes to it.
class SavRepository {
  SavRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('SAV');

  Future<List<SavContactModel>> fetchAll() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => SavContactModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Stream<List<SavContactModel>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => SavContactModel.fromJson({...doc.data(), 'id': doc.id}),
          )
          .toList(),
    );
  }
}
