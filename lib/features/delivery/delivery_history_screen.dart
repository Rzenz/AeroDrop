import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/delivery_card.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/models/delivery_model.dart';

class DeliveryHistoryScreen extends ConsumerStatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  ConsumerState<DeliveryHistoryScreen> createState() =>
      _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends ConsumerState<DeliveryHistoryScreen> {
  // ponytail: removed fake 750ms loading shimmer — data is already in memory.
  DeliveryStatus? _filter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(deliveryProvider.notifier).loadDeliveriesFromSupabase();
    });
  }

  Future<void> _handleRefresh() async {
    await ref.read(deliveryProvider.notifier).loadDeliveriesFromSupabase();
    await ref.read(notificationProvider.notifier).loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(deliveryProvider);
    final filtered = _filter == null
        ? all
        : all.where((d) => d.status == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: const CustomAppBar(title: 'Flight Records', showBackButton: false),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asymmetric large title & description
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All drone dispatches & delivery logs',
                    style: AppTextStyles.body(
                      fontSize: 14,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideX(begin: -0.05),

            // Horizontal filters list using custom Glass chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                children: [
                  _HistoryFilterChip(
                    label: 'All Flights',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  const SizedBox(width: 10),
                  ...DeliveryStatus.values
                      .where((s) => s != DeliveryStatus.assigning)
                      .map((s) {
                    final label = s == DeliveryStatus.inTransit
                        ? 'In Transit'
                        : s.name[0].toUpperCase() + s.name.substring(1);
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _HistoryFilterChip(
                        label: label,
                        selected: _filter == s,
                        onTap: () => setState(() => _filter = s),
                        color: _statusColor(s),
                      ),
                    );
                  }),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms),

            // Records List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                color: AppColors.accent,
                backgroundColor: AppColors.cardDark,
                strokeWidth: 2.5,
                child: filtered.isEmpty
                        ? EmptyStateWidget(
                            title: 'No Flight Logs Found',
                            subtitle: 'There are no drone flights matching the selected filter.',
                            lottiePath: 'assets/lottie/empty_box.json',
                            actionLabel: 'New Request',
                            onAction: () => context.push('/user/request'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final item = filtered[i];
                              final isEven = i % 2 == 0;

                              // Alternate between a standard DeliveryCard (which is an AnimatedCard)
                              // and a frosted GlassCard container representing the delivery.
                              // Also apply alternating wide/narrow margins.
                              Widget card;
                              if (isEven) {
                                card = Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: DeliveryCard(
                                    delivery: item,
                                    onTap: () => context.push('/user/track/details?id=${item.id}'),
                                  ),
                                );
                              } else {
                                card = Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: GlassCard(
                                    onTap: () => context.push('/user/track/details?id=${item.id}'),
                                    padding: const EdgeInsets.all(18),
                                    borderGradient: const LinearGradient(
                                      colors: [Colors.white24, Colors.white12],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              item.id,
                                              style: AppTextStyles.label(
                                                fontSize: 11,
                                                color: AppColors.accentLight,
                                              ),
                                            ),
                                            StatusChip.delivery(item.status.name),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          item.packageName,
                                          style: AppTextStyles.title(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              item.packageType,
                                              style: AppTextStyles.body(
                                                fontSize: 12.5,
                                                color: AppColors.textSecondaryDark,
                                              ),
                                            ),
                                            Text(
                                              '${item.packageWeight} kg',
                                              style: AppTextStyles.body(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textSecondaryDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: card,
                              )
                                  .animate(delay: (i * 60).ms)
                                  .fadeIn(duration: 400.ms)
                                  .slideY(begin: 0.15, end: 0, curve: Curves.easeOut);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(DeliveryStatus s) => switch (s) {
        DeliveryStatus.pending => AppColors.warning,
        DeliveryStatus.assigning => AppColors.accent,
        DeliveryStatus.inTransit => AppColors.primary,
        DeliveryStatus.delivered => AppColors.success,
        DeliveryStatus.cancelled => AppColors.danger,
      };
}

class _HistoryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _HistoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.15)
              : AppColors.cardDark2,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? activeColor : AppColors.borderDark,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.title(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? activeColor : AppColors.textSecondaryDark,
          ),
        ),
      ),
    );
  }
}
