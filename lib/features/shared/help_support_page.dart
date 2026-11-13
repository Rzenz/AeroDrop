import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/support_report_model.dart';
import '../../core/providers/support_chat_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_back_button.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_feedback.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/services/supabase_service.dart';

/// The customer's and vendor's support home: their own reports, a "New
/// report" action that opens the submit form, and the help content.
class HelpSupportPage extends ConsumerStatefulWidget {
  final String? orderId;
  final String? deliveryId;

  const HelpSupportPage({
    super.key,
    this.orderId,
    this.deliveryId,
  });

  @override
  ConsumerState<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends ConsumerState<HelpSupportPage> {
  // Opened from an order or delivery, the user came to report something, so
  // the form starts open with that link filled in.
  late bool _showForm =
      (widget.orderId?.isNotEmpty ?? false) ||
      (widget.deliveryId?.isNotEmpty ?? false);

  Future<void> _openThread(String reportId) async {
    await context.push('/shared/support/$reportId');
    if (mounted) ref.invalidate(mySupportReportsProvider);
  }

  void _onReportSubmitted(String reportId) {
    setState(() => _showForm = false);
    ref.invalidate(mySupportReportsProvider);
    _openThread(reportId);
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> faqs = [
      {
        'q': 'How do I request a delivery?',
        'a':
            'Navigate to your Dashboard and tap the "+" FAB button or "Request Delivery". Input the recipient details, select the target building landing pad, pick your payment choice, and review before confirming checkout.',
      },
      {
        'q': 'What payloads can be delivered?',
        'a':
            'We support academic documents, books, laboratory samples, medical aid kits, and electronics up to 0.5 kg per drone trip. Orders up to 1.0 kg are flown in two trips.',
      },
      {
        'q': 'What happens in severe weather?',
        'a':
            'The fleet system automatically halts and queues dispatches if wind speeds exceed 15 knots or during heavy rain precipitation.',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.base,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    const NeuBackButton(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Help & Campus Support',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 16),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMyReports(),
                        const SizedBox(height: 28),

                        // Quick contact card
                        NeuCard(
                          padding: const EdgeInsets.all(16),
                          accent: AppColors.primary,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Campus Dispatch Desk',
                                style: AppTextStyles.title(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildContactRow(
                                Icons.phone_rounded,
                                '+63 (032) 345-6789',
                              ),
                              const SizedBox(height: 8),
                              _buildContactRow(
                                Icons.email_rounded,
                                'support@aerodrop.uclm.edu.ph',
                              ),
                              const SizedBox(height: 8),
                              _buildContactRow(
                                Icons.location_on_rounded,
                                'Old Building, 3rd Floor • Drone Operations Center',
                              ),
                              const SizedBox(height: 8),
                              _buildContactRow(
                                Icons.schedule_rounded,
                                'Mon–Sat: 7:00 AM – 7:00 PM',
                              ),
                            ],
                          ),
                        ).animate(delay: 100.ms).fadeIn(),
                        const SizedBox(height: 24),

                        // FAQs
                        Text(
                          'Frequently Asked Questions',
                          style: AppTextStyles.title(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(faqs.length, (i) {
                          final f = faqs[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: NeuCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.help_outline_rounded,
                                        color: AppColors.accent,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          f['q']!,
                                          style: AppTextStyles.title(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    f['a']!,
                                    style: AppTextStyles.body(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).animate(delay: Duration(milliseconds: 150 + i * 50)).fadeIn();
                        }),
                        const SizedBox(height: 12),

                        // Emergency note
                        NeuCard(
                          padding: const EdgeInsets.all(16),
                          accent: AppColors.danger,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.danger,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'In flight emergencies or hazard encounters, immediately notify campus security or dial dispatch at local 911.',
                                  style: AppTextStyles.body(
                                    fontSize: 12,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate(delay: 400.ms).fadeIn(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyReports() {
    final reports = ref.watch(mySupportReportsProvider);
    final Widget list = reports.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
      error: (e, _) => _ReportsNotice(
        icon: Icons.cloud_off_rounded,
        text: 'Could not load your reports. Tap to try again.',
        onTap: () => ref.invalidate(mySupportReportsProvider),
      ),
      data: (items) => items.isEmpty
          ? const _ReportsNotice(
              icon: Icons.inbox_outlined,
              text:
                  'No reports yet. Start one and our team will reply here.',
            )
          : Column(
              children: [
                for (final r in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReportTile(
                      report: r,
                      onTap: () => _openThread(r.id),
                    ),
                  ),
              ],
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'My Reports',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.title(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (_showForm) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Submit a Support Request',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _showForm = false),
                child: Text(
                  'Cancel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SupportReportForm(
            orderId: widget.orderId,
            deliveryId: widget.deliveryId,
            onSubmitted: _onReportSubmitted,
          ),
        ] else
          NeuButton(
            text: 'New Report',
            icon: Icons.add_comment_outlined,
            onPressed: () => setState(() => _showForm = true),
          ),
        const SizedBox(height: 16),
        list,
      ],
    ).animate(delay: 50.ms).fadeIn();
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportReportForm extends StatefulWidget {
  final String? orderId;
  final String? deliveryId;

  /// Called with the new report's id once it is saved.
  final ValueChanged<String> onSubmitted;

  const _SupportReportForm({
    this.orderId,
    this.deliveryId,
    required this.onSubmitted,
  });

  @override
  State<_SupportReportForm> createState() => _SupportReportFormState();
}

class _SupportReportFormState extends State<_SupportReportForm> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedCategory = 'general';
  bool _submitting = false;

  final _categories = const [
    {'value': 'general', 'label': 'General Inquiries'},
    {'value': 'order_issue', 'label': 'Order & Payment Issue'},
    {'value': 'delivery_issue', 'label': 'Drone & Delivery Issue'},
    {'value': 'account', 'label': 'Account & Profile'},
    {'value': 'other', 'label': 'Other Feedback'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.deliveryId != null && widget.deliveryId!.isNotEmpty) {
      _selectedCategory = 'delivery_issue';
      final orderRef = widget.orderId != null && widget.orderId!.isNotEmpty
          ? 'ORD-${widget.orderId!.replaceAll('-', '').substring(0, 8).toUpperCase()}'
          : '';
      _subjectController.text = orderRef.isNotEmpty ? 'Delivery Issue ($orderRef)' : 'Delivery Issue';
    } else if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      _selectedCategory = 'order_issue';
      final orderRef = 'ORD-${widget.orderId!.replaceAll('-', '').substring(0, 8).toUpperCase()}';
      _subjectController.text = 'Order Support ($orderRef)';
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (subject.isEmpty) {
      showNeuSnack(context, 'Please enter a subject', tone: NeuToneKind.error);
      return;
    }
    if (message.isEmpty) {
      showNeuSnack(context, 'Please describe your inquiry or issue', tone: NeuToneKind.error);
      return;
    }

    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      showNeuSnack(context, 'Please sign in to submit a support report', tone: NeuToneKind.error);
      return;
    }

    setState(() => _submitting = true);
    HapticFeedback.lightImpact();

    try {
      final payload = <String, dynamic>{
        'user_id': user.id,
        'subject': subject,
        'category': _selectedCategory,
        'message': message,
        'status': 'open',
      };
      if (widget.orderId != null && widget.orderId!.isNotEmpty) {
        payload['order_id'] = widget.orderId;
      }
      if (widget.deliveryId != null && widget.deliveryId!.isNotEmpty) {
        payload['delivery_id'] = widget.deliveryId;
      }

      final inserted = await SupabaseService.client
          .from('support_reports')
          .insert(payload)
          .select('id')
          .single();

      if (!mounted) return;
      _subjectController.clear();
      _messageController.clear();
      setState(() {
        _selectedCategory = 'general';
        _submitting = false;
      });

      showNeuSnack(
        context,
        'Support ticket submitted successfully! Our campus fleet team will review it.',
        tone: NeuToneKind.success,
      );
      final reportId = inserted['id']?.toString() ?? '';
      if (reportId.isNotEmpty) widget.onSubmitted(reportId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // A rate limit or policy refusal arrives as the server's own sentence;
      // show that, not the exception's debug dump.
      final reason = e is PostgrestException ? e.message : '$e';
      showNeuSnack(
        context,
        'Failed to submit report: $reason',
        tone: NeuToneKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.orderId != null && widget.orderId!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Linked Order: ORD-${widget.orderId!.replaceAll('-', '').substring(0, 8).toUpperCase()}${widget.deliveryId != null && widget.deliveryId!.isNotEmpty ? ' • Delivery Attached' : ''}',
                      style: AppTextStyles.caption(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          CustomTextField(
            labelText: 'Subject',
            hintText: 'Brief summary of your question or issue',
            controller: _subjectController,
            prefixIcon: Icons.title_rounded,
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category',
                style: AppTextStyles.caption(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor: AppColors.bgDark,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.accent),
                    style: AppTextStyles.body(color: AppColors.textPrimary),
                    items: _categories.map((c) {
                      return DropdownMenuItem<String>(
                        value: c['value'],
                        child: Text(c['label']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CustomTextField(
            labelText: 'Message',
            hintText: 'Provide details so our team can assist you faster...',
            controller: _messageController,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            prefixIcon: Icons.chat_bubble_outline_rounded,
          ),
          const SizedBox(height: 18),
          NeuButton(
            text: 'Submit Report',
            icon: Icons.send_rounded,
            isLoading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    ).animate(delay: 450.ms).fadeIn();
  }
}

/// One of the user's reports in the My Reports list.
class _ReportTile extends StatelessWidget {
  final SupportReportModel report;
  final VoidCallback onTap;
  const _ReportTile({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = report.isResolved
        ? AppColors.success
        : AppColors.warning;
    return NeuCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      semanticLabel: 'Open report ${report.subject}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.subject.isEmpty ? 'Support report' : report.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${report.categoryLabel} · ${_lastActivity(report.lastActivityAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (report.unreadCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${report.unreadCount}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                semanticsLabel: '${report.unreadCount} unread',
                style: AppTextStyles.caption(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.bgDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              report.statusLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _lastActivity(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${at.day}/${at.month}/${at.year}';
  }
}

/// Inline empty and error state for the My Reports list. The shared empty
/// and error widgets bring their own scroll view, which cannot sit inside
/// this page's.
class _ReportsNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  const _ReportsNotice({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
