import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../mock_data/cart_mock.dart';
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
  OrderNotifier(this.ref) : super(OrderState.empty()) {
    loadOrders();
  }

  final _client = SupabaseService.client;

  Future<void> loadOrders() async {
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) {
      if (!mounted) return;
      state = OrderState(orders: []);
      return;
    }

    final user = ref.read(authProvider).user;
    if (user == null) return;

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
            'order_items(product_name, quantity, unit_price)',
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

  Future<bool> placeOrder({
    required String vendorId,
    required String dropoffLocationId,
    required double subtotal,
    required double deliveryFee,
    required double totalAmount,
    required String paymentMethod,
    required List<CartItem> items,
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
}

final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>((ref) {
  return OrderNotifier(ref);
});

// ── Vendor order list ─────────────────────────────────────────────────────────

class VendorOrdersNotifier extends StateNotifier<OrderState> {
  final Ref ref;
  RealtimeChannel? _ordersSubscription;

  VendorOrdersNotifier(this.ref) : super(OrderState.empty()) {
    loadOrders();
    _subscribeToOrders();
  }

  final _client = SupabaseService.client;

  void _subscribeToOrders() {
    if (!SupabaseService.isConfigured) return;
    final user = ref.read(authProvider).user;
    if (user == null) return;

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
    } catch (e) {
      debugPrint('Error subscribing to vendor orders realtime: $e');
    }
  }

  Future<void> loadOrders() async {
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) {
      if (!mounted) return;
      state = OrderState(orders: []);
      return;
    }

    final user = ref.read(authProvider).user;
    if (user == null) return;

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
            'order_items(product_name, quantity, unit_price)',
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

  Future<bool> updateOrderStatus(String orderId, String statusName) async {
    try {
      // Plain text status — no UUID lookup needed.
      await _client
          .from('orders')
          .update({
            'order_status': statusName,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
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

  /// Triggers the full drone assignment, weather check, and delivery workflow
  /// using the secure vendor_mark_order_ready RPC. Returns an error message if failed.
  Future<String?> markOrderReady(String orderId) async {
    try {
      await _client.rpc(
        'vendor_mark_order_ready',
        params: {'p_order_id': orderId},
      );

      if (!mounted) return null;

      await loadOrders();
      ref.read(orderProvider.notifier).loadOrders();
      return null;
    } catch (e) {
      debugPrint('vendor_mark_order_ready failed: $e');
      if (e is PostgrestException) {
        return e.message;
      }
      return e.toString();
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.unsubscribe();
    super.dispose();
  }
}

final vendorOrdersProvider =
    StateNotifierProvider<VendorOrdersNotifier, OrderState>((ref) {
      return VendorOrdersNotifier(ref);
    });
