import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users');

  Future<void> create(UserModel user) {
    return _collection.doc(user.id).set(user.toJson());
  }

  Future<void> update(UserModel user) {
    return _collection.doc(user.id).set(user.toJson());
  }

  Future<UserModel?> fetchById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromJson({...doc.data()!, 'id': doc.id});
  }

  Stream<UserModel?> watchById(String id) {
    return _collection.doc(id).snapshots().map(
          (doc) => doc.exists
              ? UserModel.fromJson({...doc.data()!, 'id': doc.id})
              : null,
        );
  }

  Stream<List<UserModel>> watchAll() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromJson({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }
}
