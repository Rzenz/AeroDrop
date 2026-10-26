import 'package:flutter/foundation.dart';
import '../../core/models/notification_model.dart';

/// Where tapping a notification should go.
///
/// [isShellTab] destinations are tabs of the current role's shell and are
/// reached with `go`; everything else is a detail page pushed on top.
typedef NotificationTarget = ({String location, bool isShellTab});

/// Types the migrations write with a related_delivery_id, so tapping one opens
/// that delivery for the current role.
const deliveryNotificationTypes = {
  'order_ready', // 03: vendor marked the order ready
  'order_queued', // 05/10/16/23: ready, waiting for the drone
  'drone_dispatched', // 04/05/10/16/23/26/27
  'package_picked_up', // 04/06
  'order_in_transit', // 03/04/06/10/17
  'delivery_trip_completed', // 23/24: one trip of a multi-trip order
  'order_delivered', // 03/05/10/17: customer
  'delivery_completed', // 03/05/10/17: vendor and admins
  'delivery_failed', // 17: admins
};

/// Types the migrations write with nowhere to open: no delivery id, and no
/// screen for the order or alert. Known, so they stay quiet in debug logs.
const inertNotificationTypes = {
  'info', // the model's default, also used for local notices
  'order_placed',
  'new_order',
  'order_confirmed',
  'order_preparing',
  'order_cancelled',
  'payment_expired',
  'payment_failed',
  'low_stock',
  'stock_out',
  'weather_alert',
  'drone_low_battery',
  'drone_stuck_returning',
};

/// Resolves the destination for [n] from the role implied by [currentPath],
/// the same route-prefix check other screens use. Every destination stays
/// inside that role's routes: pushing another role's shell on top of the
/// current one makes both navigators reserve the same page key and crashes.
///
/// Returns null when there is nowhere sensible to go. An unrecognised type is
/// always null, never guessed from its delivery id: support reports carry one
/// too, and routing them to tracking is what crashed the admin shell.
NotificationTarget? notificationTarget(
  NotificationModel n,
  String currentPath,
) {
  final isAdmin = currentPath.startsWith('/admin');
  final isVendor = currentPath.startsWith('/vendor');

  switch (n.type) {
    // Customers have no screen listing their own reports, so only admins move
    case 'support_report':
    case 'support_report_update':
      return isAdmin ? (location: '/admin/support', isShellTab: true) : null;

    case 'order_message':
      final orderId = n.metadata?['order_id']?.toString() ?? '';
      // Admins are not part of order chats
      if (orderId.isEmpty || isAdmin) return null;
      return (
        location: isVendor
            ? '/vendor/orders/$orderId/chat'
            : '/user/orders/$orderId/chat',
        isShellTab: false,
      );

    case 'multi_trip_stalled':
      return isAdmin ? (location: '/admin/deliveries', isShellTab: true) : null;

    case 'vendor_application':
      return isAdmin ? (location: '/admin/users', isShellTab: true) : null;
  }

  if (!deliveryNotificationTypes.contains(n.type)) {
    if (kDebugMode && !inertNotificationTypes.contains(n.type)) {
      debugPrint('Notification type "${n.type}" has no tap route; ignoring.');
    }
    return null;
  }

  final deliveryId = n.relatedDeliveryId ?? '';
  if (deliveryId.isEmpty) return null;
  return (
    location: isAdmin
        ? '/admin/deliveries/details?id=$deliveryId'
        : isVendor
        ? '/vendor/track/details?id=$deliveryId'
        : '/user/track/details?id=$deliveryId',
    isShellTab: false,
  );
}
