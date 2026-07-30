import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/seed/demo_business_type.dart';
import '../database/seed/demo_data_loader.dart';
import 'firestore_ids.dart';
import 'store_scope.dart';

/// Seeds a demo catalog (categories + products + opening stock) into a store's
/// Firestore data, replacing any existing catalog. Used at registration and by
/// Settings → Sample Data.
///
/// The whole catalog is written as a SINGLE atomic [WriteBatch]. With offline
/// persistence enabled, individual `.set()` calls resolve against the local
/// cache and return before syncing to the server — so a burst of ~20 separate
/// writes issued during registration can be interrupted mid-flush, leaving only
/// the first few (e.g. categories) on the server. A batch is one mutation in
/// the sync queue: it lands on the server all-or-nothing, and collapses the
/// round-trips into one so the flush is effectively instant.
class StoreCatalogSeeder {
  StoreCatalogSeeder(this._db);

  final FirebaseFirestore _db;

  Future<void> load(DemoBusinessType type, String storeId) async {
    final catalog = DemoDataLoader.catalogFor(type);

    final categories = storeCollection(_db, storeId, 'categories');
    final products = storeCollection(_db, storeId, 'products');
    final inventory = storeCollection(_db, storeId, 'inventory');
    final warehouses = storeCollection(_db, storeId, 'warehouses');
    final settings = storeCollection(_db, storeId, 'settings');

    // Snapshot what exists so we can clear it in the same batch (fresh
    // registrations have nothing; re-seeds from Settings replace the catalog).
    final existingCats = await categories.get();
    final existingProds = await products.get();
    final existingInv = await inventory.get();

    // Reuse an existing default warehouse, or create one in the batch.
    final defaultWh =
        await warehouses.where('isDefault', isEqualTo: true).limit(1).get();
    final anyWh = defaultWh.docs.isNotEmpty
        ? defaultWh
        : await warehouses.limit(1).get();

    final batch = _db.batch();

    for (final d in existingCats.docs) {
      batch.delete(d.reference);
    }
    for (final d in existingProds.docs) {
      batch.delete(d.reference);
    }
    for (final d in existingInv.docs) {
      batch.delete(d.reference);
    }

    final int warehouseId;
    if (anyWh.docs.isNotEmpty) {
      warehouseId = int.parse(anyWh.docs.first.id);
    } else {
      warehouseId = newIntId();
      batch.set(warehouses.doc('$warehouseId'), {
        'name': 'Main Store',
        'isDefault': true,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final categoryIdByName = <String, int>{};
    for (final name in catalog.categories) {
      final id = newIntId();
      batch.set(categories.doc('$id'), {
        'name': name,
        'parentCategoryId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      categoryIdByName[name] = id;
    }

    for (final p in catalog.products) {
      final pid = newIntId();
      batch.set(products.doc('$pid'), {
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
      batch.set(inventory.doc('$invId'), {
        'productId': pid,
        'variantId': null,
        'warehouseId': warehouseId,
        'currentStock': p.stock,
        'availableStock': p.stock,
        'lowStockThreshold': p.lowStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(settings.doc('demo'), {'type': type.name});

    await batch.commit();
    // With offline persistence, commit() resolves against the local cache and
    // returns before the write reaches the server. Block until the backend has
    // actually acknowledged it, so a store is never reported "registered" with
    // a catalog that only exists locally (and could be lost on reload). This is
    // a best-effort durability barrier — never let it fail the seed itself.
    try {
      await _db.waitForPendingWrites();
    } catch (_) {}
  }
}

final storeCatalogSeederProvider = Provider<StoreCatalogSeeder>((ref) {
  return StoreCatalogSeeder(ref.watch(firestoreProvider));
});
