import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/order_message_model.dart';
import '../../core/models/order_model.dart';
import '../../core/providers/order_chat_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/neu_avatar.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_feedback.dart';
import '../../core/widgets/neu_scaffold.dart';
import '../../core/widgets/neu_surface.dart';
import '../../core/widgets/neu_text_field.dart';
import '../orders/order_details_screen.dart';

/// Order statuses at which the order_messages insert policy rejects posts.
const _closedOrderStatuses = {'delivered', 'cancelled', 'rejected', 'failed'};

/// Customer <-> vendor chat for a single order.
class OrderChatScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderChatScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends ConsumerState<OrderChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _hasText = false;

  String? get _uid => SupabaseService.isConfigured
      ? SupabaseService.client.auth.currentUser?.id
      : null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });

    // A new message from the other party while the screen is open is read
    // immediately; any new message scrolls the thread to the newest entry.
    ref.listenManual<OrderChatState>(orderChatProvider(widget.orderId), (
      prev,
      next,
    ) {
      if (next.messages.length > (prev?.messages.length ?? 0)) {
        _scrollToNewest();
      }
      if (!next.isLoading && next.unreadCount > 0) _maybeMarkRead();
    });

    // The order may resolve after the screen opens; mark read once it does.
    ref.listenManual<AsyncValue<OrderModel?>>(
      orderDetailsProvider(widget.orderId),
      (_, next) {
        if (next.hasValue) _maybeMarkRead();
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeMarkRead());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isParticipant(OrderModel? order) {
    final uid = _uid;
    if (order == null || uid == null) return false;
    return uid == order.userId || uid == order.vendorId;
  }

  bool _isClosed(OrderModel order) =>
      _closedOrderStatuses.contains(order.orderStatus.trim().toLowerCase());
  /// The RPC rejects non-participants, so it is only called once the order is
  /// known and the current user is one of its two parties.
  void _maybeMarkRead() {
    if (!mounted) return;
    final order = ref.read(orderDetailsProvider(widget.orderId)).value;
    if (!_isParticipant(order)) return;
    ref.read(orderChatProvider(widget.orderId).notifier).markRead();
  }

  void _scrollToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      // The list is reversed, so offset 0 is the newest message.
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text;
    try {
      await ref
          .read(orderChatProvider(widget.orderId).notifier)
          .sendMessage(text);
      _controller.clear();
    } on ArgumentError catch (e) {
      if (mounted) {
        showNeuSnack(context, '${e.message}', tone: NeuToneKind.warning);
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      // 42501 = row-level security rejected the insert: the order most likely
      // closed since this screen last loaded it. Refresh so the composer
      // switches to the closed state instead of failing again.
      if (e.code == '42501') {
        ref.invalidate(orderDetailsProvider(widget.orderId));
        showNeuSnack(
          context,
          'This conversation is closed. Your message was not sent.',
          tone: NeuToneKind.error,
        );
      } else {
        showNeuSnack(
          context,
          'Message not sent: ${e.message}',
          tone: NeuToneKind.error,
        );
      }
    } catch (e) {
      if (mounted) {
        showNeuSnack(
          context,
          'Message not sent: $e',
          tone: NeuToneKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(orderChatProvider(widget.orderId));
    final order = ref.watch(orderDetailsProvider(widget.orderId)).value;
    final counterpart = ref.watch(orderCounterpartProvider(widget.orderId));
    final uid = _uid;

    final isVendor = GoRouterState.of(context).uri.path.startsWith('/vendor');
    // No rows, an RPC error, or still loading all fall back to a neutral role
    // label. Never a name read from the order model: a vendor cannot read
    // customer rows, so that value would be a placeholder, not the customer.
    final resolved = counterpart.asData?.value;
    final title = resolved?.displayName ?? (isVendor ? 'Customer' : 'Vendor');
    final avatarUrl = resolved?.avatarUrl;
    final shortId = widget.orderId.length > 8
        ? widget.orderId.substring(0, 8).toUpperCase()
        : widget.orderId;

    return NeuScaffold(
      appBar: CustomAppBar(
        title: title,
        subtitle: 'Order #$shortId',
        leading: NeuAvatar(imageUrl: avatarUrl, name: title, size: 32),
      ),
      padded: false,
      body: Column(
        children: [
          Expanded(
            child: _buildThread(
              chat,
              uid,
              counterpartName: title,
              counterpartAvatarUrl: avatarUrl,
            ),
          ),
          _buildBottom(chat, order),
        ],
      ),
    );
  }

  Widget _buildThread(
    OrderChatState chat,
    String? uid, {
    required String counterpartName,
    String? counterpartAvatarUrl,
  }) {
    if (chat.isLoading && chat.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (chat.error != null && chat.messages.isEmpty) {
      return ErrorStateWidget(
        title: 'Could not load messages',
        message: chat.error!,
        onRetry: () =>
            ref.read(orderChatProvider(widget.orderId).notifier).loadMessages(),
      );
    }
    if (chat.messages.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No messages yet',
        subtitle: 'Messages about this order will appear here.',
      );
    }

    final messages = chat.messages;
    final gutter = AppSpacing.pageGutter(context);
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: EdgeInsets.fromLTRB(
        gutter,
        AppSpacing.md,
        gutter,
        AppSpacing.md,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final i = messages.length - 1 - index;
        final msg = messages[i];
        final isMine = msg.isFrom(uid);
        // Messenger-style grouping: in a run of consecutive incoming
        // messages, only the chronologically last one carries the avatar.
        final endsRun =
            !isMine && (i == messages.length - 1 || messages[i + 1].isFrom(uid));
        return _MessageBubble(
          message: msg,
          isMine: isMine,
          avatar: endsRun
              ? NeuAvatar(
                  imageUrl: counterpartAvatarUrl,
                  name: counterpartName,
                  size: _incomingAvatarSize,
                )
              : null,
        );
      },
    );
  }

  Widget _buildBottom(OrderChatState chat, OrderModel? order) {
    final gutter = AppSpacing.pageGutter(context);
    final padding = EdgeInsets.fromLTRB(
      gutter,
      AppSpacing.xs,
      gutter,
      AppSpacing.sm,
    );

    // Never offer a composer the insert policy would reject: the order must
    // be loaded, the user must be one of its two parties, and it must still
    // be open.
    if (order == null) {
      return const SizedBox.shrink();
    }
    if (!_isParticipant(order)) {
      return Padding(
        padding: padding,
        child: const _ComposerNotice(
          icon: Icons.visibility_outlined,
          text: 'Only the customer and vendor can send messages here.',
        ),
      );
    }
    if (_isClosed(order)) {
      return Padding(
        padding: padding,
        child: const _ComposerNotice(
          icon: Icons.lock_outline_rounded,
          text: 'This conversation is closed.',
        ),
      );
    }
    if (order.chatAwaitingPayment) {
      return Padding(
        padding: padding,
        child: const _ComposerNotice(
          icon: Icons.hourglass_top_rounded,
          text: 'Chat opens once payment is confirmed.',
        ),
      );
    }

    final canSend = _hasText && !chat.isSending;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: NeuTextField(
              labelText: '',
              hintText: 'Write a message',
              controller: _controller,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              maxLines: 4,
              maxLength: kOrderMessageMaxLength,
              enabled: !chat.isSending,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          NeuIconButton(
            icon: Icons.send_rounded,
            tooltip: 'Send',
            iconColor: canSend ? AppColors.accentText : AppColors.textTertiary,
            onPressed: canSend ? _send : null,
          ),
        ],
      ),
    );
  }
}

