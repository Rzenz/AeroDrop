import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/notification_model.dart';
import '../../mock_data/notifications_mock.dart';

class NotificationMockNotifier extends StateNotifier<List<NotificationModel>> {
  NotificationMockNotifier() : super(List.from(mockNotifications));

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

  void reset() {
    state = List.from(mockNotifications);
  }
}

final notificationMockProvider = StateNotifierProvider<NotificationMockNotifier, List<NotificationModel>>((ref) {
  return NotificationMockNotifier();
});
