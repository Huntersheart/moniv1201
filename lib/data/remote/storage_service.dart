import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class StorageService {
  /// Prefer the bucket from [FirebaseOptions] so Android/iOS always match the console.
  FirebaseStorage _storageForPrimaryBucket() {
    final raw = DefaultFirebaseOptions.currentPlatform.storageBucket ?? '';
    if (raw.isEmpty) {
      return FirebaseStorage.instance;
    }
    final gs = raw.startsWith('gs://') ? raw : 'gs://$raw';
    return FirebaseStorage.instanceFor(app: Firebase.app(), bucket: gs);
  }

  /// Older projects sometimes still use the default `*.appspot.com` bucket only.
  FirebaseStorage _storageForLegacyAppspotBucket() {
    final id = DefaultFirebaseOptions.currentPlatform.projectId;
    return FirebaseStorage.instanceFor(
      app: Firebase.app(),
      bucket: 'gs://$id.appspot.com',
    );
  }

  Future<String> _putProfileJpeg({
    required FirebaseStorage storage,
    required String userId,
    required String dogId,
    required String filePath,
  }) async {
    if (dogId.isEmpty) {
      throw StateError('dogId is required before uploading a profile image.');
    }
    final file = File(filePath);
    final ref = storage.ref('users/$userId/dogs/$dogId/profile.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }

  Future<String> uploadDogPhoto({
    required String userId,
    required String dogId,
    required String filePath,
  }) async {
    try {
      return await _putProfileJpeg(
        storage: _storageForPrimaryBucket(),
        userId: userId,
        dogId: dogId,
        filePath: filePath,
      );
    } on FirebaseException catch (e) {
      if (_isStorageBucketNotFound(e)) {
        if (kDebugMode) {
          debugPrint(
            '[Storage] Primary bucket upload failed (${e.code}), retrying '
            'legacy appspot bucket…',
          );
        }
        return await _putProfileJpeg(
          storage: _storageForLegacyAppspotBucket(),
          userId: userId,
          dogId: dogId,
          filePath: filePath,
        );
      }
      rethrow;
    }
  }

  /// Returns true only when the **bucket itself** does not exist so the caller
  /// can retry against the legacy `.appspot.com` bucket.
  ///
  /// `object-not-found` / code -13010 means the resumable-upload session was
  /// invalidated on the server (often because an App Check placeholder token
  /// was rejected). That is NOT a missing-bucket error and must not trigger a
  /// fallback, otherwise the app spins up a second failing upload to an
  /// `.appspot.com` bucket that may not exist at all.
  static bool _isStorageBucketNotFound(FirebaseException e) {
    return e.code.toLowerCase() == 'bucket-not-found';
  }

  Future<String> uploadUserAvatar({
    required String userId,
    required String filePath,
  }) async {
    Future<String> put(FirebaseStorage storage) async {
      final file = File(filePath);
      final ref = storage.ref('users/$userId/avatar.jpg');
      final task = await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return task.ref.getDownloadURL();
    }

    try {
      return await put(_storageForPrimaryBucket());
    } on FirebaseException catch (e) {
      if (_isStorageBucketNotFound(e)) {
        return await put(_storageForLegacyAppspotBucket());
      }
      rethrow;
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
    } catch (_) {}
  }
}
