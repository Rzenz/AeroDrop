import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/delivery_model.dart';
import '../../../../core/providers/delivery_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../web_kit.dart';
import '../web_status.dart';

typedef _Row = Map<String, dynamic>;

/// System logs as tables: delivery records, the pre-flight safety checks,
/// and the newest accounts — the app's three log tabs, from the same tables.
class WebAdminLogsPage extends ConsumerStatefulWidget {
  const WebAdminLogsPage({super.key});

  @override
  ConsumerState<WebAdminLogsPage> createState() => _WebAdminLogsPageState();
}

class _WebAdminLogsPageState extends ConsumerState<WebAdminLogsPage> {
  int _tab = 0;
  bool _loading = false;
  List<_Row> _checks = [];
  List<_Row> _accounts = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!SupabaseService.isConfigured) return;
    setState(() => _loading = true);
    final c = SupabaseService.client;
    try {
      _checks = List<_Row>.from(
        await c
            .from('delivery_safety_checks')
            .select()
            .order('checked_at', ascending: false)
            .limit(50),
      );
    } catch (_) {
      _checks = [];
    }
    try {
      _accounts = List<_Row>.from(
        await c
            .from('users')
            .select('id, full_name, email, role, created_at, account_status')
            .order('created_at', ascending: false)
            .limit(50),
      );
    } catch (_) {
      _accounts = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');

  @override
  Widget build(BuildContext context) {
    final deliveries = [...ref.watch(deliveryProvider)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    Widget empty(String title, String msg) =>
        WebEmpty(icon: Icons.receipt_long_outlined, title: title, message: msg);

    final Widget body = switch (_tab) {
      0 =>
        deliveries.isEmpty
            ? empty(
                'No delivery records',
                'Records appear once deliveries are dispatched.',
              )
            : WebTable<DeliveryModel>(
                rows: deliveries.take(50).toList(),
                onRowTap: (d) =>
                    context.push('/admin/deliveries/details?id=${d.id}'),
                columns: [
                  WebColumn(
                    'Delivery',
                    (d) => Text(orderRef(d.id), style: WebText.label(size: 14)),
                    flex: 2,
                    primary: true,
                  ),
                  WebColumn(
                    'Package',
                    (d) => Text(
                      d.packageName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WebText.body(size: 13.5),
                    ),
                    flex: 4,
                  ),
                  WebColumn(
                    'Drone',
                    (d) =>
                        Text(d.droneId ?? '—', style: WebText.body(size: 13.5)),
                    flex: 2,
                  ),
                  WebColumn('Status', deliveryPill, flex: 2),
                  WebColumn(
                    'When',
                    (d) => Text(
                      shortDate(d.createdAt),
                      style: WebText.body(size: 13),
                    ),
                    flex: 2,
                  ),
                ],
              ),
      1 =>
        _checks.isEmpty
            ? empty(
                'No safety checks yet',
                'Each dispatch records its pre-flight checks here.',
              )
            : WebTable<_Row>(
                rows: _checks,
                columns: [
                  WebColumn(
                    'Check',
                    (r) => Text(
                      (r['check_type'] ?? 'Safety check').toString(),
                      style: WebText.label(size: 14),
                    ),
                    flex: 3,
                    primary: true,
                  ),
                  WebColumn(
                    'Notes',
                    (r) => Text(
                      (r['notes'] ?? '—').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WebText.body(size: 13),
                    ),
                    flex: 5,
                  ),
                  WebColumn(
                    'Result',
                    (r) => r['passed'] == true
                        ? const WebPill(
                            label: 'Passed',
                            tone: AppColors.success,
                          )
                        : const WebPill(
                            label: 'Warning',
                            tone: AppColors.warning,
                          ),
                    flex: 2,
                  ),
                  WebColumn('When', (r) {
                    final d = _date(r['checked_at']);
                    return Text(
                      d == null ? '—' : ago(d),
                      style: WebText.body(size: 13),
                    );
                  }, flex: 2),
                ],
              ),
      _ =>
        _accounts.isEmpty
            ? empty('No accounts', 'New sign-ups appear here.')
            : WebTable<_Row>(
                rows: _accounts,
                onRowTap: (r) => context.push('/admin/users/${r['id']}'),
                columns: [
                  WebColumn(
                    'Account',
                    (r) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (r['full_name'] ?? 'User').toString(),
                          style: WebText.label(size: 14),
                        ),
                        Text(
                          (r['email'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WebText.body(size: 12.5),
                        ),
                      ],
                    ),
                    flex: 5,
                    primary: true,
                  ),
                  WebColumn(
                    'Role',
                    (r) => Text(switch (r['role']) {
                      'admin' => 'Administrator',
                      'vendor' => 'Vendor',
                      _ => 'Customer',
                    }, style: WebText.body(size: 13.5)),
                    flex: 2,
                  ),
                  WebColumn('Status', (r) {
                    final s = (r['account_status'] ?? 'active').toString();
                    return WebPill(
                      label: s[0].toUpperCase() + s.substring(1),
                      tone: switch (s) {
                        'active' => AppColors.success,
                        'suspended' => AppColors.warning,
                        _ => AppColors.danger,
                      },
                    );
                  }, flex: 2),
                  WebColumn('Joined', (r) {
                    final d = _date(r['created_at']);
                    return Text(
                      d == null ? '—' : shortDate(d),
                      style: WebText.body(size: 13),
                    );
                  }, flex: 2),
                ],
              ),
    };

    return WebPage(
      title: 'System logs',
      subtitle: 'What dispatched, what was checked, and who joined.',
      onRefresh: () async {
        await ref
            .read(deliveryProvider.notifier)
            .loadAdminDeliveriesFromSupabase();
        await _fetch();
      },
      children: [
        WebTabs(
          labels: const ['Deliveries', 'Safety checks', 'New accounts'],
          counts: [deliveries.length, _checks.length, _accounts.length],
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        if (_loading && _tab != 0)
          const WebSkeleton(height: 280, radius: 22)
        else
          body,
      ],
    );
  }
}
