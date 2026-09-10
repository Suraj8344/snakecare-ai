import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/features/auth/domain/auth_session.dart';
import 'package:snakecare_mobile/src/features/auth/presentation/auth_gate.dart';

void main() {
  for (final role in UserRole.values) {
    testWidgets('home isolates ${role.name} tools', (tester) async {
      final session = AuthSession(
        accessToken: 'test',
        refreshToken: 'test',
        user: AuthUser(id: 'test', role: role),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: RoleHomeScreen(session: session)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Emergency Center'),
        role == UserRole.patient ? findsOneWidget : findsNothing,
      );
      expect(
        find.byIcon(Icons.folder_copy_outlined),
        role == UserRole.patient ? findsOneWidget : findsNothing,
      );
      expect(find.text('Driver • Registration & My trips'), findsNothing);
      expect(find.text('Registration & My trips'), findsNothing);
      expect(
        find.text('Track my ambulance'),
        role == UserRole.patient ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('driver home has no patient or authority tools', (tester) async {
    const session = AuthSession(
      accessToken: 'test',
      refreshToken: 'test',
      user: AuthUser(id: 'driver', role: UserRole.patient),
    );
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RoleHomeScreen(session: session, driverPortal: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Registration & My trips'), findsOneWidget);
    expect(find.text('Emergency Center'), findsNothing);
    expect(find.text('Track my ambulance'), findsNothing);
    expect(find.text('Manage ambulances'), findsNothing);
    expect(find.byIcon(Icons.folder_copy_outlined), findsNothing);
  });

  testWidgets('shows safe Firebase setup state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthGate())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to SnakeCare'), findsOneWidget);
    expect(find.text('Patient'), findsOneWidget);
    expect(find.text('Hospital Authority'), findsOneWidget);
    expect(find.text('Government Authority'), findsOneWidget);
    expect(
      find.textContaining('Authentication setup is required'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
      isNull,
    );
  });

  testWidgets('hides hospital operations from patients even via module preview',
      (
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
        child: MaterialApp(
          home: RoleHomeScreen(session: session, modulePreview: '7'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Hospital Operations (restricted)'),
      findsNothing,
    );
    expect(find.text('Patient history and summary'), findsNothing);
  });

  testWidgets('doctor sees patient history entry', (tester) async {
    const session = AuthSession(
      accessToken: 'test-access-token',
      refreshToken: 'test-refresh-token',
      user: AuthUser(
        id: 'doctor-1',
        role: UserRole.doctor,
        email: 'doctor@example.com',
      ),
    );
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RoleHomeScreen(session: session)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Patient history and summary'), findsOneWidget);
  });

  testWidgets('does not grant an authority interface from portal selection', (
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
      ProviderScope(
        child: MaterialApp(
          home: RoleAccessMismatchScreen(
            session: session,
            requestedRole: UserRole.hospitalAdmin,
            onUseAssignedRole: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Hospital Authority access is not assigned'),
      findsOneWidget,
    );
    expect(find.text('Open Patient interface'), findsOneWidget);
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
    expect(find.text('Manage ambulances'), findsOneWidget);
  });
}
