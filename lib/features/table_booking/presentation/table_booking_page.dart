import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../domain/restaurant_table.dart';
import '../domain/table_reservation.dart';

class TableBookingPage extends ConsumerWidget {
  const TableBookingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservations = ref.watch(tableReservationsProvider);
    final configuredTables = ref.watch(restaurantTablesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Table bookings'),
        actions: [
          IconButton(
            tooltip: 'Configure tables',
            onPressed: () => context.push('/table-configuration'),
            icon: const Icon(Icons.table_bar_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => configuredTables.when(
          data: (tables) {
            if (tables.isEmpty) {
              context.push('/table-configuration');
            } else {
              _createBooking(context, ref, tables);
            }
          },
          loading: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Loading configured tables...')),
          ),
          error: (_, __) => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not load configured tables.')),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New booking'),
      ),
      body: reservations.when(
        data: (items) {
          final now = DateTime.now();
          final upcoming = items
              .where((item) =>
                  item.endAt.isAfter(now) && item.status != 'cancelled')
              .toList();
          if (upcoming.isEmpty) {
            return const Center(
              child: Text('No upcoming table bookings'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: upcoming.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _ReservationTile(
              reservation: upcoming[index],
              onStatusChanged: (status) => ref
                  .read(tableReservationRepositoryProvider)
                  .updateStatus(upcoming[index].id, status),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load bookings: $error')),
      ),
    );
  }

  Future<void> _createBooking(
    BuildContext context,
    WidgetRef ref,
    List<RestaurantTable> tables,
  ) async {
    final draft = await showDialog<TableReservationDraft>(
      context: context,
      builder: (_) => _BookingDialog(tables: tables),
    );
    if (draft == null) return;

    try {
      await ref.read(tableReservationRepositoryProvider).create(draft);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Table booking added')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        final message = error is StateError
            ? error.message
            : 'Could not save booking. Check your connection and try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({
    required this.reservation,
    required this.onStatusChanged,
  });

  final TableReservation reservation;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = DateFormat('EEE, d MMM').format(reservation.startAt);
    final time = DateFormat('h:mm a').format(reservation.startAt);
    final statusColor =
        reservation.status == 'seated' ? colors.tertiary : colors.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          time,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontWeight: FontWeight.w700, color: colors.onPrimaryContainer),
        ),
      ),
      title: Text(reservation.guestName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '$date  ·  ${reservation.tableName}  ·  ${reservation.guestCount} guests'
          '${reservation.mobile.isEmpty ? '' : '\n${reservation.mobile}'}',
        ),
      ),
      isThreeLine: reservation.mobile.isNotEmpty,
      trailing: PopupMenuButton<String>(
        tooltip: 'Booking actions',
        onSelected: onStatusChanged,
        itemBuilder: (context) => [
          if (reservation.status == 'booked')
            const PopupMenuItem(value: 'seated', child: Text('Mark seated')),
          if (reservation.status == 'seated')
            const PopupMenuItem(value: 'completed', child: Text('Complete')),
          if (reservation.status == 'booked' || reservation.status == 'seated')
            const PopupMenuItem(
                value: 'cancelled', child: Text('Cancel booking')),
        ],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(reservation.status.toUpperCase(),
                style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
            const Icon(Icons.more_vert),
          ],
        ),
      ),
    );
  }
}

class _BookingDialog extends StatefulWidget {
  const _BookingDialog({required this.tables});

  final List<RestaurantTable> tables;

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _guestName = TextEditingController();
  final _mobile = TextEditingController();
  final _guestCount = TextEditingController(text: '2');
  String? _tableName;
  late DateTime _date;
  late TimeOfDay _time;
  int _durationMinutes = 90;

  @override
  void initState() {
    super.initState();
    final nextHour = DateTime.now().add(const Duration(hours: 1));
    _date = DateTime(nextHour.year, nextHour.month, nextHour.day);
    _time = TimeOfDay(hour: nextHour.hour, minute: 0);
  }

  @override
  void dispose() {
    _guestName.dispose();
    _mobile.dispose();
    _guestCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New table booking'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _guestName,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Guest name *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a guest name'
                      : null,
                ),
                TextFormField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _tableName,
                  decoration: const InputDecoration(labelText: 'Table *'),
                  items: widget.tables
                      .map((table) => DropdownMenuItem(
                            value: table.name,
                            child: Text(table.name),
                          ))
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Select a configured table' : null,
                  onChanged: (value) => setState(() => _tableName = value),
                ),
                TextFormField(
                  controller: _guestCount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Guests *'),
                  validator: (value) {
                    final count = int.tryParse(value ?? '');
                    return count == null || count < 1
                        ? 'Enter at least one guest'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(DateFormat('d MMM yyyy').format(_date)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectTime,
                        icon: const Icon(Icons.schedule),
                        label: Text(_time.format(context)),
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<int>(
                  initialValue: _durationMinutes,
                  decoration:
                      const InputDecoration(labelText: 'Table duration'),
                  items: const [60, 90, 120]
                      .map((minutes) => DropdownMenuItem(
                            value: minutes,
                            child: Text('$minutes minutes'),
                          ))
                      .toList(),
                  onChanged: (value) => setState(
                      () => _durationMinutes = value ?? _durationMinutes),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Book table')),
      ],
    );
  }

  Future<void> _selectDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null) setState(() => _time = selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final startAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    if (startAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future date and time')),
      );
      return;
    }
    Navigator.pop(
      context,
      TableReservationDraft(
        guestName: _guestName.text,
        mobile: _mobile.text,
        tableName: _tableName!,
        guestCount: int.parse(_guestCount.text),
        startAt: startAt,
        durationMinutes: _durationMinutes,
      ),
    );
  }
}
