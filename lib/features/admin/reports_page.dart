import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/drone_svg_painter.dart';
import '../../core/widgets/neu_back_button.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/services/supabase_service.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/models/delivery_model.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  List<Map<String, dynamic>> _droneLogs = [];
  List<Map<String, dynamic>> _userLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchSystemLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSystemLogs() async {
    if (!SupabaseService.isConfigured) return;
    setState(() => _loading = true);
    try {
      // 1. Fetch Drone Safety Logs
      try {
        final checks = await SupabaseService.client
            .from('delivery_safety_checks')
            .select()
            .order('checked_at', ascending: false)
            .limit(10);
        _droneLogs = List<Map<String, dynamic>>.from(checks);
      } catch (_) {
        _droneLogs = [];
      }

      // 2. Fetch User audit logs / recent registrations
      try {
        final users = await SupabaseService.client
            .from('users')
            .select('id, full_name, email, role, created_at, account_status')
            .order('created_at', ascending: false)
            .limit(10);
        _userLogs = List<Map<String, dynamic>>.from(users);
      } catch (_) {
        _userLogs = [];
      }
    } catch (e) {
      debugPrint('Error loading system diagnostics logs: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatRelativeTime(DateTime? date) {
    if (date == null) return '—';
    final diff = DateTime.now().toUtc().difference(date.toUtc());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header app bar
                Row(
                  children: [
                    const NeuBackButton(
                      fallbackRoute: '/admin',
                      color: AppColors.cardDark,
                      iconColor: Colors.white,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'System Diagnostics & Logs',
                      style: AppTextStyles.title(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 24),

                // Segmented Tab bar indicator
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.transparent,
                    dividerColor: Colors.transparent,
                    labelColor: AppColors.bgDark,
                    unselectedLabelColor: Colors.white60,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tabs: const [
                      Tab(text: 'Deliveries'),
                      Tab(text: 'Fleet Telemetry'),
                      Tab(text: 'User Activity'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tab views
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildDeliveriesTab(),
                            _buildDroneTelemetryTab(),
                            _buildUserActivityTab(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveriesTab() {
    final deliveries = ref.watch(deliveryProvider);
    if (deliveries.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.local_shipping_outlined,
        title: 'No Delivery Logs',
        subtitle: 'Delivery records and logs will appear here once dispatched.',
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.cardDark,
      onRefresh: () => ref
          .read(deliveryProvider.notifier)
          .loadAdminDeliveriesFromSupabase(),
      child: ListView.builder(
        itemCount: deliveries.length,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemBuilder: (context, idx) {
          final delivery = deliveries[idx];
          final isDelivered = delivery.status == DeliveryStatus.delivered;
          final statusLabel = delivery.status.name.toUpperCase();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isDelivered
                              ? AppColors.success
                              : AppColors.primary)
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: isDelivered
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CustomPaint(
                              size: const Size(20, 20),
                              painter: DroneSvgPainter(
                                animationValue: 0.0,
                                lineColor: AppColors.success,
                                accentColor: const Color(0xFF4F46E5),
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.flight_takeoff_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery #${delivery.id.substring(0, delivery.id.length > 8 ? 8 : delivery.id.length)}',
                          style: AppTextStyles.title(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Target: ${delivery.dropoffLocationName} • Drone: ${delivery.droneId ?? "—"}',
                          style: TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusChip(
                        label: statusLabel,
                        color: isDelivered
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatRelativeTime(delivery.createdAt),
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDroneTelemetryTab() {
    if (_droneLogs.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.sensors_off_rounded,
        title: 'No Telemetry Logs',
        subtitle: 'Safety checks and telemetry diagnostic logs are clear.',
      );
    }

    return ListView.builder(
      itemCount: _droneLogs.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, idx) {
        final log = _droneLogs[idx];
        final passed = log['passed'] == true;
        final checkType = log['check_type']?.toString() ?? 'Safety Check';
        final details = log['notes']?.toString() ?? 'Routine check passed';
        final recordedAt = log['checked_at'] != null
            ? DateTime.tryParse(log['checked_at'].toString())
            : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (passed ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    passed ? 'PASS' : 'WARN',
                    style: TextStyle(
                      color: passed ? AppColors.success : AppColors.warning,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$checkType: $details',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatRelativeTime(recordedAt),
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 9,
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
    );
  }

  Widget _buildUserActivityTab() {
    if (_userLogs.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history_rounded,
        title: 'No User Activity',
        subtitle: 'User registrations and activity will appear here.',
      );
    }

    return ListView.builder(
      itemCount: _userLogs.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, idx) {
        final user = _userLogs[idx];
        final name = user['full_name']?.toString() ??
            user['email']?.toString() ??
            'User';
        final role = user['role']?.toString().toUpperCase() ?? 'USER';
        final createdAt = user['created_at'] != null
            ? DateTime.tryParse(user['created_at'].toString())
            : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name registered as $role',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${user['account_status'] ?? "active"} • ${_formatRelativeTime(createdAt)}',
                        style: TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 10,
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
    );
  }
}
