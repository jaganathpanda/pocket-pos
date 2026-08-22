import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pocket_pos/features/paddy_procurement/domain/paddy_procurement.dart';
import '../../../core/utilities/money.dart';
import '../providers/paddy_procurement_providers.dart';
import 'paddy_procurement_form.dart';

class PaddyProcurementPage extends ConsumerStatefulWidget {
  const PaddyProcurementPage({super.key, this.procurementId});

  final int? procurementId;

  @override
  ConsumerState<PaddyProcurementPage> createState() =>
      _PaddyProcurementPageState();
}

class _PaddyProcurementPageState extends ConsumerState<PaddyProcurementPage> {
  final _searchController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(paddyProcurementFilterProvider.notifier).state =
        PaddyProcurementFilter(
      fromDate: _fromDate,
      toDate: _toDate,
      partyName: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );
  }

  void _clearFilters() {
    _fromDate = null;
    _toDate = null;
    _searchController.clear();
    ref.read(paddyProcurementFilterProvider.notifier).state =
        const PaddyProcurementFilter();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _fromDate ?? now.subtract(const Duration(days: 30)),
        end: _toDate ?? now,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final procurements = ref.watch(paddyProcurementStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paddy Procurement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _pickDateRange,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(null),
        icon: const Icon(Icons.add),
        label: const Text('New Procurement'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by Party or Slip No',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: _clearFilters,
                            )
                          : null,
                    ),
                    onChanged: (_) => _applyFilters(),
                  ),
                ),
                const SizedBox(width: 8),
                if (_fromDate != null || _toDate != null)
                  Chip(
                    label: Text(
                      '${_fromDate != null ? DateFormat('dd/MM/yy').format(_fromDate!) : '...'} - ${_toDate != null ? DateFormat('dd/MM/yy').format(_toDate!) : '...'}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onDeleted: _clearFilters,
                  ),
              ],
            ),
          ),
          // List
          Expanded(
            child: procurements.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.grass_rounded, size: 56, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No paddy procurements yet.',
                            style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 6),
                        Text('Tap + to start a new procurement.',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = list[index];
                    return _ProcurementTile(
                      procurement: p,
                      onTap: () => _navigateToForm(p.id),
                      onComplete: p.status == 'draft'
                          ? () => _completeProcurement(p.id!)
                          : null,
                      onDelete: p.status == 'draft'
                          ? () => _deleteProcurement(p.id!)
                          : null,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToForm(int? id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaddyProcurementForm(procurementId: id),
      ),
    ).then((_) => ref.refresh(paddyProcurementStreamProvider));
  }

  Future<void> _completeProcurement(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Procurement?'),
        content: const Text(
          'This will add the paddy to inventory. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref
          .read(paddyProcurementRepositoryProvider)
          .completeProcurement(id);
      ref.refresh(paddyProcurementStreamProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Procurement completed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteProcurement(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Procurement?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(paddyProcurementRepositoryProvider).deleteProcurement(id);
      ref.refresh(paddyProcurementStreamProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _ProcurementTile extends StatelessWidget {
  const _ProcurementTile({
    required this.procurement,
    required this.onTap,
    this.onComplete,
    this.onDelete,
  });

  final PaddyProcurement procurement;
  final VoidCallback onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFT = procurement.marketType == 'FT';
    final amount = procurement.totalAmount ?? 0;
    final status = procurement.status;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _statusColor(status).withOpacity(0.15),
        child: Icon(
          Icons.grass_rounded,
          color: _statusColor(status),
          size: 20,
        ),
      ),
      title: Text(
        '${procurement.slipNo}  •  ${procurement.partyName}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat('dd/MM/yyyy').format(procurement.date)}  •  '
            '${procurement.productName}  •  '
            '${procurement.netWeight.toStringAsFixed(2)} kg',
            style: const TextStyle(fontSize: 12),
          ),
          if (isFT)
            Text(
              '₹${formatInr(amount)}  •  Rate: ₹${(procurement.ratePerQntl ?? 0).toStringAsFixed(2)}/Qntl',
              style: const TextStyle(fontSize: 11, color: Colors.green),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(
              '${procurement.marketType}  •  ${procurement.procurementType}',
              style: const TextStyle(fontSize: 10),
            ),
            backgroundColor: procurement.marketType == 'FT'
                ? Colors.green.shade100
                : Colors.blue.shade100,
            side: BorderSide.none,
          ),
          const SizedBox(width: 4),
          Chip(
            label: Text(status.toUpperCase(),
                style: const TextStyle(fontSize: 10)),
            backgroundColor: _statusColor(status).withOpacity(0.12),
            side: BorderSide.none,
          ),
          if (status == 'draft') ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onTap,
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                onPressed: onDelete,
              ),
            if (onComplete != null)
              IconButton(
                icon: const Icon(Icons.check_circle_outline,
                    size: 18, color: Colors.green),
                onPressed: onComplete,
              ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
