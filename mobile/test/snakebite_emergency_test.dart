import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/features/snakebite_emergency/data/snakebite_emergency_repository.dart';
import 'package:snakecare_mobile/src/features/snakebite_emergency/domain/snakebite_assessment.dart';
import 'package:snakecare_mobile/src/features/snakebite_emergency/presentation/snakebite_emergency_screen.dart';

SnakebiteAssessment criticalAssessment() => SnakebiteAssessment(
      id: '11111111-2222-3333-4444-555555555555',
      urgency: 'critical',
      symptoms: const ['breathing_difficulty'],
      explanation: const [
        'Breathing difficulty can indicate life-threatening paralysis.',
      ],
      immediateActions: const ['Call local emergency services now.'],
      firstAidSteps: offlineFirstAidSteps,
      actionsToAvoid: offlineActionsToAvoid,
      rulesetVersion: 'snakecare-safety-rules-v1',
      guidanceVersion: 'WHO-SEARO-MOHFW-2016',
      assessmentNotice:
          'Emergency decision support only. This is not a diagnosis.',
      photoAvailable: false,
    );

class FakeSnakebiteEmergencyRepository extends SnakebiteEmergencyRepository {
  FakeSnakebiteEmergencyRepository() : super(Dio());

  Map<String, dynamic>? submittedPayload;

  @override
  Future<SnakebiteAssessment> assess(
    String token, {
    required Map<String, dynamic> payload,
    Uint8List? photoBytes,
    String? photoFilename,
  }) async {
    submittedPayload = payload;
    return criticalAssessment();
  }
}

void main() {
  test('parses explainable urgency metadata', () {
    final result = SnakebiteAssessment.fromJson({
      'id': '11111111-2222-3333-4444-555555555555',
      'urgency': 'high_risk',
      'symptoms': ['rapidly_spreading_swelling'],
      'explanation': ['Rapid swelling needs urgent care.'],
      'immediate_actions': ['Arrange immediate transport.'],
      'first_aid_steps': ['Keep still.'],
      'actions_to_avoid': ['No tourniquet.'],
      'ruleset_version': 'snakecare-safety-rules-v1',
      'guidance_version': 'WHO-SEARO-MOHFW-2016',
      'assessment_notice': 'Not a diagnosis.',
      'photo_available': true,
      'latitude': 18.52,
      'longitude': 73.85,
    });
    expect(result.displayUrgency, 'High-risk warning signs');
    expect(result.explanation, isNotEmpty);
    expect(result.photoAvailable, isTrue);
  });

  testWidgets('shows symptoms, voice, photo, location, vitals, and first aid',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 5000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          snakebiteEmergencyRepositoryProvider.overrideWithValue(
            FakeSnakebiteEmergencyRepository(),
          ),
        ],
        child: const MaterialApp(
          home: SnakebiteEmergencyScreen(
            accessToken: 'test-token',
            showVideo: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Snakebite Emergency'), findsOneWidget);
    expect(find.text('Immediate first aid'), findsOneWidget);
    expect(find.textContaining('No tight tourniquet'), findsOneWidget);
    await tester.tap(find.text('Immediate first aid'));
    await tester.pumpAndSettle();

    final page = find
        .descendant(
          of: find.byKey(const Key('snakebite_form_scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Breathing difficulty'),
      350,
      scrollable: page,
    );
    expect(find.text('Breathing difficulty'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Start voice input'),
      350,
      scrollable: page,
    );
    expect(find.text('Start voice input'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Select photo to upload'),
      350,
      scrollable: page,
    );
    expect(find.text('Select photo to upload'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Use current location'),
      350,
      scrollable: page,
    );
    expect(find.text('Use current location'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('5. Vitals (optional)'),
      350,
      scrollable: page,
    );
    expect(find.text('5. Vitals (optional)'), findsOneWidget);
  });

  testWidgets('submits selected symptom and renders an explanation',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 5000);
    addTearDown(tester.view.reset);
    final repository = FakeSnakebiteEmergencyRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          snakebiteEmergencyRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: SnakebiteEmergencyScreen(
            accessToken: 'test-token',
            showVideo: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Immediate first aid'));
    await tester.pumpAndSettle();
    final page = find
        .descendant(
          of: find.byKey(const Key('snakebite_form_scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final symptom = find.text('Breathing difficulty');
    await tester.scrollUntilVisible(symptom, 350, scrollable: page);
    await tester.tap(symptom);
    await tester.pump();

    final submit = find.text('Assess urgency and save');
    await tester.scrollUntilVisible(submit, 500, scrollable: page);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repository.submittedPayload?['symptoms'], ['breathing_difficulty']);
    expect(find.text('Critical danger signs'), findsOneWidget);
    expect(find.text('Why this result'), findsOneWidget);
    expect(find.textContaining('life-threatening paralysis'), findsOneWidget);
    expect(find.textContaining('not a diagnosis'), findsOneWidget);
  });
}
