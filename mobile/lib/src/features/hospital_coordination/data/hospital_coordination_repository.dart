import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/core/network/api_client.dart';
import 'package:snakecare_mobile/src/features/hospital_coordination/domain/hospital_recommendation.dart';

final hospitalCoordinationRepositoryProvider =
    Provider<HospitalCoordinationRepository>(
  (ref) => HospitalCoordinationRepository(ref.watch(dioProvider)),
);

class HospitalCoordinationRepository {
  HospitalCoordinationRepository(this._dio);
  final Dio _dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<HospitalDirectoryResult> listFacilities(
    String token, {
    String city = 'Pune',
    int limit = 50,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/hospital-coordination/facilities',
      queryParameters: {
        'city': city,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
      options: _auth(token),
    );
    return HospitalDirectoryResult.fromJson(response.data!);
  }

  Future<HospitalRecommendationResult> recommend(
    String token, {
    required String emergencyId,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/hospital-coordination/recommendations',
      data: {
        'emergency_id': emergencyId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
      options: _auth(token),
    );
    return HospitalRecommendationResult.fromJson(response.data!);
  }

  Future<Map<String, dynamic>> createPreAlert(
    String token, {
    required String emergencyId,
    required String hospitalId,
    required bool shareSymptoms,
    required bool shareVitals,
    required bool shareLocation,
    required bool shareNotes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/hospital-coordination/pre-alerts',
      data: {
        'emergency_id': emergencyId,
        'hospital_id': hospitalId,
        'share_symptoms': shareSymptoms,
        'share_vitals': shareVitals,
        'share_location': shareLocation,
        'share_notes': shareNotes,
      },
      options: _auth(token),
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> createResourceRequest(
    String token, {
    required String preAlertId,
    required bool antivenom,
    required bool emergencyBed,
    required bool icu,
    required bool ventilator,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/hospital-coordination/resource-requests',
      data: {
        'pre_alert_id': preAlertId,
        'antivenom_readiness': antivenom,
        'emergency_bed': emergencyBed,
        'icu_readiness': icu,
        'ventilator_readiness': ventilator,
      },
      options: _auth(token),
    );
    return response.data!;
  }
}
