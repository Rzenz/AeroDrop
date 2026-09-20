import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../models/cart_model.dart';
import '../services/supabase_service.dart';
import '../models/order_model.dart';
import 'auth_provider.dart';
import 'product_provider.dart';

class OrderState {
  final List<OrderModel> orders;
  final bool isLoading;
  final String? errorMessage;

  OrderState({required this.orders, this.isLoading = false, this.errorMessage});

  factory OrderState.empty() => OrderState(orders: []);
}

// ── Student order list ────────────────────────────────────────────────────────

class OrderNotifier extends StateNotifier<OrderState> {
  final Ref ref;
  RealtimeChannel? _ordersSubscription;
  RealtimeChannel? _deliveriesSubscription;

  OrderNotifier(this.ref) : super(OrderState.empty()) {
    final auth = ref.read(authProvider);
    if (auth.sessionUnlocked && auth.user != null) {
      loadOrders();
      _subscribeToOrders();
    }

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.user?.id != next.user?.id ||
          previous?.sessionUnlocked != next.sessionUnlocked) {
        _unsubscribe();
        if (next.user != null && next.sessionUnlocked) {
          loadOrders();
          _subscribeToOrders();
        } else {
          state = OrderState.empty();
        }
      }
    });
  }

  void _unsubscribe() {
    _ordersSubscription?.unsubscribe();
    _ordersSubscription = null;
    _deliveriesSubscription?.unsubscribe();
    _deliveriesSubscription = null;
  }

  final _client = SupabaseService.client;

  void _subscribeToOrders() {
    if (!SupabaseService.isConfigured) return;
    final auth = ref.read(authProvider);
    final user = auth.user;
    if (user == null || !auth.sessionUnlocked) return;

    _unsubscribe();

    try {
      _ordersSubscription = _client
          .channel('student_orders_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (payload) {
              if (mounted) {
                loadOrders();
              }
            },
          )
          .subscribe();

      // Also listen for deliveries updates
      _deliveriesSubscription = _client
          .channel('student_deliveries_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'deliveries',
            callback: (payload) {
              if (mounted) {
                loadOrders();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to student orders realtime: $e');
    }
  }

  Future<void> loadOrders() async {
    final authUser = SupabaseService.client.auth.currentUser;
    final auth = ref.read(authProvider);
    if (authUser == null || !auth.sessionUnlocked || auth.user == null) {
      if (!mounted) return;
      state = OrderState(orders: []);
      return;
    }

    final user = auth.user!;

    state = OrderState(orders: state.orders, isLoading: true);
    try {
      if (!SupabaseService.isConfigured) {
        if (mounted) {
          state = OrderState(orders: [], isLoading: false);
        }
        return;
      }

      final ordersRes = await _client
          .from('orders')
          .select(
            '*, vendor:users!vendor_id(full_name, business_name), '
            'customer:users!user_id(full_name, phone_number), '
            'campus_locations!delivery_location_id(name), '
            'order_items(product_name, quantity, unit_price), '
            'deliveries(id, status, progress, drone_id, estimated_delivery_seconds, delivery_started_at, delivery_completed_at)',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      final loaded = (ordersRes as List)
          .map((o) => OrderModel.fromMap(Map<String, dynamic>.from(o)))
          .toList();

      state = OrderState(orders: loaded, isLoading: false);
    } catch (e) {
      debugPrint('Load orders failed: $e');
      if (mounted) {
        state = OrderState(
          orders: state.orders,
          isLoading: false,
          errorMessage: e.toString(),
        );
      }
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  Future<bool> placeOrder({
    required String vendorId,
    required String dropoffLocationId,
    required double subtotal,
    required double deliveryFee,
    required double totalAmount,
    required String paymentMethod,
    required List<CartItem> items,
    String? notes,
  }) async {
    final user = ref.read(authProvider).user;
    if (user == null) return false;

    // Validate maximum drone payload (0.5 kg = 500 grams)
    final totalWeightGrams = items.fold<int>(
      0,
      (sum, item) => sum + ((item.weightKg * 1000).round() * item.quantity),
    );
    if (totalWeightGrams > 500) {
      final weightKg = (totalWeightGrams / 1000.0).toStringAsFixed(2);
      state = OrderState(
        orders: state.orders,
        isLoading: false,
        errorMessage:
            "This order exceeds the drone's maximum payload of 0.5 kg. Your order weighs $weightKg kg.",
      );
      return false;
    }

    state = OrderState(orders: state.orders, isLoading: true);

    try {
      if (!SupabaseService.isConfigured) {
        state = OrderState(orders: state.orders, isLoading: false);
        return true;
      }

      final itemsPayload = items
          .map(
            (item) => {
              'product_id': item.productId,
              'product_name': item.productName,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
            },
          )
          .toList();

      // Transactional atomic order placement RPC with row locking, stock reduction & payload check
      await _client.rpc(
        'place_order',
        params: {
          'p_vendor_id': vendorId,
          'p_delivery_location_id': dropoffLocationId,
          'p_subtotal': subtotal,
          'p_delivery_fee': deliveryFee,
          'p_total_amount': totalAmount,
          'p_payment_method': paymentMethod,
          'p_items': itemsPayload,
          'p_notes': notes,
        },
      );

      if (!mounted) return true;

      await loadOrders();
      // Invalidate/reload product inventory and vendor orders so changes reflect immediately
      ref.read(productProvider.notifier).loadProducts();
      ref.read(vendorOrdersProvider.notifier).loadOrders();
      return true;
    } catch (e) {
      debugPrint('Place order failed: $e');
      final errorMsg = e is PostgrestException ? e.message : e.toString();
      state = OrderState(
        orders: state.orders,
        isLoading: false,
        errorMessage: errorMsg,
      );
      return false;
    }
  }

  Future<bool> cancelOrder(
    String orderId, {
    String cancellationReason = 'customer',
  }) async {
    try {
      final res = await _client.rpc(
        'customer_cancel_order',
        params: {'p_order_id': orderId},
      );

      if (!mounted) return false;
      await loadOrders();
      return res == true;
    } catch (e) {
      debugPrint('Cancel order failed: $e');
      return false;
    }
  }
}

final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>((ref) {
  return OrderNotifier(ref);
});

// ── Vendor order list ─────────────────────────────────────────────────────────

class VendorOrdersNotifier extends StateNotifier<OrderState> {
  final Ref ref;
  RealtimeChannel? _ordersSubscription;
  RealtimeChannel? _deliveriesSubscription;

  VendorOrdersNotifier(this.ref) : super(OrderState.empty()) {
    final auth = ref.read(authProvider);
    if (auth.sessionUnlocked && auth.user != null) {
      loadOrders();
      _subscribeToOrders();
    }

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.user?.id != next.user?.id ||
          previous?.sessionUnlocked != next.sessionUnlocked) {
        _unsubscribe();
        if (next.user != null && next.sessionUnlocked) {
          loadOrders();
          _subscribeToOrders();
        } else {
          state = OrderState.empty();
        }
      }
    });
  }

  void _unsubscribe() {
    _ordersSubscription?.unsubscribe();
    _ordersSubscription = null;
    _deliveriesSubscription?.unsubscribe();
    _deliveriesSubscription = null;
  }

  final _client = SupabaseService.client;

  void _subscribeToOrders() {
    if (!SupabaseService.isConfigured) return;
    final auth = ref.read(authProvider);
    final user = auth.user;
    if (user == null || !auth.sessionUnlocked) return;

    _unsubscribe();

    try {
      _ordersSubscription = _client
          .channel('vendor_orders_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'vendor_id',
              value: user.id,
            ),
            callback: (payload) {
              if (mounted) {
                loadOrders();
              }
            },
          )
          .subscribe();

      // Also listen for deliveries updates
      _deliveriesSubscription = _client
          .channel('vendor_deliveries_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'deliveries',
            callback: (payload) {
              if (mounted) {
                loadOrders();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to vendor orders realtime: $e');
    }
  }

  Future<void> loadOrders() async {
    final authUser = SupabaseService.client.auth.currentUser;
    final auth = ref.read(authProvider);
    if (authUser == null || !auth.sessionUnlocked || auth.user == null) {
      if (!mounted) return;
      state = OrderState(orders: []);
      return;
    }

    final user = auth.user!;

    state = OrderState(orders: state.orders, isLoading: true);

    try {
      if (!SupabaseService.isConfigured) {
        if (mounted) {
          state = OrderState(orders: [], isLoading: false);
        }
        return;
      }

      // vendor_id IS the auth user id in the new schema — no vendors lookup.
      final ordersRes = await _client
          .from('orders')
          .select(
            '*, customer:users!user_id(full_name, phone_number), '
            'campus_locations!delivery_location_id(name), '
            'order_items(product_name, quantity, unit_price), '
            'deliveries(id, status, progress, drone_id, estimated_delivery_seconds, delivery_started_at, delivery_completed_at)',
          )
          .eq('vendor_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      final loaded = (ordersRes as List)
          .map((o) => OrderModel.fromMap(Map<String, dynamic>.from(o)))
          .toList();

      state = OrderState(orders: loaded, isLoading: false);
    } catch (e) {
      debugPrint('Load vendor orders failed: $e');
      if (mounted) {
        state = OrderState(
          orders: state.orders,
          isLoading: false,
          errorMessage: e.toString(),
        );
      }
    }
  }

  Future<bool> updateOrderStatus(
    String orderId,
    String statusName, {
    String? cancellationReason,
  }) async {
    try {
      final payload = <String, dynamic>{
        'order_status': statusName,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (statusName == 'cancelled' || statusName == 'rejected') {
        payload['cancellation_reason'] = cancellationReason ?? 'vendor';
      }

      await _client
          .from('orders')
          .update(payload)
          .eq('id', orderId);

      if (!mounted) return false;

      await loadOrders();
      ref.read(orderProvider.notifier).loadOrders();
      return true;
    } catch (e) {
      debugPrint('Update order status failed: $e');
      return false;
    }
  }

  /// Triggers drone assignment / queueing workflow using vendor_mark_order_ready.
  Future<({bool success, bool droneDispatched, String message})> markOrderReady(
    String orderId,
  ) async {
    try {
      final res = await _client.rpc(
        'vendor_mark_order_ready',
        params: {'p_order_id': orderId},
      );

      if (!mounted) {
        return (
          success: true,
          droneDispatched: true,
          message: 'Order marked ready.',
        );
      }

      await loadOrders();
      ref.read(orderProvider.notifier).loadOrders();

      final data = res is Map
          ? Map<String, dynamic>.from(res)
          : <String, dynamic>{};
      final dispatched = data['drone_dispatched'] == true;
      final msg =
          data['message']?.toString() ??
          (dispatched
              ? 'Order is ready for drone pickup! Drone dispatch initiated.'
              : 'Drone currently unavailable. This order is ready and waiting for the next available drone.');

      return (success: true, droneDispatched: dispatched, message: msg);
    } catch (e) {
      debugPrint('vendor_mark_order_ready failed: $e');
      final errorMsg = e is PostgrestException ? e.message : e.toString();
      return (success: false, droneDispatched: false, message: errorMsg);
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}

final vendorOrdersProvider =
    StateNotifierProvider<VendorOrdersNotifier, OrderState>((ref) {
      return VendorOrdersNotifier(ref);
    });

/// Live count of customer active orders (pending, confirmed, preparing, ready_for_delivery, in_transit)
/// for displaying badges on the customer navigation dock.
final customerActiveOrdersCountProvider = Provider<int>((ref) {
  final orders = ref.watch(orderProvider).orders;
  return orders.where((o) {
    final status = o.effectiveStatus.toLowerCase();
    return status == 'pending' ||
        status == 'confirmed' ||
        status == 'preparing' ||
        status == 'ready_for_delivery' ||
        status == 'in_transit';
  }).length;
});

/// Live count of vendor orders needing action (pending, confirmed, preparing)
/// for displaying badges on the vendor navigation dock.
final vendorActionOrdersCountProvider = Provider<int>((ref) {
  final orders = ref.watch(vendorOrdersProvider).orders;
  return orders.where((o) {
    final status = o.effectiveStatus.toLowerCase();
    return status == 'pending' ||
        status == 'confirmed' ||
        status == 'preparing';
  }).length;
});
