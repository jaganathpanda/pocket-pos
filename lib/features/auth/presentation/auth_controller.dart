import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_models.dart';

/// Holds the app's in-memory session (role + counter), populated from the
/// signed-in cloud store session via [enterFromStore]. There is no local
/// username/password auth — authentication is Firebase (see StoreAuthService).
class AuthController extends StateNotifier<AsyncValue<AppUser?>> {
  AuthController() : super(const AsyncData(null));

  /// Bridges a cloud store session into the app session so POS screens (which
  /// read the local user for role/counter scoping) work after a store login.
  void enterFromStore({
    required String username,
    required String role,
    int? posCounterId,
    String? posCounterName,
  }) {
    final mapped = role == 'owner' || role == 'super_admin'
        ? UserRole.superAdmin
        : role == 'manager'
            ? UserRole.shopManager
            : UserRole.cashier;
    state = AsyncData(AppUser(
      id: 0,
      username: username.isEmpty ? 'user' : username,
      role: mapped,
      isActive: true,
      posCounterId: posCounterId,
      posCounterName: posCounterName,
    ));
  }

  void logout() => state = const AsyncData(null);
}
