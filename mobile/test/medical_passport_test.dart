import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/features/medical_passport/data/medical_passport_repository.dart';
import 'package:snakecare_mobile/src/features/medical_passport/domain/medical_passport.dart';
import 'package:snakecare_mobile/src/features/medical_passport/presentation/medical_passport_screen.dart';

Map<String, dynamic> passportJson() => {
      'health_id': '11111111-2222-3333-4444-555555555555',
      'version': 1,
      'full_name': 'Patient Example',
      'date_of_birth': '1995-05-10',
      'biological_sex': 'not_disclosed',
      'blood_group': 'O+',
      'height_cm': 170,
      'weight_kg': 65,
      'preferred_language': 'English',
      'organ_donor': false,
      'insurance_provider': 'Example Health Insurance',
      'insurance_policy_number': 'POL-12345',
      'insurance_member_id': 'MEM-98765',
      'insurance_group_number': 'GRP-42',
      'insurance_plan_name': 'Emergency Plus',
      'insurance_valid_through': '2030-12-31',
      'insurance_emergency_phone': '+18005550199',
      'allergies': [
        {'allergen': 'Peanuts', 'reaction': 'Swelling', 'severity': 'severe'},
      ],
      'conditions': <dynamic>[],
      'medications': <dynamic>[],
      'emergency_contacts': <dynamic>[],
      'surgeries': [
        {
          'procedure': 'Appendectomy',
          'performed_on': '2020-02-10',
          'hospital': 'Example Hospital',
          'notes': null,
        },
      ],
      'family_history': [
        {
          'relationship': 'Father',
          'condition': 'Hypertension',
          'notes': null,
        },
      ],
    };

void main() {
  test('parses decimal measurements returned as PostgreSQL strings', () {
    final passport = MedicalPassport.fromJson({
      'health_id': '11111111-2222-3333-4444-555555555555',
      'version': 2,
      'full_name': 'Suraj Raut',
      'date_of_birth': '2007-04-02',
      'biological_sex': 'male',
      'blood_group': 'O+',
      'height_cm': '170.00',
      'weight_kg': '85.00',
      'preferred_language': 'English',
      'organ_donor': false,
      'allergies': <dynamic>[],
      'conditions': <dynamic>[],
      'medications': <dynamic>[],
      'emergency_contacts': <dynamic>[],
      'surgeries': <dynamic>[],
      'family_history': <dynamic>[],
    });

    expect(passport.heightCm, 170);
    expect(passport.weightKg, 85);
  });

  test('parses and serializes a patient-reported passport', () {
    final passport = MedicalPassport.fromJson(passportJson());
    expect(passport.bloodGroup, 'O+');
    expect(passport.insuranceProvider, 'Example Health Insurance');
    expect(passport.toUpdateJson()['insurance_member_id'], 'MEM-98765');
    expect(passport.surgeries.single.procedure, 'Appendectomy');
    expect(passport.familyHistory.single.condition, 'Hypertension');
    expect(passport.allergies.single.severity, 'severe');
    expect(passport.toUpdateJson()['version'], 1);
  });

  testWidgets('editor exposes core medical passport sections', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MedicalPassportEditor(
          initial: MedicalPassport.fromJson(passportJson()),
        ),
      ),
    );

    expect(find.text('Edit Medical Passport'), findsOneWidget);
    expect(find.text('Save information'), findsOneWidget);
    expect(find.byKey(const Key('passport_save_button')), findsOneWidget);
    expect(find.text('Blood group'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Insurance details'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Insurance details'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Allergies'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Allergies'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Emergency contacts'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Emergency contacts'), findsOneWidget);
    expect(find.text('Surgeries'), findsOneWidget);
    expect(find.text('Family history'), findsOneWidget);
  });

  testWidgets('passport header remains readable on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(349, 642);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicalPassportProvider('test-token').overrideWith(
            (ref) async => MedicalPassport.fromJson(passportJson()),
          ),
        ],
        child: const MaterialApp(
          home: MedicalPassportScreen(accessToken: 'test-token'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Patient Example'), findsOneWidget);
    expect(find.text('Edit information'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
