import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../web_breakpoints.dart';
import '../../web_tokens.dart';
import '../../widgets/web_motion.dart';
import '../../../../core/widgets/neu_surface.dart';

/// Contacts: the ways to reach the people behind AeroDrop.
///
/// Only channels that exist and are answered are listed. There is no email
/// address or phone number here on purpose: the ones in the app's Help screen
/// are placeholders, and a public page that prints a number nobody answers is
/// worse than one that prints none (R-38). Add them to [_channels] once real
/// ones exist.
///
/// Composition: a split heading, then full-width rows set large. It is a
/// different shape from About's two columns, so the page keeps changing
/// rhythm as it scrolls (R-05).
class ContactsSection extends StatelessWidget {
  const ContactsSection({super.key});

  static final _channels = <_Channel>[
    const _Channel(
      icon: Icons.forum_outlined,
      label: 'Help and support',
      value: 'Send a ticket from the app',
      note:
          'It goes to the administrators. Sign in first so they can reply '
          'to your account.',
      route: '/shared/help',
    ),
    _Channel(
      icon: Icons.storefront_outlined,
      label: 'Sell on AeroDrop',
      value: 'Apply as a campus vendor',
      note:
          'Four short steps. An administrator reviews each '
          'application before the store opens.',
      route: '/register?role=vendor',
    ),
    _Channel(
      icon: Icons.place_outlined,
      label: 'Where we are',
      value: 'University of Cebu Lapu-Lapu and Mandaue',
      note: 'Mandaue City, Cebu. Opens in OpenStreetMap.',
      url: Uri.parse(
        'https://www.openstreetmap.org/search?query='
        'University%20of%20Cebu%20Lapu-Lapu%20and%20Mandaue',
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Contacts', style: WebType.meta(color: WebInk.accent)),
        const SizedBox(height: 18),
        Text('Talk to the team behind it.', style: WebType.title(brk)),
      ],
    );

    final note = Text(
      'AeroDrop is a student project, not a company with a call centre. '
      'These are the channels that reach the people who built it and the '
      'people who run it on campus.',
      style: WebType.body(),
    );

    return WebContentFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RevealOnScroll(
            child: brk.isExpanded
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(flex: 56, child: title),
                      const SizedBox(width: 48),
                      Expanded(
                        flex: 44,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: note,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 18), note],
                  ),
          ),
          SizedBox(height: brk.isCompact ? 36 : 56),
          // Each channel is its own raised card; the gap between them does
          // the work the hairlines used to.
          for (var i = 0; i < _channels.length; i++) ...[
            if (i > 0) SizedBox(height: brk.isCompact ? 16 : 22),
            RevealOnScroll(
              delay: WebMotion.stagger * i,
              child: _ChannelRow(_channels[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Channel {
  const _Channel({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    this.route,
    this.url,
  });

  final IconData icon;

  final String label;
  final String value;
  final String note;

  /// In-app destination. Exactly one of [route] and [url] is set (R-24).
  final String? route;

  /// Off-site destination, opened in a new tab.
  final Uri? url;

  bool get external => url != null;
}

/// One contact channel as one large target.
///
/// On hover a raised fill sweeps in from the left and the arrow steps 4px in
/// its direction — the row says it is a link without any of it moving out of
/// place. The arrow is the one directional cue on the page (R-08): → for a
/// page inside AeroDrop, ↗ for one that leaves it.
class _ChannelRow extends StatefulWidget {
  const _ChannelRow(this.channel);
  final _Channel channel;

  @override
  State<_ChannelRow> createState() => _ChannelRowState();
}

class _ChannelRowState extends State<_ChannelRow> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  void _open() {
    final c = widget.channel;
    if (c.url != null) {
      launchUrl(c.url!, webOnlyWindowName: '_blank');
    } else {
      context.go(c.route!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);
    final c = widget.channel;
    final active = _hovered || _focused;
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // Pressed into the card, like the icon wells in About.
    final mark = NeuSurface(
      style: NeuStyle.inset,
      palette: WebInk.web,
      color: WebInk.web.sunken,
      width: brk.isCompact ? 40 : 48,
      height: brk.isCompact ? 40 : 48,
      borderRadius: BorderRadius.circular(brk.isCompact ? 12 : 14),
      alignment: Alignment.center,
      child: Icon(
        c.icon,
        size: brk.isCompact ? 19 : 22,
        color: WebInk.accent,
      ),
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(c.label, style: WebType.meta()),
        const SizedBox(height: 6),
        Text(
          c.value,
          style: WebType.entry(brk).copyWith(fontSize: brk.isCompact ? 18 : 24),
        ),
        const SizedBox(height: 6),
        Text(c.note, style: WebType.body().copyWith(fontSize: 14.5)),
      ],
    );

    final arrow = TweenAnimationBuilder<double>(
      tween: Tween(end: active && !reduced ? 1 : 0),
      duration: WebMotion.hover,
      curve: WebMotion.enter,
      builder: (context, t, child) => Transform.translate(
        offset: c.external ? Offset(4 * t, -4 * t) : Offset(4 * t, 0),
        child: child,
      ),
      child: Icon(
        c.external ? Icons.north_east_rounded : Icons.arrow_forward_rounded,
        size: 22,
        color: active ? WebInk.accent : WebInk.textSoft,
      ),
    );

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _open();
            return null;
          },
        ),
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Semantics(
          link: true,
          label: '${c.label}: ${c.value}. ${c.note}',
          onTap: _open,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: _open,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            // A raised card: attention lifts it, pressing sinks it into the
            // canvas. Focus adds the accent ring.
            child: AnimatedContainer(
              duration: WebMotion.hover,
              curve: WebMotion.enter,
              decoration: BoxDecoration(
                color: _pressed ? WebInk.web.sunken : WebInk.canvas,
                borderRadius: BorderRadius.circular(brk.isCompact ? 20 : 24),
                boxShadow: _pressed
                    ? const []
                    : WebInk.web.shadows(
                        active && !reduced ? NeuDepth.medium : NeuDepth.low,
                      ),
                border: _focused
                    ? Border.all(color: WebInk.accent, width: 2)
                    : null,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: brk.isCompact ? 20 : 26,
                  horizontal: brk.isCompact ? 18 : 26,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    mark,
                    SizedBox(width: brk.isCompact ? 16 : 26),
                    Expanded(child: text),
                    const SizedBox(width: 16),
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: arrow,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
