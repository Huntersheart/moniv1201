import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dog_model.dart';

class DogRepository {
  // Getter — only accessed after Firebase.initializeApp() succeeds
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _dogs(String userId) =>
      _db.collection('users').doc(userId).collection('dogs');

  Stream<List<DogModel>> watchDogs(String userId) {
    return _dogs(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => DogModel.fromMap(d.data(), id: d.id)).toList());
  }

  Future<List<DogModel>> getDogs(String userId) async {
    final snap =
        await _dogs(userId).orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => DogModel.fromMap(d.data(), id: d.id)).toList();
  }

  Future<DogModel> addDog(DogModel dog) async {
    final ref = dog.dogId.isEmpty
        ? _dogs(dog.ownerId).doc()
        : _dogs(dog.ownerId).doc(dog.dogId);
    final now = DateTime.now();
    final updated = dog.copyWith(
      dogId: ref.id,
      createdAt: dog.dogId.isEmpty ? now : dog.createdAt,
      updatedAt: now,
    );
    await ref.set(updated.toMap());
    return updated;
  }

  Future<void> updateDog(DogModel dog) async {
    await _dogs(dog.ownerId).doc(dog.dogId).set(
          dog.copyWith(updatedAt: DateTime.now()).toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> deleteDog({
    required String userId,
    required String dogId,
  }) async {
    await _dogs(userId).doc(dogId).delete();
  }

  Future<DogModel?> getDog({
    required String userId,
    required String dogId,
  }) async {
    final doc = await _dogs(userId).doc(dogId).get();
    if (!doc.exists) return null;
    return DogModel.fromMap(doc.data()!, id: doc.id);
  }

  /// Live updates from `users/{userId}/dogs/{dogId}` (your Firestore “dogs” data).
  Stream<DogModel?> watchDog({
    required String userId,
    required String dogId,
  }) {
    return _dogs(userId).doc(dogId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DogModel.fromMap(doc.data()!, id: doc.id);
    });
  }
}
