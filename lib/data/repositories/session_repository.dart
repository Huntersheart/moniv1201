import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session_model.dart';

class SessionRepository {
  /// Fetch enough recent docs to find [limit] completed sessions after filtering.
  static const int _watchFetchCap = 200;
  static int _fetchCapForLimit(int limit) => (limit * 20).clamp(80, 400);

  // Getter — only accessed after Firebase.initializeApp() succeeds
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  static List<SessionModel> _completedNewestFirst(
    Iterable<SessionModel> items,
    int max,
  ) {
    return items.where((s) => s.status == 'completed').take(max).toList();
  }

  Future<SessionModel> createSession(SessionModel session) async {
    final ref = _sessions.doc();
    final now = DateTime.now();
    final updated = session.copyWith(
      sessionId: ref.id,
      startTime: now,
      createdAt: now,
      status: 'active',
    );
    await ref.set(updated.toMap());
    return updated;
  }

  Future<SessionModel> endSession({
    required String sessionId,
    required int durationSeconds,
    required double movement,
    required double comfort,
    required double energy,
    int vestStability = 3,
    int vestWeightBearing = 0,
    int vestPainSigns = 0,
    int hipMobility = 3,
    int hipPainSigns = 0,
    int hipSatStoodAlone = 0,
    required int limpLevel,
    required int responseLevel,
    required int calmingLevel,
    required String hapticPreset,
    required double intensity,
    required bool hapticOn,
    required String notes,
    String photoUrl = '',
    String videoUrl = '',
  }) async {
    final now = DateTime.now();
    await _sessions.doc(sessionId).update({
      'status': 'completed',
      'endTime': Timestamp.fromDate(now),
      'durationSeconds': durationSeconds,
      'metricsOneToTen': true,
      'movement': movement,
      'comfort': comfort,
      'energy': energy,
      'vestStability': vestStability,
      'vestWeightBearing': vestWeightBearing,
      'vestPainSigns': vestPainSigns,
      'hipMobility': hipMobility,
      'hipPainSigns': hipPainSigns,
      'hipSatStoodAlone': hipSatStoodAlone,
      'limpLevel': limpLevel,
      'responseLevel': responseLevel,
      'calmingLevel': calmingLevel,
      'hapticPreset': hapticPreset,
      'intensity': intensity,
      'hapticOn': hapticOn,
      'notes': notes,
      'photoUrl': photoUrl,
      'videoUrl': videoUrl,
    });
    final doc = await _sessions.doc(sessionId).get();
    return SessionModel.fromMap(doc.data()!, id: doc.id);
  }

  /// Uses a 2-field index (`userId` + `startTime`); filters `completed` in memory.
  Stream<List<SessionModel>> watchUserSessions(String userId) {
    return _sessions
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .limit(_watchFetchCap)
        .snapshots()
        .map(
          (snap) => _completedNewestFirst(
            snap.docs.map((d) => SessionModel.fromMap(d.data(), id: d.id)),
            100,
          ),
        );
  }

  Future<List<SessionModel>> getUserSessions(String userId,
      {int limit = 20}) async {
    final cap = _fetchCapForLimit(limit);
    final snap = await _sessions
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .limit(cap)
        .get();
    return _completedNewestFirst(
      snap.docs.map((d) => SessionModel.fromMap(d.data(), id: d.id)),
      limit,
    );
  }

  /// Uses a 2-field index (`dogId` + `startTime`); filters `completed` in memory.
  Future<List<SessionModel>> getDogSessions(String dogId,
      {int limit = 20}) async {
    final cap = _fetchCapForLimit(limit);
    final snap = await _sessions
        .where('dogId', isEqualTo: dogId)
        .orderBy('startTime', descending: true)
        .limit(cap)
        .get();
    return _completedNewestFirst(
      snap.docs.map((d) => SessionModel.fromMap(d.data(), id: d.id)),
      limit,
    );
  }

  Future<SessionModel?> getSession(String sessionId) async {
    final doc = await _sessions.doc(sessionId).get();
    if (!doc.exists) return null;
    return SessionModel.fromMap(doc.data()!, id: doc.id);
  }

  /// Live Firestore reads for a single session document (active or completed).
  Stream<SessionModel?> watchSession(String sessionId) {
    return _sessions.doc(sessionId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return SessionModel.fromMap(doc.data()!, id: doc.id);
    });
  }

  /// Merges live metrics into `sessions/{sessionId}` while `status` is still `active`.
  /// Called on an interval during [SessionLiveView] so Firebase always has the latest fields.
  Future<void> syncActiveSessionProgress({
    required String sessionId,
    required int durationSeconds,
    required double movement,
    required double comfort,
    required double energy,
    int vestStability = 3,
    int vestWeightBearing = 0,
    int vestPainSigns = 0,
    int hipMobility = 3,
    int hipPainSigns = 0,
    int hipSatStoodAlone = 0,
    required int limpLevel,
    required int responseLevel,
    required int calmingLevel,
    required String hapticPreset,
    required double intensity,
    required bool hapticOn,
    required String notes,
    String photoUrl = '',
    String videoUrl = '',
  }) async {
    await _sessions.doc(sessionId).set(
      {
        'durationSeconds': durationSeconds,
        'metricsOneToTen': true,
        'movement': movement,
        'comfort': comfort,
        'energy': energy,
        'vestStability': vestStability,
        'vestWeightBearing': vestWeightBearing,
        'vestPainSigns': vestPainSigns,
        'hipMobility': hipMobility,
        'hipPainSigns': hipPainSigns,
        'hipSatStoodAlone': hipSatStoodAlone,
        'limpLevel': limpLevel,
        'responseLevel': responseLevel,
        'calmingLevel': calmingLevel,
        'hapticPreset': hapticPreset,
        'intensity': intensity,
        'hapticOn': hapticOn,
        'notes': notes,
        'photoUrl': photoUrl,
        'videoUrl': videoUrl,
        'status': 'active',
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteSession(String sessionId) async {
    await _sessions.doc(sessionId).delete();
  }

  Future<void> deleteSessionsByDog({
    required String userId,
    required String dogId,
  }) async {
    if (userId.isEmpty || dogId.isEmpty) return;
    const int pageSize = 200;
    while (true) {
      final snap = await _sessions
          .where('userId', isEqualTo: userId)
          .where('dogId', isEqualTo: dogId)
          .limit(pageSize)
          .get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < pageSize) break;
    }
  }
}
