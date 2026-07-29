import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/warehouse/data/firestore_warehouse_repository.dart';
import '../database/seed/demo_business_type.dart';
import '../database/seed/demo_data_loader.dart';
import 'firestore_ids.dart';
import 'store_scope.dart';

/// Seeds a demo catalog (categories + products + opening stock) into a store's
/// Firestore data, replacing any existing catalog. Used by Settings → Sample
/// Data.
class StoreCatalogSeeder {
  StoreCatalogSeeder(this._db);

  final FirebaseFirestore _db;

  Future<void> load(DemoBusinessType type, String storeId) async {
    final catalog = DemoDataLoader.catalogFor(type);
    await _clear(storeId, 'inventory');
    await _clear(storeId, 'products');
    await _clear(storeId, 'categories');

    final warehouseId =
        await FirestoreWarehouseRepository(_db, storeId).defaultWarehouseId();

    final categoryIdByName = <String, int>{};
    for (final name in catalog.categories) {
      final id = newIntId();
      await storeCollection(_db, storeId, 'categories').doc('$id').set({
        'name': name,
        'parentCategoryId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      categoryIdByName[name] = id;
    }

    for (final p in catalog.products) {
      final pid = newIntId();
      await storeCollection(_db, storeId, 'products').doc('$pid').set({
        'name': p.name,
        'productCode': p.code,
        'barcode': p.barcode,
        'categoryId': categoryIdByName[p.category],
        'purchasePrice': p.purchasePrice,
        'sellingPrice': p.sellingPrice,
        'mrp': p.mrp,
        'taxPercent': p.taxPercent,
        'unit': p.unit,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      final invId = newIntId();
      await storeCollection(_db, storeId, 'inventory').doc('$invId').set({
        'productId': pid,
        'variantId': null,
        'warehouseId': warehouseId,
        'currentStock': p.stock,
        'availableStock': p.stock,
        'lowStockThreshold': p.lowStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await storeCollection(_db, storeId, 'settings')
        .doc('demo')
        .set({'type': type.name});
  }

  Future<void> _clear(String storeId, String name) async {
    final snap = await storeCollection(_db, storeId, name).get();
    for (final d in snap.docs) {
      await d.reference.delete();
    }
  }
}

final storeCatalogSeederProvider = Provider<StoreCatalogSeeder>((ref) {
  return StoreCatalogSeeder(ref.watch(firestoreProvider));
});
