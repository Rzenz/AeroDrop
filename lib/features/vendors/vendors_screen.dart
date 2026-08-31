import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/neu_input.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/neu_card.dart';
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
      backgroundColor: AppColors.base,
      appBar: const CustomAppBar(title: 'Vendors', showBackButton: false),
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
              hintText: 'Search vendors or buildings',
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
              options: _allCategories,
              selectedIndex: _allCategories.indexOf(_categoryFilter),
              onSelected: (i) =>
                  setState(() => _categoryFilter = _allCategories[i]),
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
                        Icon(
                          Icons.storefront_outlined,
                          color: AppColors.textSecondary,
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No vendors are currently available.',
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
              ),
              alignment: Alignment.center,
              child: Text(
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
