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
import '../../core/providers/weather_provider.dart';
import '../../core/models/drone_model.dart';
import '../../core/models/delivery_model.dart';
import '../../core/widgets/neu_back_button.dart';

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
          child: Text(
            'Delivery not found',
            style: TextStyle(color: AppColors.textSecondaryDark),
          ),
        ),
      );
    }
    final delivery = deliveries[deliveryIndex];
    final drone = delivery.droneId != null
        ? drones.firstWhere(
            (d) => d.id == delivery.droneId,
            orElse: () => drones.first,
          )
        : null;

    final address = delivery.deliveryAddress;
    String pickup = 'Main Gate';
    String dropoff = address;
    if (address.startsWith('From ') && address.contains(' to ')) {
      pickup = address.substring(5, address.indexOf(' to '));
      dropoff = address.substring(address.indexOf(' to ') + 4);
    }

    final weather = ref.watch(weatherProvider);
    final isWeatherSafe = !weather.isGrounded;
    final isWeightValid =
        delivery.packageWeight > 0 && delivery.packageWeight <= 0.5;
    final isRouteValid =
        pickup.isNotEmpty && dropoff.isNotEmpty && dropoff != 'Unknown';
    final hasItems =
        delivery.packageName != 'No package items available.' &&
        delivery.packageName.isNotEmpty;
    final isDroneAvailable =
        delivery.droneId != null ||
        drones.any(
          (d) => d.name == 'DRN-001' && d.status == DroneStatus.available,
        );

    final allPassed =
        isWeatherSafe &&
        isWeightValid &&
        isRouteValid &&
        hasItems &&
        isDroneAvailable;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.cardDark,
            onRefresh: () async {
              await ref
                  .read(deliveryProvider.notifier)
                  .loadDeliveriesFromSupabase();
              await ref.read(droneProvider.notifier).loadDronesFromSupabase();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      const NeuBackButton(
                        fallbackRoute: '/admin/deliveries',
                        color: AppColors.cardDark,
                        iconColor: Colors.white,
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
                              'Order ${delivery.id.substring(0, 8).toUpperCase()}',
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
                  _buildTimelineStepper(
                    delivery.status,
                  ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05),

                  const SizedBox(height: 24),

                  // Route Info Card
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route Information',
                          style: AppTextStyles.title(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Divider(height: 24, color: AppColors.borderDark),
                        _buildDetailRow(
                          Icons.person_outline_rounded,
                          'Sender',
                          delivery.senderName,
                        ),
                        _buildDetailRow(
                          Icons.pin_drop_outlined,
                          'Pickup Location',
                          pickup,
                        ),
                        _buildDetailRow(
                          Icons.flag_outlined,
                          'Drop-off Location',
                          dropoff,
                        ),
                        _buildDetailRow(
                          Icons.assignment_ind_outlined,
                          'Recipient',
                          delivery.recipientName,
                        ),
                        _buildDetailRow(
                          Icons.phone_iphone_rounded,
                          'Contact Phone',
                          delivery.recipientPhone.trim().isEmpty
                              ? 'No phone number provided'
                              : delivery.recipientPhone,
                        ),
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
                          style: AppTextStyles.title(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Divider(height: 24, color: AppColors.borderDark),
                        _buildDetailRow(
                          Icons.inventory_2_outlined,
                          'Package Name',
                          delivery.packageName,
                        ),
                        _buildDetailRow(
                          Icons.category_outlined,
                          'Category',
                          delivery.packageType,
                        ),
                        _buildDetailRow(
                          Icons.scale_rounded,
                          'Weight Load',
                          '${delivery.packageWeight} kg',
                        ),
                        _buildDetailRow(
                          Icons.scale_outlined,
                          'Max Payload Limit',
                          '0.5 kg',
                        ),
                        if (delivery.estimatedDistanceKm != null)
                          _buildDetailRow(
                            Icons.map_outlined,
                            'Estimated Distance',
                            '${delivery.estimatedDistanceKm} km',
                          ),
                        if (delivery.paymentAmount != null)
                          _buildDetailRow(
                            Icons.payments_outlined,
                            'Payment Amount',
                            '₱${delivery.paymentAmount!.toStringAsFixed(2)}',
                          ),
                      ],
                    ),
                  ).animate(delay: 280.ms).fadeIn().slideY(begin: 0.05),

                  const SizedBox(height: 20),

                  // Cargo Verification Section
                  _CargoVerificationCard(
                    delivery: delivery,
                  ).animate(delay: 320.ms).fadeIn().slideY(begin: 0.05),

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
                                style: AppTextStyles.title(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.success,
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(
                            height: 24,
                            color: AppColors.borderDark,
                          ),
                          _buildDetailRow(
                            Icons.flight_takeoff_rounded,
                            'Drone Name',
                            drone.name,
                          ),
                          _buildDetailRow(
                            Icons.battery_charging_full_rounded,
                            'Battery Level',
                            '${drone.batteryLevel.toStringAsFixed(1)}%',
                          ),
                          _buildDetailRow(
                            Icons.pin_drop_rounded,
                            'Current Coordinates',
                            drone.currentCoordinates,
                          ),
                        ],
                      ),
                    ).animate(delay: 360.ms).fadeIn().slideY(begin: 0.05),
                    const SizedBox(height: 24),
                  ],

                  // Action Buttons
                  if (delivery.status == DeliveryStatus.pending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Reject Request',
                            gradient: AppColors.dangerGradient,
                            onPressed: () async {
                              final error = await ref
                                  .read(deliveryProvider.notifier)
                                  .rejectDelivery(delivery.id);
                              if (context.mounted) {
                                if (error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to reject: $error'),
                                      backgroundColor: AppColors.danger,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Delivery request rejected.',
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  context.pop();
                                }
                              }
                            },
                            icon: Icons.close_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomButton(
                            text: 'Accept & Dispatch',
                            onPressed: () async {
                              if (!allPassed) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Cannot dispatch: flight readiness checks have not passed.',
                                    ),
                                    backgroundColor: AppColors.danger,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              final error = await ref
                                  .read(deliveryProvider.notifier)
                                  .acceptDelivery(delivery.id);
                              if (context.mounted) {
                                if (error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to accept: $error'),
                                      backgroundColor: AppColors.danger,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Delivery accepted and drone assigned!',
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  context.pop();
                                }
                              }
                            },
                            icon: Icons.check_rounded,
                          ),
                        ),
                      ],
                    ).animate(delay: 440.ms).fadeIn(),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
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
            style: AppTextStyles.body(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondaryDark,
            ),
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
                  child: const Icon(
                    Icons.cancel_rounded,
                    color: AppColors.danger,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'This delivery was Cancelled',
                  style: AppTextStyles.title(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
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
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isPassed
                                  ? stepColor.withValues(alpha: 0.15)
                                  : AppColors.cardDark2,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isPassed
                                    ? stepColor
                                    : AppColors.borderDark,
                                width: 2,
                              ),
                              boxShadow: isCurrent
                                  ? [
                                      BoxShadow(
                                        color: stepColor.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              stepIcon,
                              color: isPassed
                                  ? stepColor
                                  : AppColors.textSecondaryDark,
                              size: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            stepLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isPassed
                                  ? Colors.white
                                  : AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                      if (index < statusList.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.only(
                              bottom: 16,
                              left: 4,
                              right: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  isPassed ? stepColor : AppColors.borderDark,
                                  index + 1 <= activeIndex
                                      ? AppColors.primary
                                      : AppColors.borderDark,
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
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CargoVerificationCard extends ConsumerWidget {
  final DeliveryModel delivery;
  const _CargoVerificationCard({required this.delivery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(weatherProvider);
    final drones = ref.watch(droneProvider);

    final isWeatherSafe = !weather.isGrounded;
    final isWeightValid =
        delivery.packageWeight > 0 && delivery.packageWeight <= 0.5;

    final address = delivery.deliveryAddress;
    String pickup = 'Main Gate';
    String dropoff = address;
    if (address.startsWith('From ') && address.contains(' to ')) {
      pickup = address.substring(5, address.indexOf(' to '));
      dropoff = address.substring(address.indexOf(' to ') + 4);
    }
    final isRouteValid =
        pickup.isNotEmpty && dropoff.isNotEmpty && dropoff != 'Unknown';

    final hasItems =
        delivery.packageName != 'No package items available.' &&
        delivery.packageName.isNotEmpty;

    final isDroneAvailable =
        delivery.droneId != null ||
        drones.any(
          (d) => d.name == 'DRN-001' && d.status == DroneStatus.available,
        );

    final allPassed =
        isWeatherSafe &&
        isWeightValid &&
        isRouteValid &&
        hasItems &&
        isDroneAvailable;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cargo Dispatch Readiness',
                style: AppTextStyles.title(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (allPassed ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: allPassed ? AppColors.success : AppColors.warning,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  allPassed ? 'READY FOR DISPATCH' : 'DISPATCH BLOCKED',
                  style: TextStyle(
                    color: allPassed ? AppColors.success : AppColors.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.borderDark),
          _buildCheckRow(
            Icons.receipt_long_outlined,
            'Order Record Details',
            delivery.id.isNotEmpty
                ? 'Valid Order (ID: ${delivery.id.substring(0, 8).toUpperCase()})'
                : 'Missing Order',
            delivery.id.isNotEmpty,
          ),
          _buildCheckRow(
            Icons.shopping_bag_outlined,
            'Package Contents Listed',
            hasItems ? delivery.packageName : 'No package items available.',
            hasItems,
          ),
          _buildCheckRow(
            Icons.scale_outlined,
            'Payload Weight Limit',
            '${delivery.packageWeight.toStringAsFixed(3)} kg (Max 0.500 kg)',
            isWeightValid,
          ),
          _buildCheckRow(
            Icons.map_outlined,
            'Valid Flight Route',
            'From $pickup to $dropoff',
            isRouteValid,
          ),
          _buildCheckRow(
            Icons.cloud_outlined,
            'Flight Weather Safety',
            isWeatherSafe
                ? 'Safe to fly (${weather.weatherStatus.toUpperCase()})'
                : 'Unsafe weather (${weather.weatherStatus.toUpperCase()})',
            isWeatherSafe,
          ),
          _buildCheckRow(
            Icons.rocket_launch_outlined,
            'Carrier Drone Allocation',
            isDroneAvailable
                ? (delivery.droneId != null
                      ? 'Drone Assigned'
                      : 'DRN-001 Available')
                : 'DRN-001 Busy / Unavailable',
            isDroneAvailable,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(
    IconData icon,
    String label,
    String value,
    bool passed,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: passed ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: passed ? Colors.white : AppColors.textSecondaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    color: passed
                        ? AppColors.textSecondaryDark
                        : AppColors.warning.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: passed ? AppColors.success : AppColors.warning,
          ),
        ],
      ),
    );
  }
}
