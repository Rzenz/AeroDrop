import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/delivery_model.dart';
import '../../../../core/providers/delivery_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../web_kit.dart';
import '../web_status.dart';

/// Dispatch: every delivery in a table filtered by status, with the
/// approve-and-assign and reject actions on those waiting.
class WebAdminDeliveriesPage extends ConsumerStatefulWidget {
  const WebAdminDeliveriesPage({super.key});

  @override
  ConsumerState<WebAdminDeliveriesPage> createState() =>
      _WebAdminDeliveriesPageState();
}

class _WebAdminDeliveriesPageState
    extends ConsumerState<WebAdminDeliveriesPage> {
  static const _filters = <(String, DeliveryStatus?)>[
    ('All', null),
    ('Waiting', DeliveryStatus.pending),
    ('Assigning', DeliveryStatus.assigning),
    ('In flight', DeliveryStatus.inTransit),
    ('Delivered', DeliveryStatus.delivered),
    ('Cancelled', DeliveryStatus.cancelled),
  ];

  int _filter = 0;
  bool _loading = true;
  final _busy = <String>{};
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(_fetch);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (mounted) setState(() => _loading = true);
    await ref.read(deliveryProvider.notifier).loadAdminDeliveriesFromSupabase();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _accept(DeliveryModel d) async {
    setState(() => _busy.add(d.id));
    final err = await ref.read(deliveryProvider.notifier).acceptDelivery(d.id);
    if (!mounted) return;
    setState(() => _busy.remove(d.id));
    showNeuSnack(
      context,
      err == null
          ? 'Approved — a drone is assigned.'
          : 'Could not approve: $err',
      tone: err == null ? NeuToneKind.success : NeuToneKind.error,
    );
    if (err == null) _fetch();
  }

  Future<void> _reject(DeliveryModel d) async {
    final ok = await showNeuConfirm(
      context,
      title: 'Reject this delivery?',
      message:
          'The customer and the canteen are told it will not fly. This '
          'cannot be undone.',
      confirmLabel: 'Reject',
      destructive: true,
      icon: Icons.block_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _busy.add(d.id));
    final err = await ref.read(deliveryProvider.notifier).rejectDelivery(d.id);
    if (!mounted) return;
    setState(() => _busy.remove(d.id));
    showNeuSnack(
      context,
      err == null ? 'Delivery rejected.' : 'Could not reject: $err',
      tone: err == null ? NeuToneKind.success : NeuToneKind.error,
    );
    if (err == null) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final all = [...ref.watch(deliveryProvider)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    int count(DeliveryStatus? s) =>
        s == null ? all.length : all.where((d) => d.status == s).length;
    final status = _filters[_filter].$2;
    final q = _query.trim().toLowerCase();
    final rows = all
        .where(
          (d) =>
              (status == null || d.status == status) &&
              (q.isEmpty ||
                  d.packageName.toLowerCase().contains(q) ||
                  d.senderName.toLowerCase().contains(q) ||
                  d.recipientName.toLowerCase().contains(q) ||
                  d.id.toLowerCase().contains(q)),
        )
        .toList();
    final waiting = count(DeliveryStatus.pending);

    Widget body;
    if (_loading && all.isEmpty) {
      body = Column(
        children: [
          for (var i = 0; i < 6; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            const WebSkeleton(height: 66, radius: 16),
          ],
        ],
      );
    } else if (rows.isEmpty) {
      body = WebEmpty(
        icon: Icons.local_shipping_outlined,
        title: all.isEmpty ? 'No deliveries yet' : 'Nothing matches that',
        message: all.isEmpty
            ? 'Deliveries appear here as soon as customers place orders.'
            : 'Try another status or search.',
      );
    } else {
      body = WebTable<DeliveryModel>(
        rows: rows,
        onRowTap: (d) => context.push('/admin/deliveries/details?id=${d.id}'),
        columns: [
          WebColumn(
            'Delivery',
            (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.packageName.isEmpty ? orderRef(d.id) : d.packageName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: WebText.label(size: 14),
                ),
                Text(
                  '${orderRef(d.id)} · ${ago(d.createdAt)}',
                  style: WebText.body(size: 12),
                ),
              ],
            ),
            flex: 4,
            primary: true,
          ),
          WebColumn(
            'From',
            (d) => Text(
              d.senderName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: WebText.body(size: 13.5),
            ),
            flex: 3,
          ),
          WebColumn(
            'To',
            (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.dropoffLocationName ?? d.deliveryAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WebText.body(size: 13.5, color: AppColors.textPrimary),
                ),
                Text(
                  d.recipientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WebText.body(size: 12),
                ),
              ],
            ),
            flex: 3,
          ),
          WebColumn(
            'Weight',
            (d) => Text(
              '${(d.packageWeight * 1000).round()} g',
              style: WebText.body(size: 13.5),
            ),
            flex: 2,
          ),
          WebColumn(
            'Status',
            (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                deliveryPill(d),
                if (d.status == DeliveryStatus.cancelled)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      d.cancellationReasonDisplay,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WebText.body(size: 11.5),
                    ),
                  ),
              ],
            ),
            flex: 3,
          ),
        ],
        trailing: (d) => d.status != DeliveryStatus.pending
            ? const SizedBox.shrink()
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WebIconButton(
                    icon: Icons.check_rounded,
                    tooltip: 'Approve and assign a drone',
                    size: 36,
                    color: AppColors.readable(AppColors.success),
                    onPressed: _busy.contains(d.id) ? null : () => _accept(d),
                  ),
                  const SizedBox(width: 4),
                  WebIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Reject',
                    size: 36,
                    color: AppColors.readable(AppColors.danger),
                    onPressed: _busy.contains(d.id) ? null : () => _reject(d),
                  ),
                ],
              ),
      );
    }

    return WebPage(
      title: 'Deliveries',
      subtitle: waiting == 0
          ? 'Nothing waiting for approval.'
          : '$waiting waiting for approval',
      onRefresh: _fetch,
      actions: [
        WebSearch(
          controller: _search,
          hint: 'Search package, canteen or customer',
          width: WebLayout.isCompact(context) ? null : 320,
          onChanged: (v) => setState(() => _query = v),
        ),
      ],
      children: [
        WebTabs(
          labels: [for (final f in _filters) f.$1],
          counts: [for (final f in _filters) count(f.$2)],
          selected: _filter,
          onSelected: (i) => setState(() => _filter = i),
        ),
        body,
      ],
    );
  }
}
