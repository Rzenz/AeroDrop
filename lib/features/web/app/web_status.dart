import 'package:flutter/material.dart';

import '../../../core/models/delivery_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/theme/app_colors.dart';
import 'web_kit.dart';

/// The order steps in the order they happen, as the app's timeline shows.
const orderSteps = <(String, String, IconData)>[
  ('pending', 'Placed', Icons.receipt_long_outlined),
  ('confirmed', 'Confirmed', Icons.check_circle_outline_rounded),
  ('preparing', 'Preparing', Icons.soup_kitchen_outlined),
  ('ready_for_delivery', 'Ready', Icons.inventory_2_outlined),
  ('in_transit', 'In flight', Icons.flight_takeoff_rounded),
  ('delivered', 'Delivered', Icons.where_to_vote_outlined),
];

/// Index of [status] in [orderSteps]; -1 when the order was stopped.
int orderStepIndex(String status) {
  final s = status.toLowerCase();
  if (s == 'cancelled' || s == 'rejected' || s == 'failed') return -1;
  if (s == 'ready' || s == 'ready_for_pickup') return 3;
  if (s == 'out_for_delivery' || s == 'picked_up') return 4;
  final i = orderSteps.indexWhere((e) => e.$1 == s);
  return i < 0 ? 0 : i;
}

Color orderTone(String status) => switch (status.toLowerCase()) {
  'delivered' => AppColors.success,
  'in_transit' || 'out_for_delivery' || 'picked_up' => AppColors.accent,
  'ready_for_delivery' || 'ready' || 'ready_for_pickup' => AppColors.primary,
  'preparing' || 'confirmed' => AppColors.warning,
  'cancelled' || 'rejected' || 'failed' => AppColors.danger,
  _ => AppColors.textTertiaryDark,
};

WebPill orderPill(OrderModel o) =>
    WebPill(label: o.statusDisplay, tone: orderTone(o.effectiveStatus));

/// "ORD-1A2B3C4D" — the reference the receipt and support use.
String orderRef(String id) {
  final raw = id.replaceAll('-', '');
  return '#${(raw.length > 8 ? raw.substring(0, 8) : raw).toUpperCase()}';
}

String shortDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${months[d.month - 1]} ${d.day}, $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "5 min ago", "3 h ago", or the date.
String ago(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return shortDate(d);
}

/// The steps as a horizontal track — done steps filled, the current one
/// ringed — that wraps to a vertical list on a narrow page.
class WebOrderTimeline extends StatelessWidget {
  const WebOrderTimeline({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final at = orderStepIndex(status);
    if (at < 0) {
      return Row(
        children: [
          Icon(
            Icons.cancel_outlined,
            color: AppColors.readable(AppColors.danger),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This order was ${status.toLowerCase()}.',
              style: WebText.label(size: 15),
            ),
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final horizontal = box.maxWidth >= 560;
        final dots = [
          for (var i = 0; i < orderSteps.length; i++)
            _Step(
              label: orderSteps[i].$2,
              icon: orderSteps[i].$3,
              done: i < at || (i == at && i == orderSteps.length - 1),
              current: i == at && i != orderSteps.length - 1,
            ),
        ];
        if (!horizontal) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < dots.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 19),
                    child: Container(
                      width: 2,
                      height: 14,
                      color: i <= at ? AppColors.accentFill : AppColors.border,
                    ),
                  ),
                dots[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < dots.length; i++) ...[
              Expanded(child: dots[i]),
              if (i < dots.length - 1)
                Padding(
                  padding: const EdgeInsets.only(top: 19),
                  child: Container(
                    width: 22,
                    height: 2,
                    color: i < at ? AppColors.accentFill : AppColors.border,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.icon,
    required this.done,
    required this.current,
  });

  final String label;
  final IconData icon;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final on = done || current;
    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AppColors.accentFill : AppColors.surfaceSunken,
        border: Border.all(
          color: current ? AppColors.accentText : Colors.transparent,
          width: 2,
        ),
      ),
      child: Icon(
        done ? Icons.check_rounded : icon,
        size: 19,
        color: done
            ? AppColors.onAccentFill
            : (current ? AppColors.accentText : AppColors.textTertiary),
      ),
    );
    Text text(TextAlign align) => Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: WebText.label(
        size: 12.5,
        color: on ? AppColors.textPrimary : AppColors.textTertiary,
        weight: current ? FontWeight.w700 : FontWeight.w600,
      ),
    );
    return Semantics(
      label: '$label${done ? ', done' : (current ? ', current' : '')}',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth < 120
            ? Column(
                children: [
                  dot,
                  const SizedBox(height: 8),
                  text(TextAlign.center),
                ],
              )
            : Row(
                children: [
                  dot,
                  const SizedBox(width: 12),
                  Expanded(child: text(TextAlign.start)),
                ],
              ),
      ),
    );
  }
}

String deliveryLabel(DeliveryStatus s) => switch (s) {
  DeliveryStatus.pending => 'Waiting to dispatch',
  DeliveryStatus.assigning => 'Assigning a drone',
  DeliveryStatus.inTransit => 'In flight',
  DeliveryStatus.delivered => 'Delivered',
  DeliveryStatus.cancelled => 'Cancelled',
};

Color deliveryTone(DeliveryStatus s) => switch (s) {
  DeliveryStatus.pending => AppColors.warning,
  DeliveryStatus.assigning => AppColors.primary,
  DeliveryStatus.inTransit => AppColors.accent,
  DeliveryStatus.delivered => AppColors.success,
  DeliveryStatus.cancelled => AppColors.danger,
};

WebPill deliveryPill(DeliveryModel d) =>
    WebPill(label: deliveryLabel(d.status), tone: deliveryTone(d.status));
