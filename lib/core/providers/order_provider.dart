import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../mock_data/cart_mock.dart';
import '../services/supabase_service.dart';
import '../models/order_model.dart';
import 'auth_provider.dart';

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

    state = OrderState(orders: state.orders, isLoading: true);

    try {
      if (!SupabaseService.isConfigured) {
        state = OrderState(orders: state.orders, isLoading: false);
        return true;
      }

      // Insert order with flat text columns — no lookup UUID needed.
      final orderRes = await _client
          .from('orders')
          .insert({
            'user_id': user.id,
            'vendor_id': vendorId,
            'delivery_location_id': dropoffLocationId,
            'order_status': 'pending',
            'subtotal': subtotal,
            'delivery_fee': deliveryFee,
            'total_amount': totalAmount,
            'payment_method': paymentMethod,
            'payment_status': paymentMethod == 'gcash_simulated'
                ? 'paid'
                : 'pending',
            'payment_reference': 'PAY-${DateTime.now().millisecondsSinceEpoch}',
          })
          .select('id')
          .single();

      final orderId = orderRes['id'].toString();

      // Insert order items
      final itemsData = items
          .map(
            (item) => {
              'order_id': orderId,
              'product_id': item.productId,
              'product_name': item.productName,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'weight_grams': (item.weightKg * 1000).toInt(),
              'subtotal': item.unitPrice * item.quantity,
            },
          )
          .toList();

      await _client.from('order_items').insert(itemsData);

      await loadOrders();
      return true;
    } catch (e) {
      debugPrint('Place order failed: $e');
      state = OrderState(
        orders: state.orders,
        isLoading: false,
        errorMessage: e.toString(),
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
  VendorOrdersNotifier(this.ref) : super(OrderState.empty()) {
    loadOrders();
  }

  final _client = SupabaseService.client;

  Future<void> loadOrders() async {
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) {
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
}

final vendorOrdersProvider =
    StateNotifierProvider<VendorOrdersNotifier, OrderState>((ref) {
      return VendorOrdersNotifier(ref);
    });
