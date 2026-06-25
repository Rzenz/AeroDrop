import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/models/notification_model.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Color _colorFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('maintenance') || t.contains('alert') || t.contains('system')) {
      return AppColors.warning;
    }
    if (t.contains('delivered') || t.contains('success')) {
      return AppColors.success;
    }
    if (t.contains('dispatch') || t.contains('transit')) {
      return AppColors.primary;
    }
    return AppColors.secondary;
  }

  IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('maintenance') || t.contains('alert') || t.contains('system')) {
      return Icons.warning_rounded;
    }
    if (t.contains('delivered') || t.contains('success')) {
      return Icons.verified_rounded;
    }
    if (t.contains('dispatch') || t.contains('transit')) {
      return Icons.flight_takeoff_rounded;
    }
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Notifications',
            style: AppTextStyles.title(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationProvider.notifier).markAllAsRead(),
            child: Text('Mark all read',
                style: AppTextStyles.body(
                    fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
          ),
        ],
      ),
      body: notifications.isEmpty
          ? const EmptyStateWidget(
              title: 'All Caught Up!',
              subtitle: 'No new notifications right now.',
              lottiePath: 'assets/lottie/empty_box.json',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: notifications.length,
              itemBuilder: (context, i) {
                final n = notifications[i];
                final color = _colorFor(n.title);
                final icon = _iconFor(n.title);
                return _NotificationTile(
                  notification: n,
                  color: color,
                  icon: icon,
                  animDelay: i * 60,
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final Color color;
  final IconData icon;
  final int animDelay;

  const _NotificationTile({
    required this.notification,
    required this.color,
    required this.icon,
    required this.animDelay,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isRead ? AppColors.cardDark : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? AppColors.borderDark : color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color strip
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            margin: const EdgeInsets.only(top: 18),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: AppTextStyles.title(
                          fontSize: 14,
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(notification.body,
                      style: AppTextStyles.body(
                          fontSize: 12, color: AppColors.textSecondaryDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          if (!isRead)
            Container(
              margin: const EdgeInsets.all(14),
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: animDelay))
        .fadeIn()
        .slideX(begin: 0.05);
  }
}
