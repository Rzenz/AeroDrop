import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_message_model.dart';
import '../services/supabase_service.dart';

/// Matches the CHECK constraint on public.order_messages.message.
const int kOrderMessageMaxLength = 1000;

class OrderChatState {
  final List<OrderMessageModel> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final String? currentUserId;

  const OrderChatState({
    this.messages = const [],
    this.isLoading = true,
    this.isSending = false,
    this.error,
    this.currentUserId,
  });

  /// Messages the other party sent that the current user has not read yet.
  int get unreadCount => messages
      .where((m) => !m.isFrom(currentUserId) && m.readAt == null)
      .length;

  OrderChatState copyWith({
    List<OrderMessageModel>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) {
    return OrderChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
      currentUserId: currentUserId,
    );
  }
}

/// The other party on an order, as returned by get_order_counterpart().
class OrderCounterpart {
  final String id;
  final String displayName;

  /// 'vendor' or 'customer'.
  final String role;

  /// Public storage URL: a vendor's business logo (falling back to their
  /// avatar), or a customer's avatar. Null when there is none.
  final String? avatarUrl;

  const OrderCounterpart({
    required this.id,
    required this.displayName,
    required this.role,
    this.avatarUrl,
  });

  factory OrderCounterpart.fromMap(Map<String, dynamic> map) {
    final avatar = map['avatar_url']?.toString().trim() ?? '';
    return OrderCounterpart(
      id: map['counterpart_id']?.toString() ?? '',
      displayName: map['display_name']?.toString().trim() ?? '',
      role: map['counterpart_role']?.toString() ?? '',
      avatarUrl: avatar.isEmpty ? null : avatar,
    );
  }
}

/// Counterpart lookup for the chat header.
///
/// Goes through the SECURITY DEFINER RPC because users_select does not let a
/// vendor read a customer's row. Resolves to null when the order has no
/// counterpart (the RPC returns no rows); errors when the caller is neither a
/// participant nor an admin.
final orderCounterpartProvider = FutureProvider.autoDispose
    .family<OrderCounterpart?, String>((ref, orderId) async {
      if (!SupabaseService.isConfigured) return null;

      final res = await SupabaseService.client.rpc(
        'get_order_counterpart',
        params: {'p_order_id': orderId},
      );

      final rows = res is List ? res : const [];
      if (rows.isEmpty) return null;
      final counterpart = OrderCounterpart.fromMap(
        Map<String, dynamic>.from(rows.first as Map),
      );
      return counterpart.displayName.isEmpty ? null : counterpart;
    });

/// Per-order chat thread, keyed by orderId.
///
/// Auto-disposed so the realtime channel is torn down as soon as neither the
/// chat screen nor the order details badge is watching it.
final orderChatProvider = StateNotifierProvider.autoDispose
    .family<OrderChatNotifier, OrderChatState, String>((ref, orderId) {
      return OrderChatNotifier(orderId);
    });

class OrderChatNotifier extends StateNotifier<OrderChatState> {
  final String orderId;
  RealtimeChannel? _channel;
  bool _markingRead = false;

  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  bool get _isValidUuid => _uuidRegex.hasMatch(orderId);

  OrderChatNotifier(this.orderId)
    : super(
        OrderChatState(
          currentUserId: SupabaseService.isConfigured
              ? SupabaseService.client.auth.currentUser?.id
              : null,
        ),
      ) {
    if (!SupabaseService.isConfigured) {
      state = state.copyWith(
        isLoading: false,
        error: 'Messaging is unavailable offline.',
      );
      return;
    }
    if (!_isValidUuid) {
      state = state.copyWith(isLoading: false, error: 'Invalid order.');
      return;
    }
    loadMessages();
    _subscribeRealtime();
  }

