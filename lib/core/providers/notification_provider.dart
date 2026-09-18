import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../models/notification_model.dart';
import '../config/simulation_config.dart';
import '../../providers/mock/notification_mock_provider.dart';
import '../services/supabase_service.dart';

import 'auth_provider.dart';

class NotificationNotifier extends StateNotifier<List<NotificationModel>> {
  final Ref? ref;
  RealtimeChannel? _subscription;

  NotificationNotifier([this.ref]) : super([]) {
    if (ref != null) {
      ref!.listen<AuthState>(authProvider, (previous, next) {
        if (next.user == null || !next.sessionUnlocked) {
          _unsubscribe();
          state = [];
        } else if (previous?.user?.id != next.user?.id ||
            previous?.sessionUnlocked != next.sessionUnlocked) {
          _subscribeRealtime(next.user!.id);
          loadNotifications();
        }
      });
    }

    if (kSimulationMode && ref != null) {
      ref!.listen<List<NotificationModel>>(notificationMockProvider, (
        previous,
        next,
      ) {
        state = next;
      }, fireImmediately: true);
    } else {
      if (SupabaseService.isConfigured) {
        Future.microtask(() {
          final u = SupabaseService.client.auth.currentUser;
          if (u != null) {
            _subscribeRealtime(u.id);
          }
          if (mounted) loadNotifications();
        });
      }
    }
  }

  void _subscribeRealtime(String userId) {
    _unsubscribe();
    if (!SupabaseService.isConfigured || kSimulationMode) return;

    try {
      _subscription = SupabaseService.client
          .channel('notifications_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              if (mounted) {
                loadNotifications();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Notification realtime subscription error: $e');
    }
  }

  void _unsubscribe() {
    if (_subscription != null) {
      try {
        SupabaseService.client.removeChannel(_subscription!);
      } catch (_) {}
      _subscription = null;
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  Future<void> loadNotifications() async {
    if (kSimulationMode) return;
    if (!SupabaseService.isConfigured) return;

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
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
          .map(
            (item) =>
                NotificationModel.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();

      if (!mounted) return;
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
      final now = DateTime.now();
      // Update in local state immediately for instant UI feedback
      state = state.map((n) => n.copyWith(isRead: true, readAt: now)).toList();

      try {
        await SupabaseService.client.rpc('mark_all_notifications_read');
      } catch (_) {
        final nowStr = now.toUtc().toIso8601String();
        await SupabaseService.client
            .from('notifications')
            .update({'is_read': true, 'read_at': nowStr})
            .eq('user_id', currentUser.id);
      }
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
    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final now = DateTime.now();
      // Update local state immediately
      state = state
          .map(
            (n) => n.id == notificationId
                ? n.copyWith(isRead: true, readAt: now)
                : n,
          )
          .toList();

      try {
        await SupabaseService.client.rpc(
          'mark_notification_read',
          params: {'p_notification_id': notificationId},
        );
      } catch (_) {
        final nowStr = now.toUtc().toIso8601String();
        await SupabaseService.client
            .from('notifications')
            .update({'is_read': true, 'read_at': nowStr})
            .eq('id', notificationId)
            .eq('user_id', currentUser.id);
      }
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

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<NotificationModel>>((ref) {
      return NotificationNotifier(ref);
    });

/// Reactive provider for the unread notification count across the entire app.
/// Unread is strictly defined as belonging to current user with read_at IS NULL (and !isRead).
final unreadNotificationCountProvider = Provider<int>((ref) {
  final authUser = ref.watch(authProvider).user;
  final currentUserId =
      authUser?.id ?? SupabaseService.client.auth.currentUser?.id;
  final notifications = ref.watch(notificationProvider);

  return notifications.where((n) {
    // If authenticated user is known, only count their own notifications
    if (currentUserId != null &&
        n.userId.isNotEmpty &&
        n.userId != currentUserId) {
      return false;
    }
    return !n.isRead && n.readAt == null;
  }).length;
});
