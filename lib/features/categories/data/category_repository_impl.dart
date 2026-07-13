import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Category>> watchAll() {
    return (_db.select(_db.categories)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  @override
  Future<void> add(String name, {int? parentCategoryId}) {
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            parentCategoryId: Value(parentCategoryId),
          ),
        );
  }

  @override
  Future<void> updateName(int id, String name) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(name: Value(name)),
    );
  }

  @override
  Future<void> delete(int id) {
    return (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }
}
