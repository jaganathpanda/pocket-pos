import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/store_scope.dart';
import '../../store/presentation/store_auth_controller.dart';
import '../data/firestore_notification_repository.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) {
  return FirestoreNotificationRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

/// Notifications addressed to the currently signed-in user.
final myNotificationsProvider =
    StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(storeSessionProvider)?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watchForUser(uid);
});

/// Unread count for the app-bar badge.
final myUnreadNotificationCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(storeSessionProvider)?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(0);
  return ref.watch(notificationRepositoryProvider).watchUnreadCount(uid);
});
