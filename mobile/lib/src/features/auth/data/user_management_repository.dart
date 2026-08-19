import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/core/network/api_client.dart';
import 'package:snakecare_mobile/src/features/auth/domain/auth_session.dart';
import 'package:snakecare_mobile/src/features/auth/domain/managed_user.dart';

final userManagementRepositoryProvider = Provider<UserManagementRepository>(
  (ref) => UserManagementRepository(ref.watch(dioProvider)),
);

class UserManagementRepository {
  UserManagementRepository(this._dio);

  final Dio _dio;

  Options _auth(String accessToken) => Options(
        headers: {'Authorization': 'Bearer $accessToken'},
      );

  Future<List<ManagedUser>> listUsers(String accessToken) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/auth/users',
      options: _auth(accessToken),
    );
    return response.data!
        .map(
          (value) => ManagedUser.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList();
  }

  Future<ManagedUser> assignRole(
    String accessToken, {
    required String userId,
    required UserRole role,
    String? hospitalEmployeeId,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/auth/users/$userId/role',
      data: {
        'role': _apiRole(role),
        if (hospitalEmployeeId != null)
          'hospital_employee_id': hospitalEmployeeId,
      },
      options: _auth(accessToken),
    );
    return ManagedUser.fromJson(response.data!);
  }

  static String _apiRole(UserRole role) => switch (role) {
        UserRole.patient => 'patient',
        UserRole.doctor => 'doctor',
        UserRole.hospitalAdmin => 'hospital_admin',
        UserRole.governmentAdmin => 'government_admin',
      };
}
