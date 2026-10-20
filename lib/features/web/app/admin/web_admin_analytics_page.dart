import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/delivery_model.dart';
import '../../../../core/models/drone_model.dart';
import '../../../../core/providers/delivery_provider.dart';
import '../../../../core/providers/drone_provider.dart';
import '../../../../core/services/analytics_export_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../web_kit.dart';
import 'web_admin_dashboard_page.dart';

/// Performance across deliveries, money, accounts and the fleet — the app's
/// analytics, laid out as a report. Package types are counted from what the
/// deliveries actually carried, not from a fixed list.
class WebAdminAnalyticsPage extends ConsumerStatefulWidget {
  const WebAdminAnalyticsPage({super.key});

  @override
  ConsumerState<WebAdminAnalyticsPage> createState() =>
      _WebAdminAnalyticsPageState();
}

class _WebAdminAnalyticsPageState extends ConsumerState<WebAdminAnalyticsPage> {
  int _users = 0, _active = 0, _suspended = 0, _deleted = 0;
  double _revenue = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      if (SupabaseService.isConfigured) {
        final c = SupabaseService.client;
        final users = List<Map<String, dynamic>>.from(
          await c.from('users').select('account_status'),
        );
        String s(Map<String, dynamic> u) =>
            (u['account_status'] ?? 'active').toString().toLowerCase();
        final paid = List<Map<String, dynamic>>.from(
          await c
              .from('orders')
              .select('total_amount')
              .eq('payment_status', 'paid'),
        );
        if (!mounted) return;
        setState(() {
          _users = users.length;
          _active = users.where((u) => s(u) == 'active').length;
          _suspended = users.where((u) => s(u) == 'suspended').length;
          _deleted = users.where((u) => s(u) == 'deleted').length;
          _revenue = paid.fold(
            0.0,
            (t, o) => t + (double.tryParse('${o['total_amount'] ?? 0}') ?? 0),
          );
        });
      }
    } catch (e) {
      debugPrint('Analytics stats: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    await ref.read(deliveryProvider.notifier).loadAdminDeliveriesFromSupabase();
    await ref.read(droneProvider.notifier).loadDronesFromSupabase();
    await _fetch();
  }

  Future<void> _export() async {
    var range = 2;
    final ranges = [
      AnalyticsDateRange.today,
      AnalyticsDateRange.last7Days,
      AnalyticsDateRange.last30Days,
      AnalyticsDateRange.thisMonth,
    ];
    final choice = await showDialog<(AnalyticsDateRange, bool)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Dialog(
          backgroundColor: AppColors.base,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Export a report', style: WebText.title(size: 19)),
                  const SizedBox(height: 6),
                  Text(
                    'Deliveries, revenue and accounts for the period you choose.',
                    style: WebText.body(size: 14),
                  ),
                  const SizedBox(height: 18),
                  WebTabs(
                    labels: const ['Today', '7 days', '30 days', 'This month'],
                    selected: range,
                    onSelected: (i) => set(() => range = i),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      WebButton(
                        label: 'Cancel',
                        kind: WebButtonKind.ghost,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      const Spacer(),
                      WebButton(
                        label: 'CSV',
                        icon: Icons.table_chart_outlined,
                        kind: WebButtonKind.secondary,
                        onPressed: () =>
                            Navigator.pop(ctx, (ranges[range](), false)),
                      ),
                      const SizedBox(width: 10),
                      WebButton(
                        label: 'PDF',
                        icon: Icons.picture_as_pdf_outlined,
                        onPressed: () =>
                            Navigator.pop(ctx, (ranges[range](), true)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final (r, pdf) = choice;
    showNeuSnack(context, pdf ? 'Preparing the PDF…' : 'Preparing the CSV…');
    try {
      final data = await AnalyticsExportService.fetchAnalyticsData(r);
      final bytes = pdf
          ? await AnalyticsExportService.generatePdf(data)
          : AnalyticsExportService.generateCsv(data);
      if (!mounted) return;
      final name =
          'aerodrop_analytics_${r.fileDateString}.${pdf ? 'pdf' : 'csv'}';
      final saved = await AnalyticsExportService.saveOrShareFile(
        bytes: Uint8List.fromList(bytes),
        fileName: name,
        mimeType: pdf ? 'application/pdf' : 'text/csv',
        context: context,
      );
      if (!mounted || saved == null) return;
      showNeuSnack(context, 'Report ready: $name', tone: NeuToneKind.success);
    } catch (e) {
      if (mounted) {
        showNeuSnack(context, 'The export failed: $e', tone: NeuToneKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = ref.watch(deliveryProvider);
    final drones = ref.watch(droneProvider);
    final total = deliveries.length;
    final delivered = deliveries
        .where((d) => d.status == DeliveryStatus.delivered)
        .length;
    final flying = deliveries
        .where((d) => d.status == DeliveryStatus.inTransit)
        .length;
    final now = DateTime.now();
    final today = deliveries
        .where(
          (d) =>
              d.createdAt.year == now.year &&
              d.createdAt.month == now.month &&
              d.createdAt.day == now.day,
        )
        .length;
    final timed = deliveries
        .where((d) => d.deliveryStartedAt != null && d.deliveredAt != null)
        .toList();
    final avgMinutes = timed.isEmpty
        ? null
        : timed.fold<int>(
                0,
                (s, d) =>
                    s +
                    d.deliveredAt!.difference(d.deliveryStartedAt!).inSeconds,
              ) /
              timed.length /
              60;

    final types = <String, int>{};
    for (final d in deliveries) {
      final t = d.packageType.trim().isEmpty ? 'Other' : d.packageType.trim();
      types.update(t, (n) => n + 1, ifAbsent: () => 1);
    }
    final typeRows = types.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    Widget share(String label, int n, int of, Color tone) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WebText.label(size: 13.5),
            ),
          ),
          Expanded(
            child: NeuSurface(
              style: NeuStyle.inset,
              depth: NeuDepth.flat,
              color: AppColors.surfaceSunken,
              height: 10,
              borderRadius: BorderRadius.circular(5),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: of == 0 ? 0 : (n / of).clamp(0.0, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Text(
              of == 0 ? '—' : '$n · ${(n / of * 100).round()}%',
              textAlign: TextAlign.right,
              style: WebText.body(size: 12.5, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );

    final tones = [
      AppColors.accentFill,
      AppColors.success,
      AppColors.warning,
      AppColors.primary,
      AppColors.danger,
    ];

    return WebPage(
      title: 'Analytics',
      subtitle: 'How deliveries, money and accounts are doing.',
      onRefresh: _refresh,
      actions: [
        WebButton(
          label: 'Export report',
          icon: Icons.download_rounded,
          onPressed: _export,
        ),
      ],
      children: [
        WebGrid(
          minTile: 210,
          children: [
            WebStat(
              label: 'Deliveries',
              value: '$total',
              icon: Icons.local_shipping_outlined,
              note: '$today today',
            ),
            WebStat(
              label: 'Delivered',
              value: total == 0
                  ? '—'
                  : '${(delivered / total * 100).toStringAsFixed(1)}%',
              icon: Icons.verified_outlined,
              tone: AppColors.success,
              note: '$delivered completed',
            ),
            WebStat(
              label: 'Average flight',
              value: avgMinutes == null
                  ? '—'
                  : '${avgMinutes.toStringAsFixed(1)} min',
              icon: Icons.timer_outlined,
              tone: AppColors.accent,
              note: '$flying in the air now',
            ),
            WebStat(
              label: 'Paid revenue',
              value: _loading ? '…' : WebText.peso(_revenue),
              icon: Icons.payments_outlined,
              tone: AppColors.primary,
              note: 'Orders marked paid',
            ),
          ],
        ),
        WebSplit(
          sideWidth: 400,
          breakpoint: 1060,
          main: WebPanel(
            title: 'Deliveries, last 7 days',
            child: WebWeekChart(deliveries: deliveries, height: 240),
          ),
          side: WebPanel(
            title: 'What was carried',
            subtitle: 'By package type.',
            child: typeRows.isEmpty
                ? Text('No deliveries yet.', style: WebText.body(size: 13.5))
                : Column(
                    children: [
                      for (var i = 0; i < typeRows.length && i < 5; i++)
                        share(
                          typeRows[i].key,
                          typeRows[i].value,
                          total,
                          tones[i % tones.length],
                        ),
                    ],
                  ),
          ),
        ),
        WebSplit(
          sideWidth: 400,
          breakpoint: 1060,
          main: WebPanel(
            title: 'Accounts',
            subtitle: _loading ? 'Loading…' : '$_users registered',
            child: Column(
              children: [
                share('Active', _active, _users, AppColors.success),
                share('Suspended', _suspended, _users, AppColors.warning),
                share('Deleted', _deleted, _users, AppColors.danger),
              ],
            ),
          ),
          side: WebPanel(
            title: 'Fleet',
            subtitle: '${drones.length} drones',
            child: Column(
              children: [
                for (final s in DroneStatus.values)
                  if (drones.any((d) => d.status == s))
                    share(
                      droneLabel(s),
                      drones.where((d) => d.status == s).length,
                      drones.length,
                      droneTone(s),
                    ),
                if (drones.isEmpty)
                  Text(
                    'No drones registered.',
                    style: WebText.body(size: 13.5),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
