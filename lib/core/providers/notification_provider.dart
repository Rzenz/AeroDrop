import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';

class NotificationNotifier extends StateNotifier<List<NotificationModel>> {
  NotificationNotifier()
      : super([
          NotificationModel(
            id: 'ntf-1',
            title: 'Drone DRN-001 Dispatched',
            body: 'Your delivery request DEL-892 has been dispatched via AeroCarrier Falcon.',
            timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
            isRead: false,
          ),
          NotificationModel(
            id: 'ntf-2',
            title: 'Delivery DEL-541 Delivered',
            body: 'SkyLifter Titan has successfully delivered package "Confidential Document Envelopes" to Main Library Lobby.',
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
            isRead: true,
          ),
          NotificationModel(
            id: 'ntf-3',
            title: 'System Alert: Maintenance',
            body: 'Drone DRN-003 is flagged for battery calibration and scheduled maintenance.',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
            isRead: true,
          ),
        ]);

  void addNotification(String title, String body) {
    final newNtf = NotificationModel(
      id: 'ntf-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      timestamp: DateTime.now(),
      isRead: false,
    );
    state = [newNtf, ...state];
  }

  void markAsRead(String id) {
    state = state.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
  }

  void markAllAsRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void clearAll() {
    state = [];
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, List<NotificationModel>>((ref) {
  return NotificationNotifier();
});
