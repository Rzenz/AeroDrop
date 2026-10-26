import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_feedback.dart';
import '../../core/widgets/neu_surface.dart';
import '../../core/widgets/delivery_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/staggered_list.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/delivery_model.dart';
import '../../core/models/order_model.dart';
import '../../core/models/product_model.dart';
import '../../core/providers/order_provider.dart';
import '../../core/providers/location_provider.dart';

import '../../core/providers/notification_provider.dart';
import '../../core/providers/weather_provider.dart';
import '../../core/providers/vendor_provider.dart';
import '../../core/providers/product_provider.dart';

/// Customer home.
///
/// Top to bottom: header (avatar, drop-off, alerts), one status banner,
/// category chips over a featured carousel, vendors, recent orders.
/// Destinations already in the bottom navigation are not repeated here.
class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final deliveries = ref.watch(deliveryProvider);
    final orders = ref.watch(orderProvider).orders;
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    final active = deliveries
        .where(
          (d) =>
              d.status == DeliveryStatus.inTransit ||
              d.status == DeliveryStatus.assigning ||
              d.status == DeliveryStatus.pending,
        )
        .toList();
    active.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final firstName = user?.name.split(' ').first ?? 'Pilot';
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'P';

    return Scaffold(
      backgroundColor: AppColors.base,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.base,
        onRefresh: () async {
          await ref.read(orderProvider.notifier).loadOrders();
          await ref
              .read(deliveryProvider.notifier)
              .loadDeliveriesFromSupabase();
          await ref.read(notificationProvider.notifier).loadNotifications();
          await ref.read(productProvider.notifier).loadProducts();
          await ref.read(vendorProvider.notifier).loadVendors();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Header — avatar, drop-off control, alerts.
            SliverAppBar(
              pinned: true,
              toolbarHeight: 74,
              backgroundColor: AppColors.base,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageGutter(context),
                ),
                child: Row(
                  children: [
                    NeuPressable(
                      width: 44,
                      height: 44,
                      borderRadius: BorderRadius.circular(22),
                      color: AppColors.accent,
                      alignment: Alignment.center,
                      semanticLabel: 'Your profile',
                      onTap: () => context.go('/user/profile'),
                      child: user?.avatarUrl != null &&
                              user!.avatarUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.network(
                                user.avatarUrl!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _AvatarInitial(initial: initial),
                              ),
                            )
                          : _AvatarInitial(initial: initial),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(child: _DropoffControl()),
                    const SizedBox(width: AppSpacing.sm),
                    NeuIconButton(
                      icon: Icons.notifications_none_rounded,
                      tooltip: 'Notifications',
                      badgeCount: unreadCount,
                      onPressed: () => context.push('/user/notifications'),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageGutter(context),
                AppSpacing.xs,
                AppSpacing.pageGutter(context),
                AppSpacing.dockClearance(context),
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  StaggeredColumn(
                    delayMs: 50,
                    children: [
                      // 2. Status banner — the active delivery when there is
                      // one, otherwise campus weather. Never both.
                      if (active.isNotEmpty)
                        DeliveryCard(
                          delivery: active.first,
                          onTap: () => context.go('/user/track'),
                        )
                      else
                        const AeroDropWeatherWidget(),

                      const SizedBox(height: 24),

                      // 3 + 4. Category chips over the featured carousel.
                      const _FeaturedProducts(),

                      const SizedBox(height: 24),

                      // 5. Best Choice — vendors.
                      SectionHeader(
                        title: 'Best Choice',
                        actionLabel: 'See all',
                        onAction: () => context.go('/user/shop'),
                      ),
                      const SizedBox(height: 12),
                      const _VendorStrip(),

                      const SizedBox(height: 24),

                      // 6. Recent orders, condensed.
                      SectionHeader(
                        title: 'Recent Orders',
                        actionLabel: 'View all',
                        onAction: () => context.go('/user/orders'),
                      ),
                      const SizedBox(height: 12),
                      if (orders.isEmpty)
                        const _EmptyNote(
                          icon: Icons.shopping_bag_outlined,
                          title: 'No orders yet',
                          message: 'Your recent orders will show up here.',
                        )
                      else
                        Column(
                          children: [
                            for (final order in orders.take(3))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _RecentOrderRow(order: order),
                              ),
                          ],
                        ),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String initial;
  const _AvatarInitial({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Text(
      initial,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: AppTextStyles.title(
        fontSize: 16,
        color: AppColors.bgDark,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// ─── Drop-off control ──────────────────────────────────────────────────────

/// The user's saved drop-off point. Tapping opens a picker; the choice is
/// saved to the profile's campus location and becomes checkout's default.
class _DropoffControl extends ConsumerWidget {
  const _DropoffControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedId = ref.watch(authProvider.select((s) => s.user?.campusLocationId));
    final locations = ref.watch(dropoffLocationsProvider).value ?? const [];

    String? savedName;
    for (final l in locations) {
      if (l.id == savedId) savedName = l.name;
    }
    // A saved id that is no longer a selectable drop-off reads as unset
    final hasSaved = savedName != null;

    return Semantics(
      button: true,
      label: hasSaved ? 'Drop-off: $savedName. Change' : 'Set drop-off',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openPicker(context, ref, savedId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Deliver to',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(fontSize: 11),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      savedName ?? 'Set drop-off',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: hasSaved
                            ? AppColors.textPrimary
                            : AppColors.accent,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    WidgetRef ref,
    String? savedId,
  ) async {
    final picked = await showNeuSheet<CampusLocation>(
      context,
      title: 'Choose your drop-off',
      child: Consumer(
        builder: (sheetContext, sheetRef, _) {
          final async = sheetRef.watch(dropoffLocationsProvider);
          return async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: NeuLoader(),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Unable to load campus locations.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: AppColors.danger,
                ),
              ),
            ),
            data: (locations) => locations.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No drop-off points are available right now.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final loc in locations)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: Icon(
                            Icons.location_on_outlined,
                            color: loc.id == savedId
                                ? AppColors.accent
                                : AppColors.textSecondary,
                          ),
                          title: Text(
                            loc.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              fontWeight: loc.id == savedId
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: loc.id == savedId
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.accent,
                                )
                              : null,
                          onTap: () => Navigator.of(sheetContext).pop(loc),
                        ),
                    ],
                  ),
          );
        },
      ),
    );

    if (picked == null || picked.id == savedId) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    // Saved through the same path as the profile editor. On failure the auth
    // state keeps the previous user, so the control keeps its old value.
    final ok = await ref
        .read(authProvider.notifier)
        .updateProfile(
          user.fullName,
          user.email,
          campusLocationId: picked.id,
        );
    if (!context.mounted) return;
    showNeuSnack(
      context,
      ok
          ? 'Drop-off set to ${picked.name}.'
          : (ref.read(authProvider).errorMessage ??
                'Could not save your drop-off. Please try again.'),
      tone: ok ? NeuToneKind.success : NeuToneKind.error,
    );
  }
}

// ─── Featured products ─────────────────────────────────────────────────────

/// Category chips and the featured carousel they filter. Both work on the
/// products already loaded; nothing is fetched here.
class _FeaturedProducts extends ConsumerStatefulWidget {
  const _FeaturedProducts();

  @override
  ConsumerState<_FeaturedProducts> createState() => _FeaturedProductsState();
}

class _FeaturedProductsState extends ConsumerState<_FeaturedProducts> {
  static const _all = 'All';
  static const _maxFeatured = 6;

  final _pageController = PageController(viewportFraction: 0.86);
  String _category = _all;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _select(String category) {
    if (category == _category) return;
    setState(() => _category = category);
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);
    final inStock = productState.products
        .where((p) => p.isAvailable && p.stock > 0)
        .toList();

    final categories = {
      for (final p in inStock)
        if (p.category.trim().isNotEmpty) p.category.trim(),
    }.toList()
      ..sort();

    // A chip whose category has since disappeared falls back to All
    final selected =
        _category == _all || categories.contains(_category) ? _category : _all;

    final featured = inStock
        .where((p) => selected == _all || p.category.trim() == selected)
        .toList()
      ..sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        return byRating != 0 ? byRating : b.reviewCount.compareTo(a.reviewCount);
      });
    final top = featured.take(_maxFeatured).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (categories.isNotEmpty) ...[
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                for (final c in [_all, ...categories])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _CategoryChip(
                      label: c,
                      selected: c == selected,
                      onTap: () => _select(c),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SectionHeader(
          title: selected == _all ? 'Featured' : 'Featured · $selected',
        ),
        const SizedBox(height: 12),
        if (productState.isLoading && productState.products.isEmpty)
          const SizedBox(height: 120, child: NeuLoader())
        else if (top.isEmpty)
          _EmptyNote(
            icon: Icons.fastfood_outlined,
            title: selected == _all
                ? 'No products available'
                : 'Nothing in $selected right now',
            message: 'Check back soon, or browse every vendor in Shop.',
          )
        else if (top.length < 2)
          // A one-card carousel looks broken; a plain row does not
          Row(
            children: [
              Expanded(child: _FeaturedCard(product: top.first)),
            ],
          )
        else ...[
          SizedBox(
            height: _FeaturedCard.height,
            child: PageView.builder(
              controller: _pageController,
              padEnds: false,
              itemCount: top.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _FeaturedCard(product: top[i]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: SmoothPageIndicator(
              controller: _pageController,
              count: top.length,
              effect: WormEffect(
                dotWidth: 7,
                dotHeight: 7,
                spacing: 6,
                activeDotColor: AppColors.accent,
                dotColor: AppColors.border,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          constraints: const BoxConstraints(maxWidth: 180),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          // Centred vertically but as wide as the label: an aligned
          // container would stretch every chip to its maximum width
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label(
                fontSize: 12,
                letterSpacing: 0,
                fontWeight: FontWeight.bold,
                color: selected ? AppColors.bgDark : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  static const double height = 210;

  final ProductModel product;
  const _FeaturedCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: NeuCard(
        onTap: () => context.push('/user/products/${product.id}'),
        semanticLabel: product.name,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.surfaceRaised,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.vendorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '₱${product.price.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label(
                            fontSize: 13,
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      Icon(
                        product.hasReviews
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: product.hasReviews
                            ? AppColors.warning
                            : AppColors.textSecondary,
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        product.hasReviews
                            ? '${product.rating.toStringAsFixed(1)} (${product.reviewCount})'
                            : 'New',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption(
                          fontSize: 11,
                          color: product.hasReviews
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Vendors ───────────────────────────────────────────────────────────────

class _VendorStrip extends ConsumerWidget {
  const _VendorStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorState = ref.watch(vendorProvider);

    if (vendorState.isLoading && vendorState.vendors.isEmpty) {
      return const SizedBox(height: 110, child: NeuLoader());
    }
    if (vendorState.errorMessage != null && vendorState.vendors.isEmpty) {
      return NeuCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Unable to load vendors.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(
                  fontSize: 12,
                  color: AppColors.danger,
                ),
              ),
            ),
            TextButton(
              onPressed: () => ref.read(vendorProvider.notifier).loadVendors(),
              child: Text(
                'Retry',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(
                  fontSize: 12,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (vendorState.vendors.isEmpty) {
      return const _EmptyNote(
        icon: Icons.storefront_outlined,
        title: 'No vendors available',
        message: 'Campus vendors will appear here once they open.',
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: vendorState.vendors.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) =>
            _VendorCard(vendor: vendorState.vendors[index]),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final VendorViewModel vendor;
  const _VendorCard({required this.vendor});

  @override
  Widget build(BuildContext context) {
    final hasLogo =
        vendor.businessLogoUrl != null && vendor.businessLogoUrl!.isNotEmpty;

    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 14),
      child: NeuCard(
        onTap: () => context.push('/user/vendors/${vendor.id}'),
        padding: const EdgeInsets.all(12),
        accent: vendor.logoColor.withValues(alpha: 0.4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: vendor.logoColor,
                borderRadius: BorderRadius.circular(12),
                image: hasLogo
                    ? DecorationImage(
                        image: NetworkImage(vendor.businessLogoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: hasLogo
                  ? null
                  : Text(
                      vendor.logoInitials,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: AppTextStyles.subHead(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    vendor.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vendor.building.split('–').first.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        vendor.hasReviews
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: vendor.hasReviews
                            ? AppColors.warning
                            : AppColors.textSecondaryDark,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          vendor.hasReviews
                              ? '${vendor.rating.toStringAsFixed(1)} (${vendor.reviewCount})'
                              : 'New',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label(
                            fontSize: 11,
                            color: vendor.hasReviews
                                ? AppColors.textPrimary
                                : AppColors.textSecondaryDark,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0,
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
      ),
    );
  }
}

// ─── Recent orders ─────────────────────────────────────────────────────────

class _RecentOrderRow extends StatelessWidget {
  final OrderModel order;
  const _RecentOrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.effectiveStatus) {
      'pending' => AppColors.warning,
      'confirmed' || 'preparing' => AppColors.info,
      'ready_for_delivery' => AppColors.primaryLight,
      'in_transit' => AppColors.accent,
      'delivered' => AppColors.success,
      _ => AppColors.danger,
    };
    final itemsSummary = order.items.isNotEmpty
        ? order.items.map((i) => '${i.productName} ×${i.quantity}').join(', ')
        : 'No items listed';

    return NeuCard(
      onTap: () => context.push('/user/orders/${order.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_outlined,
              color: AppColors.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.vendorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subHead(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  itemsSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 110),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  order.statusDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label(
                    fontSize: 10.5,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₱${order.totalAmount.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.subHead(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Shared empty state ────────────────────────────────────────────────────

class _EmptyNote extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyNote({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subHead(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AeroDropWeatherWidget extends ConsumerWidget {
  const AeroDropWeatherWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(weatherProvider);

    return NeuCard(
      accent: const Color(0xFF1A2B45).withValues(alpha: 0.85),
      child: weather.isLoading && weather.id == null
          ? const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          : weather.errorMessage != null && weather.id == null
          ? SizedBox(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Unable to load campus weather.',
                      style: AppTextStyles.subHead(
                        fontSize: 13,
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => ref
                          .read(weatherProvider.notifier)
                          .loadWeatherSafety(),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.accent,
                        size: 16,
                      ),
                      label: Text(
                        'Retry',
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _buildWeatherContent(context, ref, weather),
    );
  }

  Widget _buildWeatherContent(
    BuildContext context,
    WidgetRef ref,
    WeatherState weather,
  ) {
    final String status;
    final Color statusColor;
    final IconData weatherIcon;
    final Color iconColor;
    final String condition =
        weather.condition ?? 'No weather record configured.';

    switch (weather.safetyStatus) {
      case 'grounded':
        status = 'GROUNDED';
        statusColor = AppColors.danger;
        weatherIcon = Icons.thunderstorm_rounded;
        iconColor = AppColors.danger;
        break;
      case 'caution':
        status = 'CAUTION';
        statusColor = AppColors.warning;
        weatherIcon = Icons.air_rounded;
        iconColor = AppColors.warning;
        break;
      default:
        status = 'SAFE';
        statusColor = AppColors.success;
        weatherIcon = Icons.wb_sunny_rounded;
        iconColor = AppColors.accent;
        break;
    }

    final tempStr = weather.temperatureDisplay;
    final windStr = weather.windDisplay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UCLM Campus Weather',
                    style: AppTextStyles.subHead(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          weather.lastUpdatedText,
                          style: AppTextStyles.label(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status chip — read only, no tap handler, no edit icon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                status,
                style: AppTextStyles.body(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Weather Info Row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Icon(weatherIcon, color: iconColor, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            tempStr,
                            maxLines: 1,
                            softWrap: false,
                            style: AppTextStyles.display(
                              fontSize: 24,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          condition,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(height: 40, width: 1.5, color: AppColors.border),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _WeatherMetric(
                icon: Icons.air_rounded,
                value: windStr,
                label: (weather.windGusts != null &&
                        weather.windSpeed != null &&
                        weather.windGusts! > weather.windSpeed!)
                    ? 'Wind & Gusts'
                    : 'Wind Speed',
                iconColor: Colors.cyanAccent,
              ),
            ),
          ],
        ),
        if (weather.message != null && weather.message!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              weather.message!,
              style: AppTextStyles.caption(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  const _WeatherMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.title(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.label(
            fontSize: 9,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
