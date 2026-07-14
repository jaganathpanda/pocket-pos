enum UserRole { superAdmin, shopOwner, shopManager, cashier }

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    required this.isActive,
    this.posCounterId,
    this.posCounterName,
  });

  final int id;
  final String username;
  final UserRole role;
  final bool isActive;

  /// POS counter this user is locked to. Null means the user (owner/manager)
  /// can see data across all counters.
  final int? posCounterId;
  final String? posCounterName;

  /// Only owners (and super admins) may add/manage POS counters and users.
  bool get canManagePos =>
      role == UserRole.superAdmin || role == UserRole.shopOwner;

  /// True when this user's view must be limited to a single counter.
  bool get isCounterScoped => posCounterId != null;
}
