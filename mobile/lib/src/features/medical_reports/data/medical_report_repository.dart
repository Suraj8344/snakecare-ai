import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/core/network/api_client.dart';
import 'package:snakecare_mobile/src/features/medical_reports/domain/medical_report.dart';

final medicalReportRepositoryProvider = Provider<MedicalReportRepository>(
  (ref) => MedicalReportRepository(ref.watch(dioProvider)),
);

class MedicalReportRepository {
  MedicalReportRepository(this._dio);
  final Dio _dio;

  Options _authorization(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<MedicalReportPage> search(
    String token, {
    String? query,
    String? category,
    String? contentType,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/medical-reports',
      queryParameters: {
        if (query?.trim().isNotEmpty == true) 'q': query!.trim(),
        if (category?.isNotEmpty == true) 'category': category,
        if (contentType?.isNotEmpty == true) 'content_type': contentType,
        'page_size': 100,
      },
      options: _authorization(token),
    );
    return MedicalReportPage.fromJson(response.data!);
  }

  Future<MedicalReport> upload(
    String token, {
    required String filename,
    required Uint8List bytes,
    required String title,
    String? reportDate,
    String? providerName,
    String? notes,
    String? category,
  }) async {
    final data = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      'title': title.trim(),
      if (reportDate?.isNotEmpty == true) 'report_date': reportDate,
      if (providerName?.trim().isNotEmpty == true)
        'provider_name': providerName!.trim(),
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
      if (category?.isNotEmpty == true) 'category': category,
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/medical-reports',
      data: data,
      options: _authorization(token),
    );
    return MedicalReport.fromJson(response.data!);
  }

  Future<void> delete(String token, String reportId) async {
    await _dio.delete<void>(
      '/api/v1/medical-reports/$reportId',
      options: _authorization(token),
    );
  }
}
