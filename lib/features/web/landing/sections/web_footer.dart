import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/brand_mark.dart';
import '../../web_breakpoints.dart';
import '../../web_tokens.dart';
import '../../widgets/web_motion.dart';
import 'hero_section.dart' show signInLocation;

/// Two link groups, not four.
///
/// The site has exactly two kinds of destination — pages that explain the
/// project and doors into the app — so Product / Company / Resources / Legal
/// would mean padding two columns with nothing. It sits on the canvas with
/// a hairline above it, so the page ends on the same night it started on.
class WebFooter extends StatelessWidget {
  const WebFooter({super.key});

  static const _about = <(String, String)>[
    ('Help and support', '/shared/help'),
    ('Privacy policy', '/shared/privacy-policy'),
    ('Terms and conditions', '/shared/terms-conditions'),
  ];

  static const _app = <(String, String)>[
    ('Browse vendors', '/user/shop'),
    ('Sign in', signInLocation),
    ('Create an account', '/register'),
    ('Apply as a vendor', '/register?role=vendor'),
  ];

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    return Container(
      padding: EdgeInsets.only(
        top: brk.isCompact ? 72 : 112,
        bottom: brk.isCompact ? 40 : 52,
      ),
      child: WebContentFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WebRule(),
            SizedBox(height: brk.isCompact ? 44 : 64),
            if (brk.isCompact)
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Identity(),
                  SizedBox(height: 40),
                  _LinkGroup('The project', _about),
                  SizedBox(height: 32),
                  _LinkGroup('Get in', _app),
                ],
              )
            else
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 42, child: _Identity()),
                  Spacer(flex: 10),
                  Expanded(flex: 26, child: _LinkGroup('The project', _about)),
                  Expanded(flex: 22, child: _LinkGroup('Get in', _app)),
                ],
              ),
            SizedBox(height: brk.isCompact ? 24 : 32),
          ],
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BrandMark(size: 28, elevated: false),
            const SizedBox(width: 11),
            Flexible(
              child: Text(
                'AeroDrop',
                overflow: TextOverflow.ellipsis,
                style: WebType.action(
                  color: WebInk.text,
                  weight: FontWeight.w700,
                ).copyWith(fontSize: 17, letterSpacing: -0.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Text(
            'Campus package delivery and drone flight operations for UCLM, '
            'built as one system for students, vendors and administrators.',
            style: WebType.body(color: WebInk.textSoft),
          ),
        ),
      ],
    );
  }
}

class _LinkGroup extends StatelessWidget {
  const _LinkGroup(this.title, this.links);

  final String title;
  final List<(String, String)> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: WebType.meta()),
        const SizedBox(height: 20),
        for (final (label, route) in links) ...[
          _FooterLink(label: label, route: route),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _FooterLink extends StatefulWidget {
  const _FooterLink({required this.label, required this.route});

  final String label;
  final String route;

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go(widget.route),
        child: AnimatedDefaultTextStyle(
          duration: WebMotion.hover,
          curve: WebMotion.enter,
          style: WebType.body(
            color: _hovered ? WebInk.text : WebInk.textSoft,
          ).copyWith(fontSize: 14.5),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}
