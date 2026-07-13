import 'auth_models.dart';

abstract class AuthRepository {
  Future<AppUser?> login({required String username, required String pin});
  Future<void> logout();
  Future<AppUser?> currentUser();
}
