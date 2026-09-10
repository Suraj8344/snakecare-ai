import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/core/config/app_config.dart';
import 'package:snakecare_mobile/src/features/auth/presentation/auth_gate.dart';

void main() {
  testWidgets('authority website hides mobile account interfaces',
      (tester) async {
    if (!AppConfig.staffWebOnly) return;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LoginScreen(
            selectedRole: null,
            onRoleSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Hospital Authority'), findsOneWidget);
    expect(find.text('Government Authority'), findsOneWidget);
    expect(find.text('Patient'), findsNothing);
    expect(find.text('Doctor'), findsNothing);
    expect(find.text('Ambulance Driver'), findsNothing);
  });
}
