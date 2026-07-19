import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../mock_data/products_mock.dart';
import '../../core/providers/product_provider.dart';

class VendorProductsScreen extends ConsumerStatefulWidget {
  const VendorProductsScreen({super.key});

  @override
  ConsumerState<VendorProductsScreen> createState() =>
      _VendorProductsScreenState();
}

class _VendorProductsScreenState extends ConsumerState<VendorProductsScreen> {
  String _search = '';
  String _category = 'All';

  List<MockProduct> _getFiltered(List<MockProduct> products) {
    return products.where((p) {
      final matchSearch =
          _search.isEmpty ||
          p.name.toLowerCase().contains(_search.toLowerCase());
      final matchCat = _category == 'All' || p.category == _category;
      return matchSearch && matchCat;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(vendorProductsProvider);
    final filtered = _getFiltered(productState.products);
    final categories = [
      'All',
      ...productState.products.map((p) => p.category).toSet(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory Catalog',
                          style: AppTextStyles.label(
                            fontSize: 10,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        Text(
                          'My Products',
                          style: AppTextStyles.heading(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/vendor/products/add'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.add_rounded,
                            color: AppColors.primaryDark,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Add Item',
                            style: TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search input field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (value) => setState(() => _search = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search stock catalog…',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondaryDark,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondaryDark,
                  ),
                  filled: true,
                  fillColor: AppColors.cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Categories list scrollable chips
            SizedBox(
              height: 54,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final cat = categories[idx];
                  final selected = cat == _category;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.accent : AppColors.cardDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.accent
                              : AppColors.borderDark,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: selected
                                ? AppColors.primaryDark
                                : Colors.white,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Responsive 2-Column Grid Layout
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
                          const Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.textSecondaryDark,
                            size: 56,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No items found in this category.',
                            style: AppTextStyles.subHead(color: Colors.white70),
                          ),
                        ],
                      ).animate().fadeIn(),
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref
                          .read(vendorProductsProvider.notifier)
                          .loadProducts(),
                      color: AppColors.accent,
                      child: GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.72,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          return VendorProductCard(
                            product: filtered[idx],
                            onEdit: () => context.push(
                              '/vendor/products/edit?id=${filtered[idx].id}',
                            ),
                            onDelete: () =>
                                _showDeleteDialog(context, filtered[idx]),
                          ).animate().fadeIn(delay: (idx * 40).ms);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, MockProduct product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Product?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remove "${product.name}" from your listings?',
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              final success = await ref
                  .read(vendorProductsProvider.notifier)
                  .deleteProduct(product.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '"${product.name}" deleted successfully.'
                          : 'Failed to delete "${product.name}".',
                    ),
                    backgroundColor: success
                        ? AppColors.success
                        : AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class VendorProductCard extends StatelessWidget {
  final MockProduct product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VendorProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.stock <= 5;
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image + Availability Badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: Image.network(
                  product.imageUrl,
                  height: 110,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 110,
                    color: AppColors.cardDark2,
                    child: const Icon(
                      Icons.image_outlined,
                      color: AppColors.textSecondaryDark,
                      size: 30,
                    ),
                  ),
                ),
              ),
              if (!product.isAvailable || product.stock == 0)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Grounded',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.body(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₱${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isLowStock
                                ? Icons.warning_amber_rounded
                                : Icons.inventory_2_outlined,
                            size: 13,
                            color: isLowStock
                                ? AppColors.warning
                                : AppColors.textSecondaryDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Stock: ${product.stock}',
                            style: TextStyle(
                              color: isLowStock
                                  ? AppColors.warning
                                  : AppColors.textSecondaryDark,
                              fontSize: 11,
                              fontWeight: isLowStock
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_rounded,
                              size: 16,
                              color: AppColors.primaryLight,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: onEdit,
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: AppColors.danger,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: onDelete,
                          ),
                        ],
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
