import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/database/app_database.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';
import '../../../firebase_options.dart';
import '../domain/pos_counter_repository.dart';

/// Store-scoped Firestore implementation of [PosCounterRepository].
/// Counters live at `stores/{storeId}/pos_counters`; staff are the store's
/// Firebase Auth users under `stores/{storeId}/users`.
class FirestorePosCounterRepository implements PosCounterRepository {
  FirestorePosCounterRepository(this._db, this._storeId);

  final FirebaseFirestore _db;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _counters =>
      storeCollection(_db, _storeId, 'pos_counters');
  CollectionReference<Map<String, dynamic>> get _users =>
      storeCollection(_db, _storeId, 'users');

  // ── Counters ───────────────────────────────────────────────────────────────

  @override
  Stream<List<PosCounter>> watchCounters() {
    return _counters.snapshots().map((snap) {
      final list = snap.docs.map(_counterFromDoc).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  @override
  Future<List<PosCounter>> activeCounters() async {
    final snap = await _counters.where('isActive', isEqualTo: true).get();
    final list = snap.docs.map(_counterFromDoc).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Future<int> addCounter(String name) async {
    final id = newIntId();
    await _counters.doc('$id').set({
      'name': name.trim(),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  @override
  Future<void> renameCounter(int id, String name) =>
      _counters.doc('$id').set({'name': name.trim()}, SetOptions(merge: true));

  @override
  Future<void> setCounterActive(int id, bool active) =>
      _counters.doc('$id').set({'isActive': active}, SetOptions(merge: true));

  // ── Staff (store users) ────────────────────────────────────────────────────

  @override
  Stream<List<PosUserRow>> watchPosUsers() {
    return _users.snapshots().asyncMap((snap) async {
      final counterNames = await _counterNamesById();
      return snap.docs
          .where((d) => (d.data()['role'] as String?) != 'owner')
          .map((d) {
        final data = d.data();
        final counterId = (data['posCounterId'] as num?)?.toInt();
        return PosUserRow(
          uid: d.id,
          username: (data['username'] as String?) ?? '',
          isActive: (data['isActive'] as bool?) ?? true,
          counterName: counterId == null ? null : counterNames[counterId],
        );
      }).toList();
    });
  }

  @override
  Future<void> addPosUser({
    required String username,
    required String pin,
    required int counterId,
  }) async {
    final email =
        '${username.trim().toLowerCase()}@${_storeId.toLowerCase()}.pocketpos.app';

    // Use a throwaway secondary Firebase app so creating the staff account does
    // NOT sign the owner out of the primary app.
    final secondary = await Firebase.initializeApp(
      name: 'staffCreator',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      final auth = FirebaseAuth.instanceFor(app: secondary);
      final sdb = FirebaseFirestore.instanceFor(app: secondary);
      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: pin.trim(),
      );
      final uid = cred.user!.uid;

      // Write the docs while signed in AS the new staff user so the security
      // rule (`request.auth.uid == uid`) passes — the owner's primary session
      // is untouched.
      await storeCollection(sdb, _storeId, 'users').doc(uid).set({
        'username': username.trim(),
        'role': 'cashier',
        'posCounterId': counterId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await sdb.collection('user_store_index').doc(uid).set({'storeId': _storeId});
      await auth.signOut();
    } finally {
      await secondary.delete();
    }
  }

  @override
  Stream<List<PosUserRow>> watchMillers() {
    return _users.snapshots().map((snap) {
      const millerRoles = {'owner', 'super_admin', 'manager'};
      return snap.docs
          .where((d) => millerRoles.contains(d.data()['role'] as String?))
          .map((d) {
        final data = d.data();
        return PosUserRow(
          uid: d.id,
          username: (data['username'] as String?) ?? '',
          isActive: (data['isActive'] as bool?) ?? true,
        );
      }).toList();
    });
  }

  @override
  Future<void> setUserActive(String uid, bool active) =>
      _users.doc(uid).set({'isActive': active}, SetOptions(merge: true));

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<Map<int, String>> _counterNamesById() async {
    final snap = await _counters.get();
    return {
      for (final d in snap.docs)
        (int.tryParse(d.id) ?? 0): (d.data()['name'] as String?) ?? ''
    };
  }

  PosCounter _counterFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return PosCounter(
      id: int.tryParse(doc.id) ?? 0,
      name: (d['name'] as String?) ?? '',
      isActive: (d['isActive'] as bool?) ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
