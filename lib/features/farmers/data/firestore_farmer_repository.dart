import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';
import '../domain/farmer.dart';
import '../domain/farmer_repository.dart';

class FirestoreFarmerRepository implements FarmerRepository {
  final FirebaseFirestore _db;
  final String _storeId;

  FirestoreFarmerRepository(this._db, this._storeId);

  CollectionReference<Map<String, dynamic>> get _col =>
      storeCollection(_db, _storeId, 'farmers');

  @override
  Stream<List<Farmer>> watchAll({String? type}) {
    var query = _col.where('isActive', isEqualTo: true);
    if (type != null && type.isNotEmpty) {
      query = query.where('type', isEqualTo: type);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  @override
  Future<List<Farmer>> search(String query, {String? type}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    // Client-side filtering (Firestore doesn't support full-text search)
    final snap = await _col.where('isActive', isEqualTo: true).get();
    final all = snap.docs.map(_fromDoc);

    var results = all.where((f) =>
        f.name.toLowerCase().contains(q) ||
        (f.mobile?.toLowerCase().contains(q) ?? false) ||
        (f.aadhaarNumber?.toLowerCase().contains(q) ?? false) ||
        (f.kisanCardNumber?.toLowerCase().contains(q) ?? false));

    if (type != null && type.isNotEmpty) {
      results = results.where((f) => f.type == type);
    }

    return results.take(30).toList();
  }

  @override
  Future<Farmer?> getById(int id) async {
    final doc = await _col.doc('$id').get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  @override
  Future<int> add({
    required String name,
    required String type,
    String? mobile,
    String? gstNumber,
    String? email,
    String? address,
    String? contactPerson,
    String? kisanCardNumber,
    String? aadhaarNumber,
    String? village,
    String? district,
    String? mandiLicenseNumber,
  }) async {
    final id = newIntId();
    await _col.doc('$id').set({
      'name': name.trim(),
      'type': type,
      'mobile': mobile,
      'gstNumber': gstNumber,
      'email': email,
      'address': address,
      'contactPerson': contactPerson,
      'kisanCardNumber': kisanCardNumber,
      'aadhaarNumber': aadhaarNumber,
      'village': village,
      'district': district,
      'mandiLicenseNumber': mandiLicenseNumber,
      'outstandingBalance': 0.0,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  @override
  Future<void> update({
    required int id,
    required String name,
    required String type,
    String? mobile,
    String? gstNumber,
    String? email,
    String? address,
    String? contactPerson,
    String? kisanCardNumber,
    String? aadhaarNumber,
    String? village,
    String? district,
    String? mandiLicenseNumber,
  }) {
    return _col.doc('$id').set({
      'name': name.trim(),
      'type': type,
      'mobile': mobile,
      'gstNumber': gstNumber,
      'email': email,
      'address': address,
      'contactPerson': contactPerson,
      'kisanCardNumber': kisanCardNumber,
      'aadhaarNumber': aadhaarNumber,
      'village': village,
      'district': district,
      'mandiLicenseNumber': mandiLicenseNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> delete(int id) {
    return _col.doc('$id').set({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Farmer _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Farmer(
      id: int.tryParse(doc.id) ?? 0,
      name: d['name'] as String? ?? '',
      type: d['type'] as String? ?? 'farmer',
      mobile: d['mobile'] as String?,
      gstNumber: d['gstNumber'] as String?,
      email: d['email'] as String?,
      address: d['address'] as String?,
      contactPerson: d['contactPerson'] as String?,
      outstandingBalance: (d['outstandingBalance'] as num?)?.toDouble() ?? 0,
      isActive: (d['isActive'] as bool?) ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      kisanCardNumber: d['kisanCardNumber'] as String?,
      aadhaarNumber: d['aadhaarNumber'] as String?,
      village: d['village'] as String?,
      district: d['district'] as String?,
      mandiLicenseNumber: d['mandiLicenseNumber'] as String?,
    );
  }
}
