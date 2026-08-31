import 'package:flutter/material.dart';
import '../../core/widgets/neu_feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_surface.dart';
import '../../core/widgets/delivery_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/staggered_list.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/drone_svg_painter.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/delivery_model.dart';

import '../../core/providers/notification_provider.dart';
import '../../core/providers/weather_provider.dart';
import '../../core/providers/vendor_provider.dart';
import '../../core/providers/product_provider.dart';

class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final deliveries = ref.watch(deliveryProvider);
    final notifications = ref.watch(notificationProvider);
    final vendorState = ref.watch(vendorProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;
    final productState = ref.watch(productProvider);
    final popularProducts = productState.products
        .where((p) => p.stock > 0)
        .toList();

    final active = deliveries
        .where(
          (d) =>
              d.status == DeliveryStatus.inTransit ||
              d.status == DeliveryStatus.pending,
        )
        .toList();
    active.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning ☀️'
        : hour < 17
        ? 'Good Afternoon 🌤'
        : 'Good Evening 🌙';
    final firstName = user?.name.split(' ').first ?? 'Pilot';

    return Scaffold(
      backgroundColor: AppColors.base,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.base,
        onRefresh: () async {
          await ref
              .read(deliveryProvider.notifier)
              .loadDeliveriesFromSupabase();
          await ref.read(notificationProvider.notifier).loadNotifications();
          await ref.read(productProvider.notifier).loadProducts();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header — greeting, alerts, profile. Flat on the canvas so the
            // only things carrying depth are the two controls on the right.
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            greeting,
                            style: AppTextStyles.caption(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            firstName,
                            style: AppTextStyles.heading(fontSize: 22),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    NeuIconButton(
                      icon: Icons.notifications_none_rounded,
                      tooltip: 'Notifications',
                      badgeCount: unreadCount,
                      onPressed: () => context.push('/user/notifications'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    NeuPressable(
                      width: 44,
                      height: 44,
                      borderRadius: BorderRadius.circular(22),
                      color: AppColors.accent,
                      alignment: Alignment.center,
                      semanticLabel: 'Your profile',
                      onTap: () => context.go('/user/profile'),
                      child: Text(
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : 'P',
                        style: AppTextStyles.title(
                          fontSize: 16,
                          color: AppColors.bgDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Scrollable Body
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
                      // Quick Actions Grid (Moved to top)
                      const _QuickActions(),

                      const SizedBox(height: 28),

                      // Weekly Trend Sparkline (Glass Card)
                      // UCLM Flight Weather Advisories (Glass Card)
                      const AeroDropWeatherWidget(),

                      const SizedBox(height: 28),

                      // Featured Vendors Section
                      const SectionHeader(
                        title: 'Featured Vendors',
                        actionLabel: 'See All →',
                        onAction: null,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 110,
                        child: vendorState.isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.accent,
                                ),
                              )
                            : vendorState.errorMessage != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Unable to load vendors.',
                                      style: AppTextStyles.caption(
                                        fontSize: 12,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextButton(
                                      onPressed: () => ref
                                          .read(vendorProvider.notifier)
                                          .loadVendors(),
                                      child: Text(
                                        'Retry',
                                        style: AppTextStyles.caption(
                                          fontSize: 12,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : vendorState.vendors.isEmpty
                            ? Center(
                                child: Text(
                                  'No vendors are currently available.',
                                  style: AppTextStyles.caption(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: vendorState.vendors.length,
                                physics: const BouncingScrollPhysics(),
                                itemBuilder: (context, index) {
                                  final vendor = vendorState.vendors[index];
                                  return Container(
                                    width: 240,
                                    margin: const EdgeInsets.only(right: 14),
                                    child: NeuCard(
                                      onTap: () => context.push(
                                        '/user/vendors/${vendor.id}',
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      accent: vendor.logoColor.withValues(
                                        alpha: 0.4,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: vendor.logoColor,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              vendor.logoInitials,
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
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  vendor.businessName,
                                                  style: AppTextStyles.title(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  vendor.building
                                                      .split('–')
                                                      .first
                                                      .trim(),
                                                  style: AppTextStyles.body(
                                                    fontSize: 11,
                                                    color: AppColors
                                                        .textSecondaryDark,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.star_rounded,
                                                      color: AppColors.accent,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${vendor.rating}',
                                                      style:
                                                          AppTextStyles.label(
                                                            fontSize: 11,
                                                            color: AppColors
                                                                .textSecondary,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            letterSpacing: 0,
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
                                },
                              ),
                      ),

                      if (popularProducts.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const SectionHeader(
                          title: 'Popular Right Now',
                          actionLabel: 'Shop Menu →',
                          onAction: null,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 170,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: popularProducts.length,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              final product = popularProducts[index];
                              return Container(
                                width: 140,
                                margin: const EdgeInsets.only(right: 14),
                                child: NeuCard(
                                  onTap: () => context.push(
                                    '/user/products/${product.id}',
                                  ),
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(16),
                                                ),
                                            image: DecorationImage(
                                              image: NetworkImage(
                                                product.imageUrl,
                                              ),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.name,
                                              style: AppTextStyles.title(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              product.vendorName,
                                              style: AppTextStyles.label(
                                                fontSize: 9,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '₱${product.price.toStringAsFixed(2)}',
                                              style: AppTextStyles.label(
                                                fontSize: 11,
                                                color: AppColors.accent,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      // Active Delivery Section
                      if (active.isNotEmpty) ...[
                        SectionHeader(
                          title: 'Active Drone Delivery',
                          actionLabel: 'Track Live →',
                          onAction: () => context.go('/user/track'),
                        ),
                        const SizedBox(height: 12),
                        DeliveryCard(
                          delivery: active.first,
                          onTap: () => context.go('/user/track'),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Recent Orders Section with Alternating Cards
                      SectionHeader(
                        title: 'Recent Orders',
                        actionLabel: 'View All →',
                        onAction: () => context.go('/user/orders'),
                      ),
                      const SizedBox(height: 12),

                      if (deliveries.isEmpty)
                        NeuCard(
                          padding: const EdgeInsets.symmetric(
                            vertical: 36,
                            horizontal: 24,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                color: AppColors.textSecondary,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'You have no orders yet.',
                                style: AppTextStyles.subHead(
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Order delicious food & drinks above!',
                                style: AppTextStyles.body(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: List.generate(deliveries.take(3).length, (
                            index,
                          ) {
                            final delivery = deliveries[index];

                            // Alternate between gradient-rimmed AnimatedCard (via DeliveryCard)
                            // and a frosted NeuCard containing the delivery details.
                            if (index % 2 == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: DeliveryCard(
                                  delivery: delivery,
                                  onTap: () => context.push(
                                    '/user/track/details?id=${delivery.id}',
                                  ),
                                ),
                              );
                            } else {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: NeuCard(
                                  onTap: () => context.push(
                                    '/user/track/details?id=${delivery.id}',
                                  ),
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              delivery.id,
                                              style: AppTextStyles.label(
                                                fontSize: 11,
                                                color: AppColors.accentLight,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          StatusChip.delivery(
                                            delivery.status.name,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        delivery.packageName,
                                        style: AppTextStyles.title(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            delivery.packageType,
                                            style: AppTextStyles.body(
                                              fontSize: 12.5,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            '₱${(delivery.paymentAmount ?? 0).toStringAsFixed(2)}',
                                            style: AppTextStyles.body(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          }),
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

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  /// One action tile: a tinted inset icon well over a label.
  ///
  /// No accent rim here — four rimmed tiles side by side read as noise, and
  /// the icon colour already distinguishes them.
  Widget _buildActionCard(_QuickActionData a, {double margin = 0}) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: margin),
        child: NeuCard(
          onTap: a.onTap,
          semanticLabel: a.label,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NeuSurface(
                style: NeuStyle.inset,
                depth: NeuDepth.flat,
                width: 38,
                height: 38,
                alignment: Alignment.center,
                borderRadius: BorderRadius.circular(19),
                color: Color.alphaBlend(
                  a.color.withValues(alpha: 0.14),
                  AppColors.surfaceSunken,
                ),
                child: a.customIcon != null
                    ? SizedBox(height: 21, width: 21, child: a.customIcon!)
                    : Icon(a.icon, color: a.color, size: 20),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                a.label,
                style: AppTextStyles.label(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        customIcon: CustomPaint(
          size: const Size(22, 22),
          painter: DroneSvgPainter(
            animationValue: 0.0,
            lineColor: AppColors.accent,
            accentColor: AppColors.accent,
          ),
        ),
        label: 'Order Food',
        color: AppColors.accent,
        onTap: () => context.go('/user/shop'),
      ),
      _QuickActionData(
        icon: Icons.radar_rounded,
        label: 'Drone Radar',
        color: AppColors.primaryLight,
        onTap: () => context.go('/user/track'),
      ),
      _QuickActionData(
        icon: Icons.receipt_long_rounded,
        label: 'My Orders',
        color: AppColors.success,
        onTap: () => context.go('/user/orders'),
      ),
      _QuickActionData(
        icon: Icons.storefront_rounded,
        label: 'All Vendors',
        color: AppColors.info,
        onTap: () => context.go('/user/vendors'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick Actions', showAccentBar: true),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = (constraints.maxWidth - 24) / 4;
            final bool useTwoRows =
                cardWidth < 75; // if less than 75px, 4 in a row is too cramped

            if (useTwoRows) {
              return Column(
                children: [
                  Row(
                    children: [
                      _buildActionCard(actions[0]),
                      const SizedBox(width: 8),
                      _buildActionCard(actions[1]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildActionCard(actions[2]),
                      const SizedBox(width: 8),
                      _buildActionCard(actions[3]),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: actions
                  .map((a) => _buildActionCard(a, margin: 4))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionData {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _QuickActionData({
    this.icon,
    this.customIcon,
    required this.label,
    required this.color,
    required this.onTap,
  });
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
        iconColor = AppColors.primaryLight;
        break;
      case 'caution':
        status = 'CAUTION';
        statusColor = AppColors.warning;
        weatherIcon = Icons.air_rounded;
        iconColor = Colors.cyanAccent;
        break;
      default:
        status = 'SAFE';
        statusColor = AppColors.success;
        weatherIcon = Icons.wb_sunny_rounded;
        iconColor = AppColors.accent;
        break;
    }

    final tempStr = weather.temperature != null
        ? "${weather.temperature!.toStringAsFixed(1)}°C"
        : 'N/A';
    final windStr = weather.windSpeed != null
        ? "${weather.windSpeed!.toStringAsFixed(1)} km/h"
        : 'N/A';

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
                  Row(
                    children: [
                      Text(
                        'UCLM Campus Weather',
                        style: AppTextStyles.subHead(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showWeatherSimulationDialog(context, ref),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: AppColors.accent,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Drone dispatch environment conditions',
                    style: AppTextStyles.label(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
              child: Row(
                children: [
                  Icon(weatherIcon, color: iconColor, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tempStr,
                          style: AppTextStyles.display(
                            fontSize: 24,
                            color: AppColors.textPrimary,
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
            _WeatherMetric(
              icon: Icons.air_rounded,
              value: windStr,
              label: 'Wind Speed',
              iconColor: Colors.cyanAccent,
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

  void _showWeatherSimulationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        String? error;

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> selectStatus(String status) async {
              setState(() {
                isLoading = true;
                error = null;
              });

              try {
                final success = await ref
                    .read(weatherProvider.notifier)
                    .setSimulatedWeather(status);
                if (!success) {
                  throw Exception('Failed status update from provider.');
                }

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                if (context.mounted) {
                  final statusDisplay = status == 'safe'
                      ? 'Safe'
                      : (status == 'caution' ? 'Caution' : 'Grounded');
                  showNeuSnack(
                    context,
                    'Weather updated to $statusDisplay.',
                    tone: NeuToneKind.success,
                  );
                }
              } on PostgrestException catch (pe) {
                debugPrint('Weather simulation PostgrestException: $pe');
                setState(() {
                  isLoading = false;
                  error = 'Unable to update weather.';
                });
              } catch (e) {
                debugPrint('Weather simulation update failed: $e');
                setState(() {
                  isLoading = false;
                  error = 'Unable to update weather.';
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.base,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Change Campus Weather Simulation',
                style: AppTextStyles.subHead(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'This is an intentional prototype simulation feature.',
                    style: AppTextStyles.caption(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (error != null) ...[
                    Text(
                      error!,
                      style: AppTextStyles.caption(
                        fontSize: 12,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      ),
                    )
                  else ...[
                    _buildDialogOption(
                      title: 'Excellent (Clear & Safe)',
                      color: AppColors.success,
                      icon: Icons.wb_sunny_rounded,
                      onTap: () => selectStatus('safe'),
                    ),
                    const SizedBox(height: 10),
                    _buildDialogOption(
                      title: 'Caution (High Winds)',
                      color: AppColors.warning,
                      icon: Icons.air_rounded,
                      onTap: () => selectStatus('caution'),
                    ),
                    const SizedBox(height: 10),
                    _buildDialogOption(
                      title: 'Grounded (Heavy Rain/Storm)',
                      color: AppColors.danger,
                      icon: Icons.thunderstorm_rounded,
                      onTap: () => selectStatus('grounded'),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.body(color: Colors.grey),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogOption({
    required String title,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.subHead(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
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
            Text(
              value,
              style: AppTextStyles.title(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.label(
            fontSize: 9,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
