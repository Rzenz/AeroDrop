import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/cart_model.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/providers/vendor_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dashboard/widgets/dash_kit.dart';
import '../../web_tokens.dart';
import '../web_kit.dart';

/// Adds one of [p] to the cart — never more than the canteen has in stock.
/// Returns false when the shelf is already all in the cart.
bool webAddToCart(ProductModel p) {
  final inCart = cartNotifier.value
      .where((c) => c.productId == p.id)
      .fold<int>(0, (s, c) => s + c.quantity);
  if (inCart >= p.stock || !p.isAvailable) return false;
  cartNotifier.addItem(
    CartItem(
      productId: p.id,
      productName: p.name,
      vendorId: p.vendorId,
      vendorName: p.vendorName,
      imageUrl: p.imageUrl,
      unitPrice: p.price,
      weightKg: p.weightKg,
    ),
  );
  return true;
}

/// A grid of products with live in-cart counts on each card's add button.
class WebProductGrid extends StatelessWidget {
  const WebProductGrid({super.key, required this.products});

  final List<ProductModel> products;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: cartNotifier,
      builder: (context, cart, _) {
        int inCart(String id) => cart
            .where((c) => c.productId == id)
            .fold<int>(0, (s, c) => s + c.quantity);
        return WebGrid(
          minTile: 200,
          maxColumns: 5,
          gap: 22,
          children: [
            for (final p in products)
              DashProductCard(
                product: p,
                inCart: inCart(p.id),
                onOpen: () => context.push('/user/products/${p.id}'),
                onAdd: () => webAddToCart(p),
              ),
          ],
        );
      },
    );
  }
}

/// A canteen: its logo (or a sky tile with its initials), name, building,
/// category and rating. The whole card opens the store.
class WebStoreCard extends StatelessWidget {
  const WebStoreCard({super.key, required this.vendor, required this.onOpen});

  final VendorViewModel vendor;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final v = vendor;
    final sky = WebSky.values[v.businessName.hashCode.abs() % 4];
    final logo = v.businessLogoUrl;

    return WebHoverCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(8),
      semanticLabel: '${v.businessName}, ${v.building}. ${v.ratingLabel}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 128,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(gradient: sky.gradient),
                    child: logo == null || logo.isEmpty
                        ? Center(
                            child: Text(
                              v.logoInitials,
                              style: WebText.display(38, color: sky.ink),
                            ),
                          )
                        : Image.network(
                            logo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                v.logoInitials,
                                style: WebText.display(38, color: sky.ink),
                              ),
                            ),
                          ),
                  ),
                  if ((v.businessCategory ?? '').isNotEmpty)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          v.businessCategory!,
                          style: WebText.label(size: 11.5, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: WebText.title(size: 16.5),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 15,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        v.building,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WebText.body(size: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      v.hasReviews
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 16,
                      color: v.hasReviews
                          ? const Color(0xFFE9A23B)
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        v.ratingLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WebText.label(
                          size: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      'View menu',
                      style: WebText.label(
                        size: 13,
                        color: AppColors.accentText,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: AppColors.accentText,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading placeholders in the shape of the grid that is coming.
class WebGridSkeleton extends StatelessWidget {
  const WebGridSkeleton({super.key, this.height = 260, this.count = 8});

  final double height;
  final int count;

  @override
  Widget build(BuildContext context) => WebGrid(
    minTile: 200,
    maxColumns: 5,
    gap: 22,
    children: [
      for (var i = 0; i < count; i++) WebSkeleton(height: height, radius: 22),
    ],
  );
}

/// Canteens in [cart], in the order their items were added.
List<String> cartCanteens(List<CartItem> cart) => [
  ...{for (final c in cart) c.vendorName},
];

/// Grams of everything in [cart] — what the drone has to lift.
int cartWeightGrams(List<CartItem> cart) => cart.fold<int>(
  0,
  (sum, i) => sum + ((i.weightKg * 1000).round() * i.quantity),
);
