import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String phoneNumber;
  final String avatarUrl;
  final bool isOnboardingComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Last successful app login (synced to Firestore on each sign-in).
  final DateTime? lastLoginAt;

  /// User role stored in Firestore. Supported values:
  ///   'admin'   → full access, sees all 3 modules in Start Session
  ///   'pioneer' → limited access, sees only SIGNARA™ Collar (default)
  final String role;

  bool get isAdmin => role == 'admin';
  bool get isPioneer => !isAdmin;

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.phoneNumber = '',
    this.avatarUrl = '',
    this.isOnboardingComplete = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    this.role = 'pioneer',
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String? ?? '',
      isOnboardingComplete: map['isOnboardingComplete'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp?)?.toDate(),
      role: map['role'] as String? ?? 'pioneer',
    );
  }

  /// Full map — used internally (e.g. admin writes, initial account creation).
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
      'isOnboardingComplete': isOnboardingComplete,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (lastLoginAt != null)
        'lastLoginAt': Timestamp.fromDate(lastLoginAt!),
      'role': role,
    };
  }

  /// Safe map for regular user self-updates — intentionally excludes `role`
  /// so a user can never accidentally overwrite the role field in Firestore.
  Map<String, dynamic> toMapForSelfUpdate() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
      'isOnboardingComplete': isOnboardingComplete,
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (lastLoginAt != null)
        'lastLoginAt': Timestamp.fromDate(lastLoginAt!),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? avatarUrl,
    bool? isOnboardingComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    String? role,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      role: role ?? this.role,
    );
  }
}
