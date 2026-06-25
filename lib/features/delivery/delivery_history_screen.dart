import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/delivery_card.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/models/delivery_model.dart';

class DeliveryHistoryScreen extends ConsumerStatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  ConsumerState<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends ConsumerState<DeliveryHistoryScreen> {
  bool _loading = true;
  DeliveryStatus? _filter;

  @override
  void initState() {
    super.initState();
    // Simulate loading shimmer
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(deliveryProvider);
    final filtered = _filter == null ? all : all.where((d) => d.status == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Delivery History',
            style: AppTextStyles.title(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                _FilterChip(label: 'All', selected: _filter == null,
                    onTap: () => setState(() => _filter = null)),
                const SizedBox(width: 8),
                ...DeliveryStatus.values.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: s.name[0].toUpperCase() + s.name.substring(1),
                        selected: _filter == s,
                        onTap: () => setState(() => _filter = s),
                        color: _statusColor(s),
                      ),
                    )),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms),

          // List
          Expanded(
            child: _loading
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemBuilder: (_, _) => const SkeletonCard(),
                  )
                : filtered.isEmpty
                    ? const EmptyStateWidget(
                        title: 'No Deliveries Found',
                        subtitle: 'Try changing the filter or request a new delivery.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => DeliveryCard(
                          delivery: filtered[i],
                          onTap: () {},
                        )
                            .animate(delay: Duration(milliseconds: i * 60))
                            .fadeIn()
                            .slideX(begin: 0.04),
                      ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(DeliveryStatus s) => switch (s) {
        DeliveryStatus.pending => AppColors.warning,
        DeliveryStatus.assigning => AppColors.info,
        DeliveryStatus.inTransit => AppColors.primary,
        DeliveryStatus.delivered => AppColors.success,
        DeliveryStatus.cancelled => AppColors.danger,
      };
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.15) : AppColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : AppColors.borderDark),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? c : AppColors.textSecondaryDark)),
      ),
    );
  }
}
