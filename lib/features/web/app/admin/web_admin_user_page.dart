import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/order_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../../../../core/widgets/wide_shell.dart';
import '../web_kit.dart';
import '../web_status.dart';
import 'web_admin_users_page.dart' show askReason;

/// One account, for an administrator: who they are, their store if they
/// applied for one, their latest orders, and the account actions.
class WebAdminUserPage extends ConsumerStatefulWidget {
  const WebAdminUserPage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<WebAdminUserPage> createState() => _WebAdminUserPageState();
}

class _WebAdminUserPageState extends ConsumerState<WebAdminUserPage> {
  Map<String, dynamic>? _user;
  String? _location;
  List<OrderModel> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!SupabaseService.isConfigured) throw Exception('not configured');
      final c = SupabaseService.client;
      final row = await c
          .from('users')
          .select()
          .eq('id', widget.userId)
          .maybeSingle();
      if (row == null) {
        setState(() {
          _loading = false;
          _error = 'This account does not exist.';
        });
        return;
      }
      String? loc;
      final locId = row['campus_location_id'];
      if (locId != null && '$locId'.isNotEmpty) {
        loc =
            (await c
                    .from('campus_locations')
                    .select('name')
                    .eq('id', locId)
                    .maybeSingle())?['name']
                ?.toString();
      }
      var orders = <OrderModel>[];
      try {
        final column = row['role'] == 'vendor' ? 'vendor_id' : 'user_id';
        final res = await c
            .from('orders')
            .select('''
              *,
              vendor:users!vendor_id(full_name, business_name),
              customer:users!user_id(full_name, phone_number),
              campus_locations!delivery_location_id(name),
              order_items(product_id, product_name, quantity, unit_price, weight_grams),
              deliveries(id, status, progress, drone_id, estimated_delivery_seconds, delivery_started_at, delivery_completed_at, created_at)
            ''')
            .eq(column, widget.userId)
            .order('created_at', ascending: false)
            .limit(8);
        orders = [
          for (final o in res) OrderModel.fromMap(Map<String, dynamic>.from(o)),
        ];
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _user = Map<String, dynamic>.from(row);
        _location = loc;
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'The account could not be loaded.';
        });
      }
    }
  }

  Future<void> _suspend(String name) async {
    final reason = await askReason(
      context,
      title: 'Suspend $name?',
      message: 'They are blocked from signing in until reactivated.',
      initial: 'Suspended by admin',
      confirm: 'Suspend',
    );
    if (reason == null || !mounted) return;
    final err = await ref
        .read(authProvider.notifier)
        .suspendUser(widget.userId, reason: reason);
    _done(err, '$name is suspended.');
  }

  Future<void> _activate(String name) async {
    final err = await ref
        .read(authProvider.notifier)
        .activateUser(widget.userId);
    _done(err, '$name is active again.');
  }

  Future<void> _delete(String name) async {
    final reason = await askReason(
      context,
      title: 'Delete $name?',
      message: 'The account is closed. Delivery records are kept for history.',
      initial: 'Deleted by admin',
      confirm: 'Delete account',
    );
    if (reason == null || !mounted) return;
    final err = await ref
        .read(authProvider.notifier)
        .deleteUserAccount(widget.userId, reason: reason);
    _done(err, '$name\'s account is deleted.');
  }

  void _done(String? err, String ok) {
    if (!mounted) return;
    showNeuSnack(
      context,
      err ?? ok,
      tone: err == null ? NeuToneKind.success : NeuToneKind.error,
    );
    if (err == null) _fetch();
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _date(Object? v) {
    final d = v == null ? null : DateTime.tryParse('$v');
    return d == null ? 'Not available' : shortDate(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    void back() =>
        context.canPop() ? context.pop() : context.go('/admin/users');
    if (_loading) {
      return WebPage(
        title: 'Account',
        back: true,
        onBack: back,
        children: const [WebSkeleton(height: 220, radius: 24)],
      );
    }
    final u = _user;
    if (u == null) {
      return WebPage(
        title: 'Account',
        back: true,
        onBack: back,
        children: [
          WebEmpty(
            icon: Icons.person_off_outlined,
            title: _error ?? 'Account not found',
            message: 'It may have been removed.',
            action: WebButton(
              label: 'Try again',
              kind: WebButtonKind.secondary,
              onPressed: _fetch,
            ),
          ),
        ],
      );
    }

    final me = ref.watch(authProvider).user;
    final name = (u['full_name'] ?? 'No name').toString();
    final role = (u['role'] ?? 'user').toString();
    final status = (u['account_status'] ?? 'active').toString();
    final vendorStatus = u['vendor_status']?.toString();
    final self = me?.id == widget.userId;
    final manageable = !self && role != 'admin' && status != 'deleted';
    final statusTone = switch (status) {
      'active' => AppColors.success,
      'suspended' => AppColors.warning,
      _ => AppColors.danger,
    };

    final identity = WebPanel(
      depth: NeuDepth.medium,
      child: Column(
        children: [
          NeuSurface(
            borderRadius: BorderRadius.circular(60),
            padding: const EdgeInsets.all(6),
            child: WideAvatar(
              name: name,
              url: u['avatar_url']?.toString(),
              size: 92,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: WebText.title(size: 19),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              WebPill(
                label: switch (role) {
                  'admin' => 'Administrator',
                  'vendor' => 'Vendor',
                  _ => 'Customer',
                },
                tone: AppColors.accent,
              ),
              WebPill(label: _cap(status), tone: statusTone),
            ],
          ),
        ],
      ),
    );

    final profile = WebPanel(
      title: 'Profile',
      child: Column(
        children: [
          WebKeyValue('Email', (u['email'] ?? 'Not provided').toString()),
          WebKeyValue(
            'Phone',
            (u['phone_number']?.toString().isNotEmpty ?? false)
                ? u['phone_number'].toString()
                : 'Not provided',
          ),
          WebKeyValue('Member since', _date(u['created_at'])),
          WebKeyValue('Last updated', _date(u['updated_at'])),
        ],
      ),
    );

    final store = vendorStatus == null
        ? null
        : WebPanel(
            title: 'Store application',
            action: WebPill(
              label: vendorStatus == 'active' ? 'Approved' : _cap(vendorStatus),
              tone: switch (vendorStatus) {
                'active' => AppColors.success,
                'pending' => AppColors.primary,
                'suspended' => AppColors.warning,
                _ => AppColors.danger,
              },
            ),
            child: Column(
              children: [
                WebKeyValue(
                  'Store',
                  (u['business_name'] ?? 'Not provided').toString(),
                ),
                WebKeyValue(
                  'Category',
                  (u['business_category'] ?? 'Not provided').toString(),
                ),
                WebKeyValue('Building', _location ?? 'Not provided'),
                if ((u['business_description'] ?? '')
                    .toString()
                    .isNotEmpty) ...[
                  const WebGroove(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      u['business_description'].toString(),
                      style: WebText.body(size: 14),
                    ),
                  ),
                ],
              ],
            ),
          );

    final orders = WebPanel(
      title: role == 'vendor' ? 'Latest orders received' : 'Latest orders',
      child: _orders.isEmpty
          ? Text('No orders.', style: WebText.body(size: 13.5))
          : WebTable<OrderModel>(
              rows: _orders,
              columns: [
                WebColumn(
                  'Order',
                  (o) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(orderRef(o.id), style: WebText.label(size: 14)),
                      Text(
                        shortDate(o.createdAt),
                        style: WebText.body(size: 12),
                      ),
                    ],
                  ),
                  flex: 3,
                  primary: true,
                ),
                WebColumn(
                  role == 'vendor' ? 'Customer' : 'Canteen',
                  (o) => Text(
                    role == 'vendor' ? o.customerName : o.vendorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WebText.body(size: 13.5),
                  ),
                  flex: 3,
                ),
                WebColumn(
                  'Total',
                  (o) => Text(
                    WebText.peso(o.totalAmount),
                    style: WebText.label(size: 14),
                  ),
                  flex: 2,
                  align: Alignment.centerRight,
                ),
                WebColumn('Status', orderPill, flex: 3),
              ],
            ),
    );

    return WebPage(
      title: name,
      subtitle: self ? 'This is your account.' : (u['email'] ?? '').toString(),
      back: true,
      onBack: back,
      onRefresh: _fetch,
      actions: [
        if (manageable)
          WebButton(
            label: status == 'active' ? 'Suspend' : 'Activate',
            icon: status == 'active'
                ? Icons.pause_circle_outline_rounded
                : Icons.play_circle_outline_rounded,
            kind: WebButtonKind.secondary,
            onPressed: () =>
                status == 'active' ? _suspend(name) : _activate(name),
          ),
        if (manageable)
          WebButton(
            label: 'Delete account',
            icon: Icons.delete_outline_rounded,
            kind: WebButtonKind.danger,
            onPressed: () => _delete(name),
          ),
      ],
      children: [
        WebSplit(
          sideWidth: 320,
          sideFirstWhenStacked: true,
          side: identity,
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              profile,
              if (store != null) ...[const SizedBox(height: 22), store],
              const SizedBox(height: 22),
              orders,
            ],
          ),
        ),
      ],
    );
  }
}
