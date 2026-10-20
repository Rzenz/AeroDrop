import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../web_kit.dart';
import '../web_status.dart';

void _back(BuildContext context) =>
    context.canPop() ? context.pop() : context.go('/');

// ─── Help ────────────────────────────────────────────────────────────────────

/// Help and support: a ticket to the administrators beside answers to the
/// questions people actually ask. The ticket writes the same row as the
/// app's form.
///
/// The app's page also lists a phone number, an email address and an
/// operations office, and answers that give a 5 kg payload; none of those
/// is AeroDrop's, so the answers here follow the app's real rules and no
/// contact details are invented.
class WebHelpPage extends StatefulWidget {
  const WebHelpPage({super.key, this.orderId, this.deliveryId});

  final String? orderId;
  final String? deliveryId;

  @override
  State<WebHelpPage> createState() => _WebHelpPageState();
}

class _WebHelpPageState extends State<WebHelpPage> {
  static const _categories = [
    ('general', 'General question'),
    ('order_issue', 'An order or a payment'),
    ('delivery_issue', 'A drone or a delivery'),
    ('account', 'My account'),
    ('other', 'Something else'),
  ];

  static const _faq = [
    (
      'How do I order?',
      'Open Shop, add food from a campus canteen to your cart, then check '
          'out: choose the building pad it should land on and how to pay.',
    ),
    (
      'How much can one drone carry?',
      'Up to 0.5 kg per order. Checkout shows the weight of your cart and '
          'stops you before you go over.',
    ),
    (
      'What happens when the weather turns?',
      'Every flight is checked against campus weather first. When it is '
          'unsafe, flights are grounded and checkout pauses until it clears.',
    ),
    (
      'Can I cancel?',
      'Yes, until the canteen has packed it. Once it is ready for the drone '
          'or in the air, it can no longer be cancelled.',
    ),
    (
      'How do I pay?',
      'Online by GCash or card on the payment page, or with the simulated '
          'GCash and card options used for testing.',
    ),
  ];

  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'general';
  bool _sending = false;

