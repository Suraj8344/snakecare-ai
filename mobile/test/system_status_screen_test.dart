import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/features/system_status/domain/service_status.dart';
import 'package:snakecare_mobile/src/features/system_status/presentation/system_status_controller.dart';
import 'package:snakecare_mobile/src/features/system_status/presentation/system_status_screen.dart';

void main() {
  testWidgets('renders healthy foundation state', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          systemStatusProvider.overrideWith(
            (Ref ref) async => const ServiceStatus(
              service: 'snakecare-api',
              status: 'ok',
              version: '0.1.0',
              readiness: 'ready',
              apiBaseUrl: 'http://127.0.0.1:8001',
            ),
          ),
        ],
        child: const MaterialApp(home: SystemStatusScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('All core services operational'), findsOneWidget);
    expect(find.text('API service'), findsOneWidget);
    expect(find.text('Database readiness'), findsOneWidget);
    expect(find.text('http://127.0.0.1:8001'), findsOneWidget);
  });
}
