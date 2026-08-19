import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snakecare_mobile/src/core/config/app_config.dart';
import 'package:snakecare_mobile/src/core/network/api_client.dart';
import 'package:snakecare_mobile/src/core/security/secure_storage.dart';
import 'package:snakecare_mobile/src/features/auth/domain/auth_session.dart';

final authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
  );
});

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  static const _refreshKey = 'snakecare_refresh_token';
  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<AuthSession> signInWithEmail(String email, String password) async {
    _requireFirebase();
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser!;
    if (!refreshed.emailVerified) {
      await refreshed.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
      throw StateError(
        'Email is not verified. We sent a new verification link to ${email.trim()}. '
        'Open the link, then return and sign in.',
      );
    }
    return _exchange(await refreshed.getIdToken(true));
  }

  Future<AuthSession> registerWithEmail(String email, String password) async {
    _requireFirebase();
    final credential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    await user.sendEmailVerification();
    await FirebaseAuth.instance.signOut();
    throw StateError(
      'Account created. A verification link was sent to ${email.trim()}. '
      'Verify the email, then sign in.',
    );
  }

  Future<AuthSession> signInWithGoogle() async {
    _requireFirebase();
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    if (kIsWeb) {
      try {
        final credential =
            await FirebaseAuth.instance.signInWithPopup(provider);
        return _exchange(await credential.user!.getIdToken(true));
      } on FirebaseAuthException catch (error) {
        if (error.code == 'popup-blocked' ||
            error.code == 'popup-closed-by-user' ||
            error.code == 'web-context-cancelled') {
          throw StateError(
            'Google sign-in could not open in this browser. '
            'Open SnakeCare in Google Chrome, or sign in with email and password.',
          );
        }
        rethrow;
      }
    }
    final credential = await FirebaseAuth.instance.signInWithProvider(
      provider,
    );
    return _exchange(await credential.user!.getIdToken(true));
  }

  Future<AuthSession?> restoreExistingSession() async {
    if (!AppConfig.firebaseEnabled) return null;
    final user = FirebaseAuth.instance.currentUser ??
        await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) return null;
    try {
      return await _exchange(await user.getIdToken(true));
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;
      await _clearLocalSession();
      return null;
    } on FirebaseAuthException catch (error) {
      if (error.code != 'user-token-expired' &&
          error.code != 'invalid-user-token' &&
          error.code != 'user-disabled') {
        rethrow;
      }
      await _clearLocalSession();
      return null;
    }
  }

  Future<String> sendPhoneCode(String phoneNumber) async {
    _requireFirebase();
    final result = Completer<String>();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        final user =
            await FirebaseAuth.instance.signInWithCredential(credential);
        result.complete(await user.user!.getIdToken(true));
      },
      verificationFailed: result.completeError,
      codeSent: (verificationId, _) => result.complete(verificationId),
      codeAutoRetrievalTimeout: (verificationId) {
        if (!result.isCompleted) result.complete(verificationId);
      },
    );
    return result.future;
  }

  Future<AuthSession> confirmPhoneCode(
    String verificationId,
    String code,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    return _exchange(await result.user!.getIdToken(true));
  }

  Future<void> logout(String refreshToken, String accessToken) async {
    try {
      await _dio.post<void>(
        '/api/v1/auth/logout',
        data: {'refresh_token': refreshToken},
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
    } on DioException {
      // Local sign-out must still complete if session revocation is unavailable.
    } finally {
      await _clearLocalSession();
    }
  }

  Future<void> _clearLocalSession() async {
    await _storage.delete(key: _refreshKey);
    if (AppConfig.firebaseEnabled) await FirebaseAuth.instance.signOut();
  }

  Future<AuthSession> _exchange(String? idToken) async {
    if (idToken == null) {
      throw StateError('Firebase did not issue an identity token.');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/session',
      data: {'firebase_id_token': idToken},
    );
    final session = AuthSession.fromJson(response.data!);
    await _storage.write(key: _refreshKey, value: session.refreshToken);
    return session;
  }

  static void _requireFirebase() {
    if (!AppConfig.firebaseEnabled) {
      throw StateError('Firebase is not configured for this build.');
    }
  }
}
