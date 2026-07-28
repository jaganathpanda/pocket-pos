import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store_auth_service.dart';
import '../domain/store_models.dart';

final storeAuthServiceProvider =
    Provider<StoreAuthService>((ref) => StoreAuthService());

final storeAuthControllerProvider =
    StateNotifierProvider<StoreAuthController, StoreAuthState>((ref) {
  return StoreAuthController(ref.watch(storeAuthServiceProvider));
});

/// Convenience: the active store session (null unless signed into a store).
final storeSessionProvider = Provider<StoreSession?>((ref) {
  return ref.watch(storeAuthControllerProvider).session;
});

/// The active tenant id for scoping all data. Null when not in a store.
final activeStoreIdProvider = Provider<String?>((ref) {
  return ref.watch(storeAuthControllerProvider).session?.storeId;
});

class StoreAuthController extends StateNotifier<StoreAuthState> {
  StoreAuthController(this._service)
      : super(const StoreAuthState(stage: StoreAuthStage.unknown)) {
    _init();
  }

  final StoreAuthService _service;

  Future<void> _init() async {
    try {
      state = await _service.restore();
    } catch (_) {
      state = const StoreAuthState(stage: StoreAuthStage.loggedOut);
    }
  }

  Future<bool> login({
    required String storeId,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final session = await _service.login(
        storeId: storeId,
        username: username,
        password: password,
      );
      state = StoreAuthState(
        stage: session.isApproved
            ? StoreAuthStage.active
            : StoreAuthStage.pending,
        session: session,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    } catch (e) {
      state = state.copyWith(busy: false, error: _clean(e));
      return false;
    }
  }

  /// Returns the generated store id on success, or null on failure.
  Future<String?> register({
    required String storeName,
    required String ownerName,
    required String ownerUsername,
    required String password,
    String? mobile,
    String? email,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final storeId = await _service.registerStore(
        storeName: storeName,
        ownerName: ownerName,
        ownerUsername: ownerUsername,
        password: password,
        mobile: mobile,
        email: email,
      );
      state = await _service.restore(); // pending session
      return storeId;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return null;
    } catch (e) {
      state = state.copyWith(busy: false, error: _clean(e));
      return null;
    }
  }

  Future<bool> adminLogin({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await _service.adminLogin(email: email, password: password);
      state = const StoreAuthState(stage: StoreAuthStage.admin);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    } catch (e) {
      state = state.copyWith(busy: false, error: _clean(e));
      return false;
    }
  }

  /// Re-checks the current store's status (for the pending screen's refresh).
  Future<void> refreshStatus() async {
    try {
      state = await _service.restore();
    } catch (_) {}
  }

  Future<void> logout() async {
    await _service.logout();
    state = const StoreAuthState(stage: StoreAuthStage.loggedOut);
  }

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That username is already taken for this store.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid store id, username or password.';
      case 'weak-password':
        return 'Password is too weak (min 6 characters).';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');
}
