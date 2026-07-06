import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
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
import '../../core/widgets/aerodrop_warning_dialog.dart';
import '../../core/theme/app_theme.dart';
import '../../mock_data/vendors_mock.dart';
import '../../mock_data/products_mock.dart';

class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final deliveries = ref.watch(deliveryProvider);
    final notifications = ref.watch(notificationProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;

    final active = deliveries.where((d) => d.status == DeliveryStatus.inTransit || d.status == DeliveryStatus.pending).toList();
    active.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning ☀️'
        : hour < 17
            ? 'Good Afternoon 🌤'
            : 'Good Evening 🌙';
    final firstName = user?.name.split(' ').first ?? 'Pilot';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.cardDark,
        onRefresh: () async {
          await ref.read(deliveryProvider.notifier).loadDeliveriesFromSupabase();
          await ref.read(notificationProvider.notifier).loadNotifications();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          // Sticky SliverAppBar
          SliverAppBar(
            expandedHeight: 110,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.bgDark,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1565C0), AppColors.bgDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        greeting,
                        style: AppTextStyles.label(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        firstName,
                        style: AppTextStyles.title(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.push('/user/notifications'),
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
                            if (unreadCount > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 14,
                                    minHeight: 14,
                                  ),
                                  child: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: AppColors.bgDark,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.accent,
                        child: Text(
                          firstName.isNotEmpty ? firstName[0] : 'P',
                          style: AppTextStyles.title(
                            fontSize: 12,
                            color: AppColors.bgDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Scrollable Body
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                StaggeredColumn(
                  delayMs: 50,
                  children: [
                    // Quick Actions Grid (Moved to top)
                    _QuickActions(),

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
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: mockVendors.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final vendor = mockVendors[index];
                          return Container(
                            width: 240,
                            margin: const EdgeInsets.only(right: 14),
                            child: GlassCard(
                              onTap: () => context.push('/user/vendors/${vendor.id}'),
                              padding: const EdgeInsets.all(12),
                              borderGradient: LinearGradient(
                                colors: [vendor.logoColor.withValues(alpha: 0.4), Colors.white12],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: vendor.logoColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      vendor.logoInitials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
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
                                          style: AppTextStyles.title(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          vendor.building.split('–').first.trim(),
                                          style: AppTextStyles.body(
                                            fontSize: 11,
                                            color: AppColors.textSecondaryDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.star_rounded, color: AppColors.accent, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${vendor.rating}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
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

                    const SizedBox(height: 28),

                    // Popular Items Section
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
                        itemCount: mockProducts.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final product = mockProducts[index];
                          return Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 14),
                            child: GlassCard(
                              onTap: () => context.push('/user/products/${product.id}'),
                              padding: EdgeInsets.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Image with network image loaded beautifully or fallback to colored container
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                        image: DecorationImage(
                                          image: NetworkImage(product.imageUrl),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: AppTextStyles.title(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          product.vendorName,
                                          style: AppTextStyles.label(
                                            fontSize: 9,
                                            color: AppColors.textSecondaryDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₱${product.price.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
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
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.shopping_bag_outlined,
                              color: AppColors.textSecondaryDark,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No orders placed yet',
                              style: AppTextStyles.subHead(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Order delicious food & drinks above!',
                              style: AppTextStyles.body(
                                fontSize: 13,
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: List.generate(
                          deliveries.take(3).length,
                          (index) {
                            final delivery = deliveries[index];

                            // Alternate between gradient-rimmed AnimatedCard (via DeliveryCard)
                            // and a frosted GlassCard containing the delivery details.
                            if (index % 2 == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: DeliveryCard(
                                  delivery: delivery,
                                  onTap: () => context.push('/user/track/details?id=${delivery.id}'),
                                ),
                              );
                            } else {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GlassCard(
                                  onTap: () => context.push('/user/track/details?id=${delivery.id}'),
                                  padding: const EdgeInsets.all(18),
                                  borderGradient: const LinearGradient(
                                    colors: [Colors.white24, Colors.white12],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                          StatusChip.delivery(delivery.status.name),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        delivery.packageName,
                                        style: AppTextStyles.title(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            delivery.packageType,
                                            style: AppTextStyles.body(
                                              fontSize: 12.5,
                                              color: AppColors.textSecondaryDark,
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
                          },
                        ),
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
  Widget _buildActionCard(_QuickActionData a, {double margin = 0}) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: margin),
        child: GlassCard(
          onTap: a.onTap,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          borderGradient: LinearGradient(
            colors: [a.color.withValues(alpha: 0.3), Colors.transparent],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (a.customIcon != null)
                SizedBox(
                  height: 22,
                  width: 22,
                  child: a.customIcon!,
                )
              else if (a.icon != null)
                Icon(a.icon, color: a.color, size: 22),
              const SizedBox(height: 6),
              Text(
                a.label,
                style: AppTextStyles.label(
                  fontSize: 9.5,
                  color: AppColors.textSecondaryDark,
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
            accentColor: const Color(0xFF4F46E5),
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
            final bool useTwoRows = cardWidth < 75; // if less than 75px, 4 in a row is too cramped
            
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
              children: actions.map((a) => _buildActionCard(a, margin: 4)).toList(),
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

class AeroDropWeatherWidget extends ConsumerStatefulWidget {
  const AeroDropWeatherWidget({super.key});

  @override
  ConsumerState<AeroDropWeatherWidget> createState() =>
      _AeroDropWeatherWidgetState();
}

class _AeroDropWeatherWidgetState
    extends ConsumerState<AeroDropWeatherWidget> {

  void _showWeatherSelectDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.isDarkMode ? AppColors.cardDark : AppColors.cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Change Campus Weather Simulation',
          style: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white : AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.wb_sunny_rounded, color: AppColors.accent),
              title: Text('Excellent (Clear & Safe)',
                  style: TextStyle(
                    color: AppTheme.isDarkMode ? Colors.white : AppColors.textPrimaryLight,
                  )),
              onTap: () async {
                Navigator.of(dialogContext).pop();
                await _applyWeather('safe');
              },
            ),
            ListTile(
              leading: const Icon(Icons.air_rounded, color: AppColors.warning),
              title: Text('Caution (High Winds)',
                  style: TextStyle(
                    color: AppTheme.isDarkMode ? Colors.white : AppColors.textPrimaryLight,
                  )),
              onTap: () async {
                Navigator.of(dialogContext).pop();
                await _applyWeather('caution');
              },
            ),
            ListTile(
              leading: const Icon(Icons.thunderstorm_rounded, color: AppColors.danger),
              title: Text('Grounded (Heavy Rain/Storm)',
                  style: TextStyle(
                    color: AppTheme.isDarkMode ? Colors.white : AppColors.textPrimaryLight,
                  )),
              onTap: () async {
                Navigator.of(dialogContext).pop();
                await _applyWeather('grounded');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyWeather(String statusKey) async {
    final error =
        await ref.read(weatherProvider.notifier).updateWeatherStatus(statusKey);

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    switch (statusKey) {
      case 'safe':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weather updated to Safe.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      case 'caution':
        showAeroDropWarningDialog(
          context: context,
          title: 'Caution Weather',
          message:
              'Delivery may be delayed due to caution-level weather conditions.',
          icon: Icons.air_rounded,
          iconColor: AppColors.warning,
          centerIcon: Icons.flight_rounded,
          centerIconColor: AppColors.warning,
        );
      case 'grounded':
        showAeroDropWarningDialog(
          context: context,
          title: 'Drone Delivery Grounded',
          message:
              'Weather is currently unsafe for drone delivery. New delivery requests will be automatically cancelled.',
          icon: Icons.thunderstorm_rounded,
          iconColor: AppColors.danger,
          centerIcon: Icons.flight_land_rounded,
          centerIconColor: AppColors.danger,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = ref.watch(weatherProvider);

    // Map WeatherStatus → display values
    final String status;
    final Color statusColor;
    final IconData weatherIcon;
    final Color iconColor;
    final String condition;
    switch (weather.status) {
      case WeatherStatus.grounded:
        status = 'GROUNDED';
        statusColor = AppColors.danger;
        weatherIcon = Icons.thunderstorm_rounded;
        iconColor = AppColors.primaryLight;
        condition = 'Heavy Rain';
      case WeatherStatus.caution:
        status = 'CAUTION';
        statusColor = AppColors.warning;
        weatherIcon = Icons.air_rounded;
        iconColor = Colors.cyanAccent;
        condition = 'High Winds';
      case WeatherStatus.safe:
        status = 'EXCELLENT';
        statusColor = AppColors.success;
        weatherIcon = Icons.wb_sunny_rounded;
        iconColor = AppColors.accent;
        condition = 'Clear Skies';
    }

    return GlassCard(
      borderGradient: LinearGradient(
        colors: [
          const Color(0xFF1A2B45).withValues(alpha: 0.85),
          const Color(0xFF0F243A).withValues(alpha: 0.9),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
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
                          fontSize: 15, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Drone dispatch environment conditions',
                      style: AppTextStyles.label(
                        fontSize: 10,
                        color: AppColors.textSecondaryDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status chip — tapping opens selector
              GestureDetector(
                onTap: weather.isLoading ? null : _showWeatherSelectDialog,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      weather.isLoading
                          ? SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: statusColor,
                              ),
                            )
                          : Text(
                              status,
                              style: AppTextStyles.body(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_location_outlined,
                          size: 10, color: statusColor),
                    ],
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
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            switch (weather.weatherStatus) {
                              'grounded' => '22.0°C',
                              'caution' => '32.0°C',
                              _ => '30.0°C',
                            },
                            style: AppTextStyles.display(
                              fontSize: 24,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            condition,
                            style: AppTextStyles.body(
                              fontSize: 12,
                              color: AppColors.textSecondaryDark,
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
              Container(
                height: 40,
                width: 1.5,
                color: AppColors.borderDark,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WeatherMetric(
                    icon: Icons.air_rounded,
                    value: switch (weather.weatherStatus) {
                      'grounded' => '40.0 km/h',
                      'caution' => '28.0 km/h',
                      _ => '10.0 km/h',
                    },
                    label: 'Wind Speed',
                    iconColor: Colors.cyanAccent,
                  ),
                  const SizedBox(height: 8),
                  _WeatherMetric(
                    icon: Icons.water_drop_rounded,
                    value: '62%',
                    label: 'Humidity',
                    iconColor: AppColors.info,
                  ),
                ],
              ),
            ],
          ),
        ],
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
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.label(
            fontSize: 9,
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }
}
