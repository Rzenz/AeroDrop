import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../web_breakpoints.dart';
import '../../web_tokens.dart';
import '../../widgets/web_motion.dart';
import '../../widgets/web_phone_browse.dart';
import '../web_nav_bar.dart';
import '../../../../core/theme/app_shadows.dart';

/// Where a canteen tile sends the visitor: the app's Shop screen with the
/// canteen's building already in the store search. Signed-out visitors are
/// sent through sign-in by the router and land here afterwards.
/// The sign-in page, marked as coming from this page so the router shows it
/// even to a visitor who still has a session.
const signInLocation = '/login?from=landing';

String shopLocation({String? search}) => search == null
    ? '/user/shop'
    : '/user/shop?search=${Uri.encodeQueryComponent(search)}';

/// The hero, composed after the reference: a short line, a centred display
/// headline, a tilted phone, and photographed canteen tiles around it.
///
/// What changed from the reference and why:
/// - The tiles are not tips. Each is a campus canteen and opens the app's
///   Shop searched to its building, so the hero is the first step of
///   ordering rather than a mood board (C-3).
/// - Their colours run through a school day, first class to evening
///   ([WebSky]), read left to right — not unrelated pastels (R-01).
/// - The phone shows the app's Shop screen listing the same canteens, and
///   hovering a tile types its building into the search there — the tile and
///   the screen are one thing.
class HeroSection extends StatefulWidget {
  const HeroSection({super.key});

  /// Shared with the phone. `search` is what the Shop's store search
  /// receives; it matches a vendor's building name.
  static const canteens = <WebCanteen>[
    WebCanteen(
      'Annex Building Canteen',
      WebSky.dawn,
      search: 'Annex',
      photo: WebPhoto.annex,
    ),
    WebCanteen(
      'Old Building Canteen',
      WebSky.noon,
      search: 'Old Building',
      photo: WebPhoto.oldBuilding,
    ),
    WebCanteen(
      'Engineering Building Canteen',
      WebSky.dusk,
      search: 'Engineering',
      photo: WebPhoto.engineering,
    ),
    WebCanteen(
      'Maritime Building Canteen',
      WebSky.night,
      search: 'Maritime',
      photo: WebPhoto.maritime,
    ),
  ];

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  final _focus = ValueNotifier<String?>(null);

  /// False until the hero's webfonts have arrived (or 1.5s has passed).
  ///
  /// The entrance is a sequence of words rising through masks sized to the
  /// display face. Played before Unbounded loads, it runs in the fallback
  /// face and then visibly swaps, so the hero waits for the fonts, invisible
  /// at its final size so nothing below it moves, and plays once they land.
  bool _fontsReady = false;

