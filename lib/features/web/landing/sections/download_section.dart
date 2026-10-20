import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../web_breakpoints.dart';
import '../../web_tokens.dart';
import '../../widgets/web_actions.dart';
import '../../widgets/web_home_screen_drop.dart';
import '../../widgets/web_motion.dart';
import 'hero_section.dart' show shopLocation;
import '../../../../core/theme/app_shadows.dart';

/// Where the store badges go.
///
/// TODO(release): replace both with AeroDrop's own listing pages before this
/// page goes live — `https://play.google.com/store/apps/details?id=<app id>`
/// and `https://apps.apple.com/app/id<numeric id>`. Until then the Play badge
/// opens a Play search, which already lists other apps named AeroDrop, and
/// the App Store badge opens Apple's App Store page, because Apple has no web
/// search. Google Play also rejects the current `com.example.aerodrop` app
/// ID, so the Android build needs its own ID before it can be listed.
const kPlayStoreUrl = 'https://play.google.com/store/search?q=AeroDrop&c=apps';
const kAppStoreUrl = 'https://www.apple.com/app-store/';

/// Download the app: how to get AeroDrop from Google Play or the App Store.
///
/// A platform switch picks the store; the steps, the store badge and the
/// phone beside them all follow it, and every pick replays the drone dropping
/// the icon onto that phone's home screen.
///
/// This is also the page's closing panel: a drone over a city at dusk, the
/// photograph the hero opens on seen from further away, so the scroll ends
/// where the browsing started.
class DownloadSection extends StatefulWidget {
  const DownloadSection({super.key});

  @override
  State<DownloadSection> createState() => _DownloadSectionState();
}

enum _Platform {
  android('Android', FontAwesomeIcons.googlePlay),
  iphone('iPhone', FontAwesomeIcons.apple);

  const _Platform(this.label, this.storeLogo);
  final String label;

  /// The store's own mark, shown on the tab and on the badge.
  final FaIconData storeLogo;

  WebPhoneKind get phone => switch (this) {
    _Platform.android => WebPhoneKind.android,
    _Platform.iphone => WebPhoneKind.iphone,
  };

  /// The store's install flow, in the store's own words for each control.
  List<String> get steps => switch (this) {
    _Platform.android => const [
      'Open the Google Play Store on your Android phone.',
      'Search for AeroDrop and open its page.',
      'Tap Install, then Open, and sign in to your account.',
    ],
    _Platform.iphone => const [
      'Open the App Store on your iPhone.',
      'Search for AeroDrop and open its page.',
      'Tap Get, confirm with Face ID or your passcode, then open it and '
          'sign in.',
    ],
  };
}

class _DownloadSectionState extends State<DownloadSection> {
  /// Starts on the visitor's own platform, which on the web build is the
  /// operating system the browser reports. Visitors on a computer start on
  /// Android, the more common phone on campus; either tab is one tap away.
  late _Platform _platform = defaultTargetPlatform == TargetPlatform.iOS
      ? _Platform.iphone
      : _Platform.android;

  /// Bumped on every tap of the switch, including the tab already showing,
  /// so the phone replays the drop each time a platform is chosen.
  int _replay = 0;

  void _choose(_Platform platform) => setState(() {
    _platform = platform;
    _replay++;
  });

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Download the app', style: WebType.meta(color: WebInk.onPanel)),
        const SizedBox(height: 18),
        Text(
          'IT LANDS ON\nYOUR HOME SCREEN.',
          style: WebType.displayAt(switch (brk) {
            WebBreak.expanded => 50,
            WebBreak.medium => 40,
            WebBreak.compact => 26,
          }, color: WebInk.onPanel).copyWith(height: 1.05),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'Get AeroDrop from Google Play or the App Store, and sign in with '
            'the same account you use on the web.',
            style: WebType.lead(brk, color: WebInk.onPanel),
          ),
        ),
        SizedBox(height: brk.isCompact ? 26 : 32),
        _PlatformSwitch(selected: _platform, onSelected: _choose),
        const SizedBox(height: 22),
        _Steps(platform: _platform),
        SizedBox(height: brk.isCompact ? 28 : 34),
        _Actions(platform: _platform),
      ],
    );

    final phoneWidth = switch (brk) {
      WebBreak.expanded => 270.0,
      WebBreak.medium => 220.0,
      WebBreak.compact => 220.0,
    };

    final phone = WebHomeScreenDrop(
      width: phoneWidth,
      kind: _platform.phone,
      replay: _replay,
    );

    return WebContentFrame(
      child: RevealOnScroll(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: brk.isCompact ? 22 : (brk.isMedium ? 44 : 72),
            vertical: brk.isCompact ? 40 : 72,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(brk.isCompact ? 24 : 32),
            boxShadow: WebInk.web.shadows(NeuDepth.high),
            color: WebInk.panel.last,
            // A drone over a skyline at dusk, under a flat navy wash so the
            // white copy and the store badge keep their contrast.
            image: DecorationImage(
              image: const AssetImage(WebPhoto.download),
              onError: WebPhoto.ignore,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.2),
              colorFilter: ColorFilter.mode(
                WebInk.panel.last.withValues(alpha: 0.74),
                BlendMode.srcOver,
              ),
            ),
          ),
          child: brk.isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    copy,
                    const SizedBox(height: 40),
                    Center(child: phone),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 58, child: copy),
                    SizedBox(width: brk.isMedium ? 32 : 56),
                    Expanded(flex: 42, child: Center(child: phone)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The selected store's badge, then a way in that needs no install.
class _Actions extends StatelessWidget {
  const _Actions({required this.platform});

  final _Platform platform;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 28,
      runSpacing: 18,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: WebMotion.hover,
          child: _StoreBadge(key: ValueKey(platform), platform: platform),
        ),
        WebRuledAction(
          label: 'Or use it in the browser',
          onPanel: true,
          onTap: () => context.go(shopLocation()),
        ),
      ],
    );
  }
}

