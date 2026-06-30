import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/models/delivery_model.dart';
import 'package:go_router/go_router.dart';

class AdminDeliveriesScreen extends ConsumerStatefulWidget {
  const AdminDeliveriesScreen({super.key});

  @override
  ConsumerState<AdminDeliveriesScreen> createState() =>
      _AdminDeliveriesScreenState();
}

class _AdminDeliveriesScreenState extends ConsumerState<AdminDeliveriesScreen> {
  bool _loading = true;
  DeliveryStatus? _filter;

  @override
  void initState() {
    super.initState();
    _fetchDeliveries();
  }

  Future<void> _fetchDeliveries() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await ref.read(deliveryProvider.notifier).loadAdminDeliveriesFromSupabase();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _accept(String id) async {
    final error = await ref.read(deliveryProvider.notifier).acceptDelivery(id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept: $error'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Delivery accepted and drone assigned!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _fetchDeliveries();
    }
  }

  Future<void> _reject(String id) async {
    final error = await ref.read(deliveryProvider.notifier).rejectDelivery(id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject: $error'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Delivery request rejected.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _fetchDeliveries();
    }
  }

  Color _statusColor(DeliveryStatus s) => switch (s) {
        DeliveryStatus.pending => AppColors.warning,
        DeliveryStatus.assigning => AppColors.info,
        DeliveryStatus.inTransit => AppColors.primary,
        DeliveryStatus.delivered => AppColors.success,
        DeliveryStatus.cancelled => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(deliveryProvider);
    final items = _filter == null ? all : all.where((d) => d.status == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                _filterChip('All', _filter == null,
                    () => setState(() => _filter = null), AppColors.primary),
                const SizedBox(width: 8),
                ...DeliveryStatus.values
                    .where((s) => s != DeliveryStatus.assigning)
                    .map((s) {
                  final label = s == DeliveryStatus.inTransit
                      ? 'In Transit'
                      : s.name[0].toUpperCase() + s.name.substring(1);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _filterChip(
                      label,
                      _filter == s,
                      () => setState(() => _filter = s),
                      _statusColor(s),
                    ),
                  );
                }),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchDeliveries,
              color: AppColors.accent,
              backgroundColor: AppColors.cardDark,
              child: _loading
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: 6,
                      itemBuilder: (_, _) => const SkeletonCard())
                  : items.isEmpty
                      ? const EmptyStateWidget(
                          title: 'No Deliveries',
                          subtitle: 'Nothing matches this filter.')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final d = items[i];
                            final address = d.deliveryAddress;
                            String pickup = 'Main Gate';
                            String dropoff = address;
                            if (address.startsWith('From ') && address.contains(' to ')) {
                              pickup = address.substring(5, address.indexOf(' to '));
                              dropoff = address.substring(address.indexOf(' to ') + 4);
                            }

                            return GestureDetector(
                              onTap: () => context
                                  .push('/admin/deliveries/details?id=${d.id}'),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.cardDark,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.borderDark),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: _statusColor(d.status)
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(Icons.local_shipping_rounded,
                                              color: _statusColor(d.status), size: 18),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(d.senderName,
                                                  style: AppTextStyles.title(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white)),
                                              Text(
                                                  '$pickup → $dropoff',
                                                  style: AppTextStyles.body(
                                                      fontSize: 12,
                                                      color: AppColors.textSecondaryDark),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                        StatusChip.delivery(d.status == DeliveryStatus.pending ? 'Pending Admin Approval' : d.status.name),
                                      ],
                                    ),
                                    if (d.status == DeliveryStatus.pending) ...[
                                      const SizedBox(height: 12),
                                      const Divider(color: AppColors.borderDark, height: 1),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => _reject(d.id),
                                            icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                                            label: const Text('Reject', style: TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.bold)),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          TextButton.icon(
                                            onPressed: () => _accept(d.id),
                                            icon: const Icon(Icons.check_rounded, size: 16, color: AppColors.success),
                                            label: const Text('Accept', style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.bold)),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              backgroundColor: AppColors.success.withValues(alpha: 0.1),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                                .animate(delay: Duration(milliseconds: i * 50))
                                .fadeIn()
                                .slideX(begin: 0.04);
                          },
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _filterChip(String label, bool sel, VoidCallback onTap, Color color) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: sel ? color.withValues(alpha: 0.15) : AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sel ? color : AppColors.borderDark),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              color: sel ? color : AppColors.textSecondaryDark)),
    ),
  );
}
