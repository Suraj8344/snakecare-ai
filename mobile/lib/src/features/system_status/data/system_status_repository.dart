import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/core/network/api_client.dart';
import 'package:snakecare_mobile/src/core/config/app_config.dart';
import 'package:snakecare_mobile/src/features/system_status/domain/service_status.dart';

abstract interface class SystemStatusRepository {
  Future<ServiceStatus> getHealth();
}

class DioSystemStatusRepository implements SystemStatusRepository {
  const DioSystemStatusRepository(this._dio);

  final Dio _dio;

  @override
  Future<ServiceStatus> getHealth() async {
    final Response<Map<String, Object?>> response =
        await _dio.get<Map<String, Object?>>('/api/v1/health');
    final Map<String, Object?>? data = response.data;
    if (data == null) {
      throw const FormatException('Empty health response');
    }
    final health = ServiceStatus.fromJson(data);
    try {
      final readyResponse =
          await _dio.get<Map<String, Object?>>('/api/v1/ready');
      final readyData = readyResponse.data;
      if (readyData == null) {
        throw const FormatException('Empty readiness response');
      }
      final ready = ServiceStatus.fromJson(readyData);
      return health.copyWith(
        readiness: ready.status,
        checkedAt: DateTime.now().toLocal().toIso8601String(),
        apiBaseUrl: AppConfig.apiBaseUrl,
      );
    } on Object catch (error) {
      return health.copyWith(
        readiness: 'unavailable',
        readinessDetail: _readinessMessage(error),
        checkedAt: DateTime.now().toLocal().toIso8601String(),
        apiBaseUrl: AppConfig.apiBaseUrl,
      );
    }
  }
}

String _readinessMessage(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    return status == null
        ? 'Database readiness request could not connect.'
        : 'Database readiness returned HTTP $status.';
  }
  return 'Database readiness returned an invalid response.';
}

final systemStatusRepositoryProvider =
    Provider<SystemStatusRepository>((Ref ref) {
  return DioSystemStatusRepository(ref.watch(dioProvider));
});
