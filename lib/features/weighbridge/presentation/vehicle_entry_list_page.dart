import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pocket_pos/core/di/providers.dart';
import 'package:pocket_pos/features/weighbridge/presentation/vehicle_entry_detail_page.dart';
import '../domain/vehicle_entry.dart';

class VehicleEntryListPage extends ConsumerStatefulWidget {
  const VehicleEntryListPage({super.key});

  @override
  ConsumerState<VehicleEntryListPage> createState() =>
      _VehicleEntryListPageState();
}

class _VehicleEntryListPageState extends ConsumerState<VehicleEntryListPage> {
  DateTime? _fromDate;
  DateTime? _toDate;
  final _vehicleCtrl = TextEditingController();
  final _partyCtrl = TextEditingController();

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    _partyCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(weighbridgeFilterProvider.notifier).state = WeighbridgeFilter(
      fromDate: _fromDate,
      toDate: _toDate,
      vehicleNo:
          _vehicleCtrl.text.trim().isEmpty ? null : _vehicleCtrl.text.trim(),
      partyName: _partyCtrl.text.trim().isEmpty ? null : _partyCtrl.text.trim(),
    );
  }

  void _clearFilters() {
    _fromDate = null;
    _toDate = null;
    _vehicleCtrl.clear();
    _partyCtrl.clear();
    ref.read(weighbridgeFilterProvider.notifier).state =
        const WeighbridgeFilter();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(vehicleEntriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Weight Entry [Modify]'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToDetail(null),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
      body: entriesAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('No vehicle entries found.'));
          }
          return Column(
            children: [
              // Optional filter bar (simplified)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _vehicleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle No',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _partyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Party Name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _applyFilters,
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearFilters,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: entry.complete
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          child: Text(entry.complete ? '✓' : '📝'),
                        ),
                        title: Text('${entry.slipNo}  •  ${entry.vehicleNo}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${DateFormat('dd/MM/yyyy').format(entry.date)}  •  ${entry.partyName}  •  ${entry.productName ?? 'Product'}'),
                            Text(
                                'Net: ${entry.netWeight} kg  •  Pkts: ${entry.bags ?? 0}  •  Lot: ${entry.lotNumber ?? '-'}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (entry.complete)
                              Chip(
                                label: Text(entry.completeCode ?? 'Done'),
                                backgroundColor: Colors.green.shade100,
                              ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _navigateToDetail(entry);
                                if (value == 'complete') _markComplete(entry);
                                if (value == 'delete') _confirmDelete(entry);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'edit', child: Text('Edit')),
                                if (!entry.complete)
                                  const PopupMenuItem(
                                      value: 'complete',
                                      child: Text('Mark Complete')),
                                const PopupMenuItem(
                                    value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    final now = DateTime.now();
    final from = _fromDate ?? now.subtract(const Duration(days: 30));
    final to = _toDate ?? now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(start: from, end: to),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _applyFilters();
    }
  }

  void _navigateToDetail(VehicleEntry? entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleEntryDetailPage(entryId: entry?.id),
      ),
    ).then((_) => ref.invalidate(vehicleEntriesStreamProvider));
  }

  Future<void> _markComplete(VehicleEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Complete'),
        content: Text('Complete entry #${entry.slipNo}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Complete')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(weighbridgeRepositoryProvider).markComplete(entry.id);
      ref.invalidate(vehicleEntriesStreamProvider);
    }
  }

  Future<void> _confirmDelete(VehicleEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Delete entry #${entry.slipNo}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(weighbridgeRepositoryProvider).deleteEntry(entry.id);
      ref.invalidate(vehicleEntriesStreamProvider);
    }
  }
}
