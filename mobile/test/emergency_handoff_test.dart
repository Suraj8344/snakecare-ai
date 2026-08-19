import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/features/emergency_handoff/data/emergency_handoff_repository.dart';
import 'package:snakecare_mobile/src/features/emergency_handoff/domain/emergency_handoff.dart';
import 'package:snakecare_mobile/src/features/emergency_handoff/presentation/emergency_handoff_screen.dart';

EmergencyHandoff handoff(String status) => EmergencyHandoff(
      id: 'handoff-id',
      emergencyId: 'emergency-id',
      simulationOnly: true,
      status: status,
      responseStatus: status == 'countdown_active' ? 'confirmed' : 'unknown',
      countdownSeconds: 15,
      structuredSummary: const {'simulation_only': true},
    );

class FakeEmergencyHandoffRepository extends EmergencyHandoffRepository {
  FakeEmergencyHandoffRepository() : super(Dio());

  @override
  Future<EmergencyHandoff> create(
    String token, {
    required String emergencyId,
  }) async =>
      handoff('prepared');

  @override
  Future<EmergencyHandoff> action(
    String token,
    String handoffId,
    String action,
  ) async =>
      handoff(action == 'cancel' ? 'cancelled' : 'countdown_active');
}

void main() {
  test('selects an installed English speech voice with safe fallbacks', () {
    expect(
      selectPreferredSpeechLanguage(['hi-IN', 'en-US', 'en-IN']),
      'en-IN',
    );
    expect(
      selectPreferredSpeechLanguage(['fr-FR', 'en-AU']),
      'en-AU',
    );
    expect(selectPreferredSpeechLanguage(['hi-IN']), isNull);
  });

  test('parses simulation-only handoff state', () {
    final result = EmergencyHandoff.fromJson({
      'id': 'handoff-id',
      'emergency_id': 'emergency-id',
      'simulation_only': true,
      'status': 'prepared',
      'response_status': 'unknown',
      'countdown_seconds': 15,
      'structured_summary': {'simulation_only': true},
    });
    expect(result.simulationOnly, isTrue);
    expect(result.countdownSeconds, 15);
  });

  test('parses a Gemini-classified source-bound answer', () {
    final result = VoiceAssistantAnswer.fromJson({
      'question': 'location',
      'answer': 'Emergency location: Pune',
      'source': 'patient_reported_emergency',
      'missing': false,
      'simulation_only': true,
      'confidence': 0.93,
      'model': 'gemini-test',
      'audio_base64': 'UklGRg==',
      'audio_mime_type': 'audio/wav',
      'audio_model': 'gemini-tts-test',
    });
    expect(result.question, 'location');
    expect(result.confidence, 0.93);
    expect(result.answer, contains('Pune'));
    expect(result.audioBase64, 'UklGRg==');
    expect(result.audioMimeType, 'audio/wav');
  });

  testWidgets(
      'labels the feature as simulation and gates preparation on consent',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emergencyHandoffRepositoryProvider.overrideWithValue(
            FakeEmergencyHandoffRepository(),
          ),
        ],
        child: const MaterialApp(
          home: EmergencyHandoffScreen(
            accessToken: 'token',
            emergencyId: 'emergency-id',
          ),
        ),
      ),
    );

    expect(find.textContaining('SIMULATION ONLY'), findsOneWidget);
    expect(find.textContaining('will not call 112'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('prepare_handoff')))
          .onPressed,
      isNull,
    );

    for (var index = 0; index < 5; index++) {
      await tester.tap(find.byType(CheckboxListTile).at(index));
      await tester.pump();
    }
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('prepare_handoff')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('countdown can be cancelled without external contact',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emergencyHandoffRepositoryProvider.overrideWithValue(
            FakeEmergencyHandoffRepository(),
          ),
        ],
        child: const MaterialApp(
          home: EmergencyHandoffScreen(
            accessToken: 'token',
            emergencyId: 'emergency-id',
          ),
        ),
      ),
    );
    for (var index = 0; index < 5; index++) {
      await tester.tap(find.byType(CheckboxListTile).at(index));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('prepare_handoff')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 15-second rehearsal countdown'));
    await tester.pump();
    expect(
      find.textContaining('does not infer unconsciousness'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel countdown'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No external service was contacted'),
      findsOneWidget,
    );
  });
}
