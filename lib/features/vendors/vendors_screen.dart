import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/vendor_provider.dart';

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  String _search = '';
  String _categoryFilter = 'All';

  static const _allCategories = [
    'All',
    'Food',
    'Drinks',
    'Electronics',
    'Stationery',
    'Books',
    'Maritime Supplies',
    'Healthy Food',
  ];

  List<VendorViewModel> _getFiltered(List<VendorViewModel> vendors) {
    return vendors.where((v) {
      final matchSearch =
          _search.isEmpty ||
          v.businessName.toLowerCase().contains(_search.toLowerCase()) ||
          v.building.toLowerCase().contains(_search.toLowerCase());
      final matchCat =
          _categoryFilter == 'All' ||
          v.categories.any((c) => c.contains(_categoryFilter));
      return matchSearch && matchCat;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vendorState = ref.watch(vendorProvider);
    final filtered = _getFiltered(vendorState.vendors);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: const CustomAppBar(title: 'Vendors', showBackButton: false),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search vendors or buildings…',
                hintStyle: TextStyle(color: AppColors.textSecondaryDark),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondaryDark,
                ),
                filled: true,
                fillColor: AppColors.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Category chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: _allCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _allCategories[i];
                final selected = cat == _categoryFilter;
                return GestureDetector(
                  onTap: () => setState(() => _categoryFilter = cat),
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
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: selected ? AppColors.bgDark : Colors.white,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Vendor list / loading / empty state
          Expanded(
            child: vendorState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          color: AppColors.textSecondaryDark,
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No vendors are currently available.',
                          style: AppTextStyles.subHead(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              ref.read(vendorProvider.notifier).loadVendors(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.cardDark,
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _VendorCard(
                      vendor: filtered[i],
                      onTap: () =>
                          context.push('/user/vendors/${filtered[i].id}'),
                    ).animate().fadeIn(delay: (i * 60).ms).slideY(begin: 0.1),
                  ),
          ),
        ],
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
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        borderGradient: LinearGradient(
          colors: [vendor.logoColor.withValues(alpha: 0.3), Colors.white12],
        ),
        child: Row(
          children: [
            // Logo
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: vendor.logoColor,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                vendor.logoInitials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
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
                            color: Colors.white,
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
                          style: TextStyle(
                            color: vendor.isOpen
                                ? AppColors.success
                                : AppColors.danger,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: AppColors.textSecondaryDark,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          vendor.building,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: AppColors.textSecondaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                              style: const TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 9.5,
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
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryDark,
            ),
          ],
        ),
      ),
    );
  }
}
