import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/store_models.dart';
import 'store_auth_controller.dart';

final _pendingStoresProvider = StreamProvider<List<StoreRecord>>((ref) {
  return ref
      .watch(storeAuthServiceProvider)
      .watchStoresByStatus(StoreStatus.pending);
});

final _approvedStoresProvider = StreamProvider<List<StoreRecord>>((ref) {
  return ref
      .watch(storeAuthServiceProvider)
      .watchStoresByStatus(StoreStatus.approved);
});

class AdminApprovalPage extends ConsumerWidget {
  const AdminApprovalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(_pendingStoresProvider);
    final approved = ref.watch(_approvedStoresProvider);
    final service = ref.watch(storeAuthServiceProvider);

    Future<void> setStatus(StoreRecord s, StoreStatus status) async {
      try {
        await service.setStoreStatus(s.storeId, status);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Approvals'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(storeAuthControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _SectionHeader('Pending approval'),
          pending.when(
            data: (list) => list.isEmpty
                ? const _Empty('No stores waiting for approval.')
                : Column(
                    children: [
                      for (final s in list)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.storefront_rounded,
                                color: Colors.orange),
                            title: Text('${s.name}  (${s.storeId})'),
                            subtitle: Text(
                                'Owner: ${s.ownerName}${s.mobile != null && s.mobile!.isNotEmpty ? ' • ${s.mobile}' : ''}'),
                            trailing: FilledButton(
                              onPressed: () => setStatus(s, StoreStatus.approved),
                              child: const Text('Approve'),
                            ),
                          ),
                        ),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Empty('Error: $e'),
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Approved stores'),
          approved.when(
            data: (list) => list.isEmpty
                ? const _Empty('No approved stores yet.')
                : Column(
                    children: [
                      for (final s in list)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.check_circle,
                                color: Colors.green),
                            title: Text('${s.name}  (${s.storeId})'),
                            subtitle: Text('Owner: ${s.ownerName}'),
                            trailing: TextButton(
                              onPressed: () => setStatus(s, StoreStatus.suspended),
                              child: const Text('Suspend'),
                            ),
                          ),
                        ),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Empty('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: const TextStyle(color: Colors.grey)),
      );
}
