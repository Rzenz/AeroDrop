import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/staggered_list.dart';

class TrackingDetailsPage extends StatelessWidget {
  final String deliveryId;
  const TrackingDetailsPage({super.key, required this.deliveryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: const CustomAppBar(title: 'Tracking Telemetry'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F243A), AppColors.bgDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StaggeredColumn(
                delayMs: 60,
                children: [
                  const SizedBox(height: 12),

                  // ETA Card
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    borderGradient: const LinearGradient(
                      colors: [AppColors.primary, Colors.transparent],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.timer_rounded, color: AppColors.primaryLight, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estimated Arrival Time',
                                style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '8 minutes remaining',
                                style: AppTextStyles.title(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Drone info
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    borderGradient: const LinearGradient(
                      colors: [AppColors.accent, Colors.transparent],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assigned Hardware',
                          style: AppTextStyles.title(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.accent),
                        ),
                        const Divider(color: AppColors.borderDark, height: 24),
                        _rowDetail(Icons.airplay_rounded, 'Drone ID', 'DRN-001 (AeroCarrier)'),
                        _rowDetail(Icons.battery_charging_full_rounded, 'Hardware Battery', '85% Operational'),
                        _rowDetail(Icons.speed_rounded, 'Flight Speed', '12.4 m/s'),
                        _rowDetail(Icons.height_rounded, 'Flight Altitude', '34.2 m'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pilot info
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    borderGradient: const LinearGradient(
                      colors: [AppColors.primary, Colors.transparent],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilot Telemetry Logs',
                          style: AppTextStyles.title(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                        ),
                        const Divider(color: AppColors.borderDark, height: 24),
                        _rowDetail(Icons.shield_rounded, 'System Mode', 'UCLM Autonomous Autopilot Core'),
                        _rowDetail(Icons.wifi_rounded, 'Signal Connection', 'Excellent RSSI (-45dB)'),
                        _rowDetail(Icons.compass_calibration_rounded, 'Telemetry Lock', '3D GPS Fix Locked'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Route details
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    borderGradient: const LinearGradient(
                      colors: [Colors.white12, Colors.transparent],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route Tracking',
                          style: AppTextStyles.title(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        const Divider(color: AppColors.borderDark, height: 24),
                        _rowDetail(Icons.my_location_rounded, 'Origin', 'UCLM Science Lab Ground Hub'),
                        _rowDetail(Icons.flag_rounded, 'Destination', 'Engineering Hub Room 204'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondaryDark, size: 18),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.body(fontSize: 13, color: AppColors.textSecondaryDark)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: AppTextStyles.title(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
