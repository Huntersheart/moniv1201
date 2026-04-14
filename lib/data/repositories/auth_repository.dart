import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../remote/auth_service.dart';

bool _isTransientFirestore(Object e) {
  if (e is FirebaseException) {
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'resource-exhausted':
        return true;
    }
  }
  final s = e.toString().toLowerCase();
  return s.contains('unavailable') || s.contains('deadline-exceeded');
}

Future<T> _retryTransient<T>(
  Future<T> Function() op, {
  int maxAttempts = 4,
}) async {
  Object? last;
  for (var i = 0; i < maxAttempts; i++) {
    try {
      return await op();
    } catch (e) {
      last = e;
      if (!_isTransientFirestore(e) || i == maxAttempts - 1) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 300 * (1 << i)));
    }
  }
  throw last!;
}

class AuthRepository {
  final AuthService _authService;

  AuthRepository(this._authService);

  // Getter — only accessed after Firebase.initializeApp() succeeds
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  User? get currentUser => _authService.currentUser;
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _getOrCreateUserDoc(credential.user!);
  }

  Future<UserModel> signUp({
    required String email,
    required String password,
  }) async {
    final credential = await _authService.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _getOrCreateUserDoc(credential.user!);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    await _authService.confirmPasswordReset(
      code: code,
      newPassword: newPassword,
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _authService.updatePassword(newPassword);
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// When Firestore is temporarily unavailable, returns null (use [fallbackUserFromAuth]).
  Future<UserModel?> getCurrentUserProfile() async {
    final user = _authService.currentUser;
    if (user == null) return null;
    try {
      final doc = await _retryTransient(() => _users.doc(user.uid).get());
      if (!doc.exists) return null;
      // Always use Auth uid so Firestore paths/queries match security rules.
      return UserModel.fromMap(doc.data()!).copyWith(uid: user.uid);
    } on FirebaseException catch (e) {
      if (_isTransientFirestore(e)) return null;
      rethrow;
    }
  }

  /// Offline-safe profile used when Firestore read fails or doc is missing.
  UserModel fallbackUserFromAuth(User firebaseUser) {
    final now = DateTime.now();
    return UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? '',
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateUserProfile(UserModel model) async {
    await _users.doc(model.uid).set(
          model.copyWith(updatedAt: DateTime.now()).toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await _users.doc(uid).set(
      {'fcmToken': token, 'updatedAt': Timestamp.now()},
      SetOptions(merge: true),
    );
  }

  Future<UserModel> _getOrCreateUserDoc(User firebaseUser) async {
    try {
      return await _retryTransient(() async {
        final docRef = _users.doc(firebaseUser.uid);
        final doc = await docRef.get();
        final now = DateTime.now();
        if (doc.exists) {
          final existing =
              UserModel.fromMap(doc.data()!).copyWith(uid: firebaseUser.uid);
          final merged = existing.copyWith(
            email: firebaseUser.email ?? existing.email,
            displayName: firebaseUser.displayName ?? existing.displayName,
            updatedAt: now,
            lastLoginAt: now,
          );
          await docRef.set(merged.toMap(), SetOptions(merge: true));
          return merged;
        }
        final model = UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? '',
          createdAt: now,
          updatedAt: now,
          lastLoginAt: now,
          role: 'pioneer',
        );
        await docRef.set(model.toMap());
        return model;
      });
    } catch (_) {
      return fallbackUserFromAuth(firebaseUser);
    }
  }
}
