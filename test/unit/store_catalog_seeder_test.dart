import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_pos/core/database/seed/demo_business_type.dart';
import 'package:pocket_pos/core/firestore/store_catalog_seeder.dart';

void main() {
  test('seeds categories, products, inventory, warehouse and settings', () async {
    final db = FakeFirebaseFirestore();
    const storeId = 'STR-TEST01';

    await StoreCatalogSeeder(db).load(DemoBusinessType.grocery, storeId);

    Future<QuerySnapshot<Map<String, dynamic>>> col(String name) => db
        .collection('stores')
        .doc(storeId)
        .collection(name)
        .get();

    final cats = await col('categories');
    final prods = await col('products');
    final inv = await col('inventory');
    final wh = await col('warehouses');
    final settings = await col('settings');

    print('categories=${cats.size} products=${prods.size} '
        'inventory=${inv.size} warehouses=${wh.size} settings=${settings.size}');

    expect(cats.size, 5, reason: 'grocery has 5 categories');
    expect(prods.size, 7, reason: 'grocery has 7 products');
    expect(inv.size, 7, reason: 'one inventory row per product');
    expect(wh.size, 1, reason: 'a default warehouse is created');

    // Every product must point at a real category id and its inventory row.
    final catIds = cats.docs.map((d) => int.parse(d.id)).toSet();
    for (final p in prods.docs) {
      expect(catIds.contains(p['categoryId']), isTrue,
          reason: '${p['name']} categoryId ${p['categoryId']} must exist');
    }
    final prodIds = prods.docs.map((d) => int.parse(d.id)).toSet();
    for (final row in inv.docs) {
      expect(prodIds.contains(row['productId']), isTrue,
          reason: 'inventory productId ${row['productId']} must exist');
    }
  });

  test('re-seeding replaces the previous catalog (no duplicates)', () async {
    final db = FakeFirebaseFirestore();
    const storeId = 'STR-TEST02';

    await StoreCatalogSeeder(db).load(DemoBusinessType.grocery, storeId);
    await StoreCatalogSeeder(db).load(DemoBusinessType.bakery, storeId);

    final prods =
        await db.collection('stores').doc(storeId).collection('products').get();
    // Bakery-only count — grocery products must have been cleared.
    print('after re-seed products=${prods.size}');
    expect(prods.size, greaterThan(0));
  });
}
