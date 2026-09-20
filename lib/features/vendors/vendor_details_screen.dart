import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/providers/vendor_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/models/product_model.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/neu_back_button.dart';
import '../../core/widgets/cart_button.dart';
import '../../core/providers/review_provider.dart';
import '../shared/widgets/reviews_list_sheet.dart';

class VendorDetailsScreen extends ConsumerStatefulWidget {
  final String vendorId;
  const VendorDetailsScreen({super.key, required this.vendorId});

  @override
  ConsumerState<VendorDetailsScreen> createState() =>
      _VendorDetailsScreenState();
}

class _VendorDetailsScreenState extends ConsumerState<VendorDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  VendorViewModel? _vendor;
  List<ProductModel> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadVendorData();
  }

  Future<void> _loadVendorData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!SupabaseService.isConfigured) {
        setState(() {
          _loading = false;
          _error = 'Supabase is not configured';
        });
        return;
      }

      // Load vendor
      final vendorRes = await SupabaseService.client
          .from('users')
          .select('*, campus_locations(name)')
          .eq('id', widget.vendorId)
          .eq('role', 'vendor')
          .eq('vendor_status', 'active')
          .eq('account_status', 'active')
          .maybeSingle();

      if (vendorRes == null) {
        setState(() {
          _loading = false;
          _error = 'Vendor not found.';
        });
        return;
      }

      final vendor = VendorViewModel.fromMap(vendorRes);

      // Load products
      final productsRes = await SupabaseService.client
          .from('products')
          .select()
          .eq('vendor_id', widget.vendorId)
          .eq('is_active', true);

      // Fetch dynamic product ratings summaries
      final Map<String, (double, int)> productRatingsMap = {};
      try {
        final prodSummaries = await SupabaseService.client.from('product_ratings_summary').select();
        for (final s in prodSummaries) {
          final pId = s['product_id']?.toString();
          if (pId != null) {
            final avg = (s['average_rating'] as num?)?.toDouble() ?? 0.0;
            final cnt = (s['review_count'] as num?)?.toInt() ?? 0;
            productRatingsMap[pId] = (avg, cnt);
          }
        }
      } catch (_) {}

      final List<ProductModel> products = [];
      for (final p in productsRes) {
        final pId = p['id'].toString();
        final r = productRatingsMap[pId] ?? (0.0, 0);
        products.add(
          ProductModel(
            id: pId,
            vendorId: p['vendor_id'].toString(),
            vendorName: vendor.businessName,
            name: p['name'].toString(),
            description: p['description']?.toString() ?? '',
            price: (p['price'] as num).toDouble(),
            stock: (p['stock_quantity'] as num?)?.toInt() ?? 0,
            category: p['category']?.toString() ?? 'Other',
            weightKg: (((p['weight_grams'] as num?) ?? 0) / 1000.0),
            imageUrl: p['image_url']?.toString() ?? '',
            isAvailable: p['is_active'] as bool? ?? true,
            rating: r.$1,
            reviewCount: r.$2,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _vendor = vendor;
          _products = products;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.base,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    if (_error != null || _vendor == null) {
      return Scaffold(
        backgroundColor: AppColors.base,
        appBar: AppBar(
          backgroundColor: AppColors.base,
          leading: const Padding(
            padding: EdgeInsets.only(left: AppSpacing.xs),
            child: Center(child: NeuBackButton()),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error ?? 'Vendor not found.',
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadVendorData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.base,
                ),
                child: Text(
                  'Retry',
                  style: AppTextStyles.body(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final vendor = _vendor!;
    final products = _products;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 200,
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
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      vendor.logoColor.withValues(alpha: 0.8),
                      AppColors.bgDark,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: vendor.logoColor,
                        borderRadius: BorderRadius.circular(18),
                        image: vendor.businessLogoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(vendor.businessLogoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: vendor.logoColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: vendor.businessLogoUrl == null
                          ? Text(
                              vendor.logoInitials,
                              style: AppTextStyles.heading(
                                fontSize: 26,
                                color: AppColors.textPrimary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      vendor.businessName,
                      style: AppTextStyles.subHead(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: vendor.isOpen
                                ? AppColors.success.withValues(alpha: 0.2)
                                : AppColors.danger.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            vendor.isOpen ? '● Open Now' : '● Closed',
                            style: AppTextStyles.label(
                              fontSize: 11,
                              color: vendor.isOpen
                                  ? AppColors.success
                                  : AppColors.danger,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Consumer(
                          builder: (context, ref, _) {
                            final summaryAsync = ref.watch(vendorRatingsSummaryProvider(widget.vendorId));
                            final summary = summaryAsync.valueOrNull;
                            final hasReviews = summary != null && summary.totalReviews > 0;
                            return GestureDetector(
                              onTap: hasReviews
                                  ? () => ReviewsListSheet.showForVendor(
                                        context,
                                        vendorId: widget.vendorId,
                                        vendorName: vendor.businessName,
                                      )
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.warning.withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: AppColors.warning,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      hasReviews
                                          ? '${summary.averageRating.toStringAsFixed(1)} (${summary.totalReviews} ${summary.totalReviews == 1 ? 'review' : 'reviews'})'
                                          : 'No reviews yet',
                                      style: AppTextStyles.label(
                                        fontSize: 11,
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tab,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: const [
                Tab(text: 'Products'),
                Tab(text: 'About & Reviews'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            // Products tab
            products.isEmpty
                ? Center(
                    child: Text(
                      'No products listed yet.',
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                    itemCount: products.length,
                    itemBuilder: (context, i) => _ProductCard(
                      product: products[i],
                      onTap: () =>
                          context.push('/user/products/${products[i].id}'),
                    ).animate().fadeIn(delay: (i * 60).ms),
                  ),

            // About tab
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _InfoRow(
                  icon: Icons.info_outline_rounded,
                  label: 'Description',
                  value: vendor.description,
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: vendor.building,
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Owner',
                  value: vendor.ownerName,
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: vendor.phone,
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: vendor.email,
                ),
                const SizedBox(height: 20),
                Divider(color: AppColors.border),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final summaryAsync = ref.watch(vendorRatingsSummaryProvider(widget.vendorId));
                    final summary = summaryAsync.valueOrNull;
                    final hasReviews = summary != null && summary.totalReviews > 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Customer Reviews',
                              style: AppTextStyles.subHead(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (hasReviews)
                              TextButton(
                                onPressed: () => ReviewsListSheet.showForVendor(
                                  context,
                                  vendorId: widget.vendorId,
                                  vendorName: vendor.businessName,
                                ),
                                child: Text(
                                  'View All',
                                  style: AppTextStyles.label(
                                    fontSize: 12,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              hasReviews ? Icons.star_rounded : Icons.star_border_rounded,
                              color: hasReviews ? AppColors.warning : AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasReviews
                                  ? '${summary.averageRating.toStringAsFixed(1)} out of 5.0'
                                  : 'No reviews yet',
                              style: AppTextStyles.subHead(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasReviews
                                  ? '(${summary.totalReviews} ${summary.totalReviews == 1 ? 'review' : 'reviews'})'
                                  : '',
                              style: AppTextStyles.body(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryLight, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              product.imageUrl,
              height: 110,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 110,
                color: AppColors.surfaceRaised,
                child: Icon(
                  Icons.image_outlined,
                  color: AppColors.textSecondary,
                  size: 32,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${product.price.toStringAsFixed(2)}',
                  style: AppTextStyles.subHead(
                    fontSize: 14,
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: product.isAvailable && product.stock > 0
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.isAvailable && product.stock > 0
                            ? 'In Stock'
                            : 'Unavailable',
                        style: AppTextStyles.label(
                          fontSize: 9,
                          color: product.isAvailable && product.stock > 0
                              ? AppColors.success
                              : AppColors.danger,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    Row(
                      children: [
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
                            fontSize: 9,
                            color: product.hasReviews
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
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
