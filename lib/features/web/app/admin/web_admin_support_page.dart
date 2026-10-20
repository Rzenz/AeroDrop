import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../web_kit.dart';
import '../web_status.dart';

/// Support as an inbox: the tickets on the left, the open one on the right
/// with its message, the internal notes and the resolve action. The same
/// table reads and writes as the app's support screen.
class WebAdminSupportPage extends ConsumerStatefulWidget {
  const WebAdminSupportPage({super.key});

  @override
  ConsumerState<WebAdminSupportPage> createState() =>
      _WebAdminSupportPageState();
}

class _WebAdminSupportPageState extends ConsumerState<WebAdminSupportPage> {
  static const _filters = ['all', 'open', 'resolved'];

  bool _loading = true;
  int _filter = 1;
  String _query = '';
  final _search = TextEditingController();
  final _notes = TextEditingController();
  List<Map<String, dynamic>> _reports = [];
  Map<String, Map<String, dynamic>> _users = {};
  String? _openId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      if (SupabaseService.isConfigured) {
        final c = SupabaseService.client;
        final reports = List<Map<String, dynamic>>.from(
          await c
              .from('support_reports')
              .select('*')
              .order('created_at', ascending: false),
        );
        final ids = reports
            .map((r) => r['user_id']?.toString())
            .whereType<String>()
            .toSet()
            .toList();
        final users = <String, Map<String, dynamic>>{};
        if (ids.isNotEmpty) {
          try {
            for (final u
                in await c
                    .from('users')
                    .select('id, full_name, email, role')
                    .filter('id', 'in', ids)) {
              users[u['id'].toString()] = Map<String, dynamic>.from(u);
            }
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            _reports = reports;
            _users = users;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showNeuSnack(
          context,
          'Could not load tickets: $e',
          tone: NeuToneKind.error,
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setStatus(String id, String status) async {
    HapticFeedback.lightImpact();
    try {
      await SupabaseService.client
          .from('support_reports')
          .update({
            'status': status,
            'resolved_at': status == 'resolved'
                ? DateTime.now().toIso8601String()
                : null,
          })
          .eq('id', id);
      if (!mounted) return;
      showNeuSnack(
        context,
        status == 'resolved' ? 'Ticket resolved.' : 'Ticket reopened.',
        tone: NeuToneKind.success,
      );
      _fetch();
    } catch (e) {
      if (mounted) {
        showNeuSnack(context, 'Could not update: $e', tone: NeuToneKind.error);
      }
    }
  }

  Future<void> _saveNotes(String id) async {
    setState(() => _saving = true);
    try {
      await SupabaseService.client
          .from('support_reports')
          .update({'admin_notes': _notes.text})
          .eq('id', id);
      if (!mounted) return;
      showNeuSnack(context, 'Notes saved.', tone: NeuToneKind.success);
      _fetch();
    } catch (e) {
      if (mounted) {
        showNeuSnack(
          context,
          'Could not save notes: $e',
          tone: NeuToneKind.error,
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  void _open(Map<String, dynamic> r) {
    setState(() {
      _openId = r['id'].toString();
      _notes.text = (r['admin_notes'] ?? '').toString();
    });
  }

  String _status(Map<String, dynamic> r) =>
      (r['status'] ?? 'open').toString().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = _reports.where((r) {
      if (_filter != 0 && _status(r) != _filters[_filter]) return false;
      if (q.isEmpty) return true;
      final u = _users[r['user_id']?.toString() ?? ''];
      return [
        r['subject'],
        r['message'],
        r['category'],
        u?['full_name'],
        u?['email'],
      ].any((v) => (v ?? '').toString().toLowerCase().contains(q));
    }).toList();
    int count(int i) => i == 0
        ? _reports.length
        : _reports.where((r) => _status(r) == _filters[i]).length;
    final open = _reports
        .where((r) => r['id'].toString() == _openId)
        .firstOrNull;

    Widget tile(Map<String, dynamic> r) {
      final u = _users[r['user_id']?.toString() ?? ''];
      final created = DateTime.tryParse('${r['created_at'] ?? ''}');
      final selected = r['id'].toString() == _openId;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: WebHoverCard(
          onTap: () => _open(r),
          radius: 18,
          padding: const EdgeInsets.all(14),
          semanticLabel:
              '${r['subject'] ?? 'Ticket'} from ${u?['full_name'] ?? 'a user'}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (r['subject'] ?? 'No subject').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WebText.label(
                        size: 14,
                        color: selected ? AppColors.accentText : null,
                      ),
                    ),
                  ),
                  if (created != null)
                    Text(
                      ago(created),
                      style: WebText.body(
                        size: 11.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                (r['message'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: WebText.body(size: 12.5),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (u?['full_name'] ?? 'Unknown user').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WebText.body(
                        size: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  WebPill(
                    label: _status(r) == 'resolved' ? 'Resolved' : 'Open',
                    tone: _status(r) == 'resolved'
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final list = _loading && _reports.isEmpty
        ? Column(
            children: [
              for (var i = 0; i < 5; i++) ...[
                const WebSkeleton(height: 92, radius: 18),
                const SizedBox(height: 10),
              ],
            ],
          )
        : shown.isEmpty
        ? WebEmpty(
            icon: Icons.inbox_outlined,
            title: _reports.isEmpty ? 'No tickets yet' : 'Nothing here',
            message: _reports.isEmpty
                ? 'Tickets sent from Help and support land here.'
                : 'Try another filter or search.',
          )
        : Column(children: [for (final r in shown) tile(r)]);

    Widget detail(Map<String, dynamic> r) {
      final u = _users[r['user_id']?.toString() ?? ''];
      final created = DateTime.tryParse('${r['created_at'] ?? ''}');
      final resolved = _status(r) == 'resolved';
      final id = r['id'].toString();
      return WebPanel(
        depth: NeuDepth.medium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    (r['subject'] ?? 'No subject').toString(),
                    style: WebText.title(size: 19),
                  ),
                ),
                WebPill(
                  label: resolved ? 'Resolved' : 'Open',
                  tone: resolved ? AppColors.success : AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                Text(
                  '${u?['full_name'] ?? 'Unknown user'} · ${u?['email'] ?? r['user_id'] ?? ''}',
                  style: WebText.body(size: 13),
                ),
                Text(
                  (r['category'] ?? 'general').toString(),
                  style: WebText.label(size: 13, color: AppColors.accentText),
                ),
                if (created != null)
                  Text(shortDate(created), style: WebText.body(size: 13)),
              ],
            ),
            const WebGroove(vertical: 16),
            Text(
              (r['message'] ?? '').toString(),
              style: WebText.body(size: 15, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 22),
            Text(
              'Internal notes',
              style: WebText.label(size: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              maxLines: 4,
              cursorColor: AppColors.accentText,
              style: WebText.body(size: 14.5, color: AppColors.textPrimary),
              decoration: webInputDecoration(
                hint: 'What was done, who was told…',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                WebButton(
                  label: 'Save notes',
                  kind: WebButtonKind.secondary,
                  loading: _saving,
                  onPressed: () => _saveNotes(id),
                ),
                WebButton(
                  label: resolved ? 'Reopen' : 'Mark resolved',
                  icon: resolved ? Icons.undo_rounded : Icons.check_rounded,
                  onPressed: () =>
                      _setStatus(id, resolved ? 'open' : 'resolved'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final empty = WebWell(
      padding: const EdgeInsets.all(40),
      radius: 22,
      child: Column(
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 32,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text('Choose a ticket to read it', style: WebText.label(size: 14.5)),
        ],
      ),
    );

    return WebPage(
      title: 'Support',
      subtitle: '${count(1)} open ${count(1) == 1 ? 'ticket' : 'tickets'}',
      onRefresh: _fetch,
      actions: [
        WebSearch(
          controller: _search,
          hint: 'Search tickets or people',
          width: WebLayout.isCompact(context) ? null : 300,
          onChanged: (v) => setState(() => _query = v),
        ),
      ],
      children: [
        WebTabs(
          labels: const ['All', 'Open', 'Resolved'],
          counts: [count(0), count(1), count(2)],
          selected: _filter,
          onSelected: (i) => setState(() => _filter = i),
        ),
        LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth >= 920) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, child: list),
                  const SizedBox(width: 22),
                  Expanded(child: open == null ? empty : detail(open)),
                ],
              );
            }
            if (open != null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: WebButton(
                      label: 'All tickets',
                      icon: Icons.arrow_back_rounded,
                      kind: WebButtonKind.ghost,
                      onPressed: () => setState(() => _openId = null),
                    ),
                  ),
                  const SizedBox(height: 10),
                  detail(open),
                ],
              );
            }
            return list;
          },
        ),
      ],
    );
  }
}
