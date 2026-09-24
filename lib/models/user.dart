class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String? token;
  final String? profileImage;
  final DateTime? createdAt;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.token,
    this.profileImage,
    this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'customer',
      token: json['token'],
      profileImage: json['profile_image'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'token': token,
      'profile_image': profileImage,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? role,
    String? token,
    String? profileImage,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      token: token ?? this.token,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}