import 'package:cloud_firestore/cloud_firestore.dart';

class DogModel {
  final String dogId;
  final String ownerId;
  final String name;
  final String breed;
  final int ageMonths;
  final double weightLbs;
  final String gender;
  final String photoUrl;
  final String microchipId;
  final List<String> anxietyHistory;
  final List<String> mobilityHistory;
  final String healthNotes;
  final DateTime? vaccinationDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DogModel({
    required this.dogId,
    required this.ownerId,
    required this.name,
    this.breed = '',
    this.ageMonths = 0,
    this.weightLbs = 0.0,
    this.gender = 'Male',
    this.photoUrl = '',
    this.microchipId = '',
    this.anxietyHistory = const [],
    this.mobilityHistory = const [],
    this.healthNotes = '',
    this.vaccinationDate,
    required this.createdAt,
    required this.updatedAt,
  });

  String get ageDisplay {
    if (ageMonths <= 0) return '—';
    if (ageMonths < 12) return '$ageMonths ${ageMonths == 1 ? 'month' : 'months'}';
    final years = ageMonths ~/ 12;
    final months = ageMonths % 12;
    final yearStr = '$years ${years == 1 ? 'year' : 'years'}';
    if (months == 0) return yearStr;
    return '$yearStr $months ${months == 1 ? 'month' : 'months'}';
  }

  String get weightDisplay => '${weightLbs.toStringAsFixed(1)} lbs';

  factory DogModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return DogModel(
      dogId: id ?? map['dogId'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      breed: map['breed'] as String? ?? '',
      ageMonths: map['ageMonths'] as int? ?? 0,
      weightLbs: (map['weightLbs'] as num?)?.toDouble() ?? (map['weightKg'] as num?)?.toDouble() ?? 0.0,
      gender: map['gender'] as String? ?? 'Male',
      photoUrl: map['photoUrl'] as String? ?? '',
      microchipId: map['microchipId'] as String? ?? '',
      anxietyHistory: List<String>.from(map['anxietyHistory'] as List? ?? []),
      mobilityHistory: List<String>.from(map['mobilityHistory'] as List? ?? []),
      healthNotes: map['healthNotes'] as String? ?? '',
      vaccinationDate: (map['vaccinationDate'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dogId': dogId,
      'ownerId': ownerId,
      'name': name,
      'breed': breed,
      'ageMonths': ageMonths,
      'weightLbs': weightLbs,
      'gender': gender,
      'photoUrl': photoUrl,
      'microchipId': microchipId,
      'anxietyHistory': anxietyHistory,
      'mobilityHistory': mobilityHistory,
      'healthNotes': healthNotes,
      if (vaccinationDate != null)
        'vaccinationDate': Timestamp.fromDate(vaccinationDate!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  DogModel copyWith({
    String? dogId,
    String? ownerId,
    String? name,
    String? breed,
    int? ageMonths,
    double? weightLbs,
    String? gender,
    String? photoUrl,
    String? microchipId,
    List<String>? anxietyHistory,
    List<String>? mobilityHistory,
    String? healthNotes,
    DateTime? vaccinationDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DogModel(
      dogId: dogId ?? this.dogId,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      ageMonths: ageMonths ?? this.ageMonths,
      weightLbs: weightLbs ?? this.weightLbs,
      gender: gender ?? this.gender,
      photoUrl: photoUrl ?? this.photoUrl,
      microchipId: microchipId ?? this.microchipId,
      anxietyHistory: anxietyHistory ?? this.anxietyHistory,
      mobilityHistory: mobilityHistory ?? this.mobilityHistory,
      healthNotes: healthNotes ?? this.healthNotes,
      vaccinationDate: vaccinationDate ?? this.vaccinationDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
