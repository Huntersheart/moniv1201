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
  /// New sessions store Movement/Comfort/Energy on **1–10**; older docs used **1–3**.
  final bool metricsOneToTen;
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
    this.movement = 5,
    this.comfort = 5,
    this.energy = 5,
    this.metricsOneToTen = true,
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

  /// Display values for Movement / Comfort / Energy — always **1–10**, matching session log.
  int get movementScore10 => _metricDisplay10(movement);
  int get comfortScore10 => _metricDisplay10(comfort);
  int get energyScore10 => _metricDisplay10(energy);

  int _metricDisplay10(double v) {
    if (metricsOneToTen) {
      return v.round().clamp(1, 10);
    }
    // Legacy Firestore: 1–3 scale → align to same anchors as old summary (1→1, 2→5, 3→10).
    final c = v.clamp(1.0, 3.0);
    if (c <= 1.0) return 1;
    if (c >= 3.0) return 10;
    return 5;
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
        return 'Clear improvement';
      default:
        return 'No improvement';
    }
  }

  /// Overall Calming Effect (1–5): None … Strong.
  String get calmingEffectDisplayLabel {
    switch (calmingLevel.clamp(1, 5)) {
      case 1:
        return 'None';
      case 2:
        return 'Minimal';
      case 3:
        return 'Moderate';
      case 4:
        return 'Good';
      case 5:
        return 'Strong';
      default:
        return '—';
    }
  }

  /// Session summary: device line (collar builds use SIGNARA™ Collar).
  String get deviceDisplayName {
    final t = moduleType.toLowerCase();
    if (t == 'collar') return 'SIGNARA™ Collar';
    final d = deviceLabel.trim();
    if (d.isNotEmpty) return d;
    return '—';
  }

  /// Session summary: e.g. "Collar Session", "Vest Session".
  String get sessionTypeDisplay {
    switch (moduleType.toLowerCase()) {
      case 'collar':
        return 'Collar Session';
      case 'vest':
        return 'Vest Session';
      case 'hip':
        return 'Hip Session';
      case 'training':
        return 'Training Session';
      default:
        if (moduleType.isEmpty) return 'Session';
        return '${moduleType[0].toUpperCase()}${moduleType.substring(1)} Session';
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
      movement: (map['movement'] as num?)?.toDouble() ?? 5,
      comfort: (map['comfort'] as num?)?.toDouble() ?? 5,
      energy: (map['energy'] as num?)?.toDouble() ?? 5,
      metricsOneToTen: map['metricsOneToTen'] as bool? ?? false,
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
      'metricsOneToTen': metricsOneToTen,
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
    bool? metricsOneToTen,
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
      metricsOneToTen: metricsOneToTen ?? this.metricsOneToTen,
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
