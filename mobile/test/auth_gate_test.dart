import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/features/auth/domain/auth_session.dart';
import 'package:snakecare_mobile/src/features/auth/presentation/auth_gate.dart';

void main() {
  testWidgets('shows safe Firebase setup state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthGate())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to SnakeCare'), findsOneWidget);
    expect(
      find.textContaining('Authentication setup is required'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
      isNull,
    );
  });

  testWidgets('shows the restricted hospital operations entry to patients', (
    tester,
  ) async {
    const session = AuthSession(
      accessToken: 'test-access-token',
      refreshToken: 'test-refresh-token',
      user: AuthUser(
        id: 'patient-1',
        role: UserRole.patient,
        email: 'patient@example.com',
      ),
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RoleHomeScreen(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Hospital Operations (restricted)'),
      findsOneWidget,
    );
  });

  testWidgets('shows staff management to government administrators', (
    tester,
  ) async {
    const session = AuthSession(
      accessToken: 'government-access-token',
      refreshToken: 'government-refresh-token',
      user: AuthUser(
        id: 'government-admin-1',
        role: UserRole.governmentAdmin,
        email: 'admin@example.gov',
      ),
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RoleHomeScreen(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manage Users & Hospital Staff'), findsOneWidget);
    expect(find.text('Review Hospital Claims'), findsOneWidget);
    expect(find.textContaining('Ambulance'), findsNothing);
  });
}
