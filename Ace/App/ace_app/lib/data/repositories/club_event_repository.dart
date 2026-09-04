import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club_event_model.dart';

class ClubEventRepository {
  ClubEventRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('events');

  /// One-shot fetch, e.g. resolving a notification tap's `eventId` to the
  /// model `EventDetailScreen` needs (routes pass it via `extra:`, not just
  /// an id, so there's nowhere else to already have it in that flow).
  Future<ClubEventModel?> getById(String eventId) async {
    final doc = await _collection.doc(eventId).get();
    if (!doc.exists) return null;
    return ClubEventModel.fromJson({...doc.data()!, 'id': doc.id});
  }

  Stream<List<ClubEventModel>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ClubEventModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList(),
    );
  }

  Future<void> create(ClubEventModel event) {
    final docRef = _collection.doc();
    return docRef.set({...event.toJson(), 'id': docRef.id});
  }

  Future<void> update(ClubEventModel event) {
    return _collection.doc(event.id).set(event.toJson());
  }

  Future<void> delete(String eventId) {
    return _collection.doc(eventId).delete();
  }

  Future<void> setParticipating(
    String eventId,
    String userId,
    bool participating,
  ) {
    return _collection.doc(eventId).update({
      'participantIds': participating
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]),
    });
  }
}
