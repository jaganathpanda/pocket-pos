import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Returns a store-scoped collection: `stores/{storeId}/{name}`.
/// This is the single place tenant isolation is applied for cloud data.
CollectionReference<Map<String, dynamic>> storeCollection(
  FirebaseFirestore db,
  String storeId,
  String name,
) {
  return db.collection('stores').doc(storeId).collection(name);
}

/// Reads a single document in an **offline-safe** way.
///
/// A plain `DocumentReference.get()` throws `unavailable`
/// ("Failed to get document because the client is offline") when the device is
/// offline and that exact document isn't already in the local cache — it does
/// NOT fall back to the cache. A `Query.get()`, however, is always served from
/// the cache offline. So when the direct get fails offline we retry via a
/// documentId query, which returns the cached copy if we have one.
///
/// Returns `null` when the document genuinely can't be found (missing, or never
/// cached while online).
Future<DocumentSnapshot<Map<String, dynamic>>?> cacheSafeDoc(
  CollectionReference<Map<String, dynamic>> col,
  String id,
) async {
  try {
    return await col.doc(id).get();
  } on FirebaseException catch (e) {
    if (e.code != 'unavailable') rethrow;
  }
  final q =
      await col.where(FieldPath.documentId, isEqualTo: id).limit(1).get();
  return q.docs.isEmpty ? null : q.docs.first;
}
