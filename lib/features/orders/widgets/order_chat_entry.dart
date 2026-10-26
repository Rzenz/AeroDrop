import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/order_chat_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/neu_button.dart';

// Entry points into the customer <-> vendor order chat. Each is its own
// ConsumerWidget so the chat provider (and its realtime channel) only exists
// while an entry point is actually on screen.

String _chatRoute(String orderId, bool isVendor) =>
    '${isVendor ? '/vendor' : '/user'}/orders/$orderId/chat';

String _chatLabel(bool isVendor) =>
    isVendor ? 'Message customer' : 'Message vendor';

String? _chatSemantics(bool isVendor, int unread) =>
    unread > 0 ? '${_chatLabel(isVendor)}, $unread unread' : null;

/// Chat bubble icon with the unread count pinned to its corner.
class _ChatIconWithBadge extends StatelessWidget {
  final int unread;
  final Color color;

  const _ChatIconWithBadge({required this.unread, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.chat_bubble_outline_rounded, size: 20, color: color),
        if (unread > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: AppRadii.brPill,
                border: Border.all(color: AppColors.base, width: 1.5),
              ),
              child: Center(
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Message vendor" / "Message customer" with an unread badge.
class OrderChatButton extends ConsumerWidget {
  final String orderId;
  final bool isVendor;

  const OrderChatButton({
    super.key,
    required this.orderId,
    required this.isVendor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(
      orderChatProvider(orderId).select((s) => s.unreadCount),
    );

    return NeuButton(
      text: _chatLabel(isVendor),
      variant: NeuButtonVariant.neutral,
      semanticLabel: _chatSemantics(isVendor, unread),
      leading: _ChatIconWithBadge(
        unread: unread,
        color: AppColors.textPrimary,
      ),
      onPressed: () => context.push(_chatRoute(orderId, isVendor)),
    );
  }
}

/// Compact app bar version of [OrderChatButton], for screens where the full
/// button would sit below content the user is watching (the tracking map).
class OrderChatAction extends ConsumerWidget {
  final String orderId;
  final bool isVendor;

  const OrderChatAction({
    super.key,
    required this.orderId,
    required this.isVendor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(
      orderChatProvider(orderId).select((s) => s.unreadCount),
    );

    return Semantics(
      label: _chatSemantics(isVendor, unread),
      child: IconButton(
        tooltip: _chatLabel(isVendor),
        icon: _ChatIconWithBadge(unread: unread, color: AppColors.accent),
        onPressed: () => context.push(_chatRoute(orderId, isVendor)),
      ),
    );
  }
}
