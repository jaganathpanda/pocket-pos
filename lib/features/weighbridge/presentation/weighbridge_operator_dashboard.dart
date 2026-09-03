import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../store/presentation/store_auth_controller.dart';
import '../domain/vehicle_entry.dart';
import 'vehicle_entry_detail_page.dart';

/// Landing screen for a Weighbridge Operator: create vehicle entries and track
/// their approval status. Operators do not see the rest of the app.
class WeighbridgeOperatorDashboard extends ConsumerWidget {
  const WeighbridgeOperatorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(myWeighbridgeEntriesProvider);
    final username = ref.watch(storeSessionProvider)?.username ?? 'Operator';

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.watch(storeSessionProvider)?.storeName ?? 'Weighbridge'),
        actions: [
          TextButton.icon(
            onPressed: () =>
                ref.read(storeAuthControllerProvider.notifier).exitMill(),
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            label: const Text('Switch Mill',
                style: TextStyle(color: Colors.white)),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(storeAuthControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const VehicleEntryDetailPage(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Vehicle Entry'),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          final pending = entries.where((e) => e.isPending).toList();
          final approved = entries.where((e) => e.isApproved).toList();
          final rejected = entries.where((e) => e.isRejected).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Welcome, $username',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  _CountTile(
                      label: 'Pending',
                      count: pending.length,
                      color: Colors.orange),
                  const SizedBox(width: 8),
                  _CountTile(
                      label: 'Approved',
                      count: approved.length,
                      color: Colors.green),
                  const SizedBox(width: 8),
                  _CountTile(
                      label: 'Rejected',
                      count: rejected.length,
                      color: Colors.red),
                ],
              ),
              const SizedBox(height: 16),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(
                      child: Text('No entries yet. Tap + to add one.')),
                )
              else
                ...entries.map((e) => _EntryTile(entry: e)),
            ],
          );
        },
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile(
      {required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final VehicleEntry entry;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (entry.status) {
      'pending' => (Colors.orange, Icons.hourglass_top),
      'rejected' => (Colors.red, Icons.cancel_outlined),
      _ => (Colors.green, Icons.check_circle_outline),
    };
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text('${entry.vehicleNo}  ·  ${entry.slipNo}'),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy').format(entry.date)} · '
          '${entry.netWeight.toStringAsFixed(0)} Kg'
          '${entry.isRejected && entry.rejectionReason != null ? '\nReason: ${entry.rejectionReason}' : ''}',
        ),
        isThreeLine: entry.isRejected && entry.rejectionReason != null,
        trailing: Text(entry.status.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VehicleEntryDetailPage(entryId: entry.id),
          ),
        ),
      ),
    );
  }
}
