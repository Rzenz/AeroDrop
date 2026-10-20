import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../web_breakpoints.dart';
import '../../web_tokens.dart';
import '../../widgets/web_motion.dart';
import '../../widgets/web_actions.dart';
import 'hero_section.dart' show shopLocation;

/// The closing call to action, on a panel filled with the app icon's own
/// gradient.
///
/// This is the page's only full-colour block outside the hero tiles, and its
/// colour is the night tile's scaled up: the last tile in the hero and the
/// last panel on the page are the same sky, so the scroll ends where the
/// browsing started. Rounded like the tiles, inset like the content, rather
/// than a full-bleed stripe.
class ClosingSection extends StatelessWidget {
  const ClosingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    return WebContentFrame(
      child: RevealOnScroll(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: brk.isCompact ? 24 : (brk.isMedium ? 48 : 72),
            vertical: brk.isCompact ? 48 : 88,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(brk.isCompact ? 24 : 32),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: WebInk.panel,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Text(
                  'Same account on a laptop in the library '
                  'or a phone between classes.',
                  style: WebType.title(brk, color: WebInk.onPanel),
                ),
              ),
              SizedBox(height: brk.isCompact ? 22 : 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  'Same cart, same order history, same flight in progress.',
                  style: WebType.lead(brk, color: WebInk.onPanel),
                ),
              ),
              SizedBox(height: brk.isCompact ? 34 : 44),
              const _ClosingActions(),
              SizedBox(height: brk.isCompact ? 40 : 56),
              const WebRule(color: WebInk.onPanelRule),
              const SizedBox(height: 22),
              // Stated here rather than only in the footer, because this is
              // where the page asks someone to sign up. A visitor should know
              // what they are signing into before they click, not after.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(
                  'AeroDrop is a prototype. Ordering, vendor management, '
                  'accounts and records are real and run on live data. Drone '
                  'flight, telemetry and weather are simulated — the system '
                  'does not yet control physical drone hardware.',
                  style: WebType.body(color: WebInk.onPanel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosingActions extends StatelessWidget {
  const _ClosingActions();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        return Wrap(
          spacing: 30,
          runSpacing: 20,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: WebFilledAction(
                label: 'Browse vendors',
                onPanel: true,
                onTap: () => context.go(shopLocation()),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: WebRuledAction(
                label: 'Create an account',
                onPanel: true,
                onTap: () => context.go('/register'),
              ),
            ),
          ],
        );
      },
    );
  }
}