  bool get _hasOrder => widget.orderId?.isNotEmpty ?? false;
  bool get _hasDelivery => widget.deliveryId?.isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    if (_hasDelivery) {
      _category = 'delivery_issue';
      _subject.text = _hasOrder
          ? 'Delivery issue (${orderRef(widget.orderId!)})'
          : 'Delivery issue';
    } else if (_hasOrder) {
      _category = 'order_issue';
      _subject.text = 'Order support (${orderRef(widget.orderId!)})';
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      showNeuSnack(
        context,
        subject.isEmpty ? 'Add a subject.' : 'Describe what happened.',
        tone: NeuToneKind.error,
      );
      return;
    }
    final user = SupabaseService.isConfigured
        ? SupabaseService.client.auth.currentUser
        : null;
    if (user == null) {
      showNeuSnack(
        context,
        'Sign in to send a ticket.',
        tone: NeuToneKind.error,
      );
      return;
    }
    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    try {
      await SupabaseService.client.from('support_reports').insert({
        'user_id': user.id,
        'subject': subject,
        'category': _category,
        'message': message,
        'status': 'open',
        if (_hasOrder) 'order_id': widget.orderId,
        if (_hasDelivery) 'delivery_id': widget.deliveryId,
      });
      if (!mounted) return;
      _subject.clear();
      _message.clear();
      setState(() => _category = 'general');
      showNeuSnack(
        context,
        'Ticket sent. The administrators will reply on your account.',
        tone: NeuToneKind.success,
      );
    } catch (e) {
      if (mounted) {
        showNeuSnack(
          context,
          'The ticket could not be sent: $e',
          tone: NeuToneKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = WebPanel(
      title: 'Send a ticket',
      subtitle: 'It goes to the AeroDrop administrators.',
      depth: NeuDepth.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hasOrder) ...[
            WebWell(
              radius: 14,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 18,
                    color: AppColors.accentText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Linked to order ${orderRef(widget.orderId!)}'
                      '${_hasDelivery ? ' and its delivery' : ''}',
                      style: WebText.label(size: 13.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'About',
            style: WebText.label(size: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _categories)
                WebChip(
                  label: c.$2,
                  selected: _category == c.$1,
                  onTap: () => setState(() => _category = c.$1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          WebField(
            label: 'Subject',
            controller: _subject,
            hint: 'What is it about?',
          ),
          const SizedBox(height: 16),
          WebField(
            label: 'Message',
            controller: _message,
            maxLines: 6,
            hint: 'What happened, and when.',
          ),
          const SizedBox(height: 20),
          WebButton(
            label: 'Send ticket',
            icon: Icons.send_rounded,
            expand: true,
            loading: _sending,
            onPressed: _send,
          ),
        ],
      ),
    );

    final faq = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Common questions', style: WebText.title(size: 18)),
        const SizedBox(height: 14),
        for (final f in _faq) ...[
          _Faq(question: f.$1, answer: f.$2),
          const SizedBox(height: 12),
        ],
      ],
    );

    return WebPage(
      title: 'Help and support',
      subtitle: 'Answers first, and a ticket when they are not enough.',
      back: true,
      onBack: () => _back(context),
      maxWidth: 1120,
      children: [
        WebSplit(main: faq, side: form, sideWidth: 440, breakpoint: 960),
      ],
    );
  }
}

class _Faq extends StatefulWidget {
  const _Faq({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  State<_Faq> createState() => _FaqState();
}

class _FaqState extends State<_Faq> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return WebHoverCard(
      onTap: () => setState(() => _open = !_open),
      radius: 18,
      semanticLabel: widget.question,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: const Cubic(0.2, 0, 0, 1),
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: WebText.label(size: 14.5),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (_open) ...[
              const SizedBox(height: 10),
              Text(widget.answer, style: WebText.body(size: 14)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── About ───────────────────────────────────────────────────────────────────

/// What AeroDrop is, in the landing page's own words, and the rules it
/// flies by.
class WebAboutPage extends StatelessWidget {
  const WebAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget step(int n, String title, String text) => WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeuSurface(
            style: NeuStyle.inset,
            color: AppColors.surfaceSunken,
            width: 40,
            height: 40,
            borderRadius: BorderRadius.circular(12),
            alignment: Alignment.center,
            child: Text(
              '$n',
              style: WebText.numeric(size: 17, color: AppColors.accentText),
            ),
          ),
          const SizedBox(height: 14),
          Text(title, style: WebText.title(size: 16)),
          const SizedBox(height: 6),
          Text(text, style: WebText.body(size: 14)),
        ],
      ),
    );

    return WebPage(
      title: 'About AeroDrop',
      subtitle: 'Campus delivery by drone, for the UCLM community.',
      back: true,
      onBack: () => _back(context),
      maxWidth: 1040,
      children: [
        WebPanel(
          depth: NeuDepth.medium,
          child: Text(
            'AeroDrop is the capstone project of fourth-year BSIT students at '
            'the University of Cebu Lapu-Lapu and Mandaue. Students, faculty '
            'and staff order from approved campus vendors, and a drone flies '
            'each order to their building.',
            style: WebText.body(size: 16, color: AppColors.textPrimary),
          ),
        ),
        WebGrid(
          minTile: 240,
          maxColumns: 3,
          children: [
            step(
              1,
              'Order',
              'Pick food from a campus canteen and choose the building it lands at.',
            ),
            step(
              2,
              'Prepared',
              'The canteen accepts it, cooks it and packs it for the drone.',
            ),
            step(
              3,
              'Flown',
              'A drone carries it across campus while you follow it on the map.',
            ),
          ],
        ),
        WebPanel(
          title: 'The rules it flies by',
          child: const Column(
            children: [
              WebKeyValue('Payload', 'Up to 0.5 kg per order'),
              WebKeyValue('Weather', 'Grounded when campus weather is unsafe'),
              WebKeyValue(
                'Airspace',
                'Kept out of the no-fly zones set by administrators',
              ),
              WebKeyValue(
                'Vendors',
                'Approved by an administrator before they sell',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Policies ────────────────────────────────────────────────────────────────

/// A policy document: its sections listed beside the text on a wide page.
class WebPolicyPage extends StatelessWidget {
  const WebPolicyPage({super.key, required this.title, required this.sections});

  final String title;
  final List<(String, String)> sections;

  static const privacy = WebPolicyPage(
    title: 'Privacy policy',
    sections: [
      (
        'Information collection',
        'AeroDrop collects basic user account profile details (Name, Email, and Department) and location specifications during flight dispatch requests. Live telemetry and flight coordinate parameters are audited solely for campus airspace coordination.',
      ),
      (
        'Use of information',
        'The collected specifications are utilized strictly to orchestrate automated drone dispatches, ensure proper package delivery to platforms, audit operator access roles, and prevent unauthorized airspace access.',
      ),
      (
        'Airspace safety and security',
        'We do not share any user metrics or coordinates with external third-party agencies. All flight logs and payload histories are stored locally inside UCLM secure servers and are subjected to role-based access restrictions.',
      ),
    ],
  );

  static const terms = WebPolicyPage(
    title: 'Terms and conditions',
    sections: [
      (
        'Payload responsibilities',
        'Users are solely responsible for verifying that their delivery items do not exceed the 5.0 kg maximum weight threshold and are non-hazardous, dry, and securely sealed before handing them to the drone deck loader.',
      ),
      (
        'Automated flight paths',
        'Flights are controlled by autonomous autopilot firmware following safe campus corridors. Users must not interfere with flight corridors, geofenced areas, or attempt unauthorized remote commands.',
      ),
      (
        'Liability and accidents',
        'UCLM and the drone fleet logistics team hold final authority for flight overrides. In the event of emergency landing, payload recovery will be handled by the nearest designated fleet support ground crew.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final body = WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const WebGroove(vertical: 18),
            Text('${i + 1}. ${sections[i].$1}', style: WebText.title(size: 17)),
            const SizedBox(height: 8),
            Text(sections[i].$2, style: WebText.body(size: 15)),
          ],
        ],
      ),
    );
    final contents = WebPanel(
      title: 'Contents',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sections.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '${i + 1}. ${sections[i].$1}',
                style: WebText.label(size: 14, weight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
    return WebPage(
      title: title,
      back: true,
      onBack: () => _back(context),
      maxWidth: 1040,
      children: [
        WebSplit(
          main: body,
          side: contents,
          sideWidth: 300,
          sideFirstWhenStacked: true,
        ),
      ],
    );
  }
}
