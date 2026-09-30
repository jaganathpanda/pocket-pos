import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../domain/restaurant_table.dart';

class TableConfigurationPage extends ConsumerWidget {
  const TableConfigurationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(restaurantTablesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Table configuration')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTable(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add table'),
      ),
      body: tables.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.table_restaurant_outlined, size: 40),
                    SizedBox(height: 12),
                    Text('No tables configured'),
                    SizedBox(height: 4),
                    Text('Add your restaurant tables to use them in bookings.'),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _TableTile(
              table: items[index],
              onRemove: () => _removeTable(context, ref, items[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load tables: $error')),
      ),
    );
  }

  Future<void> _addTable(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddRestaurantTableDialog(),
    );
    if (name == null) return;

    try {
      await ref.read(tableReservationRepositoryProvider).addTable(name);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _removeTable(
    BuildContext context,
    WidgetRef ref,
    RestaurantTable table,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove table?'),
        content: Text('Remove ${table.name} from the configured tables?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(tableReservationRepositoryProvider)
          .removeTable(table.name);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _showError(BuildContext context, Object error) {
    final message = switch (error) {
      StateError() => error.message,
      FirebaseException() =>
        'Could not save table (${error.code}): ${error.message ?? 'Check Firestore access and connection.'}',
      _ => 'Could not save table: $error',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _AddRestaurantTableDialog extends StatefulWidget {
  const _AddRestaurantTableDialog();

  @override
  State<_AddRestaurantTableDialog> createState() =>
      _AddRestaurantTableDialogState();
}

class _AddRestaurantTableDialogState extends State<_AddRestaurantTableDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add restaurant table'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Table name',
            hintText: 'Table 1',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter a table name'
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add table'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _controller.text.trim());
  }
}

class _TableTile extends StatelessWidget {
  const _TableTile({required this.table, required this.onRemove});

  final RestaurantTable table;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.table_restaurant_outlined),
      title: Text(table.name),
      trailing: IconButton(
        tooltip: 'Remove table',
        onPressed: onRemove,
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}
