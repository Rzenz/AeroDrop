import 'package:flutter/material.dart';
import '../../core/widgets/custom_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../mock_data/products_mock.dart';
import '../../mock_data/cart_mock.dart';
import '../../core/providers/product_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/neu_back_button.dart';
import '../../core/widgets/cart_button.dart';
import '../../core/widgets/neu_feedback.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailsScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  /// The hero image, so a product added to the cart flies from the product.
  final _heroKey = GlobalKey();

  /// Sends a thumbnail of [product] arcing into the cart, then confirms.
  ///
  /// The toast is raised when the puck lands rather than on the tap, so the
  /// two read as one event: the item flies to the cart, and the cart says it
  /// got it. Firing both at once puts a banner over the flight it is meant to
  /// be describing.
  ///
  /// When the hero has scrolled out from under the pinned bar there is no box
  /// to measure and the flight is skipped — the toast still appears.
  void _flyProduct(MockProduct product) {
    final box = _heroKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    flyToCart(
      context,
      // A square token rather than the whole hero: what travels should be the
      // size of the thing arriving, not the size of the banner it came from.
      from: Rect.fromCenter(
        center:
            origin?.center ?? MediaQuery.sizeOf(context).center(Offset.zero),
        width: 84,
        height: 84,
      ),
      // The toast carries the wording, so no separate announcement: a screen
      // reader would otherwise hear the same sentence twice.
      onArrive: () {
        if (!mounted) return;
        showNeuSnack(
          context,
          '${product.name} added to cart',
          tone: NeuToneKind.success,
        );
      },
      thumbnail: Image.network(
        product.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(
          color: AppColors.surfaceSunken,
          child: Icon(
            Icons.shopping_bag_rounded,
            color: AppColors.accentText,
            size: 30,
          ),
        ),
      ),
    );
  }

  MockProduct? _directProduct;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _fetchIfMissing();
  }

  Future<void> _fetchIfMissing() async {
    final cached = ref
        .read(productProvider)
        .products
        .where((p) => p.id == widget.productId)
        .firstOrNull;

    if (cached != null) {
      setState(() => _directProduct = cached);
      return;
    }

    if (!SupabaseService.isConfigured) return;

    setState(() => _fetching = true);
    try {
      Map<String, dynamic>? res;
      try {
        res = await SupabaseService.client
            .from('products')
            .select(
              '*, users!vendor_id(full_name, business_name, role, vendor_status, account_status)',
            )
            .eq('id', widget.productId)
            .maybeSingle();
      } catch (_) {
        res = await SupabaseService.client
            .from('products')
            .select()
            .eq('id', widget.productId)
            .maybeSingle();
      }

      if (res != null && mounted) {
        final vendorMap = res['users'] as Map<String, dynamic>?;
        final vendorName =
            vendorMap?['business_name']?.toString() ??
            vendorMap?['full_name']?.toString() ??
            res['vendor_name']?.toString() ??
            'Campus Vendor';
        final cat = res['category']?.toString() ?? 'Other';
        setState(() {
          _directProduct = MockProduct(
            id: res!['id'].toString(),
            vendorId: res['vendor_id']?.toString() ?? '',
            vendorName: vendorName,
            name: res['name']?.toString() ?? 'Item',
            description: res['description']?.toString() ?? '',
            price: (res['price'] as num?)?.toDouble() ?? 0.0,
            stock: (res['stock_quantity'] as num?)?.toInt() ?? 0,
            category: cat,
            weightKg: (((res['weight_grams'] as num?) ?? 0) / 1000.0),
            imageUrl: res['image_url']?.toString().isNotEmpty == true
                ? res['image_url'].toString()
                : 'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=400',
            isAvailable: res['is_active'] as bool? ?? true,
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching product: $e');
    } finally {
      if (mounted) {
        setState(() => _fetching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);
    final product =
        productState.products
            .where((p) => p.id == widget.productId)
            .firstOrNull ??
        _directProduct;

    if (product == null) {
      if (_fetching || productState.isLoading) {
        return Scaffold(
          backgroundColor: AppColors.base,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        );
      }

      return Scaffold(
        backgroundColor: AppColors.base,
        appBar: CustomAppBar(title: 'Product Details'),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: AppColors.textSecondary,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Product not found or unavailable.',
                style: AppTextStyles.body(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
                child: Text(
                  'Go Back',
                  style: AppTextStyles.body(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool available = product.isAvailable && product.stock > 0;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: CustomScrollView(
        slivers: [
          // Hero image + back button
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.base,
            leading: const Padding(
              padding: EdgeInsets.only(left: AppSpacing.xs),
              child: Center(child: NeuBackButton()),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Center(
                  child: NeuCartButton(
                    onPressed: () => context.push('/user/cart'),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              // Keyed so the add-to-cart flight can start from the product
              // itself rather than from the button that was pressed.
              background: Image.network(
                key: _heroKey,
                product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.base,
                  child: Icon(
                    Icons.image_outlined,
                    color: AppColors.textSecondary,
                    size: 60,
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.category,
                      style: AppTextStyles.label(
                        fontSize: 11,
                        color: AppColors.primaryLight,
                        letterSpacing: 0,
                      ),
                    ),
                  ).animate().fadeIn(),
                  const SizedBox(height: 10),

                  // Name
                  Text(
                    product.name,
                    style: AppTextStyles.heading(
                      fontSize: 22,
                      color: AppColors.textPrimary,
                    ),
                  ).animate().fadeIn(delay: 50.ms),

                  // Vendor
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      if (product.vendorId.isNotEmpty) {
                        context.push('/user/vendors/${product.vendorId}');
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          color: AppColors.primaryLight,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          product.vendorName,
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: AppColors.primaryLight,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primaryLight,
                          size: 14,
                        ),
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
                        style: AppTextStyles.heading(
                          fontSize: 28,
                          color: AppColors.accent,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: available
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: available
                                    ? AppColors.success
                                    : AppColors.danger,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              available ? 'In Stock' : 'Unavailable',
                              style: AppTextStyles.label(
                                fontSize: 12,
                                color: available
                                    ? AppColors.success
                                    : AppColors.danger,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${product.stock} left',
                            style: AppTextStyles.body(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 24),
                  Divider(color: AppColors.border),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'Description',
                    style: AppTextStyles.subHead(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description.isEmpty
                        ? 'No description provided.'
                        : product.description,
                    style: AppTextStyles.body(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 20),
                  Divider(color: AppColors.border),
                  const SizedBox(height: 16),

                  // Specs
                  Text(
                    'Product Info',
                    style: AppTextStyles.subHead(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SpecRow(
                    icon: Icons.scale_rounded,
                    label: 'Weight',
                    value: '${product.weightKg} kg',
                  ),
                  const SizedBox(height: 10),
                  _SpecRow(
                    icon: Icons.category_outlined,
                    label: 'Category',
                    value: product.category,
                  ),
                  const SizedBox(height: 10),
                  _SpecRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'Stock',
                    value: '${product.stock} units',
                  ),
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
                          cartNotifier.addItem(
                            CartItem(
                              productId: product.id,
                              productName: product.name,
                              vendorId: product.vendorId,
                              vendorName: product.vendorName,
                              imageUrl: product.imageUrl,
                              unitPrice: product.price,
                              weightKg: product.weightKg,
                            ),
                          );
                          _flyProduct(product);
                        }
                      }
                    : null,
                icon: Icon(
                  inCart
                      ? Icons.shopping_cart_rounded
                      : Icons.add_shopping_cart_rounded,
                ),
                label: Text(
                  inCart ? 'View Cart' : 'Add to Cart',
                  style: AppTextStyles.subHead(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: available
                      ? AppColors.accent
                      : AppColors.border,
                  foregroundColor: available
                      ? AppColors.bgDark
                      : AppColors.textSecondary,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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

  const _SpecRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTextStyles.body(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.body(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
