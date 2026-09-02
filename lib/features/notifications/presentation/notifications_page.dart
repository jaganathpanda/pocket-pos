import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../weighbridge/presentation/vehicle_entry_detail_page.dart';
import '../domain/app_notification.dart';
import '../providers/notification_providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myNotificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => _markAll(ref),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No notifications.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) =>
                _NotificationTile(notification: items[i]),
          );
        },
      ),
    );
  }

  void _markAll(WidgetRef ref) {
    // Resolve current uid via the repository's target; use the first item's
    // targetUid if available, else no-op.
    final items = ref.read(myNotificationsProvider).valueOrNull ?? const [];
    if (items.isEmpty) return;
    ref
        .read(notificationRepositoryProvider)
        .markAllRead(items.first.targetUid);
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});
  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;
    return ListTile(
      leading: Icon(
        n.type == 'weighbridge_approval'
            ? Icons.local_shipping_outlined
            : Icons.notifications_outlined,
        color: n.isRead ? Colors.grey : Theme.of(context).colorScheme.primary,
      ),
      title: Text(n.title,
          style: TextStyle(
              fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
      subtitle: Text(
        '${n.message}\n${DateFormat('dd/MM/yyyy HH:mm').format(n.createdAt)}',
      ),
      isThreeLine: true,
      trailing: n.isRead
          ? null
          : const Icon(Icons.circle, size: 10, color: Colors.blue),
      onTap: () async {
        await ref.read(notificationRepositoryProvider).markRead(n.id);
        if (!context.mounted) return;
        if (n.entityType == 'vehicle_entry' && n.entityId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VehicleEntryDetailPage(entryId: n.entityId),
            ),
          );
        }
      },
    );
  }
}
