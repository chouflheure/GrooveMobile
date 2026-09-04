import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club_model.dart';

class ClubRepository {
  ClubRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('clubs');

  Future<List<ClubModel>> fetchAll() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => ClubModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Stream<List<ClubModel>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ClubModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList(),
    );
  }
}
