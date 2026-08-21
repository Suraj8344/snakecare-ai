import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/core/config/app_config.dart';

final dioProvider = Provider<Dio>((Ref ref) {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      // Render's free service may need time to wake after inactivity.
      receiveTimeout: const Duration(seconds: 75),
      headers: <String, String>{'Accept': 'application/json'},
    ),
  );
});
