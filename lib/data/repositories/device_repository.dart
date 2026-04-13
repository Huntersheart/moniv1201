import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/device_model.dart';

class DeviceRepository {
  // Getter — only accessed after Firebase.initializeApp() succeeds
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _devices =>
      _db.collection('devices');

  Stream<List<DeviceModel>> watchUserDevices(String userId) {
    return _devices
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DeviceModel.fromMap(d.data(), id: d.id))
            .toList());
  }

  Future<List<DeviceModel>> getUserDevices(String userId) async {
    final snap = await _devices.where('ownerId', isEqualTo: userId).get();
    return snap.docs
        .map((d) => DeviceModel.fromMap(d.data(), id: d.id))
        .toList();
  }

  Future<DeviceModel> addDevice(DeviceModel device) async {
    final ref = _devices.doc();
    final updated = device.copyWith(deviceId: ref.id);
    await ref.set(updated.toMap());
    return updated;
  }

  Future<void> updateDevice(DeviceModel device) async {
    await _devices
        .doc(device.deviceId)
        .set(device.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteDevice(String deviceId) async {
    await _devices.doc(deviceId).delete();
  }

  Future<void> linkDeviceToDog({
    required String deviceId,
    required String dogId,
  }) async {
    await _devices.doc(deviceId).update({'dogId': dogId});
  }

  Future<void> updateBattery({
    required String deviceId,
    required int batteryLevel,
  }) async {
    await _devices.doc(deviceId).update({
      'batteryLevel': batteryLevel,
      'lastSeen': Timestamp.now(),
    });
  }
}
