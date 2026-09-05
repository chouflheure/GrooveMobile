import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads a user/club/court's image to Firebase Storage, one object per
/// id (`users/{id}.ext`, `clubs/{id}.ext`, `courts/{id}.ext`) so a new
/// upload for the same id simply overwrites the previous image instead of
/// leaving orphaned files behind.
class StorageRepository {
  StorageRepository({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadUserImage(String userId, File file) =>
      _upload('users', userId, file);

  Future<String> uploadClubImage(String clubId, File file) =>
      _upload('clubs', clubId, file);

  Future<String> uploadCourtImage(String courtId, File file) =>
      _upload('courts', courtId, file);

  Future<String> _upload(String folder, String id, File file) async {
    final dotIndex = file.path.lastIndexOf('.');
    final ext = dotIndex == -1 ? 'jpg' : file.path.substring(dotIndex + 1);
    final ref = _storage.ref('$folder/$id.$ext');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}
