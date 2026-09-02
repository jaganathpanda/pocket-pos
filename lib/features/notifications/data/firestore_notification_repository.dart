import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';

class FirestoreNotificationRepository implements NotificationRepository {
  final FirebaseFirestore _db;
  final String _storeId;

  FirestoreNotificationRepository(this._db, this._storeId);

  CollectionReference<Map<String, dynamic>> get _col =>
      storeCollection(_db, _storeId, 'notifications');

  @override
  Stream<List<AppNotification>> watchForUser(String targetUid) {
    if (targetUid.isEmpty) return Stream.value(const []);
    return _col
        .where('targetUid', isEqualTo: targetUid)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  @override
  Stream<int> watchUnreadCount(String targetUid) {
    if (targetUid.isEmpty) return Stream.value(0);
    return _col
        .where('targetUid', isEqualTo: targetUid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  @override
  Future<void> create({
    required String type,
    required String title,
    required String message,
    required String targetUid,
    String? entityType,
    int? entityId,
  }) async {
    final id = newIntId();
    await _col.doc('$id').set({
      'type': type,
      'title': title,
      'message': message,
      'targetUid': targetUid,
      'entityType': entityType,
      'entityId': entityId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markRead(int id) =>
      _col.doc('$id').set({'isRead': true}, SetOptions(merge: true));

  @override
  Future<void> markAllRead(String targetUid) async {
    final snap = await _col
        .where('targetUid', isEqualTo: targetUid)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.set(d.reference, {'isRead': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  AppNotification _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppNotification(
      id: int.tryParse(doc.id) ?? 0,
      type: d['type'] as String? ?? '',
      title: d['title'] as String? ?? '',
      message: d['message'] as String? ?? '',
      targetUid: d['targetUid'] as String? ?? '',
      entityType: d['entityType'] as String?,
      entityId: (d['entityId'] as num?)?.toInt(),
      isRead: (d['isRead'] as bool?) ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
