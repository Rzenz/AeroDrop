import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/models/notification_model.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Color _colorFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('maintenance') ||
        t.contains('alert') ||
        t.contains('system')) {
      return AppColors.warning;
    }
    if (t.contains('delivered') || t.contains('success')) {
      return AppColors.success;
    }
    if (t.contains('dispatch') || t.contains('transit')) {
      return AppColors.primary;
    }
    return AppColors.accent;
  }

  IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('maintenance') ||
        t.contains('alert') ||
        t.contains('system')) {
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  // Back Button to go to home
                  GestureDetector(
                    onTap: () => context.go('/user'),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: AppTextStyles.title(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stay updated on drone status & alerts',
                          style: AppTextStyles.body(
                            fontSize: 14,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (notifications.isNotEmpty)
                    TextButton(
                      onPressed: () => ref
                          .read(notificationProvider.notifier)
                          .markAllAsRead(),
                      child: Text(
                        'Mark all read',
                        style: AppTextStyles.body(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.1, end: 0),

            // Notifications timeline
            Expanded(
              child: notifications.isEmpty
                  ? const EmptyStateWidget(
                      title: 'All Caught Up!',
                      subtitle: 'No new notifications at the moment.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
                      itemCount: notifications.length,
                      itemBuilder: (context, i) {
                        final n = notifications[i];
                        final color = _colorFor(n.title);
                        final icon = _iconFor(n.title);
                        return _TimelineNotificationTile(
                          notification: n,
                          color: color,
                          icon: icon,
                          isFirst: i == 0,
                          isLast: i == notifications.length - 1,
                          animDelay: i * 65,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineNotificationTile extends StatefulWidget {
  final NotificationModel notification;
  final Color color;
  final IconData icon;
  final bool isFirst;
  final bool isLast;
  final int animDelay;

  const _TimelineNotificationTile({
    required this.notification,
    required this.color,
    required this.icon,
    required this.isFirst,
    required this.isLast,
    required this.animDelay,
  });

  @override
  State<_TimelineNotificationTile> createState() =>
      _TimelineNotificationTileState();
}

class _TimelineNotificationTileState extends State<_TimelineNotificationTile>
    with TickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    if (!widget.notification.isRead) {
      _initPulseController();
    }
  }

  void _initPulseController() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _TimelineNotificationTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notification.isRead != oldWidget.notification.isRead) {
      if (widget.notification.isRead) {
        _pulseController?.dispose();
        _pulseController = null;
      } else {
        _initPulseController();
      }
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRead = widget.notification.isRead;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline node & line column
          SizedBox(
            width: 36,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Connecting line
                Positioned(
                  top: widget.isFirst ? 24 : 0,
                  bottom: widget.isLast ? 0 : 0,
                  child: Container(
                    width: 2,
                    color: AppColors.borderDark,
                  ),
                ),
                // Timeline node dot
                Positioned(
                  top: 24,
                  child: _pulseController != null
                      ? AnimatedBuilder(
                          animation: _pulseController!,
                          builder: (context, child) {
                            return Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.color,
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.color.withValues(
                                      alpha: 0.3 +
                                          (_pulseController!.value * 0.4),
                                    ),
                                    blurRadius: 4 +
                                        (_pulseController!.value * 8),
                                    spreadRadius: 1 +
                                        (_pulseController!.value * 2),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.borderDark,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isRead
                      ? AppColors.cardDark
                      : widget.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isRead
                        ? AppColors.borderDark
                        : widget.color.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.notification.title,
                            style: AppTextStyles.title(
                              fontSize: 14,
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.notification.body,
                            style: AppTextStyles.body(
                              fontSize: 12,
                              color: AppColors.textSecondaryDark,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: widget.animDelay)).fadeIn().slideX(
          begin: 0.08,
          end: 0,
        );
  }
}
