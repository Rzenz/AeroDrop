import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/neu_feedback.dart';
import '../../core/services/supabase_service.dart';

class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen> {
  bool _loading = true;
  String _selectedFilter = 'all'; // 'all', 'open', 'resolved'
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _reports = [];
  Map<String, Map<String, dynamic>> _userMap = {};

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchReports() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      if (SupabaseService.isConfigured) {
        final reportsRes = await SupabaseService.client
            .from('support_reports')
            .select('*')
            .order('created_at', ascending: false);

        final List<Map<String, dynamic>> loadedReports =
            List<Map<String, dynamic>>.from(reportsRes);

        final userIds = loadedReports
            .map((r) => r['user_id']?.toString())
            .whereType<String>()
            .toSet()
            .toList();

        final Map<String, Map<String, dynamic>> loadedUsers = {};
        if (userIds.isNotEmpty) {
          try {
            final usersRes = await SupabaseService.client
                .from('users')
                .select('id, full_name, email, role')
                .filter('id', 'in', userIds);

            for (final u in usersRes) {
              loadedUsers[u['id'].toString()] = Map<String, dynamic>.from(u);
            }
          } catch (_) {
            // Ignore error fetching users; will fallback to user_id
          }
        }

        if (mounted) {
          setState(() {
            _reports = loadedReports;
            _userMap = loadedUsers;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showNeuSnack(context, 'Failed to load reports: $e', tone: NeuToneKind.error);
      }
    }
  }

  Future<void> _updateReportStatus(String reportId, String newStatus) async {
    HapticFeedback.lightImpact();
    try {
      final updates = <String, dynamic>{
        'status': newStatus,
        'resolved_at': newStatus == 'resolved' ? DateTime.now().toIso8601String() : null,
      };

      await SupabaseService.client
          .from('support_reports')
          .update(updates)
          .eq('id', reportId);

      if (!mounted) return;
      showNeuSnack(
        context,
        newStatus == 'resolved' ? 'Report marked as resolved' : 'Report reopened',
        tone: NeuToneKind.success,
      );
      _fetchReports();
    } catch (e) {
      if (!mounted) return;
      showNeuSnack(context, 'Update failed: $e', tone: NeuToneKind.error);
    }
  }

  Future<void> _editAdminNotes(String reportId, String currentNotes) async {
    final controller = TextEditingController(text: currentNotes);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF132031),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Admin Notes',
          style: AppTextStyles.title(fontSize: 18, color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: AppTextStyles.body(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Add internal resolution notes...',
            hintStyle: AppTextStyles.body(color: Colors.white54),
            filled: true,
            fillColor: AppColors.cardDark2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderDark),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.body(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.bgDark,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save Note'),
          ),
        ],
      ),
    );

    if (res != null) {
      try {
        await SupabaseService.client
            .from('support_reports')
            .update({'admin_notes': res})
            .eq('id', reportId);

        if (!mounted) return;
        showNeuSnack(context, 'Note saved successfully', tone: NeuToneKind.success);
        _fetchReports();
      } catch (e) {
        if (!mounted) return;
        showNeuSnack(context, 'Failed to save note: $e', tone: NeuToneKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _reports.where((r) {
      final status = (r['status'] ?? 'open').toString().toLowerCase();
      if (_selectedFilter != 'all' && status != _selectedFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final subject = (r['subject'] ?? '').toString().toLowerCase();
        final message = (r['message'] ?? '').toString().toLowerCase();
        final category = (r['category'] ?? '').toString().toLowerCase();
        final userId = r['user_id']?.toString() ?? '';
        final user = _userMap[userId];
        final userName = (user?['full_name'] ?? '').toString().toLowerCase();
        final userEmail = (user?['email'] ?? '').toString().toLowerCase();

        return subject.contains(_searchQuery) ||
            message.contains(_searchQuery) ||
            category.contains(_searchQuery) ||
            userName.contains(_searchQuery) ||
            userEmail.contains(_searchQuery);
      }
      return true;
    }).toList();

    final openCount = _reports.where((r) => (r['status'] ?? 'open') == 'open').length;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.bgDark,
          onRefresh: _fetchReports,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Support & Inquiries',
                                style: AppTextStyles.title(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$openCount open issue${openCount == 1 ? '' : 's'} needing attention',
                                style: AppTextStyles.body(
                                  fontSize: 13,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: openCount > 0
                                  ? AppColors.warning.withValues(alpha: 0.18)
                                  : AppColors.success.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: openCount > 0 ? AppColors.warning : AppColors.success,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              openCount > 0 ? '$openCount Open' : 'All Clear',
                              style: AppTextStyles.caption(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: openCount > 0 ? AppColors.warning : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Search bar
                      TextField(
                        controller: _searchController,
                        style: AppTextStyles.body(color: Colors.white),
                        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search by subject, user, or keyword...',
                          hintStyle: AppTextStyles.body(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white54),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF162338),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Filter chips
                      Row(
                        children: [
                          _FilterChip(
                            label: 'All (${_reports.length})',
                            isSelected: _selectedFilter == 'all',
                            onTap: () => setState(() => _selectedFilter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Open ($openCount)',
                            isSelected: _selectedFilter == 'open',
                            onTap: () => setState(() => _selectedFilter = 'open'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Resolved (${_reports.length - openCount})',
                            isSelected: _selectedFilter == 'resolved',
                            onTap: () => setState(() => _selectedFilter = 'resolved'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.support_agent_outlined,
                          size: 56,
                          color: Colors.white30,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No support reports found',
                          style: AppTextStyles.title(fontSize: 16, color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try changing your search keywords'
                              : 'Reports submitted by users will appear here',
                          style: AppTextStyles.body(fontSize: 13, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final report = filtered[index];
                        final reportId = report['id']?.toString() ?? '';
                        final userId = report['user_id']?.toString() ?? '';
                        final orderId = report['order_id']?.toString();
                        final deliveryId = report['delivery_id']?.toString();
                        final user = _userMap[userId];
                        final isResolved = (report['status'] ?? 'open') == 'resolved';
                        final category = report['category'] ?? 'general';
                        final subject = report['subject'] ?? 'No Subject';
                        final message = report['message'] ?? '';
                        final adminNotes = report['admin_notes'];
                        final createdAt = report['created_at'] != null
                            ? DateTime.tryParse(report['created_at'].toString())
                            : null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              _Badge(
                                                label: category.toString().toUpperCase().replaceAll('_', ' '),
                                                color: AppColors.accent,
                                              ),
                                              _Badge(
                                                label: isResolved ? 'RESOLVED' : 'OPEN',
                                                color: isResolved ? AppColors.success : AppColors.warning,
                                              ),
                                              if (orderId != null && orderId.isNotEmpty)
                                                _Badge(
                                                  label: 'ORD-${orderId.replaceAll('-', '').substring(0, 8).toUpperCase()}',
                                                  color: AppColors.info,
                                                  icon: Icons.receipt_long_rounded,
                                                ),
                                              if (deliveryId != null && deliveryId.isNotEmpty)
                                                _Badge(
                                                  label: 'DEL-${deliveryId.replaceAll('-', '').substring(0, 8).toUpperCase()}',
                                                  color: AppColors.primaryLight,
                                                  icon: Icons.navigation_rounded,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            subject,
                                            style: AppTextStyles.title(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (createdAt != null)
                                      Text(
                                        _formatDate(createdAt),
                                        style: AppTextStyles.caption(
                                          fontSize: 11,
                                          color: Colors.white54,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  message,
                                  style: AppTextStyles.body(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.88),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.accent),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          user != null
                                              ? '${user['full_name'] ?? 'User'} (${user['email'] ?? 'No email'}) • ${user['role'] ?? 'customer'}'
                                              : 'User ID: ${userId.substring(0, 8)}...',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.caption(fontSize: 12, color: Colors.white70),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (adminNotes != null && adminNotes.toString().isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.note_alt_outlined, size: 14, color: AppColors.accent),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Admin Note: $adminNotes',
                                            style: AppTextStyles.caption(
                                              fontSize: 12,
                                              color: AppColors.accent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                                      label: Text(
                                        adminNotes != null && adminNotes.toString().isNotEmpty
                                            ? 'Edit Note'
                                            : 'Add Note',
                                        style: AppTextStyles.caption(fontSize: 12),
                                      ),
                                      onPressed: () => _editAdminNotes(reportId, adminNotes?.toString() ?? ''),
                                    ),
                                    const SizedBox(width: 8),
                                    if (!isResolved)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.success,
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        icon: const Icon(Icons.check_rounded, size: 15),
                                        label: const Text('Resolve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        onPressed: () => _updateReportStatus(reportId, 'resolved'),
                                      )
                                    else
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.warning,
                                          side: const BorderSide(color: AppColors.warning),
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        icon: const Icon(Icons.replay_rounded, size: 15),
                                        label: const Text('Reopen', style: TextStyle(fontSize: 12)),
                                        onPressed: () => _updateReportStatus(reportId, 'open'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ).animate(delay: Duration(milliseconds: index * 40)).fadeIn().slideY(begin: 0.05);
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = months[dt.month - 1];
    final d = dt.day;
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$m $d • $h:$min $ampm';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.bgDark : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTextStyles.caption(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
