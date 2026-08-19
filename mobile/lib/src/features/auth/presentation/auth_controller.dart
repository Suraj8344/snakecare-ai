import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/features/auth/data/auth_repository.dart';
import 'package:snakecare_mobile/src/features/auth/domain/auth_session.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthSession?> build() => _repository.restoreExistingSession();

  Future<void> email(
    String email,
    String password, {
    bool register = false,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => register
          ? _repository.registerWithEmail(email, password)
          : _repository.signInWithEmail(email, password),
    );
  }

  Future<void> google() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.signInWithGoogle);
  }

  Future<String> sendPhoneCode(String phone) =>
      _repository.sendPhoneCode(phone);

  Future<void> confirmPhone(String verificationId, String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.confirmPhoneCode(verificationId, code),
    );
  }

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
      state = const AsyncData(null);
    }
  }
}
