import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification_model.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('notifications');

  Stream<List<AppNotificationModel>> watchForUser(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    AppNotificationModel.fromJson({...doc.data(), 'id': doc.id}),
              )
              .toList(),
        );
  }

  Future<void> markAllSeen(List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.update(_collection.doc(id), {'seen': true});
    }
    await batch.commit();
  }

  Future<void> markClicked(String id) {
    return _collection.doc(id).update({'clicked': true});
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
