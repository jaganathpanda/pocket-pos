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
