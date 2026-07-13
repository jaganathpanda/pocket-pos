import '../../../core/database/app_database.dart';

abstract class CategoryRepository {
  Stream<List<Category>> watchAll();
  Future<void> add(String name, {int? parentCategoryId});
  Future<void> updateName(int id, String name);
  Future<void> delete(int id);
}
