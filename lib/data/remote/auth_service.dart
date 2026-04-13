import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // Getter — only accessed after Firebase.initializeApp() succeeds
  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim();
    if (kIsWeb) {
      await _auth.sendPasswordResetEmail(email: trimmed);
      return;
    }
    await _auth.sendPasswordResetEmail(
      email: trimmed,
      actionCodeSettings: ActionCodeSettings(
        url: 'https://hunters-heart.firebaseapp.com/__/auth/action',
        handleCodeInApp: true,
        androidPackageName: 'com.example.slgnara_collar',
        androidInstallApp: true,
        androidMinimumVersion: '1',
        iOSBundleId: 'com.example.slgnaraCollar',
      ),
    );
  }

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    await _auth.confirmPasswordReset(
      code: code,
      newPassword: newPassword,
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _auth.currentUser?.updatePassword(newPassword);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }
}