  Future<void> loadMessages() async {
    if (!SupabaseService.isConfigured || !_isValidUuid) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final res = await SupabaseService.client
          .from('order_messages')
          .select('id, order_id, sender_id, message, created_at, read_at')
          .eq('order_id', orderId)
          .order('created_at', ascending: true);

      if (!mounted) return;
      final loaded = (res as List)
          .map((e) => OrderMessageModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      state = state.copyWith(
        messages: _mergeSorted(loaded, state.messages),
        isLoading: false,
      );
    } catch (e) {
      debugPrint('loadMessages error for order $orderId: $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, error: _describe(e));
      }
    }
  }

  void _subscribeRealtime() {
    _unsubscribeRealtime();

    try {
      _channel = SupabaseService.client
          .channel('order_chat_$orderId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'order_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_id',
              value: orderId,
            ),
            callback: (payload) {
              final rec = payload.newRecord;
              if (mounted && rec.isNotEmpty) {
                _upsert(OrderMessageModel.fromMap(rec));
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to order chat realtime: $e');
    }
  }

  void _unsubscribeRealtime() {
    if (_channel != null) {
      try {
        SupabaseService.client.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }
  }

  /// Sends [text] as the current user.
  ///
  /// Validates locally first so an empty or oversized message never reaches
  /// the network, then throws on any failure (validation or server) so the
  /// caller can show it. Only order_id, sender_id and message are sent.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }
    if (trimmed.length > kOrderMessageMaxLength) {
      throw ArgumentError(
        'Message is too long (${trimmed.length}/$kOrderMessageMaxLength characters).',
      );
    }
    if (!SupabaseService.isConfigured) {
      throw StateError('Messaging is unavailable offline.');
    }
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('You need to be signed in to send messages.');
    }

    state = state.copyWith(isSending: true);
    try {
      final row = await SupabaseService.client
          .from('order_messages')
          .insert({'order_id': orderId, 'sender_id': uid, 'message': trimmed})
          .select('id, order_id, sender_id, message, created_at, read_at')
          .single();
      if (mounted) _upsert(OrderMessageModel.fromMap(row));
    } finally {
      if (mounted) state = state.copyWith(isSending: false);
    }
  }

  /// Marks every message the other party sent as read, server side, and
  /// clears the matching bell notification.
  ///
  /// Only the messages known at call time are flipped locally, so a message
  /// that arrives while the RPC is in flight still counts as unread.
  Future<void> markRead() async {
    if (!SupabaseService.isConfigured || !_isValidUuid || _markingRead) return;
    _markingRead = true;
    final pendingIds = state.messages
        .where((m) => !m.isFrom(state.currentUserId) && m.readAt == null)
        .map((m) => m.id)
        .toSet();

    try {
      await SupabaseService.client.rpc(
        'mark_order_messages_read',
        params: {'p_order_id': orderId},
      );
      if (!mounted) return;
      final now = DateTime.now();
      state = state.copyWith(
        messages: state.messages
            .map((m) => pendingIds.contains(m.id) ? m.markedRead(now) : m)
            .toList(),
      );
    } catch (e) {
      debugPrint('mark_order_messages_read error for order $orderId: $e');
    } finally {
      _markingRead = false;
    }
  }

  void _upsert(OrderMessageModel msg) {
    if (msg.id.isEmpty) return;
    state = state.copyWith(messages: _mergeSorted([msg], state.messages));
  }

  /// Dedupes by id (a sent message arrives both from the insert response and
  /// from realtime) and keeps created_at ascending order.
  static List<OrderMessageModel> _mergeSorted(
    List<OrderMessageModel> incoming,
    List<OrderMessageModel> existing,
  ) {
    final byId = <String, OrderMessageModel>{
      for (final m in existing) m.id: m,
    };
    for (final m in incoming) {
      final prev = byId[m.id];
      // Keep a locally-applied read receipt if the incoming copy predates it.
      byId[m.id] = (prev?.readAt != null && m.readAt == null) ? prev! : m;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  static String _describe(Object e) {
    if (e is PostgrestException) return e.message;
    return e.toString();
  }

  @override
  void dispose() {
    _unsubscribeRealtime();
    super.dispose();
  }
}
