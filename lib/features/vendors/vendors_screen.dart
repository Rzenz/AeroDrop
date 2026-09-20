import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/cart_button.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_input.dart';
import '../../core/models/product_model.dart';
import '../../core/providers/product_provider.dart';
import '../../core/providers/vendor_provider.dart';

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  int _selectedTab = 0; // 0 = Stores, 1 = All Products
  String _vendorSearch = '';
  String _vendorCategory = 'All';
  String _productSearch = '';
  String _productCategory = 'All';

  static const _vendorCategories = [
    'All',
    'Food',
    'Drinks',
    'Electronics',
    'Stationery',
    'Books',
    'Maritime Supplies',
    'Healthy Food',
  ];

  List<VendorViewModel> _getFilteredVendors(List<VendorViewModel> vendors) {
    return vendors.where((v) {
      final matchSearch =
          _vendorSearch.isEmpty ||
          v.businessName.toLowerCase().contains(_vendorSearch.toLowerCase()) ||
          v.building.toLowerCase().contains(_vendorSearch.toLowerCase());
      final matchCat =
          _vendorCategory == 'All' ||
          v.categories.any((c) => c.toLowerCase().contains(_vendorCategory.toLowerCase()));
      return matchSearch && matchCat;
    }).toList();
  }

  List<ProductModel> _getFilteredProducts(List<ProductModel> products) {
    return products.where((p) {
      final matchSearch =
          _productSearch.isEmpty ||
          p.name.toLowerCase().contains(_productSearch.toLowerCase()) ||
          p.vendorName.toLowerCase().contains(_productSearch.toLowerCase());
      final matchCat =
          _productCategory == 'All' || p.category == _productCategory;
      return matchSearch && matchCat;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vendorState = ref.watch(vendorProvider);
    final productState = ref.watch(productProvider);
    final filteredVendors = _getFilteredVendors(vendorState.vendors);
    final filteredProducts = _getFilteredProducts(productState.products);

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
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.base,
        onRefresh: () async {
          await ref.read(vendorProvider.notifier).loadVendors();
          await ref.read(productProvider.notifier).loadProducts();
        },
        child: Column(
          children: [
            // Mode Switcher: Stores vs All Products
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageGutter(context),
                AppSpacing.xs,
                AppSpacing.pageGutter(context),
                AppSpacing.xs,
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSunken,
                  borderRadius: AppRadii.brPill,
                  border: Border.all(color: AppColors.border, width: 0.8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        label: 'Stores',
                        icon: Icons.storefront_rounded,
                        isSelected: _selectedTab == 0,
                        onTap: () => setState(() => _selectedTab = 0),
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        label: 'All Products',
                        icon: Icons.inventory_2_outlined,
                        isSelected: _selectedTab == 1,
                        onTap: () => setState(() => _selectedTab = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_selectedTab == 0) ...[
              // Store Search
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter(context),
                  0,
                  AppSpacing.pageGutter(context),
                  0,
                ),
                child: NeuSearchField(
                  hintText: 'Search campus stores or buildings',
                  onChanged: (v) => setState(() => _vendorSearch = v),
                ),
              ),

              // Store Category Chips
              SizedBox(
                height: 56,
                child: NeuFilterBar(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageGutter(context),
                    vertical: AppSpacing.xs,
                  ),
                  options: _vendorCategories,
                  selectedIndex: _vendorCategories.indexOf(_vendorCategory),
                  onSelected: (i) =>
                      setState(() => _vendorCategory = _vendorCategories[i]),
                ),
              ),

              // Store count
              if (!vendorState.isLoading)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageGutter(context),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${filteredVendors.length} store${filteredVendors.length == 1 ? '' : 's'} available',
                        style: AppTextStyles.body(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),

              // Vendor list / loading / empty state
              Expanded(
                child: vendorState.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.accent),
                      )
                    : filteredVendors.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              color: AppColors.textSecondary,
                              size: 56,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No stores found matching your search.',
                              style: AppTextStyles.subHead(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  ref.read(vendorProvider.notifier).loadVendors(),
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
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: filteredVendors.length,
                        itemBuilder: (context, i) => _VendorCard(
                          vendor: filteredVendors[i],
                          onTap: () =>
                              context.push('/user/vendors/${filteredVendors[i].id}'),
                        ).animate().fadeIn(delay: (i * 50).ms).slideY(begin: 0.08),
                      ),
              ),
            ] else ...[
              // Products Search
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter(context),
                  0,
                  AppSpacing.pageGutter(context),
                  0,
                ),
                child: NeuSearchField(
                  hintText: 'Search products or vendors',
                  onChanged: (v) => setState(() => _productSearch = v),
                ),
              ),

              // Product Category chips
              SizedBox(
                height: 56,
                child: NeuFilterBar(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageGutter(context),
                    vertical: AppSpacing.xs,
                  ),
                  options: productState.categories,
                  selectedIndex:
                      productState.categories.indexOf(_productCategory),
                  onSelected: (i) => setState(
                    () => _productCategory = productState.categories[i],
                  ),
                ),
              ),

              // Product count
              if (!productState.isLoading)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageGutter(context),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${filteredProducts.length} product${filteredProducts.length == 1 ? '' : 's'}',
                        style: AppTextStyles.body(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),

              // Products grid
              Expanded(
                child: productState.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.accent),
                      )
                    : filteredProducts.isEmpty
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
                              'No products found matching your search.',
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
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: AppBreakpoints.gridColumns(context),
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisExtent: _ProductGridCard.preferredHeight(context),
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, i) => _ProductGridCard(
                          product: filteredProducts[i],
                          onTap: () => context.push(
                            '/user/products/${filteredProducts[i].id}',
                          ),
                        )
                            .animate()
                            .fadeIn(delay: (i * 40).ms)
                            .scale(begin: const Offset(0.96, 0.96)),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: AppRadii.brPill,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.label(
                fontSize: 12.5,
                color: isSelected ? Colors.black : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final VendorViewModel vendor;
  final VoidCallback onTap;

  const _VendorCard({required this.vendor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        accent: vendor.logoColor.withValues(alpha: 0.3),
        child: Row(
          children: [
            // Logo
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: vendor.logoColor,
                borderRadius: BorderRadius.circular(14),
                image: vendor.businessLogoUrl != null &&
                        vendor.businessLogoUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(vendor.businessLogoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: vendor.businessLogoUrl != null &&
                      vendor.businessLogoUrl!.isNotEmpty
                  ? null
                  : Text(
                      vendor.logoInitials,
                      style: AppTextStyles.heading(
                        fontSize: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          vendor.businessName,
                          style: AppTextStyles.subHead(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Open/closed badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: vendor.isOpen
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: vendor.isOpen
                                ? AppColors.success
                                : AppColors.danger,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          vendor.isOpen ? 'Open' : 'Closed',
                          style: AppTextStyles.label(
                            fontSize: 10,
                            color: vendor.isOpen
                                ? AppColors.success
                                : AppColors.danger,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          vendor.building,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        vendor.hasReviews
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: vendor.hasReviews
                            ? AppColors.warning
                            : AppColors.textSecondary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vendor.hasReviews
                            ? '${vendor.rating.toStringAsFixed(1)} (${vendor.reviewCount} ${vendor.reviewCount == 1 ? 'review' : 'reviews'})'
                            : 'No reviews yet',
                        style: AppTextStyles.label(
                          fontSize: 11,
                          color: vendor.hasReviews
                              ? AppColors.warning
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: vendor.categories
                        .take(3)
                        .map(
                          (cat) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cat,
                              style: AppTextStyles.caption(
                                fontSize: 9.5,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  const _ProductGridCard({required this.product, required this.onTap});

  final ProductModel product;
  final VoidCallback onTap;

  static const double _imageHeight = 118;

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
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.lg),
            ),
            child: SizedBox(
              height: _imageHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (product.imageUrl.isNotEmpty)
                    Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
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
                    )
                  else
                    Container(
                      color: AppColors.surfaceSunken,
                      child: Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.vendorName,
                          style: AppTextStyles.caption(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        product.hasReviews
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: product.hasReviews
                            ? AppColors.warning
                            : AppColors.textSecondary,
                        size: 11,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        product.hasReviews
                            ? product.rating.toStringAsFixed(1)
                            : 'New',
                        style: AppTextStyles.caption(
                          fontSize: 9.5,
                          color: product.hasReviews
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
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
