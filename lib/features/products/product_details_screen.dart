import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../mock_data/products_mock.dart';
import '../../mock_data/cart_mock.dart';

class ProductDetailsScreen extends StatelessWidget {
  final String productId;
  const ProductDetailsScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    final product = mockProducts.firstWhere(
      (p) => p.id == productId,
      orElse: () => mockProducts.first,
    );
    final bool available = product.isAvailable && product.stock > 0;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: CustomScrollView(
        slivers: [
          // Hero image + back button
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.bgDark,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              ValueListenableBuilder<List<CartItem>>(
                valueListenable: cartNotifier,
                builder: (_, cart, _) => Stack(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
                      ),
                      onPressed: () => context.push('/user/cart'),
                    ),
                    if (cart.isNotEmpty)
                      Positioned(
                        right: 6, top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                          child: Text('${cartNotifier.totalItems}', style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.cardDark,
                  child: const Icon(Icons.image_outlined, color: AppColors.textSecondaryDark, size: 60),
                ),
              ),
            ),
          ),

          // Product info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.category,
                      style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ).animate().fadeIn(),
                  const SizedBox(height: 10),

                  // Name
                  Text(
                    product.name,
                    style: AppTextStyles.heading(fontSize: 22, color: Colors.white),
                  ).animate().fadeIn(delay: 50.ms),

                  // Vendor
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => context.push('/user/vendors/${product.vendorId}'),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_outlined, color: AppColors.primaryLight, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          product.vendorName,
                          style: AppTextStyles.body(fontSize: 13, color: AppColors.primaryLight),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.primaryLight, size: 14),
                      ],
                    ),
                  ).animate().fadeIn(delay: 80.ms),

                  const SizedBox(height: 20),

                  // Price & stock row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₱${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: available
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: available ? AppColors.success : AppColors.danger,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              available ? 'In Stock' : 'Unavailable',
                              style: TextStyle(
                                color: available ? AppColors.success : AppColors.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${product.stock} left',
                            style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark),
                          ),
                        ],
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 24),
                  const Divider(color: AppColors.borderDark),
                  const SizedBox(height: 16),

                  // Description
                  Text('Description', style: AppTextStyles.subHead(fontSize: 15, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    style: AppTextStyles.body(fontSize: 14, color: Colors.white70, height: 1.6),
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 20),
                  const Divider(color: AppColors.borderDark),
                  const SizedBox(height: 16),

                  // Specs
                  Text('Product Info', style: AppTextStyles.subHead(fontSize: 15, color: Colors.white)),
                  const SizedBox(height: 12),
                  _SpecRow(icon: Icons.scale_rounded, label: 'Weight', value: '${product.weightKg} kg'),
                  const SizedBox(height: 10),
                  _SpecRow(icon: Icons.category_outlined, label: 'Category', value: product.category),
                  const SizedBox(height: 10),
                  _SpecRow(icon: Icons.inventory_2_outlined, label: 'Stock', value: '${product.stock} units'),
                ],
              ).animate().fadeIn(delay: 120.ms),
            ),
          ),
        ],
      ),

      // Add to Cart bottom bar
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: ValueListenableBuilder<List<CartItem>>(
            valueListenable: cartNotifier,
            builder: (_, cart, _) {
              final inCart = cartNotifier.hasItem(product.id);
              return FilledButton.icon(
                onPressed: available
                    ? () {
                        HapticFeedback.mediumImpact();
                        if (inCart) {
                          context.push('/user/cart');
                        } else {
                          cartNotifier.addItem(CartItem(
                            productId: product.id,
                            productName: product.name,
                            vendorId: product.vendorId,
                            vendorName: product.vendorName,
                            imageUrl: product.imageUrl,
                            unitPrice: product.price,
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${product.name} added to cart'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              action: SnackBarAction(
                                label: 'View Cart',
                                textColor: Colors.white,
                                onPressed: () => context.push('/user/cart'),
                              ),
                            ),
                          );
                        }
                      }
                    : null,
                icon: Icon(inCart ? Icons.shopping_cart_rounded : Icons.add_shopping_cart_rounded),
                label: Text(
                  inCart ? 'View Cart' : 'Add to Cart',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: available ? AppColors.accent : AppColors.borderDark,
                  foregroundColor: available ? AppColors.bgDark : AppColors.textSecondaryDark,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SpecRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondaryDark, size: 16),
        const SizedBox(width: 10),
        Text(label, style: AppTextStyles.body(fontSize: 13, color: AppColors.textSecondaryDark)),
        const Spacer(),
        Text(value, style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
