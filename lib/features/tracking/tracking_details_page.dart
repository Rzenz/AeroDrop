import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/staggered_list.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/models/delivery_model.dart';

class TrackingDetailsPage extends ConsumerWidget {
  final String deliveryId;
  const TrackingDetailsPage({super.key, required this.deliveryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<List<DeliveryModel>>(deliveryProvider, (previous, next) {
      if (previous != null) {
        for (final nextDel in next) {
          final prevDel = previous.firstWhere((d) => d.id == nextDel.id, orElse: () => nextDel);
          if (prevDel.status == DeliveryStatus.inTransit && nextDel.status == DeliveryStatus.delivered) {
            context.go('/user/delivery/completed');
            break;
          }
        }
      }
    });

    final deliveries = ref.watch(deliveryProvider);
    final delivery = deliveries.firstWhere(
      (d) => d.id == deliveryId,
      orElse: () => DeliveryModel(
        id: deliveryId,
        senderName: '',
        recipientName: '',
        recipientPhone: '',
        deliveryAddress: '',
        packageName: 'Unknown Package',
        packageWeight: 0,
        packageType: '',
        status: DeliveryStatus.cancelled,
        eta: 'N/A',
        createdAt: DateTime.now(),
        progress: 0,
      ),
    );

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
                                delivery.status == DeliveryStatus.delivered
                                    ? 'Delivered'
                                    : delivery.status == DeliveryStatus.cancelled
                                        ? 'Cancelled'
                                        : '${delivery.eta} remaining',
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
                        _rowDetail(Icons.airplay_rounded, 'Drone ID', delivery.droneId ?? 'Assigning...'),
                        _rowDetail(Icons.battery_charging_full_rounded, 'Hardware Battery', delivery.status == DeliveryStatus.inTransit ? '${(85 - (delivery.progress * 10).toInt())}% Operational' : '85% Operational'),
                        _rowDetail(Icons.speed_rounded, 'Flight Speed', delivery.status == DeliveryStatus.inTransit ? '12.4 m/s' : '0.0 m/s'),
                        _rowDetail(Icons.height_rounded, 'Flight Altitude', delivery.status == DeliveryStatus.inTransit ? '34.2 m' : '0.0 m'),
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
                        _rowDetail(Icons.flag_rounded, 'Destination', delivery.deliveryAddress),
                      ],
                    ),
                  ),

                  // Cancel Button
                  if (delivery.status == DeliveryStatus.pending ||
                      delivery.status == DeliveryStatus.assigning ||
                      delivery.status == DeliveryStatus.inTransit) ...[
                    const SizedBox(height: 24),
                    _DestructiveButton(
                      text: 'Cancel Delivery',
                      icon: Icons.cancel_outlined,
                      onPressed: () => _showCancelConfirmation(context, ref),
                    ),
                  ],
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

  void _showCancelConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF132031),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            Text(
              'Cancel Delivery?',
              style: AppTextStyles.title(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel this delivery request? The drone will abort the mission and return to base.',
          style: AppTextStyles.body(fontSize: 14, color: AppColors.textSecondaryDark),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'No, Keep',
              style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondaryDark),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              ref.read(deliveryProvider.notifier).updateDeliveryStatus(deliveryId, DeliveryStatus.cancelled);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delivery cancelled. Drone returning to base.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
              Navigator.pop(context); // Go back from tracking details
            },
            child: Text(
              'Yes, Cancel',
              style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestructiveButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;

  const _DestructiveButton({
    required this.text,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Colors.red.withValues(alpha: 0.15),
            Colors.redAccent.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: AppTextStyles.title(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
