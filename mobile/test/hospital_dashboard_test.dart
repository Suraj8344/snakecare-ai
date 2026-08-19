import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/features/auth/domain/auth_session.dart';
import 'package:snakecare_mobile/src/features/hospital_coordination/domain/hospital_recommendation.dart';
import 'package:snakecare_mobile/src/features/hospital_dashboard/data/hospital_dashboard_repository.dart';
import 'package:snakecare_mobile/src/features/hospital_dashboard/domain/hospital_dashboard.dart';
import 'package:snakecare_mobile/src/features/hospital_dashboard/presentation/hospital_dashboard_screen.dart';

HospitalDashboardData dashboardData() => HospitalDashboardData.fromJson({
      'facility': {
        'id': '11111111-2222-3333-4444-555555555555',
        'managed_by_user_id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'hfr_id': 'HFR-TEST-1',
        'name': 'Connected Pune Hospital',
        'address': '1 Health Road, Pune',
        'city': 'Pune',
        'state': 'Maharashtra',
        'latitude': 18.53,
        'longitude': 73.85,
        'emergency_phone': '+912000000000',
        'directions_url': null,
        'data_source': 'hospital_reported',
        'source_updated_at': '2026-08-08T08:00:00Z',
        'is_active': true,
        'capabilities': {
          'emergency_24x7': true,
          'snakebite_trained_staff': true,
          'can_administer_antivenom': true,
          'icu': true,
          'ventilator': true,
          'dialysis': false,
          'blood_bank': false,
          'data_source': 'hospital_reported',
          'verified_at': '2026-08-08T08:00:00Z',
        },
        'availability': {
          'id': '22222222-3333-4444-5555-666666666666',
          'antivenom_status': 'available',
          'antivenom_vials': 10,
          'emergency_beds': 3,
          'icu_beds': 1,
          'ventilators': 1,
          'data_source': 'hospital_reported',
          'recorded_at': '2026-08-08T08:00:00Z',
          'expires_at': '2099-08-08T09:00:00Z',
        },
      },
      'availability': null,
      'pre_alerts': <dynamic>[],
      'resource_requests': <dynamic>[],
      'boxes': [
        {
          'id': '33333333-4444-5555-6666-777777777777',
          'facility_id': '11111111-2222-3333-4444-555555555555',
          'box_serial': 'BOX-001',
          'product_name': 'Polyvalent Antivenom',
          'manufacturer': 'Example Manufacturer',
          'batch_number': 'BATCH-001',
          'expiry_date': '2030-12-31',
          'initial_vials': 10,
          'available_vials': 10,
          'status': 'active',
          'depleted_at': null,
          'created_at': '2026-08-08T08:00:00Z',
        },
      ],
      'depletion_requests': [
        {
          'id': '44444444-5555-6666-7777-888888888888',
          'box_id': '33333333-4444-5555-6666-777777777777',
          'facility_id': '11111111-2222-3333-4444-555555555555',
          'scanned_by_user_id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
          'requested_used_vials': 10,
          'status': 'pending',
          'reviewer_user_id': null,
          'review_note': null,
          'reviewed_at': null,
          'created_at': '2026-08-08T08:00:00Z',
        },
      ],
    });

class FakeHospitalDashboardRepository extends HospitalDashboardRepository {
  FakeHospitalDashboardRepository() : super(Dio());

  @override
  Future<HospitalDashboardData> dashboard(String token) async =>
      dashboardData();

  @override
  Future<List<HospitalClaim>> pendingClaims(String token) async => [
        const HospitalClaim(
          id: 'claim-id',
          facilityId: 'facility-id',
          status: 'pending',
          verificationMethod: 'hfr_or_official_documents',
          evidenceReference: 'HFR-PROOF-001',
          facilityName: 'Pune Government Hospital',
          requesterEmail: 'manager@hospital.example',
        ),
      ];
}

void main() {
  test('hospital search tolerates a commonly omitted vowel', () {
    final facility = HospitalFacility.fromJson({
      'id': '11111111-2222-3333-4444-555555555555',
      'name': 'Bharati Hospital',
      'address': 'Dhankawadi, Pune',
      'city': 'Pune',
      'state': 'Maharashtra',
      'latitude': 18.46,
      'longitude': 73.86,
      'data_source': 'review_seed',
      'source_updated_at': '2026-08-18T00:00:00Z',
      'is_active': true,
      'is_connected_to_snakecare': false,
      'capabilities': {
        'emergency_24x7': false,
        'snakebite_trained_staff': false,
        'can_administer_antivenom': false,
        'icu': false,
        'ventilator': false,
        'dialysis': false,
        'blood_bank': false,
        'data_source': 'unverified',
        'verified_at': null,
      },
      'availability': null,
      'distance_km': null,
      'source_label': 'Review directory · unverified',
      'freshness_label': 'Not independently verified',
    });

    expect(matchesHospitalSearch(facility, 'bharti hospital'), isTrue);
  });

  test('builds a Module 7 scan URL without placing stock data in it', () {
    final uri = buildAntivenomQrUri('secure-random-token');
    expect(uri.queryParameters['module'], '7');
    expect(uri.queryParameters['antivenom_token'], 'secure-random-token');
    expect(uri.queryParameters.containsKey('vials'), isFalse);
    expect(uri.queryParameters.containsKey('batch'), isFalse);
  });

  testWidgets('hospital dashboard shows inventory and pending approval',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hospitalDashboardRepositoryProvider.overrideWithValue(
            FakeHospitalDashboardRepository(),
          ),
        ],
        child: const MaterialApp(
          home: HospitalDashboardScreen(
            accessToken: 'token',
            role: UserRole.hospitalAdmin,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connected Pune Hospital'), findsOneWidget);
    expect(find.text('Antivenom box inventory'), findsOneWidget);
    expect(find.textContaining('Polyvalent Antivenom'), findsOneWidget);
    expect(find.text('Approve stock update'), findsOneWidget);
  });

  testWidgets('government dashboard exposes claim review controls',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hospitalDashboardRepositoryProvider.overrideWithValue(
            FakeHospitalDashboardRepository(),
          ),
        ],
        child: const MaterialApp(
          home: HospitalDashboardScreen(
            accessToken: 'token',
            role: UserRole.governmentAdmin,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pune Government Hospital'), findsOneWidget);
    expect(find.text('Approve connection'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });
}
