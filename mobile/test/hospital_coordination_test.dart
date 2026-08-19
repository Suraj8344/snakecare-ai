import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/features/hospital_coordination/data/hospital_coordination_repository.dart';
import 'package:snakecare_mobile/src/features/hospital_coordination/domain/hospital_recommendation.dart';
import 'package:snakecare_mobile/src/features/hospital_coordination/presentation/hospital_coordination_landing_screen.dart';
import 'package:snakecare_mobile/src/features/hospital_coordination/presentation/hospital_recommendation_screen.dart';

HospitalRecommendationResult recommendationResult() =>
    HospitalRecommendationResult.fromJson({
      'notice': 'Call to confirm and do not delay transport.',
      'items': [
        {
          'rank': 1,
          'distance_km': 4.2,
          'score': 98.5,
          'score_components': {
            'proximity': 29.5,
            'fresh antivenom status': 25,
          },
          'reasons': [
            'Approximately 4.2 km away.',
            'A current snapshot reports antivenom available.',
          ],
          'warnings': ['Call the hospital to confirm before arrival.'],
          'ruleset_version': 'hospital-readiness-rules-v1',
          'hospital': {
            'id': '11111111-2222-3333-4444-555555555555',
            'managed_by_user_id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
            'hfr_id': 'HFR-TEST-1',
            'name': 'Verified Snakebite Centre',
            'address': '1 Health Road, Pune',
            'city': 'Pune',
            'state': 'Maharashtra',
            'latitude': 18.53,
            'longitude': 73.85,
            'emergency_phone': '+912000000000',
            'directions_url': 'https://maps.google.com/?q=18.53,73.85',
            'data_source': 'government_verified',
            'source_updated_at': '2026-08-08T08:00:00Z',
            'is_active': true,
            'capabilities': {
              'emergency_24x7': true,
              'snakebite_trained_staff': true,
              'can_administer_antivenom': true,
              'icu': true,
              'ventilator': true,
              'dialysis': true,
              'blood_bank': true,
              'data_source': 'government_verified',
              'verified_at': '2026-08-08T08:00:00Z',
            },
            'availability': {
              'id': '22222222-3333-4444-5555-666666666666',
              'antivenom_status': 'available',
              'antivenom_vials': 20,
              'emergency_beds': 4,
              'icu_beds': 2,
              'ventilators': 2,
              'data_source': 'hospital_reported',
              'recorded_at': '2099-08-08T08:00:00Z',
              'expires_at': '2099-08-08T09:00:00Z',
            },
          },
        },
      ],
    });

class FakeHospitalCoordinationRepository
    extends HospitalCoordinationRepository {
  FakeHospitalCoordinationRepository() : super(Dio());

  bool preAlertSent = false;
  bool resourceRequestSent = false;

  @override
  Future<HospitalDirectoryResult> listFacilities(
    String token, {
    String city = 'Pune',
    int limit = 50,
    String? search,
  }) async =>
      HospitalDirectoryResult(
        items: [recommendationResult().items.first.hospital],
        total: 715,
        sourceAttribution: 'OpenStreetMap contributors, ODbL 1.0',
        notice: 'Map identity only. Readiness is not verified.',
      );

  @override
  Future<HospitalRecommendationResult> recommend(
    String token, {
    required String emergencyId,
    double? latitude,
    double? longitude,
  }) async =>
      recommendationResult();

  @override
  Future<Map<String, dynamic>> createPreAlert(
    String token, {
    required String emergencyId,
    required String hospitalId,
    required bool shareSymptoms,
    required bool shareVitals,
    required bool shareLocation,
    required bool shareNotes,
  }) async {
    preAlertSent = true;
    return {'id': '33333333-4444-5555-6666-777777777777'};
  }

  @override
  Future<Map<String, dynamic>> createResourceRequest(
    String token, {
    required String preAlertId,
    required bool antivenom,
    required bool emergencyBed,
    required bool icu,
    required bool ventilator,
  }) async {
    resourceRequestSent = true;
    return {'id': '44444444-5555-6666-7777-888888888888'};
  }
}

void main() {
  test('builds directions from live origin to hospital coordinates', () {
    final hospital = recommendationResult().items.first.hospital;
    final uri = buildHospitalDirectionsUri(
      hospital,
      originLatitude: 18.5204,
      originLongitude: 73.8567,
    );

    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['origin'], '18.5204,73.8567');
    expect(uri.queryParameters['destination'], '18.53,73.85');
    expect(uri.queryParameters['travelmode'], 'driving');
  });

  testWidgets('shows a direct Module 6 hospital finder entry', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 2200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hospitalCoordinationRepositoryProvider.overrideWithValue(
            FakeHospitalCoordinationRepository(),
          ),
        ],
        child: const MaterialApp(
          home: HospitalCoordinationLandingScreen(accessToken: 'test-token'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hospital Finder'), findsOneWidget);
    expect(find.text('Find prepared hospitals'), findsOneWidget);
    expect(find.text('Nearby recommendations'), findsOneWidget);
    expect(find.text('Start emergency assessment'), findsOneWidget);
    expect(find.text('715 map-listed hospitals found'), findsOneWidget);
  });

  test('parses source, freshness, and explainability metadata', () {
    final result = recommendationResult();
    final hospital = result.items.first.hospital;
    expect(hospital.sourceLabel, 'Government verified');
    expect(hospital.availability?.stockLabel, 'Antivenom reported available');
    expect(result.items.first.scoreComponents['fresh antivenom status'], 25);
  });

  testWidgets('shows recommendation explanation and sends consented pre-alert',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 4000);
    addTearDown(tester.view.reset);
    final repository = FakeHospitalCoordinationRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hospitalCoordinationRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: HospitalRecommendationScreen(
            accessToken: 'test-token',
            emergencyId: 'emergency-id',
            latitude: 18.52,
            longitude: 73.85,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Verified Snakebite Centre'), findsOneWidget);
    expect(find.textContaining('Antivenom reported available'), findsOneWidget);
    expect(find.text('Why this hospital?'), findsOneWidget);
    expect(find.textContaining('Do not wait'), findsWidgets);

    await tester.tap(find.text('Send hospital pre-alert'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Choose exactly what'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Send pre-alert'));
    await tester.pumpAndSettle();

    expect(repository.preAlertSent, isTrue);
    expect(repository.resourceRequestSent, isTrue);
    expect(find.textContaining('Pre-alert saved as pending'), findsWidgets);
  });
}
