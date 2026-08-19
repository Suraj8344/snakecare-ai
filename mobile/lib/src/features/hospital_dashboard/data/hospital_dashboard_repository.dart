import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/core/network/api_client.dart';
import 'package:snakecare_mobile/src/features/hospital_coordination/domain/hospital_recommendation.dart';
import 'package:snakecare_mobile/src/features/hospital_dashboard/domain/hospital_dashboard.dart';

final hospitalDashboardRepositoryProvider =
    Provider<HospitalDashboardRepository>(
  (ref) => HospitalDashboardRepository(ref.watch(dioProvider)),
);

class HospitalDashboardRepository {
  HospitalDashboardRepository(this._dio);
  final Dio _dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<HospitalDashboardData> dashboard(String token) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/hospital-dashboard/me',
      options: _auth(token),
    );
    return HospitalDashboardData.fromJson(response.data!);
  }

  Future<List<HospitalClaim>> myClaims(String token) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/hospital-dashboard/claims/me',
      options: _auth(token),
    );
    return response.data!
        .map(
          (value) => HospitalClaim.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList();
  }

  Future<List<HospitalClaim>> pendingClaims(String token) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/hospital-dashboard/claims/pending',
      options: _auth(token),
    );
    return response.data!
        .map(
          (value) => HospitalClaim.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList();
  }

  Future<List<HospitalFacility>> searchFacilities(
    String token,
    String search,
  ) async {
    Future<List<HospitalFacility>> request(String query) async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/hospital-coordination/facilities',
        queryParameters: {
          'city': 'Pune',
          if (query.isNotEmpty) 'search': query,
          'limit': 50,
        },
        options: _auth(token),
      );
      return (response.data!['items'] as List<dynamic>)
          .map(
            (value) => HospitalFacility.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList();
    }

    final query = search.trim();
    final exact = await request(query);
    if (query.isEmpty || exact.isNotEmpty) return exact;

    // The directory is intentionally small and cached for offline use. If the
    // API's exact substring search finds nothing, recover common omitted-vowel
    // spellings such as "Bharti" for "Bharati" locally.
    final all = await request('');
    final key = _hospitalSearchKey(query);
    return all
        .where((facility) => matchesHospitalSearch(facility, key))
        .toList();
  }

  Future<HospitalClaim> submitClaim(
    String token, {
    required String facilityId,
    required String evidenceReference,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/hospital-dashboard/claims',
      data: {
        'facility_id': facilityId,
        'verification_method': 'hfr_or_official_documents',
        'evidence_reference': evidenceReference,
      },
      options: _auth(token),
    );
    return HospitalClaim.fromJson(response.data!);
  }

  Future<void> decideClaim(String token, String id, bool approve) async {
    await _dio.post<void>(
      '/api/v1/hospital-dashboard/claims/$id/decision',
      data: {'approve': approve},
      options: _auth(token),
    );
  }

  Future<void> decideInbox(
    String token, {
    required String kind,
    required String id,
    required bool approve,
  }) async {
    await _dio.post<void>(
      '/api/v1/hospital-dashboard/$kind/$id/decision',
      data: {'status': approve ? 'accepted' : 'rejected'},
      options: _auth(token),
    );
  }

  Future<void> publishAvailability(
    String token, {
    int? emergencyBeds,
    int? icuBeds,
    int? ventilators,
  }) async {
    await _dio.post<void>(
      '/api/v1/hospital-dashboard/availability',
      data: {
        'emergency_beds': emergencyBeds,
        'icu_beds': icuBeds,
        'ventilators': ventilators,
        'expires_in_minutes': 30,
      },
      options: _auth(token),
    );
  }

  Future<AntivenomBoxRecord> registerBox(
    String token, {
    required String boxSerial,
    required String productName,
    required String manufacturer,
    required String batchNumber,
    required DateTime expiryDate,
    required int initialVials,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/hospital-dashboard/antivenom-boxes',
      data: {
        'box_serial': boxSerial,
        'product_name': productName,
        'manufacturer': manufacturer,
        'batch_number': batchNumber,
        'expiry_date': expiryDate.toIso8601String().split('T').first,
        'initial_vials': initialVials,
      },
      options: _auth(token),
    );
    return AntivenomBoxRecord.fromJson(response.data!);
  }

  Future<DepletionRequestRecord> scanBox(
    String token,
    String qrToken,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/hospital-dashboard/antivenom-scans',
      data: {'qr_token': qrToken},
      options: _auth(token),
    );
    return DepletionRequestRecord.fromJson(response.data!);
  }

  Future<void> decideDepletion(
    String token,
    String id,
    bool approve,
  ) async {
    await _dio.post<void>(
      '/api/v1/hospital-dashboard/antivenom-depletions/$id/decision',
      data: {'approve': approve},
      options: _auth(token),
    );
  }
}

String _hospitalSearchKey(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[aeiou]'), '')
    .replaceAll(RegExp('[^a-z0-9]'), '');

bool matchesHospitalSearch(HospitalFacility facility, String search) {
  final key = _hospitalSearchKey(search);
  final candidate = _hospitalSearchKey('${facility.name} ${facility.address}');
  return candidate.contains(key) || key.contains(candidate);
}
