import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/announcement_model.dart';

class BroadcastRepository {
  BroadcastRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('broadcasts');

  Stream<List<AnnouncementModel>> watchAll() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AnnouncementModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> create(AnnouncementModel announcement) {
    final docRef = _collection.doc();
    return docRef.set(announcement.copyWith(id: docRef.id).toJson());
  }

  Future<void> update(AnnouncementModel announcement) {
    return _collection.doc(announcement.id).set(announcement.toJson());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }

  Future<void> setInterested(String id, String userId, bool interested) {
    return _collection.doc(id).update({
      'interestedUserIds': interested
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]),
    });
  }
}
