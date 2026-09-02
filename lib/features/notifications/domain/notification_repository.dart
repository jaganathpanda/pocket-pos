import 'app_notification.dart';

abstract class NotificationRepository {
  /// All notifications for a user, newest first.
  Stream<List<AppNotification>> watchForUser(String targetUid);

  /// Count of unread notifications for a user (for the app-bar badge).
  Stream<int> watchUnreadCount(String targetUid);

  /// Create a notification targeted at a user.
  Future<void> create({
    required String type,
    required String title,
    required String message,
    required String targetUid,
    String? entityType,
    int? entityId,
  });

  Future<void> markRead(int id);
  Future<void> markAllRead(String targetUid);
}
