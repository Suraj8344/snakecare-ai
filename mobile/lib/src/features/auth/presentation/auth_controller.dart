import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/features/auth/data/auth_repository.dart';
import 'package:snakecare_mobile/src/features/auth/domain/auth_session.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);
  Timer? _refreshTimer;

  @override
  Future<AuthSession?> build() async {
    ref.onDispose(() => _refreshTimer?.cancel());
    final session = await _repository.restoreExistingSession();
    if (session != null) _scheduleRefresh(session);
    return session;
  }

  Future<void> email(
    String email,
    String password, {
    bool register = false,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => register
          ? _repository.registerWithEmail(email, password)
          : _repository.signInWithEmail(email, password),
    );
    state = result;
    final session = result.value;
    if (session != null) _scheduleRefresh(session);
  }

  Future<void> google() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(_repository.signInWithGoogle);
    state = result;
    final session = result.value;
    if (session != null) _scheduleRefresh(session);
  }

  Future<PhoneSignInChallenge> sendPhoneCode(String phone) async {
    final challenge = await _repository.sendPhoneCode(phone);
    if (challenge.session case final session?) {
      state = AsyncData(session);
      _scheduleRefresh(session);
    }
    return challenge;
  }

  Future<void> confirmPhone(String verificationId, String code) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _repository.confirmPhoneCode(verificationId, code),
    );
    state = result;
    final session = result.value;
    if (session != null) _scheduleRefresh(session);
  }

  Future<void> sendPasswordReset(String email) =>
      _repository.sendPasswordReset(email);

  Future<void> logout() async {
    final session = state.value;
    try {
      if (session != null) {
        await _repository.logout(
          session.refreshToken,
          session.accessToken,
        );
      }
    } finally {
      _refreshTimer?.cancel();
      state = const AsyncData(null);
    }
  }

  void _scheduleRefresh(AuthSession session) {
    _refreshTimer?.cancel();
    final expiry = session.accessExpiresAt ??
        DateTime.now().add(const Duration(minutes: 15));
    final delay =
        expiry.subtract(const Duration(minutes: 1)).difference(DateTime.now());
    _refreshTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => _refresh(session),
    );
  }

  Future<void> _refresh(AuthSession current) async {
    try {
      final refreshed = await _repository.refreshSession(current.refreshToken);
      state = AsyncData(refreshed);
      _scheduleRefresh(refreshed);
    } catch (_) {
      // A temporary network outage should not sign the user out. Retry shortly;
      // protected requests will still reject a genuinely expired token.
      _refreshTimer = Timer(
        const Duration(minutes: 1),
        () => _refresh(current),
      );
    }
  }
}
