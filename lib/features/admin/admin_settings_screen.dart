import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _liveTracking = true;
  bool _autoAssign = true;
  bool _weatherAlerts = true;
  bool _maintenanceAlerts = false;
  bool _lowBatteryAlerts = true;
  double _maxPayloadLimit = 10.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Title
            Text(
              'System Settings',
              style: AppTextStyles.title(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Text(
              'Configure global parameters and fleet defaults',
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader('Fleet Operations'),
            _buildSwitchTile(
              'Live Drone Telemetry',
              'Enable real-time position tracking for all drones.',
              _liveTracking,
              (val) => setState(() => _liveTracking = val),
              Icons.sensors_rounded,
              AppColors.primary,
            ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05),
            
            _buildSwitchTile(
              'Auto-Assign Drones',
              'Automatically dispatch available drones to pending deliveries.',
              _autoAssign,
              (val) => setState(() => _autoAssign = val),
              Icons.autorenew_rounded,
              AppColors.secondary,
            ).animate(delay: 180.ms).fadeIn().slideY(begin: 0.05),

            const SizedBox(height: 24),
            _buildSectionHeader('Notifications & Alerts'),
            _buildSwitchTile(
              'Weather Flight Alerts',
              'Pause deliveries and alert admin when weather is unsafe.',
              _weatherAlerts,
              (val) => setState(() => _weatherAlerts = val),
              Icons.wb_cloudy_rounded,
              AppColors.info,
            ).animate(delay: 260.ms).fadeIn().slideY(begin: 0.05),

            _buildSwitchTile(
              'Maintenance Reminders',
              'Get notified when a drone reaches its service interval.',
              _maintenanceAlerts,
              (val) => setState(() => _maintenanceAlerts = val),
              Icons.build_circle_rounded,
              AppColors.warning,
            ).animate(delay: 340.ms).fadeIn().slideY(begin: 0.05),

            _buildSwitchTile(
              'Low Battery Warnings',
              'Alert when a drone battery drops below 20%.',
              _lowBatteryAlerts,
              (val) => setState(() => _lowBatteryAlerts = val),
              Icons.battery_alert_rounded,
              AppColors.danger,
            ).animate(delay: 420.ms).fadeIn().slideY(begin: 0.05),

            const SizedBox(height: 24),
            _buildSectionHeader('Delivery Limits'),
            GlassCard(
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.scale_rounded, color: AppColors.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Global Max Payload',
                            style: AppTextStyles.title(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_maxPayloadLimit.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'System-wide maximum package weight per delivery.',
                    style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark),
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.borderDark,
                      thumbColor: AppColors.secondary,
                      overlayColor: AppColors.secondary.withValues(alpha: 0.12),
                      valueIndicatorColor: AppColors.primary,
                    ),
                    child: Slider(
                      value: _maxPayloadLimit,
                      min: 1,
                      max: 20,
                      divisions: 19,
                      onChanged: (val) => setState(() => _maxPayloadLimit = val),
                    ),
                  ),
                ],
              ),
            ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.05),

            const SizedBox(height: 24),
            _buildSectionHeader('System Actions'),
            _buildActionTile(
              'Recalibrate All Drones',
              'Send a calibration sync to all drones in the fleet.',
              Icons.tune_rounded,
              AppColors.secondary,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Calibration command sent to all drones.'),
                    backgroundColor: AppColors.secondary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ).animate(delay: 580.ms).fadeIn().slideY(begin: 0.05),

            _buildActionTile(
              'Reset All Sessions',
              'Clear all ongoing delivery sessions and return drones to base.',
              Icons.restart_alt_rounded,
              AppColors.danger,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Sessions cleared. Drones recalled to base.'),
                    backgroundColor: AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ).animate(delay: 660.ms).fadeIn().slideY(begin: 0.05),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppTextStyles.title(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ).copyWith(letterSpacing: 1),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          title: Text(
            title,
            style: AppTextStyles.title(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark),
          ),
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          inactiveThumbColor: AppColors.textSecondaryDark,
          inactiveTrackColor: AppColors.borderDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          title: Text(
            title,
            style: AppTextStyles.title(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark),
          ),
          onTap: onTap,
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondaryDark),
        ),
      ),
    );
  }
}
