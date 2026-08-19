import 'package:snakecare_mobile/src/features/auth/domain/auth_session.dart';

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.role,
    required this.emailVerified,
    required this.status,
    this.displayName,
    this.email,
    this.phoneNumber,
    this.hospitalEmployeeId,
  });

  factory ManagedUser.fromJson(Map<String, dynamic> json) => ManagedUser(
        id: json['id'] as String,
        role: parseRole(json['role'] as String),
        emailVerified: json['email_verified'] as bool? ?? false,
        status: json['status'] as String? ?? 'active',
        displayName: json['display_name'] as String?,
        email: json['email'] as String?,
        phoneNumber: json['phone_number'] as String?,
        hospitalEmployeeId: json['hospital_employee_id'] as String?,
      );

  final String id;
  final UserRole role;
  final bool emailVerified;
  final String status;
  final String? displayName;
  final String? email;
  final String? phoneNumber;
  final String? hospitalEmployeeId;

  String get identity =>
      displayName ??
      email ??
      phoneNumber ??
      'SnakeCare user ${id.substring(0, 8)}';
}
