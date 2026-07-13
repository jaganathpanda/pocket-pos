import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';

class SupplierPage extends ConsumerWidget {
  const SupplierPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Parties / Vendors')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add Party'),
      ),
      body: suppliers.when(
        data: (list) => list.isEmpty
            ? const Center(child: Text('No vendors yet. Add one to get started.'))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final s = list[index];
                  return _SupplierTile(
                    supplier: s,
                    onEdit: () => _showAddEditDialog(context, ref, s),
                    onViewPurchases: () => context.go('/purchases', extra: s.id),
                    onDelete: () => _confirmDelete(context, ref, s),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _showAddEditDialog(BuildContext context, WidgetRef ref, Supplier? existing) async {
    final name = TextEditingController(text: existing?.name);
    final mobile = TextEditingController(text: existing?.mobile);
    final gst = TextEditingController(text: existing?.gstNumber);
    final email = TextEditingController(text: existing?.email);
    final address = TextEditingController(text: existing?.address);
    final contact = TextEditingController(text: existing?.contactPerson);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Party / Vendor' : 'Edit Party'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(name, 'Party / Vendor Name *'),
              _field(mobile, 'Mobile'),
              _field(gst, 'GST Number'),
              _field(email, 'Email'),
              _field(contact, 'Contact Person'),
              _field(address, 'Address', maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final n = name.text.trim();
              if (n.isEmpty) return;
              final repo = ref.read(supplierRepositoryProvider);
              if (existing == null) {
                await repo.add(
                  name: n,
                  mobile: mobile.text.trim().isEmpty ? null : mobile.text.trim(),
                  gstNumber: gst.text.trim().isEmpty ? null : gst.text.trim(),
                  email: email.text.trim().isEmpty ? null : email.text.trim(),
                  address: address.text.trim().isEmpty ? null : address.text.trim(),
                  contactPerson: contact.text.trim().isEmpty ? null : contact.text.trim(),
                );
              } else {
                await repo.update(
                  id: existing.id,
                  name: n,
                  mobile: mobile.text.trim().isEmpty ? null : mobile.text.trim(),
                  gstNumber: gst.text.trim().isEmpty ? null : gst.text.trim(),
                  email: email.text.trim().isEmpty ? null : email.text.trim(),
                  address: address.text.trim().isEmpty ? null : address.text.trim(),
                  contactPerson: contact.text.trim().isEmpty ? null : contact.text.trim(),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Supplier s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vendor?'),
        content: Text('Remove "${s.name}"? Existing purchases will be retained.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(supplierRepositoryProvider).delete(s.id);
    }
  }

  Widget _field(TextEditingController c, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  const _SupplierTile({
    required this.supplier,
    required this.onEdit,
    required this.onViewPurchases,
    required this.onDelete,
  });

  final Supplier supplier;
  final VoidCallback onEdit;
  final VoidCallback onViewPurchases;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(supplier.name[0].toUpperCase()),
      ),
      title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (supplier.mobile != null) Text('📞 ${supplier.mobile}'),
          if (supplier.gstNumber != null) Text('GST: ${supplier.gstNumber}'),
          if (supplier.contactPerson != null) Text('Contact: ${supplier.contactPerson}'),
        ],
      ),
      isThreeLine: supplier.mobile != null && supplier.gstNumber != null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(
              'Due: Rs ${supplier.outstandingBalance.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 11,
                color: supplier.outstandingBalance > 0 ? Colors.red : Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'purchases') onViewPurchases();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'purchases', child: Text('View Purchases')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}
