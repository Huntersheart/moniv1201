import 'dart:async';
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
    // On some iOS setups, forcing `gs://<project>.firebasestorage.app`
    // can trigger `[firebase_storage/unknown] cannot parse response`.
    // Use the app-configured default bucket client in that case.
    if (raw.endsWith('.firebasestorage.app')) {
      return FirebaseStorage.instanceFor(app: Firebase.app());
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
    required Uint8List imageBytes,
  }) async {
    if (dogId.isEmpty) {
      throw StateError('dogId is required before uploading a profile image.');
    }
    final ref = storage.ref('users/$userId/dogs/$dogId/profile.jpg');
    // iOS gallery picks often fail with putFile (native path/sandbox); putData is reliable.
    final task = await ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }

  Future<String> uploadDogPhoto({
    required String userId,
    required String dogId,
    required Uint8List imageBytes,
  }) async {
    try {
      return await _putProfileJpeg(
        storage: _storageForPrimaryBucket(),
        userId: userId,
        dogId: dogId,
        imageBytes: imageBytes,
      );
    } on FirebaseException catch (e) {
      if (_isParseResponseError(e)) {
        if (kDebugMode) {
          debugPrint(
            '[Storage] Upload parse-response error, retrying once with '
            'default FirebaseStorage client…',
          );
        }
        return await _putProfileJpeg(
          storage: FirebaseStorage.instanceFor(app: Firebase.app()),
          userId: userId,
          dogId: dogId,
          imageBytes: imageBytes,
        );
      }
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
          imageBytes: imageBytes,
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

  static bool _isParseResponseError(FirebaseException e) {
    final code = e.code.toLowerCase();
    final msg = e.message?.toLowerCase() ?? '';
    return code == 'unknown' && msg.contains('cannot parse response');
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

  static String _sessionObjectName({
    required String userId,
    required String sessionId,
    required String filePath,
    required bool isVideo,
  }) {
    final ext = _extensionFromPath(filePath, isVideo: isVideo);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final kind = isVideo ? 'video' : 'photo';
    return 'users/$userId/sessions/$sessionId/${kind}_$stamp.$ext';
  }

  static String _extensionFromPath(String filePath, {required bool isVideo}) {
    final dot = filePath.lastIndexOf('.');
    if (dot == -1 || dot == filePath.length - 1) {
      return isVideo ? 'mp4' : 'jpg';
    }
    return filePath.substring(dot + 1).toLowerCase();
  }

  static String _contentTypeForPath(String filePath, {required bool isVideo}) {
    final lower = filePath.toLowerCase();
    if (isVideo) {
      if (lower.endsWith('.mov')) return 'video/quicktime';
      return 'video/mp4';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'image/jpeg';
  }

  Future<String> _putSessionFile({
    required FirebaseStorage storage,
    required String userId,
    required String sessionId,
    required String filePath,
    required bool isVideo,
    void Function(int progress)? onProgress,
  }) async {
    if (userId.isEmpty) throw StateError('userId is required.');
    if (sessionId.isEmpty) throw StateError('sessionId is required.');
    final file = File(filePath);
    final name = _sessionObjectName(
      userId: userId,
      sessionId: sessionId,
      filePath: filePath,
      isVideo: isVideo,
    );
    final ref = storage.ref(name);
    final task = ref.putFile(
      file,
      SettableMetadata(
        contentType: _contentTypeForPath(filePath, isVideo: isVideo),
      ),
    );
    StreamSubscription<TaskSnapshot>? progressSub;
    if (onProgress != null) {
      progressSub = task.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        if (total <= 0) return;
        final raw = (snapshot.bytesTransferred / total) * 100;
        final pct = raw.round().clamp(0, 100);
        onProgress(pct);
      });
    }
    try {
      final snap = await task;
      onProgress?.call(100);
      return snap.ref.getDownloadURL();
    } finally {
      await progressSub?.cancel();
    }
  }

  Future<String> _putSessionImageBytes({
    required FirebaseStorage storage,
    required String userId,
    required String sessionId,
    required Uint8List imageBytes,
    required String filePath,
    void Function(int progress)? onProgress,
  }) async {
    if (userId.isEmpty) throw StateError('userId is required.');
    if (sessionId.isEmpty) throw StateError('sessionId is required.');
    final name = _sessionObjectName(
      userId: userId,
      sessionId: sessionId,
      filePath: filePath,
      isVideo: false,
    );
    final ref = storage.ref(name);
    final task = ref.putData(
      imageBytes,
      SettableMetadata(
        contentType: _contentTypeForPath(filePath, isVideo: false),
      ),
    );
    StreamSubscription<TaskSnapshot>? progressSub;
    if (onProgress != null) {
      progressSub = task.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        if (total <= 0) return;
        final raw = (snapshot.bytesTransferred / total) * 100;
        final pct = raw.round().clamp(0, 100);
        onProgress(pct);
      });
    }
    try {
      final snap = await task;
      onProgress?.call(100);
      return snap.ref.getDownloadURL();
    } finally {
      await progressSub?.cancel();
    }
  }

  /// Uploads a session note image; returns the download URL.
  Future<String> uploadSessionPhoto({
    required String userId,
    required String sessionId,
    required String filePath,
    void Function(int progress)? onProgress,
  }) async {
    try {
      return await _putSessionFile(
        storage: _storageForPrimaryBucket(),
        userId: userId,
        sessionId: sessionId,
        filePath: filePath,
        isVideo: false,
        onProgress: onProgress,
      );
    } on FirebaseException catch (e) {
      if (_isParseResponseError(e)) {
        if (kDebugMode) {
          debugPrint(
            '[Storage] Session photo parse-response error, retrying once with '
            'default FirebaseStorage client…',
          );
        }
        return await _putSessionFile(
          storage: FirebaseStorage.instanceFor(app: Firebase.app()),
          userId: userId,
          sessionId: sessionId,
          filePath: filePath,
          isVideo: false,
          onProgress: onProgress,
        );
      }
      if (_isStorageBucketNotFound(e)) {
        return await _putSessionFile(
          storage: _storageForLegacyAppspotBucket(),
          userId: userId,
          sessionId: sessionId,
          filePath: filePath,
          isVideo: false,
          onProgress: onProgress,
        );
      }
      rethrow;
    }
  }

  /// Uploads a session note image using bytes (iOS-safe); returns the URL.
  Future<String> uploadSessionPhotoBytes({
    required String userId,
    required String sessionId,
    required Uint8List imageBytes,
    required String filePath,
    void Function(int progress)? onProgress,
  }) async {
    try {
      return await _putSessionImageBytes(
        storage: _storageForPrimaryBucket(),
        userId: userId,
        sessionId: sessionId,
        imageBytes: imageBytes,
        filePath: filePath,
        onProgress: onProgress,
      );
    } on FirebaseException catch (e) {
      if (_isParseResponseError(e)) {
        if (kDebugMode) {
          debugPrint(
            '[Storage] Session photo(bytes) parse-response error, retrying once '
            'with default FirebaseStorage client…',
          );
        }
        return await _putSessionImageBytes(
          storage: FirebaseStorage.instanceFor(app: Firebase.app()),
          userId: userId,
          sessionId: sessionId,
          imageBytes: imageBytes,
          filePath: filePath,
          onProgress: onProgress,
        );
      }
      if (_isStorageBucketNotFound(e)) {
        return await _putSessionImageBytes(
          storage: _storageForLegacyAppspotBucket(),
          userId: userId,
          sessionId: sessionId,
          imageBytes: imageBytes,
          filePath: filePath,
          onProgress: onProgress,
        );
      }
      rethrow;
    }
  }

  /// Uploads a session note video; returns the download URL.
  Future<String> uploadSessionVideo({
    required String userId,
    required String sessionId,
    required String filePath,
    void Function(int progress)? onProgress,
  }) async {
    try {
      return await _putSessionFile(
        storage: _storageForPrimaryBucket(),
        userId: userId,
        sessionId: sessionId,
        filePath: filePath,
        isVideo: true,
        onProgress: onProgress,
      );
    } on FirebaseException catch (e) {
      if (_isParseResponseError(e)) {
        if (kDebugMode) {
          debugPrint(
            '[Storage] Session video parse-response error, retrying once with '
            'default FirebaseStorage client…',
          );
        }
        return await _putSessionFile(
          storage: FirebaseStorage.instanceFor(app: Firebase.app()),
          userId: userId,
          sessionId: sessionId,
          filePath: filePath,
          isVideo: true,
          onProgress: onProgress,
        );
      }
      if (_isStorageBucketNotFound(e)) {
        return await _putSessionFile(
          storage: _storageForLegacyAppspotBucket(),
          userId: userId,
          sessionId: sessionId,
          filePath: filePath,
          isVideo: true,
          onProgress: onProgress,
        );
      }
      rethrow;
    }
  }
}
