import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/brand_mark.dart';
import '../web_breakpoints.dart';
import '../web_tokens.dart';
import '../widgets/web_actions.dart';
import '../widgets/web_motion.dart';
import 'sections/hero_section.dart' show shopLocation, signInLocation;
import '../../../core/widgets/neu_surface.dart';

/// Scrolls the page so the section under [key] starts just below the
/// floating bar. `Scrollable.ensureVisible` aligns to the viewport's top
/// edge, which is under the bar, so it hid every section's title.
void scrollToSection(GlobalKey key) {
  final ctx = key.currentContext;
  final box = ctx?.findRenderObject() as RenderBox?;
  if (ctx == null || box == null || !box.hasSize) return;
  final position = Scrollable.of(ctx).position;
  final viewport = Scrollable.of(ctx).context.findRenderObject() as RenderBox;
  final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
  final target = (position.pixels + top - WebNavBar.height - 32).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  final reduced = MediaQuery.maybeOf(ctx)?.disableAnimations ?? false;
  if (reduced) {
    position.jumpTo(target);
  } else {
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 620),
      curve: WebMotion.enter,
    );
  }
}

/// A destination in the top bar. Either scrolls to a section on this page or
/// routes somewhere — never both, and never neither (R-24: no dead nav).
class WebNavDestination {
  const WebNavDestination.section(this.label, this.sectionKey) : route = null;
  const WebNavDestination.route(this.label, this.route) : sectionKey = null;

  final String label;
  final GlobalKey? sectionKey;
  final String? route;
}

/// The top bar, in the reference's arrangement: section links on the left,
/// the wordmark centred, the way into the app on the right.
///
/// The right-hand control goes straight to the app's Shop. The reference puts
/// an App Store badge there; AeroDrop's equivalent of "get the app" is
/// "start browsing", and a store badge for an app that is not in a store
/// would be a dead control (R-26).
///
/// Transparent over the hero. Once content passes under it, it becomes the
/// page's one translucent surface (R-10): canvas at 82% over an 18px blur,
/// with a hairline. That is the Apple scroll-edge treatment — the bar stays
/// legible without becoming an opaque strip that hides the tiles.
class WebNavBar extends StatelessWidget {
  const WebNavBar({
    super.key,
    required this.destinations,
    required this.onMenuTap,
    required this.scrolled,
    this.activeIndex,
  });

  final List<WebNavDestination> destinations;
  final VoidCallback onMenuTap;

  /// The destination whose section is in view, or null over the hero.
  final int? activeIndex;

  /// True once the page has moved under the bar.
  final bool scrolled;

  static const double height = 76;

