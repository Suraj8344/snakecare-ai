import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/features/auth/domain/auth_session.dart';

void main() {
  test('parses a role-authoritative backend session', () {
    final session = AuthSession.fromJson({
      'access_token': 'access',
      'refresh_token': 'refresh',
      'user': {
        'id': 'user-id',
        'role': 'hospital_admin',
        'display_name': 'Hospital Lead',
        'email': 'lead@example.org',
      },
    });

    expect(session.user.role, UserRole.hospitalAdmin);
    expect(session.user.name, 'Hospital Lead');
  });
}
