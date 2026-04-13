import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String sessionId;
  final String userId;
  final String dogId;
  /// Denormalized for Firestore queries / console; optional.
  final String dogName;
  final String deviceId;
  final String deviceLabel;
  final String moduleType;
  final String status;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;

  final double movement;
  final double comfort;
  final double energy;
  final int limpLevel;
  final int responseLevel;
  final int calmingLevel;
  final String hapticPreset;
  final double intensity;
  final bool hapticOn;
  final String notes;
  final String photoUrl;
  final String videoUrl;

  final DateTime createdAt;

  const SessionModel({
    required this.sessionId,
    required this.userId,
    required this.dogId,
    this.dogName = '',
    this.deviceId = '',
    this.deviceLabel = 'Collar',
    this.moduleType = 'training',
    this.status = 'active',
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.movement = 3,
    this.comfort = 3,
    this.energy = 3,
    this.limpLevel = 0,
    this.responseLevel = 0,
    this.calmingLevel = 3,
    this.hapticPreset = 'Calm',
    this.intensity = 3,
    this.hapticOn = true,
    this.notes = '',
    this.photoUrl = '',
    this.videoUrl = '',
    required this.createdAt,
  });

  String get durationDisplay {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  String get dateDisplay {
    final d = startTime;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  /// Session log sliders store **1–3**; summary UI uses **0–10**.
  int get movementScore10 => _metric1to3To10(movement);
  int get comfortScore10 => _metric1to3To10(comfort);
  int get energyScore10 => _metric1to3To10(energy);

  static int _metric1to3To10(double v) {
    final c = v.clamp(1.0, 3.0);
    return (((c - 1) / 2) * 10).round().clamp(0, 10);
  }

  /// Haptic intensity stored **1–3** → display as **/10** on summary.
  int get intensityScore10 {
    final c = intensity.clamp(1.0, 3.0);
    return ((c / 3) * 10).round().clamp(0, 10);
  }

  String get responseDisplayLabel {
    switch (responseLevel) {
      case 1:
        return 'Slight improvement';
      case 2:
        return 'Good improvement';
      default:
        return 'No change';
    }
  }

  String get limpDisplayLabel => limpLevel == 1 ? 'Limp present' : 'No limp';

  factory SessionModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return SessionModel(
      sessionId: id ?? map['sessionId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      dogId: map['dogId'] as String? ?? '',
      dogName: map['dogName'] as String? ?? '',
      deviceId: map['deviceId'] as String? ?? '',
      deviceLabel: map['deviceLabel'] as String? ?? 'Collar',
      moduleType: map['moduleType'] as String? ?? 'training',
      status: map['status'] as String? ?? 'active',
      startTime: (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (map['endTime'] as Timestamp?)?.toDate(),
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      movement: (map['movement'] as num?)?.toDouble() ?? 3,
      comfort: (map['comfort'] as num?)?.toDouble() ?? 3,
      energy: (map['energy'] as num?)?.toDouble() ?? 3,
      limpLevel: map['limpLevel'] as int? ?? 0,
      responseLevel: map['responseLevel'] as int? ?? 0,
      calmingLevel: map['calmingLevel'] as int? ?? 3,
      hapticPreset: map['hapticPreset'] as String? ?? 'Calm',
      intensity: (map['intensity'] as num?)?.toDouble() ?? 3,
      hapticOn: map['hapticOn'] as bool? ?? true,
      notes: map['notes'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      videoUrl: map['videoUrl'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'dogId': dogId,
      'dogName': dogName,
      'deviceId': deviceId,
      'deviceLabel': deviceLabel,
      'moduleType': moduleType,
      'status': status,
      'startTime': Timestamp.fromDate(startTime),
      if (endTime != null) 'endTime': Timestamp.fromDate(endTime!),
      'durationSeconds': durationSeconds,
      'movement': movement,
      'comfort': comfort,
      'energy': energy,
      'limpLevel': limpLevel,
      'responseLevel': responseLevel,
      'calmingLevel': calmingLevel,
      'hapticPreset': hapticPreset,
      'intensity': intensity,
      'hapticOn': hapticOn,
      'notes': notes,
      'photoUrl': photoUrl,
      'videoUrl': videoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  SessionModel copyWith({
    String? sessionId,
    String? userId,
    String? dogId,
    String? dogName,
    String? deviceId,
    String? deviceLabel,
    String? moduleType,
    String? status,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    double? movement,
    double? comfort,
    double? energy,
    int? limpLevel,
    int? responseLevel,
    int? calmingLevel,
    String? hapticPreset,
    double? intensity,
    bool? hapticOn,
    String? notes,
    String? photoUrl,
    String? videoUrl,
    DateTime? createdAt,
  }) {
    return SessionModel(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      dogId: dogId ?? this.dogId,
      dogName: dogName ?? this.dogName,
      deviceId: deviceId ?? this.deviceId,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      moduleType: moduleType ?? this.moduleType,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      movement: movement ?? this.movement,
      comfort: comfort ?? this.comfort,
      energy: energy ?? this.energy,
      limpLevel: limpLevel ?? this.limpLevel,
      responseLevel: responseLevel ?? this.responseLevel,
      calmingLevel: calmingLevel ?? this.calmingLevel,
      hapticPreset: hapticPreset ?? this.hapticPreset,
      intensity: intensity ?? this.intensity,
      hapticOn: hapticOn ?? this.hapticOn,
      notes: notes ?? this.notes,
      photoUrl: photoUrl ?? this.photoUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
