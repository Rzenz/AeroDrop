import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../mock_data/cart_mock.dart';
import '../../core/providers/product_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: cartNotifier,
      builder: (context, cart, _) {
        return Scaffold(
          backgroundColor: AppColors.bgDark,
          appBar: AppBar(
            backgroundColor: AppColors.bgDark,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Cart',
              style: AppTextStyles.subHead(fontSize: 18, color: Colors.white),
            ),
            actions: [
              if (cart.isNotEmpty)
                TextButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    cartNotifier.clear();
                  },
                  child: const Text(
                    'Clear all',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
            ],
          ),
          body: cart.isEmpty
              ? _EmptyCart(onShop: () => context.go('/user/shop'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: cart.length,
                        itemBuilder: (context, i) =>
                            _CartItemCard(item: cart[i])
                                .animate()
                                .fadeIn(delay: (i * 60).ms)
                                .slideX(begin: -0.05),
                      ),
                    ),
                    _CartSummary(cart: cart),
                  ],
                ),
        );
      },
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final VoidCallback onShop;
  const _EmptyCart({required this.onShop});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            color: AppColors.textSecondaryDark,
            size: 72,
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: AppTextStyles.subHead(fontSize: 18, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse vendors and add items to order.',
            style: AppTextStyles.body(
              fontSize: 13,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onShop,
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Browse Vendors'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.bgDark,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  const _CartItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.productId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.danger,
        ),
      ),
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        cartNotifier.removeItem(item.productId);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Product image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  item.imageUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 64,
                    height: 64,
                    color: AppColors.cardDark2,
                    child: const Icon(
                      Icons.image_outlined,
                      color: AppColors.textSecondaryDark,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name + vendor
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.vendorName,
                      style: AppTextStyles.body(
                        fontSize: 11,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₱${item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              // Quantity controls
              Column(
                children: [
                  _QtyButton(
                    icon: Icons.add_rounded,
                    onTap: () => cartNotifier.increment(item.productId),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.quantity}',
                    style: AppTextStyles.subHead(
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _QtyButton(
                    icon: Icons.remove_rounded,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      cartNotifier.decrement(item.productId);
                    },
                    color: item.quantity <= 1
                        ? AppColors.danger
                        : AppColors.primaryLight,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _QtyButton({
    required this.icon,
    required this.onTap,
    this.color = AppColors.primaryLight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

class _CartSummary extends ConsumerWidget {
  final List<CartItem> cart;
  const _CartSummary({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalItems = cart.fold<int>(0, (s, i) => s + i.quantity);
    final totalAmount = cart.fold<double>(0, (s, i) => s + i.subtotal);

    // Delivery fee
    const deliveryFee = 20.0;
    final grandTotal = totalAmount + deliveryFee;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.borderDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items ($totalItems)',
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              Text(
                '₱${totalAmount.toStringAsFixed(2)}',
                style: AppTextStyles.body(fontSize: 13, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Drone Delivery',
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const Text(
                '₱20.00',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.borderDark),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTextStyles.subHead(fontSize: 16, color: Colors.white),
              ),
              Text(
                '₱${grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              final dbProducts = ref.read(productProvider).products;
              List<String> removedOrFlagged = [];

              if (dbProducts.isNotEmpty) {
                for (int i = cart.length - 1; i >= 0; i--) {
                  final item = cart[i];
                  final match = dbProducts
                      .where((p) => p.id == item.productId)
                      .firstOrNull;
                  if (match != null) {
                    if (!match.isAvailable || match.stock <= 0) {
                      cartNotifier.removeItem(item.productId);
                      removedOrFlagged.add('${item.productName} (out of stock)');
                    } else {
                      // Update price if changed
                      if (item.unitPrice != match.price) {
                        item.unitPrice = match.price;
                      }
                      // Cap quantity at available stock
                      if (item.quantity > match.stock) {
                        item.quantity = match.stock;
                        removedOrFlagged.add(
                          '${item.productName} (limited to ${match.stock} available)',
                        );
                      }
                    }
                  }
                }
              }

              if (removedOrFlagged.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cart updated: ${removedOrFlagged.join(", ")}',
                    ),
                    backgroundColor: AppColors.info,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return; // Let user review changes before proceeding
              }

              if (cart.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Your cart is empty.'),
                    backgroundColor: AppColors.warning,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              context.push('/user/checkout');
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.bgDark,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Proceed to Checkout',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
