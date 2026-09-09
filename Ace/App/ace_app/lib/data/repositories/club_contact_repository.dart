import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club_contact_model.dart';

class ClubContactRepository {
  ClubContactRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('clubContacts');

  Stream<List<ClubContactModel>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => ClubContactModel.fromJson({...doc.data(), 'id': doc.id}),
          )
          .toList(),
    );
  }

  Future<void> create(ClubContactModel contact) {
    final docRef = _collection.doc();
    return docRef.set({...contact.toJson(), 'id': docRef.id});
  }

  Future<void> delete(String contactId) {
    return _collection.doc(contactId).delete();
  }
}
