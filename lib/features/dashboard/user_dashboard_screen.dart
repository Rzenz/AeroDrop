import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/delivery_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/staggered_list.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/delivery_model.dart';

class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final deliveries = ref.watch(deliveryProvider);

    final active = deliveries.where((d) => d.status == DeliveryStatus.inTransit).toList();

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning ☀️'
        : hour < 17
            ? 'Good Afternoon 🌤'
            : 'Good Evening 🌙';
    final firstName = user?.name.split(' ').first ?? 'Pilot';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
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
                          children: [
                            const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
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

                    // Active Delivery Section
                    if (active.isNotEmpty) ...[
                      SectionHeader(
                        title: 'Active Delivery',
                        actionLabel: 'Track Live →',
                        onAction: () => context.go('/user/track'),
                      ),
                      const SizedBox(height: 12),
                      DeliveryCard(
                        delivery: active.first,
                        onTap: () => context.go('/user/track'),
                      ),
                      const SizedBox(height: 24),
                    ],



                    // Recent Deliveries Section with Alternating Cards
                    SectionHeader(
                      title: 'Recent Deliveries',
                      actionLabel: 'View All →',
                      onAction: () => context.go('/user/history'),
                    ),
                    const SizedBox(height: 12),

                    if (deliveries.isEmpty)
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.textSecondaryDark,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No deliveries yet',
                              style: AppTextStyles.subHead(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap the + button to dispatch a drone.',
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
                          deliveries.take(4).length,
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
                                          Text(
                                            delivery.id,
                                            style: AppTextStyles.label(
                                              fontSize: 11,
                                              color: AppColors.accentLight,
                                            ),
                                          ),
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
                                            '${delivery.packageWeight} kg',
                                            style: AppTextStyles.body(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textSecondaryDark,
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
        Icons.local_shipping_rounded,
        'New Request',
        AppColors.accent,
        () => context.push('/user/request'),
      ),
      _QuickActionData(
        Icons.radar_rounded,
        'Radar Track',
        AppColors.primaryLight,
        () => context.go('/user/track'),
      ),
      _QuickActionData(
        Icons.history_rounded,
        'History Log',
        AppColors.success,
        () => context.go('/user/history'),
      ),
      _QuickActionData(
        Icons.help_outline_rounded,
        'Support Help',
        AppColors.textSecondaryDark,
        () => context.push('/shared/help'),
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
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _QuickActionData(this.icon, this.label, this.color, this.onTap);
}

class AeroDropWeatherWidget extends StatefulWidget {
  const AeroDropWeatherWidget({super.key});

  @override
  State<AeroDropWeatherWidget> createState() => _AeroDropWeatherWidgetState();
}

class _AeroDropWeatherWidgetState extends State<AeroDropWeatherWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _refreshController;
  bool _isLoading = false;

  // Initial Weather States
  String _condition = 'Clear Skies';
  double _temp = 30.2;
  double _windSpeed = 11.4;
  double _humidity = 62.0;
  String _status = 'EXCELLENT';
  Color _statusColor = AppColors.success;
  IconData _weatherIcon = Icons.wb_sunny_rounded;
  Color _iconColor = AppColors.accent;

  final List<Map<String, dynamic>> _conditions = [
    {
      'condition': 'Clear Skies',
      'tempRange': [29.0, 34.0],
      'windRange': [5.0, 12.0],
      'humidityRange': [45.0, 60.0],
      'status': 'EXCELLENT',
      'statusColor': AppColors.success,
      'icon': Icons.wb_sunny_rounded,
      'iconColor': AppColors.accent,
    },
    {
      'condition': 'Partly Cloudy',
      'tempRange': [26.0, 29.5],
      'windRange': [9.0, 16.0],
      'humidityRange': [60.0, 72.0],
      'status': 'SAFE',
      'statusColor': AppColors.success,
      'icon': Icons.cloud_rounded,
      'iconColor': AppColors.primaryLight,
    },
    {
      'condition': 'High Winds',
      'tempRange': [25.0, 27.8],
      'windRange': [25.0, 36.0],
      'humidityRange': [55.0, 68.0],
      'status': 'CAUTION',
      'statusColor': AppColors.warning,
      'icon': Icons.air_rounded,
      'iconColor': Colors.cyanAccent,
    },
    {
      'condition': 'Heavy Rain',
      'tempRange': [22.5, 25.0],
      'windRange': [18.0, 28.0],
      'humidityRange': [85.0, 96.0],
      'status': 'GROUNDED',
      'statusColor': AppColors.danger,
      'icon': Icons.thunderstorm_rounded,
      'iconColor': AppColors.primaryLight,
    }
  ];

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  void _refreshWeather() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    _refreshController.repeat();

    // Simulate network/telemetry fetch delay
    await Future.delayed(const Duration(milliseconds: 700));

    final random = math.Random();
    // Ensure we pick a different condition than the current one
    final currentIdx = _conditions.indexWhere((c) => c['condition'] == _condition);
    int nextIdx;
    do {
      nextIdx = random.nextInt(_conditions.length);
    } while (nextIdx == currentIdx && _conditions.length > 1);

    final selected = _conditions[nextIdx];

    final double minTemp = selected['tempRange'][0];
    final double maxTemp = selected['tempRange'][1];
    final double minWind = selected['windRange'][0];
    final double maxWind = selected['windRange'][1];
    final double minHum = selected['humidityRange'][0];
    final double maxHum = selected['humidityRange'][1];

    if (mounted) {
      setState(() {
        _condition = selected['condition'];
        _temp = minTemp + random.nextDouble() * (maxTemp - minTemp);
        _windSpeed = minWind + random.nextDouble() * (maxWind - minWind);
        _humidity = minHum + random.nextDouble() * (maxHum - minHum);
        _status = selected['status'];
        _statusColor = selected['statusColor'];
        _weatherIcon = selected['icon'];
        _iconColor = selected['iconColor'];
        _isLoading = false;
      });
      _refreshController.stop();
      _refreshController.reset();
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderGradient: const LinearGradient(
        colors: [AppColors.primary, Colors.transparent],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row (Wrap left Column in Expanded to prevent right overflow)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UCLM Campus Weather',
                      style: AppTextStyles.subHead(fontSize: 15, color: Colors.white),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _statusColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _status,
                      style: AppTextStyles.body(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Refresh Button
                  RotationTransition(
                    turns: _refreshController,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _refreshWeather,
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Weather Info Row
          Row(
            children: [
              // Weather Icon + Temp (Wrapped in Expanded/Flexible to prevent overflow)
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _weatherIcon,
                      color: _iconColor,
                      size: 38,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_temp.toStringAsFixed(1)}°C',
                            style: AppTextStyles.display(
                              fontSize: 24,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _condition,
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
              // Telemetry stats vertical divider
              Container(
                height: 40,
                width: 1.5,
                color: AppColors.borderDark,
              ),
              const SizedBox(width: 16),
              // Right block: Metrics stacked vertically to prevent horizontal overflow
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WeatherMetric(
                    icon: Icons.air_rounded,
                    value: '${_windSpeed.toStringAsFixed(1)} km/h',
                    label: 'Wind Speed',
                    iconColor: Colors.cyanAccent,
                  ),
                  const SizedBox(height: 8),
                  _WeatherMetric(
                    icon: Icons.water_drop_rounded,
                    value: '${_humidity.toStringAsFixed(0)}%',
                    label: 'Humidity',
                    iconColor: AppColors.info,
                  ),
                ],
              ),
            ],
          ),        ],
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
