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
import '../../core/services/supabase_service.dart';

class TrackingDetailsPage extends ConsumerStatefulWidget {
  final String deliveryId;
  const TrackingDetailsPage({super.key, required this.deliveryId});

  @override
  ConsumerState<TrackingDetailsPage> createState() =>
      _TrackingDetailsPageState();
}

class _TrackingDetailsPageState extends ConsumerState<TrackingDetailsPage> {
  String _pickupName = 'Pickup location unavailable';
  String _dropoffName = 'Drop-off location unavailable';
  String _droneBatteryText = 'Drone not assigned yet';
  String _droneName = 'Assigning...';
  String _flightSpeed = '-- km/h';
  String _flightAltitude = '-- m';
  DeliveryModel? _fetchedDelivery;

  @override
  void initState() {
    super.initState();
    Future.microtask(_fetchDetails);
  }

  Future<void> _fetchDetails() async {
    if (!SupabaseService.isConfigured) return;
    if (!mounted) return;

    try {
      // 1. Fetch latest delivery details from deliveries table
      final delResponse = await SupabaseService.client
          .from('deliveries')
          .select()
          .eq('id', widget.deliveryId)
          .maybeSingle();

      if (delResponse != null) {
        final data = Map<String, dynamic>.from(delResponse);

        // Convert map to DeliveryModel status
        final isComplete =
            data['status']?.toString().toLowerCase() == 'delivered';
        final status = isComplete
            ? DeliveryStatus.delivered
            : (data['status']?.toString().toLowerCase() == 'intransit' ||
                  data['status']?.toString().toLowerCase() == 'in_transit')
            ? DeliveryStatus.inTransit
            : data['status']?.toString().toLowerCase() == 'cancelled'
            ? DeliveryStatus.cancelled
            : DeliveryStatus.pending;

        // Progress helper
        double progress = 0.0;
        if (status == DeliveryStatus.delivered) {
          progress = 1.0;
        } else if (status == DeliveryStatus.inTransit) {
          final startedAt = data['delivery_started_at'] != null
              ? DateTime.tryParse(data['delivery_started_at'].toString())
              : null;
          if (startedAt != null) {
            final totalSecs =
                (data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60;
            final elapsed = DateTime.now().difference(startedAt).inSeconds;
            progress = (elapsed / totalSecs).clamp(0.0, 1.0);
          }
        }

        // ETA helper
        String etaStr = data['eta']?.toString() ?? 'TBD';
        if (status == DeliveryStatus.delivered) {
          etaStr = '0 mins';
        } else if (status == DeliveryStatus.inTransit) {
          final startedAt = data['delivery_started_at'] != null
              ? DateTime.tryParse(data['delivery_started_at'].toString())
              : null;
          if (startedAt != null) {
            final totalSecs =
                (data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60;
            final elapsed = DateTime.now().difference(startedAt).inSeconds;
            final remaining = (totalSecs - elapsed).clamp(0, totalSecs);
            etaStr = remaining <= 0
                ? '0 mins'
                : remaining < 60
                ? '$remaining secs'
                : '${(remaining / 60).ceil()} mins';
          }
        }

        final model = DeliveryModel(
          id: data['id'].toString(),
          senderName: data['sender_name']?.toString() ?? 'Unknown Sender',
          recipientName:
              data['recipient_name']?.toString() ?? 'Unknown Recipient',
          recipientPhone: data['recipient_phone']?.toString() ?? '',
          deliveryAddress: data['delivery_address']?.toString() ?? '',
          packageName: data['package_name']?.toString() ?? 'AeroDrop Package',
          packageWeight: (data['package_weight'] as num?)?.toDouble() ?? 0.0,
          packageType: data['package_type']?.toString() ?? 'Other',
          status: status,
          droneId: data['drone_id']?.toString(),
          eta: etaStr,
          createdAt: data['created_at'] != null
              ? DateTime.tryParse(data['created_at'].toString()) ??
                    DateTime.now()
              : DateTime.now(),
          progress: progress,
          estimatedDistanceKm: data['estimated_distance_km'] != null
              ? (data['estimated_distance_km'] as num).toDouble()
              : null,
          paymentAmount: data['payment_amount'] != null
              ? (data['payment_amount'] as num).toDouble()
              : null,
          deliveryStartedAt: data['delivery_started_at'] != null
              ? DateTime.tryParse(data['delivery_started_at'].toString())
              : null,
          estimatedDeliverySeconds:
              (data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60,
          deliveredAt: data['delivered_at'] != null
              ? DateTime.tryParse(data['delivered_at'].toString())
              : null,
        );

        if (mounted) {
          setState(() {
            _fetchedDelivery = model;
          });
        }

        // 2. Fetch locations
        final pickupId = data['pickup_location_id'];
        final dropoffId = data['dropoff_location_id'];
        if (pickupId != null) {
          final p = await SupabaseService.client
              .from('campus_locations')
              .select('name')
              .eq('id', pickupId)
              .maybeSingle();
          if (p != null && mounted) {
            setState(() {
              _pickupName =
                  p['name']?.toString() ?? 'Pickup location unavailable';
            });
          }
        }
        if (dropoffId != null) {
          final d = await SupabaseService.client
              .from('campus_locations')
              .select('name')
              .eq('id', dropoffId)
              .maybeSingle();
          if (d != null && mounted) {
            setState(() {
              _dropoffName =
                  d['name']?.toString() ?? 'Drop-off location unavailable';
            });
          }
        }

        // 3. Fetch Drone details
        final droneId = data['drone_id'];
        if (droneId != null) {
          final drone = await SupabaseService.client
              .from('drones')
              .select('name, battery_level')
              .eq('id', droneId)
              .maybeSingle();
          if (drone != null && mounted) {
            setState(() {
              _droneName = drone['name']?.toString() ?? droneId.toString();
              final lvl = drone['battery_level'];
              _droneBatteryText = lvl != null
                  ? 'Drone Battery: $lvl%'
                  : 'Drone Battery: Unknown';
            });
          }

          // 4. Fetch latest telemetry
          final tel = await SupabaseService.client
              .from('drone_telemetry')
              .select()
              .eq('drone_id', droneId)
              .order('recorded_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (tel != null && mounted) {
            setState(() {
              final speed = tel['speed'];
              final alt = tel['altitude'];
              final battery = tel['battery_level'];

              if (speed != null) {
                _flightSpeed = '$speed km/h';
              } else {
                _flightSpeed = '-- km/h';
              }
              if (alt != null) {
                _flightAltitude = '$alt m';
              } else {
                _flightAltitude = '-- m';
              }
              if (battery != null) {
                _droneBatteryText = 'Drone Battery: $battery%';
              }
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _droneName = 'Assigning...';
              _droneBatteryText = 'Drone not assigned yet';
              _flightSpeed = '-- km/h';
              _flightAltitude = '-- m';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _fetchDetails: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<DeliveryModel>>(deliveryProvider, (previous, next) {
      if (previous != null) {
        for (final nextDel in next) {
          final prevDel = previous.firstWhere(
            (d) => d.id == nextDel.id,
            orElse: () => nextDel,
          );
          if (prevDel.status == DeliveryStatus.inTransit &&
              nextDel.status == DeliveryStatus.delivered) {
            context.go('/user/delivery/completed');
            break;
          }
        }
      }
    });

    final deliveries = ref.watch(deliveryProvider);
    final providerDelivery = deliveries.firstWhere(
      (d) => d.id == widget.deliveryId,
      orElse: () => DeliveryModel(
        id: widget.deliveryId,
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

    final delivery = _fetchedDelivery ?? providerDelivery;

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
          child: RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.cardDark,
            onRefresh: _fetchDetails,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                            child: const Icon(
                              Icons.timer_rounded,
                              color: AppColors.primaryLight,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estimated Arrival Time',
                                  style: AppTextStyles.body(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  delivery.status == DeliveryStatus.delivered
                                      ? 'Delivered'
                                      : delivery.status ==
                                            DeliveryStatus.cancelled
                                      ? 'Cancelled'
                                      : '${delivery.eta} remaining',
                                  style: AppTextStyles.title(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
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
                            style: AppTextStyles.title(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                          const Divider(
                            color: AppColors.borderDark,
                            height: 24,
                          ),
                          _rowDetail(
                            Icons.airplay_rounded,
                            'Drone ID',
                            _droneName,
                          ),
                          _rowDetail(
                            Icons.battery_charging_full_rounded,
                            'Drone Battery',
                            _droneBatteryText,
                          ),
                          _rowDetail(
                            Icons.speed_rounded,
                            'Flight Speed',
                            _flightSpeed,
                          ),
                          _rowDetail(
                            Icons.height_rounded,
                            'Flight Altitude',
                            _flightAltitude,
                          ),
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
                            style: AppTextStyles.title(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryLight,
                            ),
                          ),
                          const Divider(
                            color: AppColors.borderDark,
                            height: 24,
                          ),
                          _rowDetail(
                            Icons.shield_rounded,
                            'System Mode',
                            'Prototype Telemetry (UCLM Autonomous Autopilot Core)',
                          ),
                          _rowDetail(
                            Icons.wifi_rounded,
                            'Signal Connection',
                            'Excellent RSSI (-45dB)',
                          ),
                          _rowDetail(
                            Icons.compass_calibration_rounded,
                            'Telemetry Lock',
                            '3D GPS Fix Locked',
                          ),
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
                            style: AppTextStyles.title(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          const Divider(
                            color: AppColors.borderDark,
                            height: 24,
                          ),
                          _rowDetail(
                            Icons.my_location_rounded,
                            'From',
                            _pickupName,
                          ),
                          _rowDetail(Icons.flag_rounded, 'To', _dropoffName),
                        ],
                      ),
                    ),

                    // Cancel Button
                    if (delivery.status == DeliveryStatus.pending) ...[
                      const SizedBox(height: 24),
                      _DestructiveButton(
                        text: 'Cancel Request',
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
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 13,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: AppTextStyles.title(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Cancel Delivery Request?',
              style: AppTextStyles.title(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          'This request will be marked as cancelled and kept in your history.',
          style: AppTextStyles.body(
            fontSize: 14,
            color: AppColors.textSecondaryDark,
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'No',
              style: AppTextStyles.body(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondaryDark,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              final error = await ref
                  .read(deliveryProvider.notifier)
                  .cancelDeliveryRequest(widget.deliveryId);

              if (!context.mounted) return;

              if (error == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Delivery request cancelled.'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                context.pop(); // Go back from tracking details
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(
              'Yes, Cancel',
              style: AppTextStyles.body(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
