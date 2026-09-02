import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../domain/vehicle_entry.dart';
import 'vehicle_entry_detail_page.dart';

/// Miller-facing list of weighbridge entries awaiting approval, with
/// approve / reject actions. Approving unlocks the existing Convert-to-
/// Procurement flow on the entry.
class PendingApprovalsPage extends ConsumerWidget {
  const PendingApprovalsPage({super.key});

  Future<void> _approve(WidgetRef ref, VehicleEntry e) async {
    final uid = ref.read(currentUidProvider) ?? '';
    await ref.read(weighbridgeRepositoryProvider).approveEntry(
          e.id,
          approvedByUid: uid,
        );
  }

  Future<void> _reject(
      BuildContext context, WidgetRef ref, VehicleEntry e) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject entry'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Reject')),
        ],
      ),
    );
    if (reason == null) return; // cancelled
    final uid = ref.read(currentUidProvider) ?? '';
    await ref.read(weighbridgeRepositoryProvider).rejectEntry(
          e.id,
          approvedByUid: uid,
          reason: reason.isEmpty ? null : reason,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingApprovalsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Approvals')),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('No entries awaiting approval.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = entries[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${e.vehicleNo}  ·  Slip ${e.slipNo}'),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy').format(e.date)} · '
                          '${e.netWeight.toStringAsFixed(0)} Kg · '
                          '${e.weighMode == 'manual' ? 'Manual' : 'Weighbridge'}'
                          '${e.createdByName != null ? '\nBy: ${e.createdByName}' : ''}',
                        ),
                        isThreeLine: e.createdByName != null,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                VehicleEntryDetailPage(entryId: e.id),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _reject(context, ref, e),
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text('Reject',
                                style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _approve(ref, e),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