  void _go(BuildContext context, WebNavDestination d) {
    if (d.route != null) {
      context.go(d.route!);
      return;
    }
    if (d.sectionKey != null) scrollToSection(d.sectionKey!);
  }

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    final Widget bar;
    if (brk.isExpanded) {
      bar = Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _SectionLinks(
                destinations: destinations,
                activeIndex: activeIndex,
                onTap: (d) => _go(context, d),
              ),
            ),
          ),
          _Wordmark(onTap: () => context.go('/')),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _NavLink(
                  label: 'Sign in',
                  onTap: () => context.go(signInLocation),
                ),
                const SizedBox(width: 14),
                WebFilledAction(
                  label: 'Browse vendors',
                  compact: true,
                  onTap: () => context.go(shopLocation()),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      bar = Row(
        children: [
          Flexible(child: _Wordmark(onTap: () => context.go('/'))),
          const Spacer(),
          if (!brk.isCompact) ...[
            WebFilledAction(
              label: 'Browse vendors',
              compact: true,
              onTap: () => context.go(shopLocation()),
            ),
            const SizedBox(width: 6),
          ],
          _MenuButton(onTap: onMenuTap),
        ],
      );
    }

    // Once content passes under it, the bar becomes a slab of the canvas
    // raised over the page: opaque, with the shadow half of the neumorphic
    // pair falling on the content below. No frosted glass — the material is
    // the same as everything else on the page.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: scrolled ? 1 : 0),
      duration: WebMotion.hover,
      curve: WebMotion.enter,
      builder: (context, t, child) => Container(
        height: height,
        decoration: BoxDecoration(
          color: WebInk.canvas.withValues(alpha: t),
          boxShadow: [
            BoxShadow(
              color: WebInk.web.shadow.withValues(alpha: 0.7 * t),
              offset: const Offset(0, 8),
              blurRadius: 22,
              spreadRadius: -6,
            ),
          ],
        ),
        child: child,
      ),
      child: WebContentFrame(child: bar),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: 'AeroDrop home',
      onTap: onTap,
      excludeSemantics: true,
      child: HoverLift(
        onTap: onTap,
        lift: 0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 28, elevated: false),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'AeroDrop',
                overflow: TextOverflow.ellipsis,
                style: WebType.action(
                  weight: FontWeight.w800,
                ).copyWith(fontSize: 17, letterSpacing: -0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The section links, with one pill behind them.
///
/// The pill sits behind whichever link is hovered, and otherwise behind the
/// section currently in view, sliding between them (`animation-systems`:
/// tab indicators). That gives it a job — it answers "where am I on this
/// page" while scrolling and "what will I get" while pointing — which is
/// what earns a nav its only moving part (R-19). Over the hero, with nothing
/// hovered, it fades out rather than parking somewhere arbitrary.
class _SectionLinks extends StatefulWidget {
  const _SectionLinks({
    required this.destinations,
    required this.activeIndex,
    required this.onTap,
  });

  final List<WebNavDestination> destinations;
  final int? activeIndex;
  final ValueChanged<WebNavDestination> onTap;

  @override
  State<_SectionLinks> createState() => _SectionLinksState();
}

class _SectionLinksState extends State<_SectionLinks> {
  final _stackKey = GlobalKey();
  late List<GlobalKey> _keys = _makeKeys();
  List<Rect> _rects = const [];
  int? _hovered;

  List<GlobalKey> _makeKeys() => [
    for (var i = 0; i < widget.destinations.length; i++) GlobalKey(),
  ];

  @override
  void didUpdateWidget(covariant _SectionLinks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destinations.length != widget.destinations.length) {
      _keys = _makeKeys();
    }
  }

  /// Measures each link after layout. Re-run every frame the bar rebuilds,
  /// because a link's width changes once its webfont arrives.
  void _measure() {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || !stack.hasSize) return;
    final rects = <Rect>[];
    for (final key in _keys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final origin = box.localToGlobal(Offset.zero, ancestor: stack);
      rects.add(origin & box.size);
    }
    if (!listEquals(rects, _rects)) setState(() => _rects = rects);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });

    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final target = _hovered ?? widget.activeIndex;
    final hasRect = target != null && target < _rects.length;
    final rect = hasRect ? _rects[target] : null;

    // Scales down rather than overflowing if the three labels ever outgrow
    // the bar's left third — a long translation, or a large text setting.
    // The pill is measured inside the scaled box, so it stays aligned.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Stack(
        key: _stackKey,
        alignment: Alignment.centerLeft,
        children: [
          if (_rects.isNotEmpty)
            AnimatedPositioned(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              curve: WebMotion.enter,
              left: rect?.left ?? _rects.first.left,
              width: rect?.width ?? _rects.first.width,
              top: 8,
              bottom: 8,
              child: AnimatedOpacity(
                duration: WebMotion.hover,
                opacity: rect == null ? 0 : 1,
                // The current section's link sits in a well pressed into the
                // bar.
                child: NeuSurface(
                  style: NeuStyle.inset,
                  palette: WebInk.web,
                  depth: NeuDepth.flat,
                  color: WebInk.web.sunken,
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.destinations.length; i++)
                MouseRegion(
                  onEnter: (_) => setState(() => _hovered = i),
                  onExit: (_) => setState(() {
                    if (_hovered == i) _hovered = null;
                  }),
                  child: KeyedSubtree(
                    key: _keys[i],
                    child: _NavLink(
                      label: widget.destinations[i].label,
                      current: i == widget.activeIndex,
                      onTap: () => widget.onTap(widget.destinations[i]),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A nav link. The only motion is colour — no underline that slides out from
/// nowhere, because a link that grows a bar on hover is doing more than
/// telling you it is a link.
class _NavLink extends StatefulWidget {
  const _NavLink({
    required this.label,
    required this.onTap,
    this.current = false,
  });
  final String label;
  final VoidCallback onTap;

  /// Its section is the one in view. Shown in full-strength text as well as
  /// by the pill, so the state never depends on motion alone.
  final bool current;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: AnimatedDefaultTextStyle(
              duration: WebMotion.hover,
              curve: WebMotion.enter,
              style: WebType.action(
                color: _hovered || widget.current
                    ? WebInk.text
                    : WebInk.textSoft,
                weight: FontWeight.w500,
              ),
              child: Text(widget.label, maxLines: 1),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Open menu',
      icon: const Icon(Icons.menu_rounded, color: WebInk.text, size: 22),
    );
  }
}
