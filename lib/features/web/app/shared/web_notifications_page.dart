import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/notification_model.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../web_kit.dart';
import '../web_status.dart';

/// Notifications for any role, as an inbox: unread first in its own tab,
/// grouped by day, each one's subject told by its icon and tone. Opening one
/// marks it read and, when it is about a delivery, goes where the app would.
class WebNotificationsPage extends ConsumerStatefulWidget {
  const WebNotificationsPage({super.key, required this.area});

  /// 'user', 'vendor' or 'admin'.
  final String area;

  @override
  ConsumerState<WebNotificationsPage> createState() =>
      _WebNotificationsPageState();
}

class _WebNotificationsPageState extends ConsumerState<WebNotificationsPage> {
  int _tab = 0; // 0 all, 1 unread

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(notificationProvider.notifier).loadNotifications(),
    );
  }

  (Color, IconData) _look(String title) {
    final t = title.toLowerCase();
    if (t.contains('maintenance') ||
        t.contains('alert') ||
        t.contains('system') ||
        t.contains('paused') ||
        t.contains('weather')) {
      return (AppColors.warning, Icons.warning_amber_rounded);
    }
    if (t.contains('delivered') ||
        t.contains('success') ||
        t.contains('completed')) {
      return (AppColors.success, Icons.verified_outlined);
    }
    if (t.contains('dispatch') ||
        t.contains('transit') ||
        t.contains('accepted') ||
        t.contains('air')) {
      return (AppColors.primary, Icons.flight_takeoff_rounded);
    }
    if (t.contains('rejected') ||
        t.contains('cancelled') ||
        t.contains('failed')) {
      return (AppColors.danger, Icons.cancel_outlined);
    }
    return (AppColors.accent, Icons.notifications_none_rounded);
  }

  void _open(NotificationModel n) {
    ref.read(notificationProvider.notifier).markOneAsRead(n.id);
    final d = n.relatedDeliveryId;
    if (d == null || d.isEmpty) return;
    switch (widget.area) {
      case 'user':
        context.push('/user/track/details?id=$d');
      case 'vendor':
        context.push('/vendor/track/details?id=$d');
      case 'admin':
        context.push('/admin/deliveries/details?id=$d');
    }
  }

  String _day(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This week';
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) {
    final all = [...ref.watch(notificationProvider)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final unread = all.where((n) => !n.isRead).toList();
    final shown = _tab == 0 ? all : unread;

    final groups = <String, List<NotificationModel>>{};
    for (final n in shown) {
      groups.putIfAbsent(_day(n.createdAt), () => []).add(n);
    }

    return WebPage(
      title: 'Notifications',
      subtitle: unread.isEmpty
          ? 'You are all caught up.'
          : '${unread.length} unread',
      maxWidth: 960,
      onRefresh: () =>
          ref.read(notificationProvider.notifier).loadNotifications(),
      actions: [
        if (unread.isNotEmpty)
          WebButton(
            label: 'Mark all as read',
            icon: Icons.done_all_rounded,
            kind: WebButtonKind.secondary,
            onPressed: () =>
                ref.read(notificationProvider.notifier).markAllAsRead(),
          ),
      ],
      children: [
        WebTabs(
          labels: const ['All', 'Unread'],
          counts: [all.length, unread.length],
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        if (shown.isEmpty)
          WebEmpty(
            icon: Icons.notifications_none_rounded,
            title: _tab == 0 ? 'No notifications yet' : 'Nothing unread',
            message: _tab == 0
                ? 'Order updates, flights and weather alerts arrive here.'
                : 'Everything here has been read.',
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final g in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                  child: Text(g.key.toUpperCase(), style: WebText.overline()),
                ),
                for (final n in g.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _Item(
                      n: n,
                      look: _look(n.title),
                      onTap: () => _open(n),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.n, required this.look, required this.onTap});

  final NotificationModel n;
  final (Color, IconData) look;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = look;
    return WebHoverCard(
      onTap: onTap,
      radius: 20,
      semanticLabel: '${n.isRead ? '' : 'Unread. '}${n.title}. ${n.message}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeuSurface(
            style: NeuStyle.inset,
            color: AppColors.surfaceSunken,
            width: 44,
            height: 44,
            borderRadius: BorderRadius.circular(14),
            alignment: Alignment.center,
            child: Icon(icon, size: 21, color: AppColors.readable(tone)),
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
                        n.title.isEmpty ? 'Update' : n.title,
                        style: WebText.label(
                          size: 14.5,
                          weight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      ago(n.createdAt),
                      style: WebText.body(
                        size: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(n.message, style: WebText.body(size: 13.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: AnimatedOpacity(
              opacity: n.isRead ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.accentFill,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
