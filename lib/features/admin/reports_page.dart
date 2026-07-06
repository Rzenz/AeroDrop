import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/drone_svg_painter.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, String>> _deliveryLogs = [
    {'id': '#1004', 'time': '10 Mins Ago', 'target': 'Gymnasium Dome', 'weight': '0.45kg', 'drone': 'DRN-001', 'status': 'Delivered'},
    {'id': '#1003', 'time': '1 Hour Ago', 'target': 'Canteen Courtyard', 'weight': '0.22kg', 'drone': 'DRN-001', 'status': 'Delivered'},
    {'id': '#1002', 'time': '3 Hours Ago', 'target': 'Library Wing', 'weight': '0.80kg', 'drone': 'DRN-001', 'status': 'Returned'},
    {'id': '#1001', 'time': 'Yesterday', 'target': 'Science Lab', 'weight': '0.50kg', 'drone': 'DRN-001', 'status': 'Delivered'},
  ];

  final List<Map<String, String>> _droneLogs = [
    {'event': 'Drone DRN-001 compass & IMU calibration success.', 'time': '5 Mins Ago', 'level': 'INFO'},
    {'event': 'Recharge queue: DRN-001 battery restored to 100%.', 'time': '20 Mins Ago', 'level': 'SUCCESS'},
    {'event': 'Low battery alert: DRN-001 capacity dropped to 9%.', 'time': '40 Mins Ago', 'level': 'WARNING'},
    {'event': 'Takeoff check: cargo clamp safety lock engaged.', 'time': '2 Hours Ago', 'level': 'INFO'},
  ];

  final List<Map<String, String>> _userLogs = [
    {'action': 'Merchant "Sweet Escape Delights" approved.', 'time': '15 Mins Ago', 'user': 'Admin'},
    {'action': 'User account "John Doe" suspended (Policy).', 'time': '2 Hours Ago', 'user': 'Admin'},
    {'action': 'Store onboarding requested: "Quick Byte Canteen".', 'time': '3 Hours Ago', 'user': 'System'},
    {'action': 'Admin account sign-in verified.', 'time': 'Yesterday', 'user': 'Admin.Portal'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'System Diagnostics & Logs',
                      style: AppTextStyles.title(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
                  child: TabBarView(
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
    return ListView.builder(
      itemCount: _deliveryLogs.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, idx) {
        final log = _deliveryLogs[idx];
        final status = log['status']!;
        final isSuccess = status == 'Delivered';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isSuccess ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: isSuccess
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
                          Icons.assignment_return_rounded,
                          color: AppColors.danger,
                          size: 20,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order ${log['id']!} • ${log['weight']!}', style: AppTextStyles.title(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Target: ${log['target']!} • Drone: ${log['drone']!}', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusChip(
                      label: status.toUpperCase(),
                      color: isSuccess ? AppColors.success : AppColors.danger,
                    ),
                    const SizedBox(height: 4),
                    Text(log['time']!, style: const TextStyle(color: Colors.white30, fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDroneTelemetryTab() {
    return ListView.builder(
      itemCount: _droneLogs.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, idx) {
        final log = _droneLogs[idx];
        final level = log['level']!;
        Color levelColor = AppColors.primary;
        if (level == 'WARNING') levelColor = AppColors.warning;
        if (level == 'SUCCESS') levelColor = AppColors.success;

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
                    color: levelColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    level,
                    style: TextStyle(color: levelColor, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log['event']!, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3)),
                      const SizedBox(height: 4),
                      Text(log['time']!, style: const TextStyle(color: Colors.white30, fontSize: 9)),
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
    return ListView.builder(
      itemCount: _userLogs.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, idx) {
        final log = _userLogs[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.history_toggle_off_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log['action']!, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('By: ${log['user']!} • ${log['time']!}', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 10)),
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
