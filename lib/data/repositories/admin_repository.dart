import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session_model.dart';
import '../models/user_model.dart';

/// Admin-only repository.
/// All writes are intentionally guarded by Firestore Rules server-side
/// (only documents where role == 'admin' may call these).
class AdminRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  // ── Users ──────────────────────────────────────────────────────────────────

  /// Returns all user profiles ordered by creation date (newest first).
  Future<List<UserModel>> getAllUsers() async {
    final snap = await _users.orderBy('createdAt', descending: true).get();
    return snap.docs.map((doc) {
      return UserModel.fromMap(doc.data()).copyWith(uid: doc.id);
    }).toList();
  }

  /// Live stream of all user profiles — rebuilds whenever any profile changes.
  Stream<List<UserModel>> watchAllUsers() {
    return _users
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              return UserModel.fromMap(doc.data()).copyWith(uid: doc.id);
            }).toList());
  }

  /// Sets [role] for [uid]. Only 'admin' or 'pioneer' are valid values.
  Future<void> setUserRole(String uid, String role) async {
    assert(role == 'admin' || role == 'pioneer',
        'Role must be admin or pioneer');
    await _users.doc(uid).update({
      'role': role,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── Sessions ───────────────────────────────────────────────────────────────

  /// Returns all sessions across all users, ordered by start time (newest first).
  Future<List<SessionModel>> getAllSessions({int limit = 100}) async {
    final snap = await _sessions
        .orderBy('startTime', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((doc) {
      return SessionModel.fromMap(doc.data()).copyWith(sessionId: doc.id);
    }).toList();
  }

  /// Live stream of all sessions (newest first, capped at [limit]).
  Stream<List<SessionModel>> watchAllSessions({int limit = 100}) {
    return _sessions
        .orderBy('startTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              return SessionModel.fromMap(doc.data())
                  .copyWith(sessionId: doc.id);
            }).toList());
  }

  /// Sessions for a specific user.
  Future<List<SessionModel>> getSessionsForUser(String userId) async {
    final snap = await _sessions
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .get();
    return snap.docs.map((doc) {
      return SessionModel.fromMap(doc.data()).copyWith(sessionId: doc.id);
    }).toList();
  }
}
