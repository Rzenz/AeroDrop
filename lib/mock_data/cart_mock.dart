import 'package:flutter/foundation.dart';

// ─── Cart Item ─────────────────────────────────────────────────────────────

class CartItem {
  final String productId;
  final String productName;
  final String vendorId;
  final String vendorName;
  final String imageUrl;
  final double unitPrice;
  final double weightKg;
  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    required this.vendorId,
    required this.vendorName,
    required this.imageUrl,
    required this.unitPrice,
    this.weightKg = 0.0,
    this.quantity = 1,
  });

  double get subtotal => unitPrice * quantity;
}

// ─── Cart State ─────────────────────────────────────────────────────────────
// ponytail: simple ValueNotifier — no Riverpod needed for a pure in-memory cart.

class CartNotifier extends ValueNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(CartItem item) {
    final idx = value.indexWhere((i) => i.productId == item.productId);
    if (idx >= 0) {
      value[idx].quantity++;
    } else {
      value.add(item);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    value.removeWhere((i) => i.productId == productId);
    notifyListeners();
  }

  void increment(String productId) {
    final idx = value.indexWhere((i) => i.productId == productId);
    if (idx >= 0) {
      value[idx].quantity++;
      notifyListeners();
    }
  }

  void decrement(String productId) {
    final idx = value.indexWhere((i) => i.productId == productId);
    if (idx >= 0) {
      if (value[idx].quantity <= 1) {
        value.removeAt(idx);
      } else {
        value[idx].quantity--;
      }
      notifyListeners();
    }
  }

  void clear() {
    value.clear();
    notifyListeners();
  }

  int get totalItems => value.fold(0, (sum, i) => sum + i.quantity);

  double get totalAmount => value.fold(0.0, (sum, i) => sum + i.subtotal);

  bool hasItem(String productId) => value.any((i) => i.productId == productId);
}

/// Global cart singleton — UI-only, no persistence.
final cartNotifier = CartNotifier();
