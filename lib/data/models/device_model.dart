import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceModel {
  final String deviceId;
  final String deviceLabel;
  final String ownerId;
  final String dogId;
  final String macAddress;
  final String firmwareVersion;
  final int batteryLevel;
  final bool isActive;
  final DateTime? lastSeen;
  final DateTime pairedAt;

  const DeviceModel({
    required this.deviceId,
    required this.deviceLabel,
    required this.ownerId,
    this.dogId = '',
    this.macAddress = '',
    this.firmwareVersion = '',
    this.batteryLevel = 100,
    this.isActive = true,
    this.lastSeen,
    required this.pairedAt,
  });

  String get batteryDisplay => '$batteryLevel%';

  factory DeviceModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return DeviceModel(
      deviceId: id ?? map['deviceId'] as String? ?? '',
      deviceLabel: map['deviceLabel'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      dogId: map['dogId'] as String? ?? '',
      macAddress: map['macAddress'] as String? ?? '',
      firmwareVersion: map['firmwareVersion'] as String? ?? '',
      batteryLevel: map['batteryLevel'] as int? ?? 100,
      isActive: map['isActive'] as bool? ?? true,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
      pairedAt: (map['pairedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceLabel': deviceLabel,
      'ownerId': ownerId,
      'dogId': dogId,
      'macAddress': macAddress,
      'firmwareVersion': firmwareVersion,
      'batteryLevel': batteryLevel,
      'isActive': isActive,
      if (lastSeen != null) 'lastSeen': Timestamp.fromDate(lastSeen!),
      'pairedAt': Timestamp.fromDate(pairedAt),
    };
  }

  DeviceModel copyWith({
    String? deviceId,
    String? deviceLabel,
    String? ownerId,
    String? dogId,
    String? macAddress,
    String? firmwareVersion,
    int? batteryLevel,
    bool? isActive,
    DateTime? lastSeen,
    DateTime? pairedAt,
  }) {
    return DeviceModel(
      deviceId: deviceId ?? this.deviceId,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      ownerId: ownerId ?? this.ownerId,
      dogId: dogId ?? this.dogId,
      macAddress: macAddress ?? this.macAddress,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isActive: isActive ?? this.isActive,
      lastSeen: lastSeen ?? this.lastSeen,
      pairedAt: pairedAt ?? this.pairedAt,
    );
  }
}
