import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';

class PosCountersPage extends ConsumerWidget {
  const PosCountersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    // Guard: only the shop owner / super admin can manage counters and users.
    if (user != null && !user.canManagePos) {
      return Scaffold(
        appBar: AppBar(title: const Text('POS Counters')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Only the shop owner can manage POS counters and users.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final counters = ref.watch(countersProvider);
    final posUsers = ref.watch(posUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('POS Counters & Users')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(
            context,
            'Counters',
            FilledButton.icon(
              onPressed: () => _addCounterDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Counter'),
            ),
          ),
          counters.when(
            data: (list) {
              if (list.isEmpty) {
                return const _EmptyHint('No counters yet. Add POS1, POS2, …');
              }
              return Column(
                children: [
                  for (final c in list)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.point_of_sale_rounded),
                        title: Text(c.name),
                        subtitle: Text(c.isActive ? 'Active' : 'Inactive'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Rename',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _renameCounterDialog(context, ref, c),
                            ),
                            Switch(
                              value: c.isActive,
                              onChanged: (v) => ref
                                  .read(posCounterRepositoryProvider)
                                  .setCounterActive(c.id, v),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 28),
          _header(
            context,
            'POS Users',
            FilledButton.icon(
              onPressed: () => _addUserDialog(context, ref),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Add POS User'),
            ),
          ),
          posUsers.when(
            data: (list) {
              if (list.isEmpty) {
                return const _EmptyHint(
                    'No POS users yet. Add a login and assign it to a counter.');
              }
              return Column(
                children: [
                  for (final row in list)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_rounded),
                        title: Text(row.user.username),
                        subtitle: Text(
                          'Counter: ${row.counterName ?? '-'}  •  '
                          '${row.user.isActive ? 'Active' : 'Disabled'}',
                        ),
                        trailing: Switch(
                          value: row.user.isActive,
                          onChanged: (v) => ref
                              .read(posCounterRepositoryProvider)
                              .setUserActive(row.user.id, v),
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String title, Widget action) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          action,
        ],
      ),
    );
  }

  Future<void> _addCounterDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Counter'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Counter name (e.g. POS1)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _run(context, ref,
        () => ref.read(posCounterRepositoryProvider).addCounter(name));
  }

  Future<void> _renameCounterDialog(
      BuildContext context, WidgetRef ref, PosCounter counter) async {
    final ctrl = TextEditingController(text: counter.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Counter'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Counter name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _run(context, ref,
        () => ref.read(posCounterRepositoryProvider).renameCounter(counter.id, name));
  }

  Future<void> _addUserDialog(BuildContext context, WidgetRef ref) async {
    final username = TextEditingController();
    final pin = TextEditingController();
    final active = (ref.read(countersProvider).valueOrNull ?? const <PosCounter>[])
        .where((c) => c.isActive)
        .toList();

    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an active counter first.')),
      );
      return;
    }

    int selectedCounter = active.first.id;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add POS User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: username,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedCounter,
                decoration: const InputDecoration(
                  labelText: 'Counter',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in active)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) =>
                    setDialogState(() => selectedCounter = v ?? selectedCounter),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (username.text.trim().length < 3 || pin.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Username (3+ chars) and PIN required')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    await _run(
      context,
      ref,
      () => ref.read(posCounterRepositoryProvider).addPosUser(
            username: username.text,
            pin: pin.text,
            counterId: selectedCounter,
          ),
    );
  }

  Future<void> _run(
      BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
  }
}
