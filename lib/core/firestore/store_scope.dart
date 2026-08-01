import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Offline-first write: issue a Firestore write WITHOUT awaiting the server
/// acknowledgement. Firestore applies the write to the local cache the instant
/// it is called (so streams and cached reads reflect it immediately), then
/// syncs it when the network returns. Awaiting the returned Future would hang
/// the UI while offline because it only completes on server ack. Late errors
/// are swallowed so they don't surface as unhandled async exceptions — the
/// write stays queued for automatic retry.
void queueWrite(Future<void> op) {
  unawaited(op.catchError((Object e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Firestore write queued/failed (will retry on sync): $e');
    }
  }));
}

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