class _ComposerNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ComposerNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return NeuPanel(
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar beside incoming messages, and the gap between it and the bubble.
const double _incomingAvatarSize = 28;
const double _incomingAvatarGap = AppSpacing.xs;

class _MessageBubble extends StatelessWidget {
  final OrderMessageModel message;
  final bool isMine;

  /// Incoming messages only: the counterpart's avatar on the last message of
  /// a run, or null for an equal-width spacer so the run stays aligned.
  /// Ignored for the user's own messages.
  final Widget? avatar;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.75;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadii.md),
      topRight: const Radius.circular(AppRadii.md),
      bottomLeft: Radius.circular(isMine ? AppRadii.md : AppRadii.xs / 2),
      bottomRight: Radius.circular(isMine ? AppRadii.xs / 2 : AppRadii.md),
    );

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.accentFill : AppColors.surfaceRaised,
          borderRadius: radius,
        ),
        // Full message body: it wraps within the bubble's bounded
        // width rather than truncating, so nothing is hidden.
        child: Text(
          message.message,
          style: AppTextStyles.body(
            fontSize: 14,
            color: isMine ? AppColors.onAccentFill : AppColors.textPrimary,
          ),
        ),
      ),
    );

    final timestamp = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(
        _formatTimestamp(message.createdAt),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption(
          fontSize: 10.5,
          color: AppColors.textTertiary,
        ),
      ),
    );

    if (isMine) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            bubble,
            const SizedBox(height: AppSpacing.xxs),
            timestamp,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              avatar ?? const SizedBox(width: _incomingAvatarSize),
              const SizedBox(width: _incomingAvatarGap),
              Flexible(child: bubble),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Padding(
            padding: const EdgeInsets.only(
              left: _incomingAvatarSize + _incomingAvatarGap,
            ),
            child: timestamp,
          ),
        ],
      ),
    );
  }

  static String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return time;
    }
    if (dt.year == now.year) return '${dt.month}/${dt.day} $time';
    return '${dt.month}/${dt.day}/${dt.year} $time';
  }
}
