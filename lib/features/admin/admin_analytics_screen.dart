import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/analytics_card.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/providers/drone_provider.dart';
import '../../core/models/delivery_model.dart';
import '../../core/models/drone_model.dart';
import '../../core/services/supabase_service.dart';

class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen> {
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _suspendedUsers = 0;
  int _deletedUsers = 0;
  double _totalRevenue = 0.0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() => _loadingStats = true);
    try {
      if (SupabaseService.isConfigured) {
        // Fetch users standing
        final usersRes = await SupabaseService.client.from('users').select('account_status');
        final users = List<Map<String, dynamic>>.from(usersRes);
        int totalU = users.length;
        int activeU = users.where((u) => (u['account_status'] ?? 'active').toString().toLowerCase() == 'active').length;
        int suspendedU = users.where((u) => u['account_status']?.toString().toLowerCase() == 'suspended').length;
        int deletedU = users.where((u) => u['account_status']?.toString().toLowerCase() == 'deleted').length;

        // Fetch payments revenue
        final paymentsRes = await SupabaseService.client.from('payments').select('amount, status');
        final payments = List<Map<String, dynamic>>.from(paymentsRes);
        double revenue = payments
            .fold(0.0, (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0));

        if (mounted) {
          setState(() {
            _totalUsers = totalU;
            _activeUsers = activeU;
            _suspendedUsers = suspendedU;
            _deletedUsers = deletedU;
            _totalRevenue = revenue;
            _loadingStats = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _totalUsers = 12;
            _activeUsers = 10;
            _suspendedUsers = 1;
            _deletedUsers = 1;
            _totalRevenue = 450.0;
            _loadingStats = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching analytics stats: $e');
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    await ref.read(deliveryProvider.notifier).loadAdminDeliveriesFromSupabase();
    await ref.read(droneProvider.notifier).loadDronesFromSupabase();
    await _fetchStats();
  }

  double _calculateAverageFlightTimeMinutes(List<DeliveryModel> list) {
    final completed = list.where((d) => d.deliveryStartedAt != null && d.deliveredAt != null).toList();
    if (completed.isEmpty) return 0.0;
    final totalSecs = completed.fold(0, (sum, d) => sum + d.deliveredAt!.difference(d.deliveryStartedAt!).inSeconds);
    return (totalSecs / completed.length) / 60.0;
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = ref.watch(deliveryProvider);
    final drones = ref.watch(droneProvider);

    final drone001 = drones.firstWhere(
      (d) => d.id == 'DRN-001',
      orElse: () => DroneModel(
        id: 'DRN-001',
        name: 'AeroCarrier Alpha',
        batteryLevel: 100.0,
        status: DroneStatus.available,
        maxPayload: 0.5,
        modelType: '001',
        currentCoordinates: '10.3456,123.9478',
      ),
    );

    // Compute delivery counts
    int totalCount = deliveries.length;
    int inTransitCount = deliveries.where((d) => d.status == DeliveryStatus.inTransit).length;
    int deliveredCount = deliveries.where((d) => d.status == DeliveryStatus.delivered).length;
    
    double successRate = totalCount > 0 ? (deliveredCount / totalCount * 100) : 100.0;
    double avgFlightTime = _calculateAverageFlightTimeMinutes(deliveries);

    // Filter today's deliveries
    final now = DateTime.now();
    final todayDeliveries = deliveries.where((d) {
      return d.createdAt.year == now.year &&
          d.createdAt.month == now.month &&
          d.createdAt.day == now.day;
    }).length;

    // Get last 7 days daily dispatches
    final last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final barGroups = <BarChartGroupData>[];
    double maxBarValue = 5.0;
    for (int i = 0; i < 7; i++) {
      final day = last7Days[i];
      final count = deliveries.where((d) {
        return d.createdAt.year == day.year &&
            d.createdAt.month == day.month &&
            d.createdAt.day == day.day;
      }).length;
      if (count > maxBarValue) maxBarValue = count.toDouble();
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            gradient: AppColors.primaryGradient,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ));
    }

    // Package Type Breakdown percentages
    int totalPackageTypes = deliveries.length;
    int docCount = deliveries.where((d) => d.packageType.toLowerCase() == 'documents').length;
    int medCount = deliveries.where((d) => d.packageType.toLowerCase() == 'medicine').length;
    int elecCount = deliveries.where((d) => d.packageType.toLowerCase() == 'electronics').length;
    int otherCount = totalPackageTypes - (docCount + medCount + elecCount);

    int getPct(int count) {
      if (totalPackageTypes == 0) return 0;
      return ((count / totalPackageTypes) * 100).round();
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.accent,
        backgroundColor: AppColors.cardDark,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance Analytics',
                style: AppTextStyles.title(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ).animate().fadeIn(),
              Text(
                'Real-time system telemetry and dispatch metrics',
                style: AppTextStyles.body(fontSize: 13, color: AppColors.textSecondaryDark),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 24),

              // KPI Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  AnalyticsCard(
                    title: 'Total Deliveries',
                    value: '$totalCount',
                    change: 'Today: $todayDeliveries',
                    isPositive: true,
                    icon: Icons.local_shipping_rounded,
                    iconColor: AppColors.primary,
                    animDelay: 0,
                  ),
                  AnalyticsCard(
                    title: 'Success Rate',
                    value: '${successRate.toStringAsFixed(1)}%',
                    change: 'Delivered: $deliveredCount',
                    isPositive: true,
                    icon: Icons.verified_rounded,
                    iconColor: AppColors.success,
                    animDelay: 80,
                  ),
                  AnalyticsCard(
                    title: 'Avg Flight Time',
                    value: avgFlightTime > 0 ? '${avgFlightTime.toStringAsFixed(1)}m' : 'N/A',
                    change: 'In-transit: $inTransitCount',
                    isPositive: true,
                    icon: Icons.timer_rounded,
                    iconColor: AppColors.secondary,
                    animDelay: 160,
                  ),
                  AnalyticsCard(
                    title: 'Total Revenue',
                    value: '₱${_totalRevenue.toStringAsFixed(2)}',
                    change: _loadingStats ? 'Loading...' : 'Simulated payments',
                    isPositive: true,
                    icon: Icons.monetization_on_rounded,
                    iconColor: AppColors.accent,
                    animDelay: 240,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Bar Chart - daily dispatches
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Dispatch Volume',
                      style: AppTextStyles.title(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Packages dispatched per day (last 7 days)',
                      style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 160,
                      child: BarChart(
                        BarChartData(
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) {
                                  final index = v.toInt();
                                  if (index >= 0 && index < 7) {
                                    final day = last7Days[index];
                                    final label = '${day.month}/${day.day}';
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          color: AppColors.textSecondaryDark,
                                          fontSize: 9,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                                reservedSize: 28,
                              ),
                            ),
                          ),
                          barGroups: barGroups,
                          maxY: maxBarValue + 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.1),

              const SizedBox(height: 20),

              // Package type breakdown
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Package Type Breakdown',
                      style: AppTextStyles.title(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _breakdown('Documents', getPct(docCount), AppColors.primary),
                    _breakdown('Medicine', getPct(medCount), AppColors.success),
                    _breakdown('Electronics', getPct(elecCount), AppColors.secondary),
                    _breakdown('Others', getPct(otherCount), AppColors.warning),
                  ],
                ),
              ).animate(delay: 420.ms).fadeIn().slideY(begin: 0.1),

              const SizedBox(height: 20),

              // User accounts standings
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Standings & Access',
                      style: AppTextStyles.title(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _userStandingRow('Total Registered Users', _totalUsers, AppColors.primary),
                    const Divider(color: AppColors.borderDark, height: 16),
                    _userStandingRow('Active Users', _activeUsers, AppColors.success),
                    const Divider(color: AppColors.borderDark, height: 16),
                    _userStandingRow('Suspended Accounts', _suspendedUsers, AppColors.warning),
                    const Divider(color: AppColors.borderDark, height: 16),
                    _userStandingRow('Soft Deleted Accounts', _deletedUsers, AppColors.danger),
                  ],
                ),
              ).animate(delay: 480.ms).fadeIn().slideY(begin: 0.1),

              const SizedBox(height: 20),

              // Top Drones/Drone Status
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Primary Fleet Registry',
                      style: AppTextStyles.title(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _droneRow(
                      rank: '#1',
                      name: drone001.name,
                      trips: '$deliveredCount delivered dispatches',
                      battery: '${drone001.batteryLevel.toStringAsFixed(0)}% battery',
                      status: drone001.status.name.toUpperCase(),
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ).animate(delay: 520.ms).fadeIn().slideY(begin: 0.1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userStandingRow(String label, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(
          '$count',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _breakdown(String label, int pct, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(
                '$pct%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _droneRow({
    required String rank,
    required String name,
    required String trips,
    required String battery,
    required String status,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            rank,
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 11),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTextStyles.title(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                trips,
                style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark),
              ),
              const SizedBox(height: 2),
              Text(
                battery,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: drone001BatteryColor(battery),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: status == 'AVAILABLE'
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: status == 'AVAILABLE' ? AppColors.success : AppColors.warning,
            ),
          ),
        ),
      ],
    );
  }

  Color drone001BatteryColor(String text) {
    if (text.contains('10%') || text.contains('9%') || text.contains('8%') || text.contains('7%') || text.contains('6%') || text.contains('5%') || text.contains('4%') || text.contains('3%') || text.contains('2%') || text.contains('1%') || text.contains('0%')) {
      return AppColors.danger;
    }
    return AppColors.success;
  }
}