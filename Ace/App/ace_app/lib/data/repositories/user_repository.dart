import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../models/user_model.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users');

  // Separate collection some accounts are granted admin through (a doc's
  // mere presence at admin/{uid} marks that uid as admin) — kept apart from
  // the `users` doc so admin status isn't just another editable profile
  // field. Merged into `role` here so every screen can keep reading
  // `UserModel.isAdmin` without knowing about this second source.
  CollectionReference<Map<String, dynamic>> get _adminCollection =>
      _firestore.collection('admin');

  Stream<Set<String>> _watchAdminIds() => _adminCollection.snapshots().map(
    (snapshot) => snapshot.docs.map((doc) => doc.id).toSet(),
  );

  Future<Set<String>> _fetchAdminIds() async {
    final snapshot = await _adminCollection.get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  UserModel _applyAdminOverride(UserModel user, Set<String> adminIds) =>
      adminIds.contains(user.id) ? user.copyWith(role: UserRole.admin) : user;

  Future<void> create(UserModel user) {
    return _collection.doc(user.id).set(user.toJson());
  }

  Future<void> update(UserModel user) {
    return _collection.doc(user.id).set(user.toJson());
  }

  Future<UserModel?> fetchById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    final adminIds = await _fetchAdminIds();
    return _applyAdminOverride(
      UserModel.fromJson({...doc.data()!, 'id': doc.id}),
      adminIds,
    );
  }

  Stream<UserModel?> watchById(String id) {
    return Rx.combineLatest2(
      _collection.doc(id).snapshots(),
      _watchAdminIds(),
      (DocumentSnapshot<Map<String, dynamic>> doc, Set<String> adminIds) {
        if (!doc.exists) return null;
        return _applyAdminOverride(
          UserModel.fromJson({...doc.data()!, 'id': doc.id}),
          adminIds,
        );
      },
    );
  }

  Stream<List<UserModel>> watchAll() {
    return Rx.combineLatest2(
      _collection.snapshots(),
      _watchAdminIds(),
      (QuerySnapshot<Map<String, dynamic>> snapshot, Set<String> adminIds) =>
          snapshot.docs
              .map(
                (doc) => _applyAdminOverride(
                  UserModel.fromJson({...doc.data(), 'id': doc.id}),
                  adminIds,
                ),
              )
              .toList(),
    );
  }
}
