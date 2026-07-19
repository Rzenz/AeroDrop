import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/models/notification_model.dart';

class VendorNotificationsScreen extends ConsumerWidget {
  const VendorNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);

    final today = <NotificationModel>[];
    final yesterday = <NotificationModel>[];
    final earlier = <NotificationModel>[];

    final now = DateTime.now();
    for (final n in notifications) {
      final diff = now.difference(n.createdAt);
      if (diff.inDays < 1) {
        today.add(n);
      } else if (diff.inDays < 2) {
        yesterday.add(n);
      } else {
        earlier.add(n);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Notifications',
          style: AppTextStyles.subHead(fontSize: 18, color: Colors.white),
        ),
        actions: [
          if (notifications.any((n) => !n.isRead))
            IconButton(
              icon: const Icon(Icons.done_all_rounded, color: Colors.white70),
              tooltip: 'Mark all as read',
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(notificationProvider.notifier).markAllAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('All notifications marked as read.'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 56,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet.',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                if (today.isNotEmpty) ...[
                  _buildSectionHeader('TODAY'),
                  ...today.asMap().entries.map(
                    (e) => _buildTile(
                      context,
                      ref,
                      e.value,
                    ).animate().fadeIn(delay: (e.key * 50).ms),
                  ),
                  const SizedBox(height: 20),
                ],
                if (yesterday.isNotEmpty) ...[
                  _buildSectionHeader('YESTERDAY'),
                  ...yesterday.asMap().entries.map(
                    (e) => _buildTile(
                      context,
                      ref,
                      e.value,
                    ).animate().fadeIn(delay: (e.key * 50 + 150).ms),
                  ),
                  const SizedBox(height: 20),
                ],
                if (earlier.isNotEmpty) ...[
                  _buildSectionHeader('EARLIER'),
                  ...earlier.asMap().entries.map(
                    (e) => _buildTile(
                      context,
                      ref,
                      e.value,
                    ).animate().fadeIn(delay: (e.key * 50 + 300).ms),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'order':
        return Icons.receipt_long_rounded;
      case 'delivery':
        return Icons.flight_takeoff_rounded;
      case 'payment':
        return Icons.account_balance_wallet_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'success':
        return Icons.check_circle_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'order':
        return AppColors.primaryLight;
      case 'delivery':
        return AppColors.accent;
      case 'payment':
      case 'success':
        return AppColors.success;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  String _timeLabel(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  Widget _buildTile(BuildContext context, WidgetRef ref, NotificationModel n) {
    final iconColor = _colorForType(n.type);
    return GestureDetector(
      onTap: () {
        if (!n.isRead) {
          ref.read(notificationProvider.notifier).markOneAsRead(n.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconForType(n.type), color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: n.isRead
                                  ? FontWeight.bold
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.message,
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _timeLabel(n.createdAt),
                      style: TextStyle(
                        color: !n.isRead
                            ? AppColors.accent
                            : AppColors.textSecondaryDark.withValues(
                                alpha: 0.6,
                              ),
                        fontSize: 11,
                        fontWeight: !n.isRead
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
