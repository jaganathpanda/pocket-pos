import 'package:equatable/equatable.dart';

/// An in-app notification shown to a specific store user (e.g. a miller being
/// told a weighbridge entry is awaiting approval). Stored at
/// `stores/{storeId}/notifications/{id}`.
class AppNotification extends Equatable {
  final int id;
  final String type; // e.g. 'weighbridge_approval'
  final String title;
  final String message;

  /// The user this notification is for (Firebase Auth uid).
  final String targetUid;

  /// What the notification points at, so tapping it can deep-link.
  final String? entityType; // e.g. 'vehicle_entry'
  final int? entityId;

  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.targetUid,
    this.entityType,
    this.entityId,
    this.isRead = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, isRead];
}
