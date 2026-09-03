import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/seed/demo_business_type.dart';
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
        stage:
            session.isApproved ? StoreAuthStage.active : StoreAuthStage.pending,
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
    required DemoBusinessType businessType,
    String? mobile,
    String? email,
    String? referralCode,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final storeId = await _service.registerStore(
        storeName: storeName,
        ownerName: ownerName,
        ownerUsername: ownerUsername,
        password: password,
        businessType: businessType,
        mobile: mobile,
        email: email,
        referralCode: referralCode,
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

  /// Registers a platform weighbridge operator (pending admin approval).
  Future<bool> registerOperator({
    required String name,
    required String email,
    required String password,
    String? mobile,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await _service.registerOperator(
        name: name,
        email: email,
        password: password,
        mobile: mobile,
      );
      state = await _service.restore(); // pending operator session
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    } catch (e) {
      state = state.copyWith(busy: false, error: _clean(e));
      return false;
    }
  }

  Future<bool> operatorLogin({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final profile =
          await _service.operatorLogin(email: email, password: password);
      state = StoreAuthState(
        stage: profile.isApproved
            ? StoreAuthStage.operator
            : StoreAuthStage.pending,
        operator: profile,
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

  /// An approved operator enters a mill by Store ID; on success the app scopes
  /// to that mill (role stays weighbridge_operator).
  Future<bool> enterMill(String storeId) async {
    final operator = state.operator;
    if (operator == null) return false;
    state = state.copyWith(busy: true, error: null);
    try {
      final session = await _service.operatorEnterMill(
        storeId: storeId,
        operator: operator,
      );
      state = StoreAuthState(
        stage: StoreAuthStage.active,
        session: session,
        operator: operator,
      );
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: _clean(e));
      return false;
    }
  }

  /// Operator leaves the current mill and returns to the mill-selection screen.
  void exitMill() {
    final operator = state.operator;
    if (operator == null) return;
    state = StoreAuthState(stage: StoreAuthStage.operator, operator: operator);
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
