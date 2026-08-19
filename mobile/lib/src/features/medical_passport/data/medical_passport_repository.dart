import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/core/network/api_client.dart';
import 'package:snakecare_mobile/src/features/medical_passport/domain/medical_passport.dart';

final medicalPassportRepositoryProvider =
    Provider<MedicalPassportRepository>((ref) {
  return MedicalPassportRepository(ref.watch(dioProvider));
});

final medicalPassportProvider =
    FutureProvider.family<MedicalPassport, String>((ref, accessToken) {
  return ref.watch(medicalPassportRepositoryProvider).getOwn(accessToken);
});

class MedicalPassportRepository {
  MedicalPassportRepository(this._dio);
  final Dio _dio;

  Options _authorization(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<MedicalPassport> getOwn(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/medical-passport/me',
      options: _authorization(accessToken),
    );
    return MedicalPassport.fromJson(response.data!);
  }

  Future<MedicalPassport> save(
    String accessToken,
    MedicalPassport passport,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/medical-passport/me',
      data: passport.toUpdateJson(),
      options: _authorization(accessToken),
    );
    return MedicalPassport.fromJson(response.data!);
  }

  Future<List<PassportAccessGrant>> listGrants(String accessToken) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/medical-passport/access-grants',
      options: _authorization(accessToken),
    );
    return response.data!
        .map(
          (item) => PassportAccessGrant.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> grantAccess(
    String accessToken,
    String granteeEmail,
    DateTime expiresAt,
  ) async {
    await _dio.post<void>(
      '/api/v1/medical-passport/access-grants',
      data: {
        'grantee_email': granteeEmail.trim().toLowerCase(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
      },
      options: _authorization(accessToken),
    );
  }

  Future<void> revokeAccess(String accessToken, String grantId) async {
    await _dio.delete<void>(
      '/api/v1/medical-passport/access-grants/$grantId',
      options: _authorization(accessToken),
    );
  }
}
