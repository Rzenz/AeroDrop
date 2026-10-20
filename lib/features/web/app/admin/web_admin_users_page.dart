import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/wide_shell.dart';
import '../web_kit.dart';

typedef _Row = Map<String, dynamic>;

/// Asks for a reason before a suspension or deletion. Returns null when
/// cancelled.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String message,
  required String initial,
  required String confirm,
}) async {
  final reason = TextEditingController(text: initial);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.base,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: WebText.title(size: 19)),
              const SizedBox(height: 8),
              Text(message, style: WebText.body(size: 14)),
              const SizedBox(height: 18),
              WebField(label: 'Reason', controller: reason),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  WebButton(
                    label: 'Cancel',
                    kind: WebButtonKind.secondary,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                  const SizedBox(width: 12),
                  WebButton(
                    label: confirm,
                    kind: WebButtonKind.danger,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  final text = reason.text;
  reason.dispose();
  return ok == true ? text : null;
}

/// People and vendor applications, as two tables. The same queries and
/// writes as the app's directory; an administrator cannot act on their own
/// account or on another administrator.
class WebAdminUsersPage extends ConsumerStatefulWidget {
  const WebAdminUsersPage({super.key});

  @override
  ConsumerState<WebAdminUsersPage> createState() => _WebAdminUsersPageState();
}

class _WebAdminUsersPageState extends ConsumerState<WebAdminUsersPage> {
  static const _people = ['All', 'Active', 'Suspended', 'Deleted'];
  static const _apps = ['Pending', 'Approved', 'Rejected', 'Suspended'];

  int _view = 0;
  int _peopleFilter = 0;
  int _appFilter = 0;
  List<_Row> _users = [];
  bool _loading = true;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      if (!SupabaseService.isConfigured) {
        setState(() {
          _users = [];
          _loading = false;
        });
        return;
      }
      final res = await SupabaseService.client.from('users').select('*');
      final users = [
        for (final u in res)
          <String, dynamic>{
            'id': u['id'].toString(),
            'email': u['email']?.toString() ?? '',
            'name':
                u['full_name']?.toString() ??
                u['email']?.toString().split('@').first ??
                'User',
            'role': u['role']?.toString() ?? 'user',
            'phone_number': u['phone_number']?.toString() ?? '',
            'account_status': u['account_status']?.toString() ?? 'active',
            'vendor_status': u['vendor_status']?.toString(),
            'business_name': u['business_name']?.toString(),
            'campus_location_id': u['campus_location_id']?.toString() ?? '',
            'avatar_url': u['avatar_url']?.toString(),
          },
      ];
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
      if (mounted) {
        setState(() {
          _users = [];
          _loading = false;
        });
      }
    }
  }

  void _say(String m, NeuToneKind t) {
    if (mounted) showNeuSnack(context, m, tone: t);
  }

  Future<void> _approve(String id, String name) async {
    final ok = await showNeuConfirm(
      context,
      title: 'Approve $name?',
      message: 'They can list products and take orders straight away.',
      confirmLabel: 'Approve',
      icon: Icons.verified_outlined,
    );
    if (!ok || !mounted) return;
    if (!SupabaseService.isConfigured) {
      return _say('Supabase is not configured.', NeuToneKind.error);
    }
    try {
      final c = SupabaseService.client;
      final r = await c.from('users').select().eq('id', id).maybeSingle();
      if (r == null) {
        return _say('This applicant has no profile record.', NeuToneKind.error);
      }
      final missing = [
        if ((r['business_name']?.toString() ?? '').trim().isEmpty)
          'business name',
        if ((r['campus_location_id']?.toString() ?? '').trim().isEmpty)
          'building',
      ];
      if (missing.isNotEmpty) {
        return _say(
          'Cannot approve yet — the application has no ${missing.join(' or ')}.',
          NeuToneKind.error,
        );
      }
      await c
          .from('users')
          .update({
            'role': 'vendor',
            'vendor_status': 'active',
            'account_status': 'active',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
      _say('${r['business_name']} is approved.', NeuToneKind.success);
      _fetch();
    } catch (e) {
      _say('Could not approve: $e', NeuToneKind.error);
    }
  }

  Future<void> _setVendor(
    String id,
    String name,
    String status, {
    required String title,
    required String message,
    required String confirm,
  }) async {
    final ok = await showNeuConfirm(
      context,
      title: title,
      message: message,
      confirmLabel: confirm,
      destructive: true,
      icon: Icons.block_rounded,
    );
    if (!ok || !mounted) return;
    try {
      await SupabaseService.client
          .from('users')
          .update({
            'vendor_status': status,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
      _say(
        status == 'rejected'
            ? 'Application from $name rejected.'
            : '$name is suspended.',
        NeuToneKind.warning,
      );
      _fetch();
    } catch (e) {
      _say('Could not update $name: $e', NeuToneKind.error);
    }
  }

  Future<void> _suspend(String id, String name) async {
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
        .suspendUser(id, reason: reason);
    _say(
      err == null ? '$name is suspended.' : 'Could not suspend: $err',
      err == null ? NeuToneKind.success : NeuToneKind.error,
    );
    if (err == null) _fetch();
  }

  Future<void> _activate(String id, String name) async {
    final err = await ref.read(authProvider.notifier).activateUser(id);
    _say(
      err == null ? '$name is active again.' : 'Could not activate: $err',
      err == null ? NeuToneKind.success : NeuToneKind.error,
    );
    if (err == null) _fetch();
  }

  Future<void> _delete(String id, String name) async {
    final reason = await askReason(
      context,
      title: 'Delete $name?',
      message:
          'The account is closed and cannot sign in. Delivery records are '
          'kept for history.',
      initial: 'Deleted by admin',
      confirm: 'Delete account',
    );
    if (reason == null || !mounted) return;
    final err = await ref
        .read(authProvider.notifier)
        .deleteUserAccount(id, reason: reason);
    _say(
      err == null ? '$name\'s account is deleted.' : 'Could not delete: $err',
      err == null ? NeuToneKind.success : NeuToneKind.error,
    );
    if (err == null) _fetch();
  }

  Color _statusTone(String s) => switch (s) {
    'active' => AppColors.success,
    'suspended' => AppColors.warning,
    'deleted' || 'rejected' => AppColors.danger,
    'pending' => AppColors.primary,
    _ => AppColors.textTertiaryDark,
  };

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).user;
    final locations = ref.watch(campusLocationsProvider).value ?? [];
    final q = _query.trim().toLowerCase();
    bool matches(_Row u, List<String> keys) =>
        q.isEmpty ||
        keys.any((k) => (u[k]?.toString() ?? '').toLowerCase().contains(q));

    final people = _users.where((u) {
      final s = (u['account_status'] as String).toLowerCase();
      return (_peopleFilter == 0 ||
              s == _people[_peopleFilter].toLowerCase()) &&
          matches(u, [
            'name',
            'email',
            'role',
            'phone_number',
            'account_status',
          ]);
    }).toList();
    int peopleCount(int i) => i == 0
        ? _users.length
        : _users
              .where((u) => u['account_status'] == _people[i].toLowerCase())
              .length;

    String appKey(int i) => i == 1 ? 'active' : _apps[i].toLowerCase();
    final applicants = _users.where((u) => u['vendor_status'] != null);
    final apps = applicants
        .where(
          (u) =>
              u['vendor_status'] == appKey(_appFilter) &&
              matches(u, ['name', 'business_name', 'email', 'phone_number']),
        )
        .toList();
    int appCount(int i) =>
        applicants.where((u) => u['vendor_status'] == appKey(i)).length;

    Widget person(_Row u) => Row(
      children: [
        WideAvatar(
          name: u['name'] as String,
          url: u['avatar_url'] as String?,
          size: 38,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                u['name'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WebText.label(size: 14),
              ),
              Text(
                u['email'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WebText.body(size: 12.5),
              ),
            ],
          ),
        ),
      ],
    );

    Widget peopleTable() => people.isEmpty
        ? const WebEmpty(
            icon: Icons.people_outline_rounded,
            title: 'Nobody here',
            message: 'Try another status or search.',
          )
        : WebTable<_Row>(
            rows: people,
            onRowTap: (u) => context.push('/admin/users/${u['id']}'),
            columns: [
              WebColumn('Person', person, flex: 5, primary: true),
              WebColumn(
                'Role',
                (u) => Text(
                  switch (u['role']) {
                    'admin' => 'Administrator',
                    'vendor' => 'Vendor',
                    _ => 'Customer',
                  },
                  style: WebText.body(size: 13.5, color: AppColors.textPrimary),
                ),
                flex: 2,
              ),
              WebColumn(
                'Phone',
                (u) => Text(
                  (u['phone_number'] as String).isEmpty
                      ? '—'
                      : u['phone_number'] as String,
                  style: WebText.body(size: 13.5),
                ),
                flex: 3,
              ),
              WebColumn(
                'Status',
                (u) => WebPill(
                  label: _cap(u['account_status'] as String),
                  tone: _statusTone(u['account_status'] as String),
                ),
                flex: 2,
              ),
            ],
            trailing: (u) {
              final self = me?.id == u['id'];
              final admin = u['role'] == 'admin';
              final status = u['account_status'] as String;
              if (self || admin || status == 'deleted') {
                return Text(
                  self ? 'You' : (admin ? 'Admin' : ''),
                  style: WebText.body(
                    size: 12.5,
                    color: AppColors.textTertiary,
                  ),
                );
              }
              final name = u['name'] as String;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WebIconButton(
                    icon: status == 'active'
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    tooltip: status == 'active' ? 'Suspend' : 'Activate',
                    size: 36,
                    color: AppColors.readable(
                      status == 'active'
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                    onPressed: () => status == 'active'
                        ? _suspend(u['id'], name)
                        : _activate(u['id'], name),
                  ),
                  const SizedBox(width: 4),
                  WebIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete account',
                    size: 36,
                    color: AppColors.readable(AppColors.danger),
                    onPressed: () => _delete(u['id'], name),
                  ),
                ],
              );
            },
          );

    Widget appsTable() => apps.isEmpty
        ? WebEmpty(
            icon: Icons.storefront_outlined,
            title: 'No ${_apps[_appFilter].toLowerCase()} applications',
            message: _appFilter == 0
                ? 'New vendor applications arrive here for review.'
                : 'Try another status.',
          )
        : WebTable<_Row>(
            rows: apps,
            onRowTap: (u) => context.push('/admin/users/${u['id']}'),
            columns: [
              WebColumn(
                'Store',
                (u) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (u['business_name'] as String?)?.isNotEmpty == true
                          ? u['business_name'] as String
                          : 'No store name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WebText.label(size: 14),
                    ),
                    Text(
                      u['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WebText.body(size: 12.5),
                    ),
                  ],
                ),
                flex: 4,
                primary: true,
              ),
              WebColumn(
                'Building',
                (u) => Text(
                  locations
                          .where((l) => l.id == u['campus_location_id'])
                          .firstOrNull
                          ?.name ??
                      'Not set',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WebText.body(size: 13.5),
                ),
                flex: 3,
              ),
              WebColumn(
                'Contact',
                (u) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u['email'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WebText.body(
                        size: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if ((u['phone_number'] as String).isNotEmpty)
                      Text(
                        u['phone_number'] as String,
                        style: WebText.body(size: 12),
                      ),
                  ],
                ),
                flex: 4,
              ),
              WebColumn('Status', (u) {
                final s = u['vendor_status'] as String;
                return WebPill(
                  label: s == 'active' ? 'Approved' : _cap(s),
                  tone: _statusTone(s),
                );
              }, flex: 2),
            ],
            trailing: (u) {
              final s = u['vendor_status'] as String;
              final name = (u['business_name'] as String?)?.isNotEmpty == true
                  ? u['business_name'] as String
                  : u['name'] as String;
              if (s == 'pending') {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    WebIconButton(
                      icon: Icons.check_rounded,
                      tooltip: 'Approve',
                      size: 36,
                      color: AppColors.readable(AppColors.success),
                      onPressed: () => _approve(u['id'], name),
                    ),
                    const SizedBox(width: 4),
                    WebIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Reject',
                      size: 36,
                      color: AppColors.readable(AppColors.danger),
                      onPressed: () => _setVendor(
                        u['id'],
                        name,
                        'rejected',
                        title: 'Reject $name?',
                        message: 'The application is turned down.',
                        confirm: 'Reject',
                      ),
                    ),
                  ],
                );
              }
              if (s == 'active') {
                return WebIconButton(
                  icon: Icons.pause_circle_outline_rounded,
                  tooltip: 'Suspend store',
                  size: 36,
                  color: AppColors.readable(AppColors.warning),
                  onPressed: () => _setVendor(
                    u['id'],
                    name,
                    'suspended',
                    title: 'Suspend $name?',
                    message: 'The store stops receiving orders.',
                    confirm: 'Suspend',
                  ),
                );
              }
              return WebIconButton(
                icon: Icons.restart_alt_rounded,
                tooltip: 'Re-activate and approve',
                size: 36,
                color: AppColors.readable(AppColors.success),
                onPressed: () => _approve(u['id'], name),
              );
            },
          );

    final pending = appCount(0);
    return WebPage(
      title: 'Users',
      subtitle: pending == 0
          ? '${_users.length} accounts'
          : '${_users.length} accounts · $pending vendor '
                '${pending == 1 ? 'application' : 'applications'} to review',
      onRefresh: _fetch,
      actions: [
        WebSearch(
          controller: _search,
          hint: _view == 0
              ? 'Search name, email, phone, role'
              : 'Search store, owner, email',
          width: WebLayout.isCompact(context) ? null : 320,
          onChanged: (v) => setState(() => _query = v),
        ),
      ],
      children: [
        WebTabs(
          labels: const ['People', 'Vendor applications'],
          counts: [_users.length, pending],
          selected: _view,
          onSelected: (i) => setState(() => _view = i),
        ),
        if (_view == 0)
          WebTabs(
            labels: _people,
            counts: [for (var i = 0; i < _people.length; i++) peopleCount(i)],
            selected: _peopleFilter,
            onSelected: (i) => setState(() => _peopleFilter = i),
          )
        else
          WebTabs(
            labels: _apps,
            counts: [for (var i = 0; i < _apps.length; i++) appCount(i)],
            selected: _appFilter,
            onSelected: (i) => setState(() => _appFilter = i),
          ),
        if (_loading && _users.isEmpty)
          Column(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                const WebSkeleton(height: 64, radius: 16),
              ],
            ],
          )
        else if (_view == 0)
          peopleTable()
        else
          appsTable(),
      ],
    );
  }
}
