import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/court_model.dart';

class CourtRepository {
  CourtRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('courts');

  Future<List<CourtModel>> fetchAll() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => CourtModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<CourtModel?> fetchById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return CourtModel.fromJson({...doc.data()!, 'id': doc.id});
  }

  Stream<List<CourtModel>> watchAll() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => CourtModel.fromJson({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }
}
