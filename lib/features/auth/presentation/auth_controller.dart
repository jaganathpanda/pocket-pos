import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

class AuthController extends StateNotifier<AsyncValue<AppUser?>> {
  AuthController(this._repository) : super(const AsyncData(null));

  final AuthRepository _repository;

  Future<void> restoreSession() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await _repository.currentUser());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      state = const AsyncData(null);
    }
  }

  Future<bool> login(String username, String pin) async {
    state = const AsyncLoading();
    try {
      final user = await _repository.login(username: username, pin: pin);
      state = AsyncData(user);
      return user != null;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      state = const AsyncData(null);
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncData(null);
  }
}
