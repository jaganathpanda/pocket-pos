import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';
import '../domain/restaurant_table.dart';
import '../domain/table_reservation.dart';
import '../domain/table_reservation_repository.dart';

class FirestoreTableReservationRepository
    implements TableReservationRepository {
  FirestoreTableReservationRepository(this._db, this._storeId);

  final FirebaseFirestore _db;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      storeCollection(_db, _storeId, 'table_reservations');

  CollectionReference<Map<String, dynamic>> get _tableLocks =>
      storeCollection(_db, _storeId, 'table_reservation_tables');

  CollectionReference<Map<String, dynamic>> get _tables =>
      storeCollection(_db, _storeId, 'restaurant_tables');

  @override
  Stream<List<RestaurantTable>> watchTables() =>
      _tables.orderBy('name').snapshots().map(
            (snapshot) => snapshot.docs
                .map((document) => RestaurantTable(
                      name: document.data()['name'] as String? ?? '',
                    ))
                .where((table) => table.name.isNotEmpty)
                .toList(),
          );

  @override
  Stream<List<TableReservation>> watchAll() =>
      _collection.orderBy('startAt').snapshots().map(
            (snapshot) => snapshot.docs.map(_fromDocument).toList(),
          );

  @override
  Future<void> addTable(String name) async {
    final normalizedName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedName.isEmpty) {
      throw StateError('Enter a table name.');
    }
    final tableRef = _tables.doc(_tableKey(normalizedName));
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(tableRef);
      if (existing.exists) {
        throw StateError('That table is already configured.');
      }
      transaction.set(tableRef, {
        'name': normalizedName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> removeTable(String name) async {
    final tableRef = _tables.doc(_tableKey(name));
    final lockRef = _tableLocks.doc(_tableKey(name));
    await _db.runTransaction((transaction) async {
      final tableSnapshot = await transaction.get(tableRef);
      final lockSnapshot = await transaction.get(lockRef);
      if (!tableSnapshot.exists) return;
      final activeBookings =
          lockSnapshot.data()?['activeBookings'] as List<dynamic>? ?? const [];
      if (activeBookings.isNotEmpty) {
        throw StateError('Complete or cancel this table’s bookings first.');
      }
      transaction.delete(tableRef);
    });
  }

  @override
  Future<void> create(TableReservationDraft draft) async {
    final id = newIntId();
    final reservationRef = _collection.doc('$id');
    final tableRef = _tableLocks.doc(_tableKey(draft.tableName));
    final configuredTableRef = _tables.doc(_tableKey(draft.tableName));
    await _db.runTransaction((transaction) async {
      final configuredTableSnapshot = await transaction.get(configuredTableRef);
      final tableSnapshot = await transaction.get(tableRef);
      if (!configuredTableSnapshot.exists) {
        throw StateError('Choose a configured table.');
      }
      final tableData = tableSnapshot.data();
      final activeBookings =
          (tableData?['activeBookings'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
      final hasConflict = activeBookings.any((booking) {
        final existingStart = (booking['startAt'] as Timestamp).toDate();
        final existingEnd = (booking['endAt'] as Timestamp).toDate();
        return existingStart.isBefore(draft.endAt) &&
            draft.startAt.isBefore(existingEnd);
      });
      if (hasConflict) {
        throw StateError('That table already has a booking at this time.');
      }

      activeBookings.add({
        'reservationId': id,
        'startAt': Timestamp.fromDate(draft.startAt),
        'endAt': Timestamp.fromDate(draft.endAt),
      });
      transaction.set(tableRef, {
        'tableName': draft.tableName.trim(),
        'activeBookings': activeBookings,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(reservationRef, {
        'guestName': draft.guestName.trim(),
        'mobile': draft.mobile.trim(),
        'tableName': draft.tableName.trim(),
        'guestCount': draft.guestCount,
        'startAt': Timestamp.fromDate(draft.startAt),
        'endAt': Timestamp.fromDate(draft.endAt),
        'status': 'booked',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> updateStatus(int id, String status) async {
    final reservationRef = _collection.doc('$id');
    await _db.runTransaction((transaction) async {
      final reservationSnapshot = await transaction.get(reservationRef);
      final reservation = reservationSnapshot.data();
      if (reservation == null) return;

      final tableRef = _tableLocks.doc(
        _tableKey(reservation['tableName'] as String? ?? ''),
      );
      final tableSnapshot = await transaction.get(tableRef);
      final tableData = tableSnapshot.data();
      final activeBookings =
          (tableData?['activeBookings'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
      final updatedBookings = <Map<String, dynamic>>[];
      for (final booking in activeBookings) {
        if ((booking['reservationId'] as num?)?.toInt() != id) {
          updatedBookings.add(booking);
        } else if (status == 'seated') {
          updatedBookings.add({...booking, 'status': status});
        }
      }

      transaction.set(
        reservationRef,
        {
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(
        tableRef,
        {
          'activeBookings': updatedBookings,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  String _tableKey(String tableName) {
    final normalized = tableName.trim().toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
    return base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
  }

  TableReservation _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return TableReservation(
      id: int.tryParse(document.id) ?? 0,
      guestName: data['guestName'] as String? ?? '',
      mobile: data['mobile'] as String? ?? '',
      tableName: data['tableName'] as String? ?? '',
      guestCount: (data['guestCount'] as num?)?.toInt() ?? 1,
      startAt: (data['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endAt: (data['endAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'booked',
    );
  }
}
