import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../config/simulation_config.dart';
import '../../providers/mock/notification_mock_provider.dart';
import '../services/supabase_service.dart';

class NotificationNotifier extends StateNotifier<List<NotificationModel>> {
  final Ref? ref;

  NotificationNotifier([this.ref]) : super([]) {
    if (kSimulationMode && ref != null) {
      ref!.listen<List<NotificationModel>>(notificationMockProvider, (previous, next) {
        state = next;
      }, fireImmediately: true);
    } else {
      if (SupabaseService.isConfigured) {
        Future.microtask(loadNotifications);
      }
    }
  }

  Future<void> loadNotifications() async {
    if (kSimulationMode) return;
    if (!SupabaseService.isConfigured) return;

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) {
      state = [];
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((item) => NotificationModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      state = list;
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  Future<void> markAllAsRead() async {
    if (kSimulationMode && ref != null) {
      ref!.read(notificationMockProvider.notifier).markAllAsRead();
      return;
    }

    if (!SupabaseService.isConfigured) return;
    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();

      // Update in local state immediately for instant UI feedback
      state = state.map((n) => n.copyWith(isRead: true, readAt: DateTime.now())).toList();

      await SupabaseService.client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': nowStr,
          })
          .eq('user_id', currentUser.id)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> markOneAsRead(String notificationId) async {
    if (kSimulationMode && ref != null) {
      ref!.read(notificationMockProvider.notifier).markAsRead(notificationId);
      return;
    }

    if (!SupabaseService.isConfigured) return;

    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();

      // Update local state immediately
      state = state.map((n) => n.id == notificationId ? n.copyWith(isRead: true, readAt: DateTime.now()) : n).toList();

      await SupabaseService.client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': nowStr,
          })
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification $notificationId as read: $e');
    }
  }

  void clearNotifications() {
    state = [];
  }

  // Support legacy manual add for mock data
  void addNotification(String title, String body) {
    if (kSimulationMode && ref != null) {
      ref!.read(notificationMockProvider.notifier).addNotification(title, body);
      return;
    }
    final newNtf = NotificationModel(
      id: 'ntf-${DateTime.now().millisecondsSinceEpoch}',
      userId: SupabaseService.client.auth.currentUser?.id ?? '',
      title: title,
      message: body,
      type: 'info',
      isRead: false,
      createdAt: DateTime.now(),
    );
    state = [newNtf, ...state];
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, List<NotificationModel>>((ref) {
  return NotificationNotifier(ref);
});
