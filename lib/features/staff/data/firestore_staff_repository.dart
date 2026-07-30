import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/database/app_database.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';
import '../domain/staff_repository.dart';

/// Store-scoped Firestore implementation of [StaffRepository].
///
/// Queries stay single-field (or full-collection for the small staff data set)
/// so no composite indexes are required, and all filtering/sorting that would
/// otherwise need one is done client-side. This also keeps everything served
/// from the offline cache.
class FirestoreStaffRepository implements StaffRepository {
  FirestoreStaffRepository(this._db, this._storeId);

  final FirebaseFirestore _db;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _staff =>
      storeCollection(_db, _storeId, 'staffs');
  CollectionReference<Map<String, dynamic>> get _attendance =>
      storeCollection(_db, _storeId, 'staff_attendances');
  CollectionReference<Map<String, dynamic>> get _payrolls =>
      storeCollection(_db, _storeId, 'staff_payrolls');
  CollectionReference<Map<String, dynamic>> get _payments =>
      storeCollection(_db, _storeId, 'staff_salary_payments');

  static double _num(dynamic v, [double or = 0]) => (v as num?)?.toDouble() ?? or;
  static int _int(dynamic v, [int or = 0]) => (v as num?)?.toInt() ?? or;

  // ── Staff directory ────────────────────────────────────────────────────────

