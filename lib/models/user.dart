class User {
  final String uid;
  final String email;
  final String? displayName;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  const User({
    required this.uid,
    required this.email,
    this.displayName,
    required this.createdAt,
    required this.lastLoginAt,
  });

  factory User.fromJson(String uid, Map<String, dynamic> json) {
    return User(
      uid: uid,
      email: json['email'] ?? '',
      displayName: json['displayName'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      lastLoginAt: DateTime.fromMillisecondsSinceEpoch(json['lastLoginAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLoginAt': lastLoginAt.millisecondsSinceEpoch,
    };
  }

  String get firstName {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!.split(' ').first;
    }
    return email.split('@').first;
  }

  User copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
