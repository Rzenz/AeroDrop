import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/widgets/neu_input.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/neu_card.dart';
import '../../mock_data/products_mock.dart';
import '../../core/providers/product_provider.dart';
import '../../core/widgets/cart_button.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _search = '';
  String _category = 'All';

  List<MockProduct> _getFiltered(List<MockProduct> products) {
    return products.where((p) {
      final matchSearch =
          _search.isEmpty ||
          p.name.toLowerCase().contains(_search.toLowerCase()) ||
          p.vendorName.toLowerCase().contains(_search.toLowerCase());
      final matchCat = _category == 'All' || p.category == _category;
      return matchSearch && matchCat;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);
    final filtered = _getFiltered(productState.products);

    return Scaffold(
      backgroundColor: AppColors.base,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: CustomAppBar(
          title: 'Shop',
          showBackButton: false,
          action: NeuCartButton(onPressed: () => context.push('/user/cart')),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageGutter(context),
              AppSpacing.xs,
              AppSpacing.pageGutter(context),
              0,
            ),
            child: NeuSearchField(
              hintText: 'Search products',
              onChanged: (v) => setState(() => _search = v),
            ),
          ),

          // Category chips
          SizedBox(
            height: 56,
            child: NeuFilterBar(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.pageGutter(context),
                vertical: AppSpacing.xs,
              ),
              options: productState.categories,
              selectedIndex: productState.categories.indexOf(_category),
              onSelected: (i) =>
                  setState(() => _category = productState.categories[i]),
            ),
          ),

          // Product count
          if (!productState.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} product${filtered.length == 1 ? '' : 's'}',
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Grid / Loading / Empty
          Expanded(
            child: productState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.textSecondary,
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No products are currently available.',
                          style: AppTextStyles.subHead(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              ref.read(productProvider.notifier).loadProducts(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.base,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.pageGutter(context),
                      0,
                      AppSpacing.pageGutter(context),
                      AppSpacing.dockClearance(context),
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      // Two up on phones, three on tablets, four on desktop.
                      crossAxisCount: AppBreakpoints.gridColumns(context),
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisExtent: _ProductGridCard.preferredHeight(context),
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) =>
                        _ProductGridCard(
                              product: filtered[i],
                              onTap: () => context.push(
                                '/user/products/${filtered[i].id}',
                              ),
                            )
                            .animate()
                            .fadeIn(delay: (i * 50).ms)
                            .scale(begin: const Offset(0.95, 0.95)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  const _ProductGridCard({required this.product, required this.onTap});

  final MockProduct product;
  final VoidCallback onTap;

  static const double _imageHeight = 118;

  /// Tile height, scaled with the user's text size so the details block never
  /// gets squeezed out at large accessibility settings.
  static double preferredHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return _imageHeight + 104 * scale;
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = !product.isAvailable || product.stock == 0;

    return NeuCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      borderRadius: AppRadii.brLg,
      semanticLabel:
          '${product.name} from ${product.vendorName}, '
          '₱${product.price.toStringAsFixed(2)}'
          '${unavailable ? ', unavailable' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            // Matches the card radius exactly — a 16 against a 20 leaves a
            // visible sliver of card behind the image corners.
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.lg),
            ),
            child: SizedBox(
              height: _imageHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    // Decode at roughly display size rather than full
                    // resolution; a grid of full-size decodes is the usual
                    // cause of jank on a product list.
                    cacheWidth: 400,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(color: AppColors.surfaceSunken),
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.surfaceSunken,
                      child: Icon(
                        Icons.image_outlined,
                        color: AppColors.textTertiary,
                        size: 28,
                      ),
                    ),
                  ),
                  if (unavailable)
                    Container(
                      color: AppColors.bgDark.withValues(alpha: 0.62),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: AppRadii.brPill,
                        ),
                        child: Text(
                          'Unavailable',
                          style: AppTextStyles.label(
                            fontSize: 10.5,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm - 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      product.name,
                      style: AppTextStyles.subHead(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.vendorName,
                    style: AppTextStyles.caption(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  // Wrap, not Row: at a large text scale a long price and a
                  // long category cannot share one line.
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '₱${product.price.toStringAsFixed(2)}',
                        style: AppTextStyles.numeric(
                          fontSize: 14,
                          color: AppColors.accentText,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          borderRadius: AppRadii.brPill,
                        ),
                        child: Text(
                          product.category,
                          style: AppTextStyles.label(
                            fontSize: 10,
                            color: AppColors.primaryText,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
