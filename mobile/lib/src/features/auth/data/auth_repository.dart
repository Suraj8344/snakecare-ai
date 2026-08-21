import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  static Future<void>? _googleInitialization;

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

  Future<void> sendPasswordReset(String email) async {
    _requireFirebase();
    final value = email.trim();
    if (value.isEmpty) throw StateError('Enter your email address first.');
    await FirebaseAuth.instance.sendPasswordResetEmail(email: value);
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
    final googleSignIn = GoogleSignIn.instance;
    _googleInitialization ??= googleSignIn.initialize();
    await _googleInitialization;
    final account = await googleSignIn.authenticate();
    final authentication = account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: authentication.idToken,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    return _exchange(await result.user!.getIdToken(true));
  }

  Future<AuthSession?> restoreExistingSession() async {
    if (!AppConfig.firebaseEnabled) return null;
    final user = FirebaseAuth.instance.currentUser ??
        await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) return null;
    try {
      return await _exchange(await user.getIdToken(true));
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _clearLocalSession();
      }
      // A cached Firebase user may start the app before the hosted API wakes
      // or while the phone is offline. Keep emergency/offline tools usable and
      // retry the protected session when the user explicitly signs in.
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

  Future<PhoneSignInChallenge> sendPhoneCode(String phoneNumber) async {
    _requireFirebase();
    final normalized = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalized)) {
      throw StateError(
        'Enter the full phone number with country code, for example +919876543210.',
      );
    }
    final result = Completer<PhoneSignInChallenge>();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: normalized,
      verificationCompleted: (credential) async {
        try {
          final user =
              await FirebaseAuth.instance.signInWithCredential(credential);
          final session = await _exchange(await user.user!.getIdToken(true));
          if (!result.isCompleted) {
            result.complete(PhoneSignInChallenge.completed(session));
          }
        } catch (error, stackTrace) {
          if (!result.isCompleted) result.completeError(error, stackTrace);
        }
      },
      verificationFailed: (error) {
        if (!result.isCompleted) result.completeError(error);
      },
      codeSent: (verificationId, _) {
        if (!result.isCompleted) {
          result.complete(PhoneSignInChallenge.codeSent(verificationId));
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!result.isCompleted) {
          result.complete(PhoneSignInChallenge.codeSent(verificationId));
        }
      },
      timeout: const Duration(seconds: 60),
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

  Future<AuthSession> refreshSession(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    final session = AuthSession.fromJson(response.data!);
    await _storage.write(key: _refreshKey, value: session.refreshToken);
    return session;
  }

  Future<void> _clearLocalSession() async {
    await _storage.delete(key: _refreshKey);
    if (AppConfig.firebaseEnabled) await FirebaseAuth.instance.signOut();
  }

  Future<AuthSession> _exchange(String? idToken) async {
    if (idToken == null) {
      throw StateError('Firebase did not issue an identity token.');
    }
    late Response<Map<String, dynamic>> response;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/auth/session',
          data: {'firebase_id_token': idToken},
        );
        break;
      } on DioException catch (error) {
        final retryable = error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout;
        if (!retryable || attempt == 1) rethrow;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
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

class PhoneSignInChallenge {
  const PhoneSignInChallenge._({this.verificationId, this.session});

  const PhoneSignInChallenge.codeSent(String verificationId)
      : this._(verificationId: verificationId);

  const PhoneSignInChallenge.completed(AuthSession session)
      : this._(session: session);

  final String? verificationId;
  final AuthSession? session;

  bool get isCompleted => session != null;
}
