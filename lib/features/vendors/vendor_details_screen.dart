import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/vendor_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../mock_data/products_mock.dart';
import '../../mock_data/cart_mock.dart';

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
  List<MockProduct> _products = [];
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

      final List<MockProduct> products = [];
      for (final p in productsRes) {
        products.add(
          MockProduct(
            id: p['id'].toString(),
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
        backgroundColor: AppColors.bgDark,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    if (_error != null || _vendor == null) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(
          backgroundColor: AppColors.bgDark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error ?? 'Vendor not found.',
                style: TextStyle(color: AppColors.danger, fontSize: 14),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadVendorData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardDark,
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
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
      backgroundColor: AppColors.bgDark,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.bgDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              ValueListenableBuilder<List<CartItem>>(
                valueListenable: cartNotifier,
                builder: (_, cart, _) => cart.isNotEmpty
                    ? Stack(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.white,
                            ),
                            onPressed: () => context.push('/user/cart'),
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${cartNotifier.totalItems}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () => context.push('/user/cart'),
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
                        boxShadow: [
                          BoxShadow(
                            color: vendor.logoColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        vendor.logoInitials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      vendor.businessName,
                      style: AppTextStyles.subHead(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                        style: TextStyle(
                          color: vendor.isOpen
                              ? AppColors.success
                              : AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tab,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textSecondaryDark,
              tabs: const [
                Tab(text: 'Products'),
                Tab(text: 'About'),
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
                      style: AppTextStyles.body(
                        color: AppColors.textSecondaryDark,
                      ),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${vendor.rating}',
                      style: AppTextStyles.subHead(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${vendor.totalOrders} orders)',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
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
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.body(fontSize: 14, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final MockProduct product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
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
                color: AppColors.cardDark2,
                child: const Icon(
                  Icons.image_outlined,
                  color: AppColors.textSecondaryDark,
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
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
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
                        style: TextStyle(
                          color: product.isAvailable && product.stock > 0
                              ? AppColors.success
                              : AppColors.danger,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
