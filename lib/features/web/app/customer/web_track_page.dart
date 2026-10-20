import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/delivery_model.dart';
import '../../../../core/providers/delivery_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../../../../core/widgets/shared_drone_radar.dart';
import '../web_kit.dart';
import '../web_status.dart';

bool _active(DeliveryModel d) =>
    d.status == DeliveryStatus.inTransit ||
    d.status == DeliveryStatus.pending ||
    d.status == DeliveryStatus.assigning;

/// Live tracking as a map application lays it out: the campus map filling
/// the page, with the customer's deliveries in a list beside it. Choosing a
/// delivery puts it on the map. On a phone browser the map sits above the
/// list.
class WebTrackPage extends ConsumerStatefulWidget {
  const WebTrackPage({super.key});

  @override
  ConsumerState<WebTrackPage> createState() => _WebTrackPageState();
}

class _WebTrackPageState extends ConsumerState<WebTrackPage> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final all = [...ref.watch(deliveryProvider)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final active = all.where(_active).toList();
    final past = all.where((d) => !_active(d)).take(12).toList();
    final selected =
        all.where((d) => d.id == _selected).firstOrNull ??
        (active.isNotEmpty ? active.first : null);

    final map = NeuSurface(
      depth: NeuDepth.medium,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SharedDroneRadar(
          key: ValueKey(selected?.id),
          delivery: selected,
          title: selected == null
              ? 'Campus airspace'
              : deliveryLabel(selected.status),
          onTapDetails: selected == null
              ? null
              : () => context.push('/user/track/details?id=${selected.id}'),
        ),
      ),
    );

    Widget tile(DeliveryModel d) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WebHoverCard(
        onTap: () => setState(() => _selected = d.id),
        radius: 18,
        padding: const EdgeInsets.all(14),
        semanticLabel: '${deliveryLabel(d.status)}: ${d.packageName}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: WebPill(
                    label: deliveryLabel(d.status),
                    tone: deliveryTone(d.status),
                  ),
                ),
                if (d.id == selected?.id)
                  Icon(
                    Icons.my_location_rounded,
                    size: 18,
                    color: AppColors.accentText,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              d.packageName.isEmpty ? 'Your order' : d.packageName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: WebText.label(size: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '${d.senderName} → ${d.dropoffLocationName ?? d.deliveryAddress}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: WebText.body(size: 12.5),
            ),
            if (d.status == DeliveryStatus.inTransit) ...[
              const SizedBox(height: 10),
              NeuSurface(
                style: NeuStyle.inset,
                depth: NeuDepth.flat,
                color: AppColors.surfaceSunken,
                height: 6,
                borderRadius: BorderRadius.circular(3),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: d.progress.clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accentFill,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              if (d.eta.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Lands in about ${d.eta}',
                  style: WebText.body(size: 12.5),
                ),
              ],
            ] else ...[
              const SizedBox(height: 4),
              Text(
                ago(d.createdAt),
                style: WebText.body(size: 12, color: AppColors.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 24),
      children: [
        Text('In progress', style: WebText.overline()),
        const SizedBox(height: 10),
        if (active.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: WebEmpty(
              icon: Icons.flight_outlined,
              title: 'Nothing in the air',
              message: 'Place an order and its drone appears here.',
              action: WebButton(
                label: 'Order something',
                dense: true,
                onPressed: () => context.go('/user/shop'),
              ),
            ),
          ),
        for (final d in active) tile(d),
        if (past.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Earlier', style: WebText.overline()),
          const SizedBox(height: 10),
          for (final d in past) tile(d),
        ],
      ],
    );

    return WebPage.fill(
      title: 'Track',
      subtitle: active.isEmpty
          ? 'Your deliveries, live on the campus map.'
          : '${active.length} ${active.length == 1 ? 'delivery' : 'deliveries'} in progress',
      actions: [
        if (selected != null)
          WebButton(
            label: 'Flight details',
            icon: Icons.open_in_new_rounded,
            kind: WebButtonKind.secondary,
            onPressed: () =>
                context.push('/user/track/details?id=${selected.id}'),
          ),
      ],
      body: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth >= 900) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 340, child: list),
                  const SizedBox(width: 20),
                  Expanded(child: map),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: (box.maxHeight * 0.48).clamp(260.0, 420.0),
                child: map,
              ),
              const SizedBox(height: 16),
              Expanded(child: list),
            ],
          );
        },
      ),
    );
  }
}
