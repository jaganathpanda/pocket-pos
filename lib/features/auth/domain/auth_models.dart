enum UserRole { superAdmin, shopOwner, shopManager, cashier }

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    required this.isActive,
  });

  final int id;
  final String username;
  final UserRole role;
  final bool isActive;
}
