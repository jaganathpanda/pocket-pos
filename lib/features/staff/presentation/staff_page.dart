import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/utilities/money.dart';
import '../domain/staff_repository.dart';

class StaffPage extends ConsumerStatefulWidget {
  const StaffPage({super.key});

  @override
  ConsumerState<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends ConsumerState<StaffPage> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();

  DateTime _attendanceDate = DateTime.now();
  int? _selectedAttendanceStaffId;
  String _attendanceStatus = 'present';

  DateTime _payrollMonth = DateTime(DateTime.now().year, DateTime.now().month);

  int _staffPage = 0;
  int _attendancePage = 0;
  int _payrollPage = 0;

  static const int _pageSize = 10;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _designationCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(staffRepositoryProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Staff Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Registration'),
              Tab(text: 'Attendance'),
              Tab(text: 'Payroll'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRegistrationTab(context, repo),
            _buildAttendanceTab(context, repo),
            _buildPayrollTab(context, repo),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationTab(BuildContext context, StaffRepository repo) {
    return StreamBuilder<List<Staff>>(
      stream: repo.watchActiveStaff(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rows = snapshot.data!;
        final totalPages = math.max(1, (rows.length / _pageSize).ceil());
        final currentPage = _staffPage.clamp(0, totalPages - 1);
        final start = currentPage * _pageSize;
        final end = math.min(start + _pageSize, rows.length);
        final pageRows = rows.sublist(start, end);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _designationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Designation',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _salaryCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monthly Salary',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () => _registerStaff(context, repo),
                        icon: const Icon(Icons.person_add_alt_rounded),
                        label: const Text('Register Staff'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text('Registered Staff',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: () => _showInactiveStaffDialog(context, repo),
                  icon: const Icon(Icons.person_search_rounded),
                  label: const Text('Find Inactive'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No active staff found.'),
                ),
              )
            else ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Age')),
                    DataColumn(label: Text('Designation')),
                    DataColumn(label: Text('Monthly Salary')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final s in pageRows)
                      DataRow(cells: [
                        DataCell(Text(s.name)),
                        DataCell(Text(s.age.toString())),
                        DataCell(Text(s.designation)),
                        DataCell(Text(formatInr(s.monthlySalary))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit Staff',
                                onPressed: () => _showEditStaffDialog(context, repo, s),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Deactivate Staff',
                                onPressed: () => _deactivateStaff(context, repo, s),
                                icon: const Icon(Icons.person_off_outlined),
                              ),
                            ],
                          ),
                        ),
                      ]),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _Pager(
                page: currentPage,
                totalPages: totalPages,
                onPrev: currentPage == 0
                    ? null
                    : () => setState(() => _staffPage = currentPage - 1),
                onNext: currentPage >= totalPages - 1
                    ? null
                    : () => setState(() => _staffPage = currentPage + 1),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAttendanceTab(BuildContext context, StaffRepository repo) {
    final dayStart = DateTime(
      _attendanceDate.year,
      _attendanceDate.month,
      _attendanceDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final allowInactiveForSelectedDate = dayStart.isBefore(todayStart);

    return StreamBuilder<List<Staff>>(
      stream: repo.watchAllStaff(),
      builder: (context, staffSnapshot) {
        if (!staffSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final staffs = staffSnapshot.data!;
        final activeStaffs = staffs.where((s) => s.isActive).toList(growable: false);
        final selectableStaffs = allowInactiveForSelectedDate ? staffs : activeStaffs;

        if (_selectedAttendanceStaffId == null && selectableStaffs.isNotEmpty) {
          _selectedAttendanceStaffId = selectableStaffs.first.id;
        }
        if (_selectedAttendanceStaffId != null &&
            selectableStaffs.every((s) => s.id != _selectedAttendanceStaffId)) {
          _selectedAttendanceStaffId =
              selectableStaffs.isNotEmpty ? selectableStaffs.first.id : null;
        }

        return FutureBuilder<List<StaffAttendance>>(
          future: repo.attendanceForDay(dayStart, dayEnd),
          builder: (context, attendanceSnapshot) {
            final attendanceRows = attendanceSnapshot.data ?? const <StaffAttendance>[];
            final staffById = {for (final s in staffs) s.id: s};

            final totalPages =
                math.max(1, (attendanceRows.length / _pageSize).ceil());
            final currentPage = _attendancePage.clamp(0, totalPages - 1);
            final start = currentPage * _pageSize;
            final end = math.min(start + _pageSize, attendanceRows.length);
            final pageRows = attendanceRows.sublist(start, end);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Date: ${DateFormat('dd MMM yyyy').format(_attendanceDate)}',
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 30),
                                  ),
                                  initialDate: _attendanceDate,
                                );
                                if (picked != null) {
                                  setState(() {
                                    _attendanceDate = picked;
                                    _attendancePage = 0;
                                  });
                                }
                              },
                              child: const Text('Pick Date'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          value: _selectedAttendanceStaffId,
                          decoration: const InputDecoration(
                            labelText: 'Staff',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final s in selectableStaffs)
                              DropdownMenuItem<int>(
                                value: s.id,
                                child: Text(s.name),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedAttendanceStaffId = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        if (allowInactiveForSelectedDate)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Past date selected: inactive staff are available for correction.',
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ),
                          ),
                        DropdownButtonFormField<String>(
                          value: _attendanceStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'present', child: Text('Present')),
                            DropdownMenuItem(value: 'absent', child: Text('Absent')),
                            DropdownMenuItem(value: 'half_day', child: Text('Half Day')),
                            DropdownMenuItem(value: 'leave', child: Text('Leave')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _attendanceStatus = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: selectableStaffs.isEmpty
                                ? null
                                : () => _markAttendance(context, repo),
                            icon: const Icon(Icons.fact_check_outlined),
                            label: const Text('Save Attendance'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Attendance List',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (attendanceSnapshot.connectionState ==
                    ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (attendanceRows.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No attendance marked for selected date.'),
                    ),
                  )
                else ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Staff')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Date')),
                      ],
                      rows: [
                        for (final a in pageRows)
                          DataRow(cells: [
                            DataCell(Text(staffById[a.staffId]?.name ?? 'Unknown')),
                            DataCell(Text(a.status.replaceAll('_', ' ').toUpperCase())),
                            DataCell(Text(DateFormat('dd MMM yyyy').format(a.attendanceDate))),
                          ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Pager(
                    page: currentPage,
                    totalPages: totalPages,
                    onPrev: currentPage == 0
                        ? null
                        : () => setState(() => _attendancePage = currentPage - 1),
                    onNext: currentPage >= totalPages - 1
                        ? null
                        : () => setState(() => _attendancePage = currentPage + 1),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPayrollTab(BuildContext context, StaffRepository repo) {
    final monthStart = DateTime(_payrollMonth.year, _payrollMonth.month);
    final monthEnd = DateTime(_payrollMonth.year, _payrollMonth.month + 1);

    return FutureBuilder<List<StaffPayroll>>(
      future: repo.payrollsForMonth(_payrollMonth.year, _payrollMonth.month),
      builder: (context, payrollSnapshot) {
        final payrollRows = payrollSnapshot.data ?? const <StaffPayroll>[];
        final payrollIds = payrollRows.map((p) => p.id).toList(growable: false);

        return FutureBuilder<List<Staff>>(
          future: repo.allStaff(),
          builder: (context, staffSnapshot) {
            final staffs = staffSnapshot.data ?? const <Staff>[];
            final activeStaffs = staffs.where((s) => s.isActive).toList(growable: false);
            final staffById = {for (final s in staffs) s.id: s};

            return FutureBuilder<List<StaffSalaryPayment>>(
              future: repo.paymentsForPayrolls(payrollIds),
              builder: (context, paymentSnapshot) {
                final payments = paymentSnapshot.data ?? const <StaffSalaryPayment>[];
                final paymentsByPayrollId = <int, List<StaffSalaryPayment>>{};
                for (final p in payments) {
                  paymentsByPayrollId.putIfAbsent(p.payrollId, () => <StaffSalaryPayment>[]).add(p);
                }

                final totalPages = math.max(1, (payrollRows.length / _pageSize).ceil());
                final currentPage = _payrollPage.clamp(0, totalPages - 1);
                final start = currentPage * _pageSize;
                final end = math.min(start + _pageSize, payrollRows.length);
                final pageRows = payrollRows.sublist(start, end);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Month: ${DateFormat('MMMM yyyy').format(_payrollMonth)}',
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      firstDate: DateTime(2020, 1),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                      initialDate: _payrollMonth,
                                      helpText: 'Select month',
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _payrollMonth = DateTime(picked.year, picked.month);
                                        _payrollPage = 0;
                                      });
                                    }
                                  },
                                  child: const Text('Pick Month'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: activeStaffs.isEmpty
                                    ? null
                                    : () => _generatePayroll(
                                          context,
                                          repo,
                                          activeStaffs,
                                          monthStart,
                                          monthEnd,
                                        ),
                                icon: const Icon(Icons.request_quote_outlined),
                                label: const Text('Generate Payroll'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Payroll Records',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (payrollSnapshot.connectionState == ConnectionState.waiting ||
                        paymentSnapshot.connectionState == ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator())
                    else if (payrollRows.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No payroll generated for selected month.'),
                        ),
                      )
                    else ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          columns: const [
                            DataColumn(label: Text('Staff')),
                            DataColumn(label: Text('Present Days')),
                            DataColumn(label: Text('Absent Days')),
                            DataColumn(label: Text('Payable')),
                            DataColumn(label: Text('Paid')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Payments')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: [
                            for (final p in pageRows)
                              DataRow(cells: [
                                DataCell(Text(staffById[p.staffId]?.name ?? 'Unknown')),
                                DataCell(Text(p.presentDays.toStringAsFixed(1))),
                                DataCell(Text(p.absentDays.toStringAsFixed(1))),
                                DataCell(Text(formatInr(p.payableAmount))),
                                DataCell(Text(formatInr(p.paidAmount))),
                                DataCell(Text(p.status.toUpperCase())),
                                DataCell(Text(
                                  (paymentsByPayrollId[p.id]?.length ?? 0).toString(),
                                )),
                                DataCell(
                                  PopupMenuButton<String>(
                                    tooltip: 'Payroll actions',
                                    onSelected: (value) {
                                      final rowPayments =
                                          paymentsByPayrollId[p.id] ?? const <StaffSalaryPayment>[];
                                      if (value == 'pay') {
                                        _recordPayrollPayment(
                                          context,
                                          repo,
                                          p,
                                          staffById[p.staffId],
                                        );
                                        return;
                                      }
                                      if (value == 'history') {
                                        _showPaymentHistory(
                                          context,
                                          p,
                                          staffById[p.staffId],
                                          rowPayments,
                                        );
                                        return;
                                      }
                                      if (value == 'payslip') {
                                        _showPayslipDialog(
                                          context,
                                          p,
                                          staffById[p.staffId],
                                          rowPayments,
                                        );
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem<String>(
                                        value: 'pay',
                                        child: Text('Pay'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'history',
                                        child: Text('History'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'payslip',
                                        child: Text('Payslip'),
                                      ),
                                    ],
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Icon(Icons.more_horiz_rounded),
                                    ),
                                  ),
                                ),
                              ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Pager(
                        page: currentPage,
                        totalPages: totalPages,
                        onPrev: currentPage == 0
                            ? null
                            : () => setState(() => _payrollPage = currentPage - 1),
                        onNext: currentPage >= totalPages - 1
                            ? null
                            : () => setState(() => _payrollPage = currentPage + 1),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showEditStaffDialog(
    BuildContext context,
    StaffRepository repo,
    Staff staff,
  ) async {
    final nameCtrl = TextEditingController(text: staff.name);
    final ageCtrl = TextEditingController(text: staff.age.toString());
    final designationCtrl = TextEditingController(text: staff.designation);
    final salaryCtrl = TextEditingController(
      text: staff.monthlySalary.toStringAsFixed(2),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Staff'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: designationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Designation',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: salaryCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monthly Salary',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    final age = int.tryParse(ageCtrl.text.trim()) ?? 0;
    final designation = designationCtrl.text.trim();
    final salary = double.tryParse(salaryCtrl.text.trim()) ?? 0;

    if (name.isEmpty || age <= 0 || designation.isEmpty || salary <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid staff details.')),
        );
      }
      return;
    }

    await repo.updateStaff(
      id: staff.id,
      name: name,
      age: age,
      designation: designation,
      monthlySalary: salary,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff updated successfully.')),
      );
    }
  }

  Future<void> _deactivateStaff(
    BuildContext context,
    StaffRepository repo,
    Staff staff,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Staff'),
        content: Text('Deactivate ${staff.name}? They will be hidden from active staff list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await repo.setStaffActive(staff.id, false);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff deactivated.')),
      );
    }
  }

  Future<void> _showInactiveStaffDialog(
    BuildContext context,
    StaffRepository repo,
  ) async {
    final searchCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Inactive Staff Details'),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search by name or designation',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (_) => setLocalState(() {}),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: StreamBuilder<List<Staff>>(
                    stream: repo.watchInactiveStaff(),
                    builder: (context, snapshot) {
                      final rows = snapshot.data ?? const <Staff>[];
                      final q = searchCtrl.text.trim().toLowerCase();
                      final filtered = q.isEmpty
                          ? rows
                          : rows
                              .where((s) =>
                                  s.name.toLowerCase().contains(q) ||
                                  s.designation.toLowerCase().contains(q))
                              .toList(growable: false);

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (filtered.isEmpty) {
                        return const Center(child: Text('No inactive staff found.'));
                      }

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Age')),
                            DataColumn(label: Text('Designation')),
                            DataColumn(label: Text('Monthly Salary')),
                            DataColumn(label: Text('Created')),
                            DataColumn(label: Text('Action')),
                          ],
                          rows: [
                            for (final s in filtered)
                              DataRow(
                                cells: [
                                  DataCell(Text(s.name)),
                                  DataCell(Text(s.age.toString())),
                                  DataCell(Text(s.designation)),
                                  DataCell(Text(formatInr(s.monthlySalary))),
                                  DataCell(Text(DateFormat('dd MMM yyyy').format(s.createdAt))),
                                  DataCell(
                                    TextButton(
                                      onPressed: () async {
                                        await repo.setStaffActive(s.id, true);
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(ctx).showSnackBar(
                                            const SnackBar(content: Text('Staff reactivated.')),
                                          );
                                        }
                                      },
                                      child: const Text('Reactivate'),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentHistory(
    BuildContext context,
    StaffPayroll payroll,
    Staff? staff,
    List<StaffSalaryPayment> payments,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Payment History - ${staff?.name ?? 'Staff'}'),
        content: SizedBox(
          width: 540,
          child: payments.isEmpty
              ? const Text('No payment records found for this payroll.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: payments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = payments[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(formatInr(p.amount)),
                      subtitle: Text(DateFormat('dd MMM yyyy HH:mm').format(p.paidOn)),
                      trailing: Text(p.note?.trim().isNotEmpty == true ? p.note! : '-'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPayslipDialog(
    BuildContext context,
    StaffPayroll payroll,
    Staff? staff,
    List<StaffSalaryPayment> payments,
  ) async {
    final monthDate = DateTime(payroll.payrollYear, payroll.payrollMonth);
    final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
    final effectivePaid = payments.isEmpty ? payroll.paidAmount : totalPaid;
    final due = (payroll.payableAmount - effectivePaid).clamp(0, 999999999).toDouble();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Staff Payslip'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Staff: ${staff?.name ?? 'Unknown'}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Designation: ${staff?.designation ?? '-'}'),
              Text('Month: ${DateFormat('MMMM yyyy').format(monthDate)}'),
              const SizedBox(height: 10),
              Text('Present Days: ${payroll.presentDays.toStringAsFixed(1)}'),
              Text('Absent Days: ${payroll.absentDays.toStringAsFixed(1)}'),
              Text('Payable: ${formatInr(payroll.payableAmount)}'),
              Text('Paid: ${formatInr(effectivePaid)}'),
              Text('Due: ${formatInr(due)}'),
              const SizedBox(height: 12),
              const Text('Payment Entries',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (payments.isEmpty)
                const Text('No payment entries for this payslip.')
              else
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    itemCount: payments.length,
                    itemBuilder: (_, i) {
                      final p = payments[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(formatInr(p.amount)),
                        subtitle: Text(DateFormat('dd MMM yyyy HH:mm').format(p.paidOn)),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerStaff(BuildContext context, StaffRepository repo) async {
    final name = _nameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    final designation = _designationCtrl.text.trim();
    final salary = double.tryParse(_salaryCtrl.text.trim()) ?? 0;

    if (name.isEmpty || age <= 0 || designation.isEmpty || salary <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid name, age, designation and salary.')),
      );
      return;
    }

    await repo.addStaff(
      name: name,
      age: age,
      designation: designation,
      monthlySalary: salary,
    );

    _nameCtrl.clear();
    _ageCtrl.clear();
    _designationCtrl.clear();
    _salaryCtrl.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff registered successfully.')),
      );
    }
  }

  Future<void> _markAttendance(BuildContext context, StaffRepository repo) async {
    final staffId = _selectedAttendanceStaffId;
    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a staff member first.')),
      );
      return;
    }

    final dateOnly = DateTime(
      _attendanceDate.year,
      _attendanceDate.month,
      _attendanceDate.day,
    );

    await repo.markAttendance(
      staffId: staffId,
      date: dateOnly,
      status: _attendanceStatus,
    );

    setState(() {
      _attendancePage = 0;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved.')),
      );
    }
  }

  Future<void> _generatePayroll(
    BuildContext context,
    StaffRepository repo,
    List<Staff> staffs,
    DateTime monthStart,
    DateTime monthEnd,
  ) async {
    final daysInMonth = DateUtils.getDaysInMonth(monthStart.year, monthStart.month);

    for (final staff in staffs) {
      final attendance =
          await repo.attendanceForRange(staff.id, monthStart, monthEnd);

      double presentDays = 0;
      for (final row in attendance) {
        if (row.status == 'present') {
          presentDays += 1;
        } else if (row.status == 'half_day') {
          presentDays += 0.5;
        }
      }

      final absentDays = (daysInMonth - presentDays).clamp(0, daysInMonth).toDouble();
      final payableAmount = (staff.monthlySalary / daysInMonth) * presentDays;

      await repo.upsertPayroll(
        staffId: staff.id,
        month: monthStart.month,
        year: monthStart.year,
        presentDays: presentDays,
        absentDays: absentDays,
        payableAmount: payableAmount,
      );
    }

    setState(() {
      _payrollPage = 0;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payroll generated for selected month.')),
      );
    }
  }

  Future<void> _recordPayrollPayment(
    BuildContext context,
    StaffRepository repo,
    StaffPayroll payroll,
    Staff? staff,
  ) async {
    if (staff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to identify staff for this payroll.')),
      );
      return;
    }

    final paidCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payroll Payment'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: paidCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Payment Amount',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final paymentAmount = double.tryParse(paidCtrl.text.trim()) ?? 0;
    if (paymentAmount <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid payment amount.')),
        );
      }
      return;
    }

    await repo.recordSalaryPayment(
      payroll: payroll,
      staffId: staff.id,
      amount: paymentAmount,
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    );

    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payroll payment updated.')),
      );
    }
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text('Page ${page + 1} of $totalPages'),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
