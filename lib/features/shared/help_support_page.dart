import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_back_button.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_feedback.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/services/supabase_service.dart';

class HelpSupportPage extends StatelessWidget {
  final String? orderId;
  final String? deliveryId;

  const HelpSupportPage({
    super.key,
    this.orderId,
    this.deliveryId,
  });

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
            'We support academic documents, books, laboratory samples, medical aid kits, and electronics up to a maximum chassis weight limit of 5.0 kg.',
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
                    Text(
                      'Help & Campus Support',
                      style: AppTextStyles.title(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
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
                        const SizedBox(height: 28),

                        // Support report form
                        Text(
                          'Submit a Support Request',
                          style: AppTextStyles.title(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SupportReportForm(
                          orderId: orderId,
                          deliveryId: deliveryId,
                        ),
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

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: AppTextStyles.body(fontSize: 13, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _SupportReportForm extends StatefulWidget {
  final String? orderId;
  final String? deliveryId;

  const _SupportReportForm({
    this.orderId,
    this.deliveryId,
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

      await SupabaseService.client.from('support_reports').insert(payload);

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
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showNeuSnack(context, 'Failed to submit report: $e', tone: NeuToneKind.error);
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
