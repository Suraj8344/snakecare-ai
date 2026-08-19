import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/core/network/api_client.dart';
import 'package:snakecare_mobile/src/features/emergency_handoff/domain/emergency_handoff.dart';

final emergencyHandoffRepositoryProvider = Provider<EmergencyHandoffRepository>(
  (ref) => EmergencyHandoffRepository(ref.watch(dioProvider)),
);

class EmergencyHandoffRepository {
  EmergencyHandoffRepository(this._dio);
  final Dio _dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<EmergencyHandoff> create(
    String token, {
    required String emergencyId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/emergency-handoffs',
      data: {
        'emergency_id': emergencyId,
        'countdown_seconds': 15,
        'consent_identity': true,
        'consent_location': true,
        'consent_emergency_summary': true,
        'consent_medical_passport': true,
        'consent_voice_assistance': true,
      },
      options: _auth(token),
    );
    return EmergencyHandoff.fromJson(response.data!);
  }

  Future<EmergencyHandoff> get(String token, String handoffId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/emergency-handoffs/$handoffId',
      options: _auth(token),
    );
    return EmergencyHandoff.fromJson(response.data!);
  }

  Future<EmergencyHandoff> action(
    String token,
    String handoffId,
    String action,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/emergency-handoffs/$handoffId/$action',
      options: _auth(token),
    );
    return EmergencyHandoff.fromJson(response.data!);
  }

  Future<SimulatedOperatorAnswer> simulate(
    String token,
    String handoffId,
    String question,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/emergency-handoffs/$handoffId/simulate',
      data: {'question': question},
      options: _auth(token),
    );
    return SimulatedOperatorAnswer.fromJson(response.data!);
  }

  Future<VoiceAssistantAnswer> askVoiceAssistant(
    String token,
    String handoffId,
    String transcript,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/emergency-handoffs/$handoffId/voice-assistant',
      data: {'transcript': transcript},
      options: _auth(token).copyWith(
        receiveTimeout: const Duration(seconds: 80),
      ),
    );
    return VoiceAssistantAnswer.fromJson(response.data!);
  }
}
