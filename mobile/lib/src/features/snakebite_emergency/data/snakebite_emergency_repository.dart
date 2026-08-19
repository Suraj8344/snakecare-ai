import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/core/network/api_client.dart';
import 'package:snakecare_mobile/src/features/snakebite_emergency/domain/snakebite_assessment.dart';

final snakebiteEmergencyRepositoryProvider =
    Provider<SnakebiteEmergencyRepository>(
  (ref) => SnakebiteEmergencyRepository(ref.watch(dioProvider)),
);

class SnakebiteEmergencyRepository {
  SnakebiteEmergencyRepository(this._dio);
  final Dio _dio;

  Future<SnakebiteAssessment> assess(
    String token, {
    required Map<String, dynamic> payload,
    Uint8List? photoBytes,
    String? photoFilename,
  }) async {
    final form = FormData.fromMap({
      'payload': jsonEncode(payload),
      if (photoBytes != null)
        'photo': MultipartFile.fromBytes(
          photoBytes,
          filename: photoFilename ?? 'snakebite-photo.jpg',
        ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/snakebite-emergencies',
      data: form,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return SnakebiteAssessment.fromJson(response.data!);
  }
}
