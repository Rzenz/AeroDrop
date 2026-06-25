import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/providers/drone_provider.dart';
import '../../core/models/delivery_model.dart';

class DeliveryDetailsScreen extends ConsumerWidget {
  final String deliveryId;

  const DeliveryDetailsScreen({super.key, required this.deliveryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveries = ref.watch(deliveryProvider);
    final drones = ref.watch(droneProvider);

    final deliveryIndex = deliveries.indexWhere((d) => d.id == deliveryId);
    if (deliveryIndex == -1) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(
          child: Text('Delivery not found', style: TextStyle(color: AppColors.textSecondaryDark)),
        ),
      );
    }
    final delivery = deliveries[deliveryIndex];
    final drone = delivery.droneId != null
        ? drones.firstWhere((d) => d.id == delivery.droneId)
        : null;

    final address = delivery.deliveryAddress;
    String pickup = 'Main Gate';
    String dropoff = address;
    if (address.startsWith('From ') && address.contains(' to ')) {
      pickup = address.substring(5, address.indexOf(' to '));
      dropoff = address.substring(address.indexOf(' to ') + 4);
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dispatch Details',
                            style: AppTextStyles.title(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Order ${delivery.id}',
                            style: AppTextStyles.body(
                              fontSize: 12,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusChip.delivery(delivery.status.name),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),

                const SizedBox(height: 28),

                // Interactive Timeline Stepper
                _buildTimelineStepper(delivery.status)
                    .animate(delay: 100.ms)
                    .fadeIn()
                    .slideY(begin: 0.05),

                const SizedBox(height: 24),

                // Delivery Info Card
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Route Information',
                        style: AppTextStyles.title(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Divider(height: 24, color: AppColors.borderDark),
                      _buildDetailRow(Icons.person_outline_rounded, 'Sender', delivery.senderName),
                      _buildDetailRow(Icons.pin_drop_outlined, 'Pickup Location', pickup),
                      _buildDetailRow(Icons.flag_outlined, 'Drop-off Location', dropoff),
                      _buildDetailRow(Icons.assignment_ind_outlined, 'Recipient', delivery.recipientName),
                      _buildDetailRow(Icons.phone_iphone_rounded, 'Contact Phone', delivery.recipientPhone),
                    ],
                  ),
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),

                const SizedBox(height: 20),

                // Package Details
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Package Specifications',
                        style: AppTextStyles.title(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Divider(height: 24, color: AppColors.borderDark),
                      _buildDetailRow(Icons.inventory_2_outlined, 'Package Name', delivery.packageName),
                      _buildDetailRow(Icons.category_outlined, 'Category', delivery.packageType),
                      _buildDetailRow(Icons.scale_rounded, 'Weight Load', '${delivery.packageWeight} kg'),
                    ],
                  ),
                ).animate(delay: 280.ms).fadeIn().slideY(begin: 0.05),

                const SizedBox(height: 20),

                // Drone Assignment Info
                if (drone != null) ...[
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Assigned Drone Telemetry',
                              style: AppTextStyles.title(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: AppColors.success, blurRadius: 6, spreadRadius: 1)],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: AppColors.borderDark),
                        _buildDetailRow(Icons.flight_takeoff_rounded, 'Drone Name', drone.name),
                        _buildDetailRow(Icons.battery_charging_full_rounded, 'Battery Level', '${drone.batteryLevel.toStringAsFixed(1)}%'),
                        _buildDetailRow(Icons.pin_drop_rounded, 'Current Coordinates', drone.currentCoordinates),
                      ],
                    ),
                  ).animate(delay: 360.ms).fadeIn().slideY(begin: 0.05),
                  const SizedBox(height: 24),
                ],

                // Action Buttons
                if (delivery.status == DeliveryStatus.pending) ...[
                  CustomButton(
                    text: 'Cancel Dispatch',
                    gradient: AppColors.dangerGradient,
                    onPressed: () {
                      ref.read(deliveryProvider.notifier).updateDeliveryStatus(delivery.id, DeliveryStatus.cancelled);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Dispatch successfully cancelled'),
                          backgroundColor: AppColors.danger,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                      context.pop();
                    },
                    icon: Icons.cancel_outlined,
                  ).animate(delay: 440.ms).fadeIn(),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStepper(DeliveryStatus currentStatus) {
    final statusList = [
      {'status': DeliveryStatus.pending, 'label': 'Pending'},
      {'status': DeliveryStatus.inTransit, 'label': 'In Transit'},
      {'status': DeliveryStatus.delivered, 'label': 'Delivered'},
    ];

    // Determine current index
    int activeIndex = 0;
    if (currentStatus == DeliveryStatus.inTransit) activeIndex = 1;
    if (currentStatus == DeliveryStatus.delivered) activeIndex = 2;
    if (currentStatus == DeliveryStatus.cancelled) activeIndex = -1;

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dispatch Status History',
            style: AppTextStyles.body(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 16),
          if (activeIndex == -1)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'This delivery was Cancelled',
                  style: AppTextStyles.title(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.danger),
                ),
              ],
            )
          else
            Row(
              children: List.generate(statusList.length, (index) {
                final item = statusList[index];
                final stepStatus = item['status'] as DeliveryStatus;
                final stepLabel = item['label'] as String;

                final isPassed = index <= activeIndex;
                final isCurrent = index == activeIndex;

                Color stepColor;
                IconData stepIcon;
                if (stepStatus == DeliveryStatus.pending) {
                  stepIcon = Icons.schedule_rounded;
                  stepColor = AppColors.warning;
                } else if (stepStatus == DeliveryStatus.inTransit) {
                  stepIcon = Icons.flight_takeoff_rounded;
                  stepColor = AppColors.primary;
                } else {
                  stepIcon = Icons.verified_rounded;
                  stepColor = AppColors.success;
                }

                return Expanded(
                  child: Row(
                    children: [
                      // Node
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isPassed ? stepColor.withValues(alpha: 0.15) : AppColors.cardDark2,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isPassed ? stepColor : AppColors.borderDark,
                                width: 2,
                              ),
                              boxShadow: isCurrent
                                  ? [BoxShadow(color: stepColor.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)]
                                  : null,
                            ),
                            child: Icon(
                              stepIcon,
                              color: isPassed ? stepColor : AppColors.textSecondaryDark,
                              size: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            stepLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: isPassed ? Colors.white : AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                      // Connector line
                      if (index < statusList.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  isPassed ? stepColor : AppColors.borderDark,
                                  index + 1 <= activeIndex ? AppColors.primary : AppColors.borderDark,
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.secondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondaryDark, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
