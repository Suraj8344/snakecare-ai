enum UserRole {
  patient,
  doctor,
  hospitalAdmin,
  governmentAdmin,
}

UserRole parseRole(String value) => switch (value) {
      'doctor' => UserRole.doctor,
      'hospital_admin' => UserRole.hospitalAdmin,
      'government_admin' => UserRole.governmentAdmin,
      _ => UserRole.patient,
    };

class AuthUser {
  const AuthUser({
    required this.id,
    required this.role,
    this.name,
    this.email,
    this.hospitalEmployeeId,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        role: parseRole(json['role'] as String),
        name: json['display_name'] as String?,
        email: json['email'] as String?,
        hospitalEmployeeId: json['hospital_employee_id'] as String?,
      );

  final String id;
  final UserRole role;
  final String? name;
  final String? email;
  final String? hospitalEmployeeId;
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
}
