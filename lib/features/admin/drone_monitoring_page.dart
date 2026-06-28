import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/drone_provider.dart';
import '../../core/models/drone_model.dart';

class DroneMonitoringPage extends ConsumerStatefulWidget {
  final String droneId;
  const DroneMonitoringPage({super.key, required this.droneId});

  @override
  ConsumerState<DroneMonitoringPage> createState() => _DroneMonitoringPageState();
}

class _DroneMonitoringPageState extends ConsumerState<DroneMonitoringPage> {
  late Timer _telemetryTimer;
  double _altitude = 45.0;
  double _speed = 12.5;
  double _signal = 98.0;
  double _battery = 92.5;
  final List<FlSpot> _altitudeSpots = [];
  int _tickCount = 0;

  @override
  void initState() {
    super.initState();
    // Pre-populate spots
    for (int i = 0; i < 7; i++) {
      _altitudeSpots.add(FlSpot(i.toDouble(), 40.0 + (i % 3) * 2.5));
    }
    _tickCount = 6;

    // Start periodic simulation timer
    _telemetryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        _tickCount++;
        // Simulation logic
        _altitude = 42.0 + (timer.tick % 4) * 1.5;
        _speed = 11.0 + (timer.tick % 3) * 0.8;
        _signal = 95.0 + (timer.tick % 5) * 1.0;
        if (_signal > 100) _signal = 100.0;
        
        _battery -= 0.1;
        if (_battery < 0) _battery = 0.0;

        _altitudeSpots.add(FlSpot(_tickCount.toDouble(), _altitude));
        if (_altitudeSpots.length > 8) {
          _altitudeSpots.removeAt(0);
        }
      });
      // ponytail: stop burning CPU when battery is dead
      if (_battery <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _telemetryTimer.cancel();
    super.dispose();
  }

  void _triggerEmergencyLand() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.borderDark)),
        title: Text('EMERGENCY INSTRUCTION', style: AppTextStyles.title(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.danger)),
        content: const Text(
          'Are you sure you want to override flight controls and force immediate vertical descent for emergency landing?',
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondaryDark)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Emergency Landing sequence broadcasted to drone firmware!'),
                  backgroundColor: AppColors.danger,
                ),
              );
            },
            child: const Text('FORCE LAND', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drones = ref.watch(droneProvider);
    final drone = drones.firstWhere(
      (d) => d.id == widget.droneId,
      orElse: () => DroneModel(
        id: widget.droneId,
        name: 'AeroCarrier Falcon',
        batteryLevel: 92.5,
        status: DroneStatus.available,
        maxPayload: 5.0,
        modelType: 'AeroCarrier-X',
        currentCoordinates: '10.3276° N, 123.9507° E',
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live Fleet Monitor',
                            style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            '${drone.name} (${drone.id})',
                            style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 24),

                // Telemetry dashboard stats grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _buildGaugeCard('Altitude', '${_altitude.toStringAsFixed(1)} m', Icons.height_rounded, AppColors.primary),
                    _buildGaugeCard('Flight Speed', '${_speed.toStringAsFixed(1)} m/s', Icons.speed_rounded, AppColors.secondary),
                    _buildGaugeCard('GPS Signal', '${_signal.toStringAsFixed(0)}%', Icons.wifi_rounded, AppColors.success),
                    _buildGaugeCard('Remaining Battery', '${_battery.toStringAsFixed(1)}%', Icons.battery_charging_full_rounded, AppColors.warning),
                  ],
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 24),

                // Telemetry Chart
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Altitude History (m)',
                          style: AppTextStyles.title(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (val) => FlLine(
                                  color: AppColors.borderDark.withValues(alpha: 0.2),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: const FlTitlesData(
                                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _altitudeSpots,
                                  isCurved: true,
                                  gradient: const LinearGradient(
                                    colors: [AppColors.primary, AppColors.secondary],
                                  ),
                                  barWidth: 3,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary.withValues(alpha: 0.2),
                                        AppColors.primary.withValues(alpha: 0.0),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
                ),
                const SizedBox(height: 24),

                // Emergency Trigger
                CustomButton(
                  text: 'FORCE EMERGENCY LANDING',
                  icon: Icons.offline_bolt_rounded,
                  gradient: const LinearGradient(colors: [AppColors.danger, AppColors.danger]),
                  onPressed: _triggerEmergencyLand,
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGaugeCard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTextStyles.body(fontSize: 10, color: AppColors.textSecondaryDark, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.title(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