/// A store badge in the stores' own format: black, the store's logo, a
/// small line above the store's name. Built rather than embedded as an image
/// so it stays sharp at any zoom and keeps the page's focus and hover states.
class _StoreBadge extends StatefulWidget {
  const _StoreBadge({super.key, required this.platform});

  final _Platform platform;

  @override
  State<_StoreBadge> createState() => _StoreBadgeState();
}

class _StoreBadgeState extends State<_StoreBadge> {
  bool _hovered = false;
  bool _focused = false;

  (String, String) get _wording => switch (widget.platform) {
    _Platform.android => ('GET IT ON', 'Google Play'),
    _Platform.iphone => ('Download on the', 'App Store'),
  };

  void _open() => launchUrl(
    Uri.parse(
      widget.platform == _Platform.android ? kPlayStoreUrl : kAppStoreUrl,
    ),
    webOnlyWindowName: '_blank',
  );

  @override
  Widget build(BuildContext context) {
    final (small, big) = _wording;
    final active = _hovered || _focused;

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
          label: '$small $big',
          onTap: _open,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: _open,
            child: AnimatedContainer(
              duration: WebMotion.hover,
              curve: WebMotion.enter,
              padding: const EdgeInsets.fromLTRB(16, 10, 22, 10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active
                      ? WebInk.onPanel
                      : WebInk.onPanel.withValues(alpha: 0.35),
                  width: _focused ? 2 : 1,
                ),
              ),
              // A badge scales as one piece on a narrow screen rather than
              // wrapping its store name onto a second line.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      widget.platform.storeLogo,
                      size: 26,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          small,
                          style: WebType.meta(
                            color: Colors.white,
                          ).copyWith(fontSize: 10.5, letterSpacing: 0.3),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          big,
                          style: WebType.action(
                            color: Colors.white,
                            weight: FontWeight.w700,
                          ).copyWith(fontSize: 19, letterSpacing: -0.2),
                        ),
                      ],
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

/// Android / iPhone, as a segmented control whose thumb slides
/// to the selection — the slide is state indication: it shows which set of
/// steps you are reading, and from where it came.
class _PlatformSwitch extends StatelessWidget {
  const _PlatformSwitch({required this.selected, required this.onSelected});

  final _Platform selected;
  final ValueChanged<_Platform> onSelected;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = _Platform.values.length;
        final segment = (constraints.maxWidth - 8) / count < 118
            ? (constraints.maxWidth - 8) / count
            : 118.0;

        return Container(
          height: 46,
          width: segment * count + 8,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: WebInk.onPanel.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                curve: WebMotion.enter,
                left: segment * selected.index,
                top: 0,
                bottom: 0,
                width: segment,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: WebInk.onPanel,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final p in _Platform.values)
                    _Segment(
                      width: segment,
                      label: p.label,
                      logo: p.storeLogo,
                      selected: p == selected,
                      onTap: () => onSelected(p),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Segment extends StatefulWidget {
  const _Segment({
    required this.width,
    required this.label,
    required this.logo,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String label;
  final FaIconData logo;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // Deep indigo on the white thumb, white on the track.
    final ink = widget.selected ? WebInk.panel.last : WebInk.onPanel;

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
            widget.onTap();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: '${widget.label} install steps',
        onTap: widget.onTap,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: widget.width,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: _focused
                  ? Border.all(color: WebInk.onPanel, width: 2)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(widget.logo, size: 15, color: ink),
                const SizedBox(width: 8),
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: WebMotion.hover,
                    curve: WebMotion.enter,
                    style: WebType.action(color: ink, weight: FontWeight.w700),
                    child: Text(widget.label, maxLines: 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.platform});
  final _Platform platform;

  @override
  Widget build(BuildContext context) {
    final steps = platform.steps;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: WebMotion.enter)),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(platform),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: WebInk.onPanel.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: WebType.numeral(
                      WebBreak.compact,
                      color: WebInk.onPanel,
                    ).copyWith(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      steps[i],
                      style: WebType.body(
                        color: WebInk.onPanel,
                      ).copyWith(fontSize: 15, height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