  @override
  Stream<List<Staff>> watchActiveStaff() => _staff.snapshots().map((snap) {
        final list = snap.docs.map(_staffFromDoc).where((s) => s.isActive).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  @override
  Stream<List<Staff>> watchAllStaff() => _staff.snapshots().map((snap) {
        final list = snap.docs.map(_staffFromDoc).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  @override
  Stream<List<Staff>> watchInactiveStaff() => _staff.snapshots().map((snap) {
        final list = snap.docs.map(_staffFromDoc).where((s) => !s.isActive).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  @override
  Future<List<Staff>> allStaff() async {
    final snap = await _staff.get();
    return snap.docs.map(_staffFromDoc).toList();
  }

  @override
  Future<void> addStaff({
    required String name,
    required int age,
    required String designation,
    required double monthlySalary,
  }) async {
    final id = newIntId();
    await _staff.doc('$id').set({
      'name': name,
      'age': age,
      'designation': designation,
      'monthlySalary': monthlySalary,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateStaff({
    required int id,
    required String name,
    required int age,
    required String designation,
    required double monthlySalary,
  }) =>
      _staff.doc('$id').set({
        'name': name,
        'age': age,
        'designation': designation,
        'monthlySalary': monthlySalary,
      }, SetOptions(merge: true));

  @override
  Future<void> setStaffActive(int id, bool active) =>
      _staff.doc('$id').set({'isActive': active}, SetOptions(merge: true));

  // ── Attendance ──────────────────────────────────────────────────────────────

  @override
  Future<List<StaffAttendance>> attendanceForDay(
      DateTime dayStart, DateTime dayEnd) async {
    final snap = await _attendance
        .where('attendanceDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('attendanceDate', isLessThan: Timestamp.fromDate(dayEnd))
        .get();
    final list = snap.docs.map(_attendanceFromDoc).toList()
      ..sort((a, b) => a.staffId.compareTo(b.staffId));
    return list;
  }

  @override
  Future<List<StaffAttendance>> attendanceForRange(
      int staffId, DateTime from, DateTime to) async {
    final snap = await _attendance
        .where('attendanceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('attendanceDate', isLessThan: Timestamp.fromDate(to))
        .get();
    return snap.docs
        .map(_attendanceFromDoc)
        .where((a) => a.staffId == staffId)
        .toList();
  }

  @override
  Future<void> markAttendance({
    required int staffId,
    required DateTime date,
    required String status,
  }) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final sameDay = await attendanceForRange(staffId, dayStart, dayEnd);
    if (sameDay.isEmpty) {
      final id = newIntId();
      await _attendance.doc('$id').set({
        'staffId': staffId,
        'attendanceDate': Timestamp.fromDate(dayStart),
        'status': status,
        'checkInAt': null,
        'checkOutAt': null,
        'note': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _attendance
          .doc('${sameDay.first.id}')
          .set({'status': status}, SetOptions(merge: true));
    }
  }

  // ── Payroll ──────────────────────────────────────────────────────────────────

  @override
  Future<List<StaffPayroll>> payrollsForMonth(int year, int month) async {
    final snap = await _payrolls.where('payrollYear', isEqualTo: year).get();
    final list = snap.docs
        .map(_payrollFromDoc)
        .where((p) => p.payrollMonth == month)
        .toList()
      ..sort((a, b) => a.staffId.compareTo(b.staffId));
    return list;
  }

  @override
  Future<void> upsertPayroll({
    required int staffId,
    required int month,
    required int year,
    required double presentDays,
    required double absentDays,
    required double payableAmount,
  }) async {
    final existing = (await payrollsForMonth(year, month))
        .where((p) => p.staffId == staffId)
        .toList();
    if (existing.isEmpty) {
      final id = newIntId();
      await _payrolls.doc('$id').set({
        'staffId': staffId,
        'payrollMonth': month,
        'payrollYear': year,
        'presentDays': presentDays,
        'absentDays': absentDays,
        'payableAmount': payableAmount,
        'paidAmount': 0.0,
        'paidAt': null,
        'status': 'unpaid',
        'note': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _payrolls.doc('${existing.first.id}').set({
        'presentDays': presentDays,
        'absentDays': absentDays,
        'payableAmount': payableAmount,
      }, SetOptions(merge: true));
    }
  }

  // ── Salary payments ──────────────────────────────────────────────────────────

  @override
  Future<List<StaffSalaryPayment>> paymentsForPayrolls(List<int> payrollIds) async {
    if (payrollIds.isEmpty) return const [];
    final ids = payrollIds.toSet();
    final snap = await _payments.get();
    final list = snap.docs
        .map(_paymentFromDoc)
        .where((p) => ids.contains(p.payrollId))
        .toList()
      ..sort((a, b) => b.paidOn.compareTo(a.paidOn));
    return list;
  }

  @override
  Future<void> recordSalaryPayment({
    required StaffPayroll payroll,
    required int staffId,
    required double amount,
    String? note,
  }) async {
    final before = await paymentsForPayrolls([payroll.id]);
    // Carry a pre-existing lump paidAmount as legacy when no itemised rows exist.
    final legacyCarry = before.isEmpty ? payroll.paidAmount : 0.0;

    final id = newIntId();
    await _payments.doc('$id').set({
      'staffId': staffId,
      'payrollId': payroll.id,
      'amount': amount,
      'paidOn': FieldValue.serverTimestamp(),
      'note': note,
    });

    final all = await paymentsForPayrolls([payroll.id]);
    final totalPaid =
        legacyCarry + all.fold<double>(0, (acc, p) => acc + p.amount);
    final status = totalPaid >= payroll.payableAmount
        ? 'paid'
        : (totalPaid <= 0 ? 'unpaid' : 'partial');

    await _payrolls.doc('${payroll.id}').set({
      'paidAmount': totalPaid,
      'paidAt': FieldValue.serverTimestamp(),
      'status': status,
    }, SetOptions(merge: true));
  }

  // ── mappers ────────────────────────────────────────────────────────────────

  Staff _staffFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Staff(
      id: int.tryParse(doc.id) ?? 0,
      name: (d['name'] as String?) ?? '',
      age: _int(d['age']),
      designation: (d['designation'] as String?) ?? '',
      monthlySalary: _num(d['monthlySalary']),
      isActive: (d['isActive'] as bool?) ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  StaffAttendance _attendanceFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return StaffAttendance(
      id: int.tryParse(doc.id) ?? 0,
      staffId: _int(d['staffId']),
      attendanceDate: (d['attendanceDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: (d['status'] as String?) ?? 'present',
      checkInAt: (d['checkInAt'] as Timestamp?)?.toDate(),
      checkOutAt: (d['checkOutAt'] as Timestamp?)?.toDate(),
      note: d['note'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  StaffPayroll _payrollFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return StaffPayroll(
      id: int.tryParse(doc.id) ?? 0,
      staffId: _int(d['staffId']),
      payrollMonth: _int(d['payrollMonth']),
      payrollYear: _int(d['payrollYear']),
      presentDays: _num(d['presentDays']),
      absentDays: _num(d['absentDays']),
      payableAmount: _num(d['payableAmount']),
      paidAmount: _num(d['paidAmount']),
      paidAt: (d['paidAt'] as Timestamp?)?.toDate(),
      status: (d['status'] as String?) ?? 'unpaid',
      note: d['note'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  StaffSalaryPayment _paymentFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return StaffSalaryPayment(
      id: int.tryParse(doc.id) ?? 0,
      staffId: _int(d['staffId']),
      payrollId: _int(d['payrollId']),
      amount: _num(d['amount']),
      paidOn: (d['paidOn'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: d['note'] as String?,
    );
  }
}