  @override
  void initState() {
    super.initState();
    // Fonts are requested during the first build, so ask after it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GoogleFonts.pendingFonts()
          .timeout(const Duration(milliseconds: 1500))
          .catchError((_) => const <void>[])
          .whenComplete(() {
            if (mounted) setState(() => _fontsReady = true);
          });
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The photograph covers the headline and the top of the stage; the
        // tiles below it sit on the plain canvas.
        Positioned(
          left: 0,
          right: 0,
          // From the very top of the page, behind the floating bar and the
          // space the page leaves for it above the hero.
          top: -(WebNavBar.height + (brk.isCompact ? 32 : 48)),
          height: brk.isCompact ? 760 : 1040,
          child: const _HeroPhoto(),
        ),
        WebContentFrame(
          child: Opacity(
            opacity: _fontsReady ? 1 : 0,
            // A new key when the fonts land rebuilds the subtree, so every
            // entrance starts from its first frame rather than mid-way.
            child: KeyedSubtree(
              key: ValueKey(_fontsReady),
              child: Column(
                children: [
                  const _Standfirst(),
                  SizedBox(height: brk.isCompact ? 18 : 26),
                  const _Headline(),
                  SizedBox(height: brk.isCompact ? 44 : 64),
                  _Stage(focus: _focus),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Photograph ──────────────────────────────────────────────────────────────

/// The hero's backdrop: a drone over a city at dusk, under a flat navy tint
/// strong enough that the headline and the phone stay the subject. It fades
/// out — by opacity, not by blending to another colour — over its lower part,
/// so it settles into the page instead of ending at a hard edge behind the
/// tiles.
///
/// It arrives once: a 1.6s settle from 106% scale with a fade, then holds
/// still. Off under reduced motion.
class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto();

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    Widget photo = Image.asset(
      WebPhoto.hero,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.1),
      cacheWidth: 2200,
      excludeFromSemantics: true,
      errorBuilder: WebPhoto.missing,
    );
    if (!reduced) {
      photo = photo
          .animate()
          .fadeIn(duration: 900.ms, curve: WebMotion.enter)
          .scale(
            begin: const Offset(1.06, 1.06),
            end: const Offset(1, 1),
            duration: 1600.ms,
            curve: WebMotion.enter,
          );
    }
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.55, 1],
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              photo,
              ColoredBox(color: WebInk.canvas.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Copy ────────────────────────────────────────────────────────────────────

class _Standfirst extends StatelessWidget {
  const _Standfirst();

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    return Text(
      'Campus delivery by drone,\nfor the UCLM community',
      textAlign: TextAlign.center,
      style: WebType.lead(
        brk,
        color: WebInk.text,
      ).copyWith(fontSize: brk.isCompact ? 15 : 16.5, height: 1.45),
    ).entrance(context, delay: 420.ms, rise: 10);
  }
}

/// Two lines, centred, set in the display face. Each word rises through its
/// own mask (`masked-reveal`), because the headline is the hero's focal
/// point and a staged arrival reads it to you in order. Words, not letters,
/// keep the sequence calm.
class _Headline extends StatelessWidget {
  const _Headline();

  static const _lines = [
    ['ORDER', 'IT.'],
    ['WATCH', 'IT', 'FLY.'],
  ];

  /// The display size is fitted to this so the second line never wraps.
  static const _longestLine = 'WATCH IT FLY.';

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = WebType.fitDisplay(
          longestLine: _longestLine,
          maxWidth: constraints.maxWidth,
          brk: brk,
        );
        final style = WebType.displayAt(size);
        final space = size * 0.3;

        var order = 0;
        Widget word(String text) {
          final i = order++;
          final glyphs = Text(text, style: style, maxLines: 1);
          if (reduced) return glyphs;
          return ClipRect(
            clipper: const _InflatedClip(6),
            child: glyphs
                .animate()
                .slideY(
                  begin: 1.12,
                  delay: (480 + i * 45).ms,
                  duration: 820.ms,
                  curve: WebMotion.enter,
                )
                .fadeIn(delay: (480 + i * 45).ms, duration: 300.ms),
          );
        }

        return Semantics(
          header: true,
          label: 'Order it. Watch it fly.',
          excludeSemantics: true,
          child: Column(
            children: [
              for (final line in _lines)
                // A Row, not a Wrap: a line of the headline must never break.
                // If it ever cannot fit, that is a layout error the tests
                // catch, not a silent third line.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var w = 0; w < line.length; w++) ...[
                      if (w > 0) SizedBox(width: space),
                      word(line[w]),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A word's mask, grown a few pixels top and bottom so the display face's
/// tight line height does not shave the tops off the capitals.
class _InflatedClip extends CustomClipper<Rect> {
  const _InflatedClip(this.by);
  final double by;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-by, -by, size.width + by, size.height + by);

  @override
  bool shouldReclip(_InflatedClip oldClipper) => oldClipper.by != by;
}

// ─── Stage ───────────────────────────────────────────────────────────────────

/// Copy for each tile, keyed by canteen name: the description and the link.
///
/// Each description is about ordering from that canteen, and says only what
/// AeroDrop does with the order — flies it to your building, weighs it,
/// tracks it live, holds it in bad weather. Nothing about menus, prices or
/// opening hours: the page has no source for those, and a wrong lunch claim
/// on a campus page is worse than none (R-36).
const _tileCopy = <String, (String description, String link)>{
  'Annex Building Canteen': (
    'Order from the Annex canteen without leaving your seat. A drone '
        'brings it to your building.',
    'Browse Annex',
  ),
  'Old Building Canteen': (
    'The Old Building canteen, a few taps away. Every order is weighed '
        'and checked before it flies.',
    'Browse Old Building',
  ),
  'Engineering Building Canteen': (
    'Order from the Engineering canteen and watch the drone carry it '
        'across campus, live on your screen.',
    'Browse Engineering',
  ),
  'Maritime Building Canteen': (
    'Lunch from the Maritime canteen, flown to you. If the weather turns, '
        'your order waits safely on the ground.',
    'Browse Maritime',
  ),
};

class _Stage extends StatelessWidget {
  const _Stage({required this.focus});

  final ValueNotifier<String?> focus;

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => switch (brk) {
        WebBreak.expanded => _expanded(context, constraints.maxWidth),
        WebBreak.medium => _medium(context, constraints.maxWidth),
        WebBreak.compact => _compact(context, constraints.maxWidth),
      },
    );
  }

  static const _canteens = HeroSection.canteens;

  /// Entrance order: the tiles arrive in reading order — the two top tiles,
  /// the one under the phone, then the lower left — after the phone and
  /// headline have landed.
  static const _arrival = [
    'Annex Building Canteen',
    'Maritime Building Canteen',
    'Old Building Canteen',
    'Engineering Building Canteen',
  ];

  Widget _tile(
    BuildContext context,
    int index, {
    double minHeight = 0,
    bool bottomAligned = false,
  }) {
    final canteen = _canteens[index];
    return _SkyTile(
      canteen: canteen,
      copy: _tileCopy[canteen.name]!,
      minHeight: minHeight,
      bottomAligned: bottomAligned,
      focus: focus,
      onTap: () => context.go(shopLocation(search: canteen.search)),
    ).materialize(context, order: _arrival.indexOf(canteen.name));
  }

  Widget _phone(BuildContext context, double width, {bool tilt = true}) =>
      WebPhoneBrowse(
        width: width,
        canteens: _canteens,
        focus: focus,
        tilt: tilt,
      ).entrance(
        context,
        delay: 120.ms,
        rise: 48,
        scale: 0.94,
        duration: 900.ms,
      );

  /// The reference composition: tiles in three columns at staggered heights,
  /// the phone leaning over the middle one, whose copy shows below it. Four
  /// tiles, so the right column holds one tall tile whose foot sits just
  /// above the left column's, keeping the reference's ragged lower edge.
  Widget _expanded(BuildContext context, double width) {
    const gap = 24.0;
    final col = (width - gap * 2) / 3;
    final phoneW = (col * 0.84).clamp(250.0, 312.0);
    final phoneH = phoneW * 640 / 300;

    // The middle tile starts halfway down the phone and ends far enough below
    // it that its copy, set to the tile's foot, clears the device.
    final middleTop = phoneH * 0.48;
    final middleHeight = phoneH - middleTop + 170;

    const leftFirst = 268.0;
    const leftSecond = 236.0;
    final leftTop = phoneH * 0.22;
    final rightTop = phoneH * 0.06;
    final rightHeight = leftTop + leftFirst + gap + leftSecond - rightTop - 64;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: col,
              child: Column(
                children: [
                  SizedBox(height: leftTop),
                  _tile(context, 0, minHeight: leftFirst),
                  const SizedBox(height: gap),
                  _tile(context, 2, minHeight: leftSecond),
                ],
              ),
            ),
            const SizedBox(width: gap),
            SizedBox(
              width: col,
              child: Column(
                children: [
                  SizedBox(height: middleTop),
                  _tile(
                    context,
                    1,
                    minHeight: middleHeight,
                    bottomAligned: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: gap),
            SizedBox(
              width: col,
              child: Column(
                children: [
                  SizedBox(height: rightTop),
                  _tile(context, 3, minHeight: rightHeight),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          top: -phoneH * 0.06,
          left: (width - phoneW) / 2,
          child: _phone(context, phoneW),
        ),
      ],
    );
  }

  /// Two columns of tiles under the phone. The right column starts lower so
  /// the pair keeps the reference's staggered edge.
  Widget _medium(BuildContext context, double width) {
    const gap = 20.0;
    final col = (width - gap) / 2;
    final phoneW = (width * 0.4).clamp(250.0, 300.0);

    return Column(
      children: [
        _phone(context, phoneW),
        const SizedBox(height: 72),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: col,
              child: Column(
                children: [
                  _tile(context, 0, minHeight: 250),
                  const SizedBox(height: gap),
                  _tile(context, 1, minHeight: 250),
                ],
              ),
            ),
            const SizedBox(width: gap),
            SizedBox(
              width: col,
              child: Column(
                children: [
                  const SizedBox(height: 56),
                  _tile(context, 2, minHeight: 250),
                  const SizedBox(height: gap),
                  _tile(context, 3, minHeight: 250),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// One column. The phone stands upright: at this width the lean
  /// foreshortens the screen past reading.
  Widget _compact(BuildContext context, double width) {
    // Small enough that the headline and the top of the first tile share
    // the first screen with it on a 375 x 812 phone.
    final phoneW = (width * 0.62).clamp(210.0, 250.0);
    return Column(
      children: [
        _phone(context, phoneW, tilt: false),
        const SizedBox(height: 44),
        for (var i = 0; i < _canteens.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _tile(context, i),
        ],
      ],
    );
  }
}

// ─── Tile ────────────────────────────────────────────────────────────────────

/// One canteen, as a photographed tile that opens the Shop searched to its
/// building.
///
/// It is one control, not a card with a link inside: the whole surface is
/// the target, it takes keyboard focus, and Enter or Space activate it
/// (R-26, R-32). Hover and focus both lift it 4px and type its building into
/// the phone's search; press settles it at 0.96.
class _SkyTile extends StatefulWidget {
  const _SkyTile({
    required this.canteen,
    required this.copy,
    required this.minHeight,
    required this.bottomAligned,
    required this.focus,
    required this.onTap,
  });

  final WebCanteen canteen;
  final (String, String) copy;
  final double minHeight;
  final bool bottomAligned;
  final ValueNotifier<String?> focus;
  final VoidCallback onTap;

  @override
  State<_SkyTile> createState() => _SkyTileState();
}

class _SkyTileState extends State<_SkyTile> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  void _setHover(bool value) {
    setState(() => _hovered = value);
    _publish();
  }

  void _setFocus(bool value) {
    setState(() => _focused = value);
    _publish();
  }

  /// Tell the phone which tile is under attention. Leaving only clears the
  /// phone if it is still showing this tile, so moving straight from one tile
  /// to the next never flickers back to "All".
  void _publish() {
    final name = widget.canteen.name;
    if (_hovered || _focused) {
      widget.focus.value = name;
    } else if (widget.focus.value == name) {
      widget.focus.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);
    final name = widget.canteen.name;
    final (statement, link) = widget.copy;
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final active = (_hovered || _focused) && !_pressed && !reduced;

    // The caption plate: the canteen, what ordering from it means, and the
    // link — on a near-solid plate, so the copy reads on any photograph.
    final plate = ClipRRect(
      borderRadius: BorderRadius.circular(brk.isCompact ? 16 : 18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(brk.isCompact ? 16 : 18),
          decoration: BoxDecoration(
            color: WebPhoto.plate,
            borderRadius: BorderRadius.circular(brk.isCompact ? 16 : 18),
            border: Border.all(color: WebInk.text.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // The canteen is what the visitor is choosing, so it is the
              // heading; the fact under it is supporting copy.
              Text(
                name,
                style: WebType.entry(
                  brk,
                  color: WebInk.text,
                ).copyWith(fontSize: brk.isCompact ? 19 : 21),
              ),
              const SizedBox(height: 8),
              Text(
                statement,
                style: WebType.body(
                  color: WebPhoto.plateSoft,
                ).copyWith(fontSize: brk.isCompact ? 14 : 14.5, height: 1.5),
              ),
              const SizedBox(height: 16),
              _TileLink(label: link, color: WebInk.text, active: active),
            ],
          ),
        ),
      ),
    );

    // The photograph shows above the plate: at least this much of it on
    // every tile, however short.
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(height: brk.isCompact ? 150 : 110),
        plate,
      ],
    );

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      // Focus highlight only — it follows the keyboard. Hover is tracked by
      // the MouseRegion below instead of onShowHoverHighlight, which stays
      // silent unless the focus system is in traditional highlight mode.
      onShowFocusHighlight: _setFocus,
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
      child: MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: Semantics(
          button: true,
          label: '$name. $statement $link',
          onTap: widget.onTap,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: active ? 1 : 0),
              duration: WebMotion.hover,
              curve: WebMotion.enter,
              builder: (context, t, child) =>
                  Transform.translate(offset: Offset(0, -4 * t), child: child),
              child: AnimatedScale(
                scale: _pressed && !reduced ? WebMotion.pressScale : 1,
                duration: WebMotion.press,
                curve: WebMotion.enter,
                child: Container(
                  constraints: BoxConstraints(minHeight: widget.minHeight),
                  // Raised out of the canvas like every card on the site;
                  // attention lifts it a level.
                  decoration: BoxDecoration(
                    color: WebInk.canvas,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: WebInk.web.shadows(
                      active ? NeuDepth.high : NeuDepth.medium,
                    ),
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    // Focus ring: the keyboard user's equivalent of the lift.
                    border: Border.all(
                      color: _focused ? WebInk.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  // Passthrough, so the caption column gets the tile's
                  // minimum height and its plate sits on the tile's floor.
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      // The canteen's photograph fills the tile and eases in
                      // 5% while the tile has attention.
                      Positioned.fill(
                        child: AnimatedScale(
                          scale: active ? 1.05 : 1,
                          duration: const Duration(milliseconds: 520),
                          curve: WebMotion.enter,
                          child: Image.asset(
                            widget.canteen.photo,
                            fit: BoxFit.cover,
                            cacheWidth: 900,
                            excludeFromSemantics: true,
                            errorBuilder: WebPhoto.missing,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(brk.isCompact ? 10 : 12),
                        child: body,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tile's call to action, as text with a rule. The rule grows from a
/// quarter of the label to its full width while the tile is under attention — it is the one
/// visible change that says "this whole tile is the link".
class _TileLink extends StatelessWidget {
  const _TileLink({
    required this.label,
    required this.color,
    required this.active,
  });

  final String label;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    // The label sizes the Stack and the rule is laid against it, rather than
    // measuring the label with IntrinsicWidth: on web that measurement can be
    // taken with the fallback font and go stale when the webfont arrives,
    // which wrapped "Browse cafés" and clipped it to "Browse".
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7.5),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: WebType.action(color: color, weight: FontWeight.w700),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 220),
              curve: WebMotion.enter,
              widthFactor: active ? 1 : 0.24,
              child: Container(height: 1.5, color: color),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Entrance motion ─────────────────────────────────────────────────────────

/// The hero's two entrance recipes. Both run once, on first paint, and both
/// collapse to the resting state under reduced motion — nothing on the page
/// depends on an animation having played.
extension _HeroEntrance on Widget {
  /// Fade and rise, with an optional settle in scale. Used for the phone
  /// (the first thing to arrive, so the screen has a subject) and the
  /// standfirst.
  Widget entrance(
    BuildContext context, {
    required Duration delay,
    required double rise,
    double scale = 1,
    Duration duration = const Duration(milliseconds: 640),
  }) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return this;
    var a = animate(delay: delay)
        .fadeIn(duration: duration * 0.6, curve: WebMotion.enter)
        .move(
          begin: Offset(0, rise),
          end: Offset.zero,
          duration: duration,
          curve: WebMotion.enter,
        );
    if (scale != 1) {
      a = a.scale(
        begin: Offset(scale, scale),
        end: const Offset(1, 1),
        duration: duration,
        curve: WebMotion.enter,
      );
    }
    return a;
  }

  /// The reference's signature: tiles resolve out of a blur. Kept inside the
  /// `fixing-motion-performance` limits — 8px at most, once, never looped —
  /// and staggered 70ms apart so they arrive as a sequence rather than a
  /// flash (`animate`: 30–80ms).
  Widget materialize(BuildContext context, {required int order}) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return this;
    final delay = (900 + order * 70).ms;
    return animate(delay: delay)
        .fadeIn(duration: 420.ms, curve: WebMotion.enter)
        .blur(
          begin: const Offset(8, 8),
          end: Offset.zero,
          duration: 700.ms,
          curve: WebMotion.enter,
        )
        .move(
          begin: const Offset(0, 24),
          end: Offset.zero,
          duration: 760.ms,
          curve: WebMotion.enter,
        );
  }
}
