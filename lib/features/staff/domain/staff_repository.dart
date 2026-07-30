import '../../../core/database/app_database.dart';

/// Staff management: registration, attendance, payroll and salary payments.
abstract class StaffRepository {
  // Staff directory.
  Stream<List<Staff>> watchActiveStaff();
  Stream<List<Staff>> watchAllStaff();
  Stream<List<Staff>> watchInactiveStaff();
  Future<List<Staff>> allStaff();

  Future<void> addStaff({
    required String name,
    required int age,
    required String designation,
    required double monthlySalary,
  });
  Future<void> updateStaff({
    required int id,
    required String name,
    required int age,
    required String designation,
    required double monthlySalary,
  });
  Future<void> setStaffActive(int id, bool active);

  // Attendance.
  Future<List<StaffAttendance>> attendanceForDay(DateTime dayStart, DateTime dayEnd);
  Future<List<StaffAttendance>> attendanceForRange(
      int staffId, DateTime from, DateTime to);
  Future<void> markAttendance({
    required int staffId,
    required DateTime date,
    required String status,
  });

  // Payroll.
  Future<List<StaffPayroll>> payrollsForMonth(int year, int month);
  Future<void> upsertPayroll({
    required int staffId,
    required int month,
    required int year,
    required double presentDays,
    required double absentDays,
    required double payableAmount,
  });

  // Salary payments.
  Future<List<StaffSalaryPayment>> paymentsForPayrolls(List<int> payrollIds);

  /// Records a salary payment against [payroll], then recomputes the payroll's
  /// total paid amount and status (unpaid / partial / paid).
  Future<void> recordSalaryPayment({
    required StaffPayroll payroll,
    required int staffId,
    required double amount,
    String? note,
  });
}
