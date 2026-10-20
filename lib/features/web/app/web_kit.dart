import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/neu_input_border.dart';
import '../../../core/widgets/neu_surface.dart';

/// The website's app kit — the pages a signed-in customer, vendor or
/// administrator uses in a browser.
///
/// The phone app and the website share their destinations and flows but not
/// their layouts. The app is drawn for a thumb: one column, a bottom dock,
/// full-bleed lists. These pages are drawn for a browser window the way food
/// delivery and operations sites are: a page header with its actions, panels
/// arranged in columns, data in tables with a header row, grids that count
/// their columns from the width they get, and a summary beside the content
/// rather than below it. Every layout steps down to one column on a phone
/// browser instead of stretching or clipping.
///
/// The material is the app's neumorphic one (soft UI, accessibility-tuned):
/// panels and buttons are raised out of the canvas, inputs, tracks and the
/// selected tab are pressed into it, and depth replaces hairlines. Text keeps
/// 4.5:1 on the canvas, and keyboard focus is always an accent ring — soft
/// shadows alone do not show where focus is.
///
/// Motion is limited to arrival and response: sections rise 12px and fade in
/// a short stagger once, cards lift on hover, controls press in when held.
/// Nothing loops, and all of it is off under reduced motion.

// ─── Layout ──────────────────────────────────────────────────────────────────

class WebLayout {
  const WebLayout._();

  /// Below this the page is a phone browser: one column, cards for rows.
  static const double compact = 720;

  /// From this the role's sidebar is on screen.
  static const double wide = 1100;

  /// The widest any page's content runs.
  static const double maxContent = 1320;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;

  /// Side padding for a page of [width].
  static double gutter(double width) =>
      width < compact ? 16 : (width < wide ? 24 : 36);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

// ─── Type ────────────────────────────────────────────────────────────────────

/// Plus Jakarta Sans for structure, Inter for reading — the app's two
/// families, at website sizes.
class WebText {
  const WebText._();

  static TextStyle display(double size, {Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: size * -0.025,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle title({
    double size = 16,
    Color? color,
    FontWeight? weight,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight ?? FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.2,
    color: color ?? AppColors.textPrimary,
  );

  static TextStyle body({double size = 14, Color? color, FontWeight? weight}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w400,
        height: 1.5,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle label({
    double size = 13,
    Color? color,
    FontWeight? weight,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight ?? FontWeight.w600,
    height: 1.3,
    color: color ?? AppColors.textPrimary,
  );

  /// Column headers and small section labels.
  static TextStyle overline({Color? color}) => GoogleFonts.inter(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.7,
    color: color ?? AppColors.textTertiary,
  );

  static TextStyle numeric({double size = 26, Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.6,
        color: color ?? AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static String peso(num v) => '₱${v.toStringAsFixed(2)}';
}

// ─── Motion ──────────────────────────────────────────────────────────────────

const Curve _enter = Cubic(0.2, 0, 0, 1);
const Duration _quick = Duration(milliseconds: 160);

extension WebReveal on Widget {
  /// Rise 12px and fade, once, staggered 45ms by [index] and capped so a
  /// long page does not take seconds to arrive.
  Widget webReveal(BuildContext context, [int index = 0]) {
    if (WebLayout.reduced(context)) return this;
    final delay = (40 + index.clamp(0, 10) * 45).ms;
    return animate()
        .fadeIn(delay: delay, duration: 360.ms, curve: _enter)
        .move(
          begin: const Offset(0, 12),
          end: Offset.zero,
          delay: delay,
          duration: 440.ms,
          curve: _enter,
        );
  }
}

// ─── Page ────────────────────────────────────────────────────────────────────

/// A page: header (back, title, subtitle, actions) over a body in a column
/// no wider than [maxWidth], centred in the window.
///
/// [children] scroll as one page. Use [WebPage.fill] for a page whose body
/// fills the window and scrolls inside itself — a map with a list beside it.
class WebPage extends StatelessWidget {
  const WebPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.back = false,
    this.onBack,
    this.maxWidth = WebLayout.maxContent,
    this.onRefresh,
    required List<Widget> this.children,
  }) : body = null;

  const WebPage.fill({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.back = false,
    this.onBack,
    this.maxWidth = WebLayout.maxContent,
    required Widget this.body,
  }) : children = null,
       onRefresh = null;

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Shows a back control before the title — for a page opened over
  /// another (a single order, a form).
  final bool back;
  final VoidCallback? onBack;
  final double maxWidth;
  final Future<void> Function()? onRefresh;
  final List<Widget>? children;
  final Widget? body;

  void _goBack(BuildContext context) {
    if (onBack != null) return onBack!();
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = WebLayout.gutter(width);
    final compact = width < WebLayout.compact;

    final header = _PageHeader(
      title: title,
      subtitle: subtitle,
      actions: actions,
      onBack: back ? () => _goBack(context) : null,
      compact: compact,
    );

    // Every section spans the column's full width, so a row narrower than
    // the page (wrapping chips, a short table) starts at the left margin
    // instead of floating to the centre.
    Widget frame(Widget child) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );

    if (body != null) {
      return Material(
        color: AppColors.base,
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, compact ? 16 : 28, gutter, 0),
          child: frame(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header.webReveal(context),
                SizedBox(height: compact ? 16 : 24),
                Expanded(child: body!.webReveal(context, 1)),
              ],
            ),
          ),
        ),
      );
    }

    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Room at the foot for the toast, and for shadows at the edges.
      padding: EdgeInsets.fromLTRB(gutter, compact ? 16 : 28, gutter, 64),
      children: [
        frame(header.webReveal(context)),
        SizedBox(height: compact ? 18 : 28),
        for (var i = 0; i < children!.length; i++) ...[
          if (i > 0) SizedBox(height: compact ? 16 : 22),
          frame(children![i].webReveal(context, i + 1)),
        ],
      ],
    );

    return Material(
      color: AppColors.base,
      child: onRefresh == null
          ? list
          : RefreshIndicator(
              color: AppColors.accentFill,
              backgroundColor: AppColors.base,
              onRefresh: onRefresh!,
              child: list,
            ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.onBack,
    required this.compact,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (onBack != null) ...[
          WebIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: onBack,
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: WebText.display(compact ? 24 : 30)),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: WebText.body(size: compact ? 13.5 : 15)),
              ],
            ],
          ),
        ),
      ],
    );

    if (actions.isEmpty) return heading;
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: heading),
        const SizedBox(width: 20),
        Wrap(spacing: 12, runSpacing: 10, children: actions),
      ],
    );
  }
}

// ─── Surfaces ────────────────────────────────────────────────────────────────

/// A raised panel, optionally titled, with an action on the title row.
class WebPanel extends StatelessWidget {
  const WebPanel({
    super.key,
    this.title,
    this.subtitle,
    this.action,
    required this.child,
    this.padding,
    this.depth = NeuDepth.low,
  });

  final String? title;
  final String? subtitle;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final NeuDepth depth;

  @override
  Widget build(BuildContext context) {
    final compact = WebLayout.isCompact(context);
    return NeuSurface(
      depth: depth,
      borderRadius: BorderRadius.circular(compact ? 20 : 24),
      padding: padding ?? EdgeInsets.all(compact ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!, style: WebText.title(size: 17)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: WebText.body(size: 13)),
                      ],
                    ],
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 12), action!],
              ],
            ),
            SizedBox(height: compact ? 14 : 18),
          ],
          child,
        ],
      ),
    );
  }
}

/// A well pressed into the canvas — an empty state, a skeleton, a quiet
/// grouping.
class WebWell extends StatelessWidget {
  const WebWell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => NeuSurface(
    style: NeuStyle.inset,
    color: AppColors.surfaceSunken,
    borderRadius: BorderRadius.circular(radius),
    padding: padding,
    child: child,
  );
}

/// Nothing to show, said plainly, with the one useful next step.
class WebEmpty extends StatelessWidget {
  const WebEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return WebWell(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      radius: 22,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeuSurface(
              width: 56,
              height: 56,
              borderRadius: BorderRadius.circular(18),
              alignment: Alignment.center,
              child: Icon(icon, size: 26, color: AppColors.accentText),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: WebText.title(size: 16.5),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: WebText.body(size: 14),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// A placeholder block while data loads. Still — no shimmer sweep.
class WebSkeleton extends StatelessWidget {
  const WebSkeleton({super.key, this.height = 72, this.radius = 18});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => NeuSurface(
    style: NeuStyle.inset,
    color: AppColors.surfaceSunken,
    height: height,
    borderRadius: BorderRadius.circular(radius),
    child: const SizedBox.expand(),
  );
}

// ─── Grids ───────────────────────────────────────────────────────────────────

/// Children in as many equal columns as fit [minTile], with a gap wide
/// enough for neighbouring shadows. Rows take the height of their tallest
/// child, so a row of cards lines up.
class WebGrid extends StatelessWidget {
  const WebGrid({
    super.key,
    required this.children,
    this.minTile = 240,
    this.maxColumns = 4,
    this.gap = 20,
  });

  final List<Widget> children;
  final double minTile;
  final int maxColumns;
  final double gap;

  static int columnsFor(double width, double minTile, int max) =>
      ((width + 20) / (minTile + 20)).floor().clamp(1, max);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = columnsFor(box.maxWidth, minTile, maxColumns);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          final slice = children.sublist(
            i,
            (i + cols).clamp(0, children.length),
          );
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < cols; c++) ...[
                    if (c > 0) SizedBox(width: gap),
                    Expanded(
                      child: c < slice.length
                          ? slice[c]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) SizedBox(height: gap),
              rows[r],
            ],
          ],
        );
      },
    );
  }
}

/// Two columns on a wide page — [main] and a narrower [side] — stacked on a
/// narrow one with the side first or last as [sideFirstWhenStacked] says.
class WebSplit extends StatelessWidget {
  const WebSplit({
    super.key,
    required this.main,
    required this.side,
    this.sideWidth = 380,
    this.breakpoint = 980,
    this.gap = 24,
    this.sideFirstWhenStacked = false,
  });

  final Widget main;
  final Widget side;
  final double sideWidth;
  final double breakpoint;
  final double gap;
  final bool sideFirstWhenStacked;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              SizedBox(width: gap),
              SizedBox(width: sideWidth, child: side),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: sideFirstWhenStacked
              ? [side, SizedBox(height: gap), main]
              : [main, SizedBox(height: gap), side],
        );
      },
    );
  }
}

// ─── Stat ────────────────────────────────────────────────────────────────────

/// A key figure: its icon set into a well in the figure's tone, the value,
/// what it counts, and an optional line of context.
class WebStat extends StatelessWidget {
  const WebStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone,
    this.note,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? tone;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = tone == null ? AppColors.accentText : AppColors.readable(tone!);
    return WebHoverCard(
      onTap: onTap,
      semanticLabel: '$label: $value',
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          NeuSurface(
            style: NeuStyle.inset,
            color: AppColors.surfaceSunken,
            width: 48,
            height: 48,
            borderRadius: BorderRadius.circular(15),
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: t),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WebText.body(size: 13),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: WebText.numeric(size: 24)),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WebText.body(
                      size: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hover card ──────────────────────────────────────────────────────────────

/// A raised card that lifts a level on hover and presses into the canvas
/// while held, when it has an [onTap]. Without one it is a plain panel.
class WebHoverCard extends StatefulWidget {
  const WebHoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final String? semanticLabel;

  @override
  State<WebHoverCard> createState() => _WebHoverCardState();
}

class _WebHoverCardState extends State<WebHoverCard> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tappable = widget.onTap != null;
    final reduced = WebLayout.reduced(context);
    final lift = tappable && _hovered && !reduced;
    final down = tappable && _pressed;
    final radius = BorderRadius.circular(widget.radius);

    final card = AnimatedContainer(
      duration: _quick,
      curve: _enter,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: down ? AppColors.surfaceSunken : AppColors.base,
        borderRadius: radius,
        boxShadow: down
            ? const []
            : AppShadows.raised(lift ? NeuDepth.medium : NeuDepth.low),
        border: _focused
            ? Border.all(color: AppColors.accentText, width: 2)
            : null,
      ),
      child: widget.child,
    );

    if (!tappable) {
      return widget.semanticLabel == null
          ? card
          : Semantics(label: widget.semanticLabel, child: card);
    }

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap!();
              return null;
            },
          ),
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: GestureDetector(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: card,
          ),
        ),
      ),
    );
  }
}

// ─── Buttons ─────────────────────────────────────────────────────────────────

enum WebButtonKind { primary, secondary, danger, ghost }

/// A button raised out of the canvas. Primary is the accent; secondary is
/// the canvas itself; danger carries the danger tone for irreversible
/// actions; ghost is text only. Pressing pushes it in.
class WebButton extends StatefulWidget {
  const WebButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.kind = WebButtonKind.primary,
    this.loading = false,
    this.expand = false,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final WebButtonKind kind;
  final bool loading;
  final bool expand;
  final bool dense;

  @override
  State<WebButton> createState() => _WebButtonState();
}

class _WebButtonState extends State<WebButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _activate() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final down = _pressed && _enabled;
    final (Color fill, Color ink) = switch (kind) {
      WebButtonKind.primary => (
        down
            ? Color.lerp(AppColors.accentFill, Colors.black, 0.12)!
            : (_hovered && _enabled
                  ? Color.lerp(AppColors.accentFill, Colors.white, 0.12)!
                  : AppColors.accentFill),
        AppColors.onAccentFill,
      ),
      WebButtonKind.danger => (
        down
            ? Color.lerp(AppColors.danger, Colors.black, 0.15)!
            : AppColors.danger,
        Colors.white,
      ),
      WebButtonKind.secondary => (
        down ? AppColors.surfaceSunken : AppColors.base,
        AppColors.textPrimary,
      ),
      WebButtonKind.ghost => (
        down || _hovered ? AppColors.surfaceSunken : Colors.transparent,
        AppColors.accentText,
      ),
    };
    final shadows = kind == WebButtonKind.ghost || !_enabled || down
        ? const <BoxShadow>[]
        : AppShadows.raised(_hovered ? NeuDepth.medium : NeuDepth.low);

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: ink),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: 18, color: ink),
        if (widget.loading || widget.icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WebText.label(size: 14, color: ink, weight: FontWeight.w700),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: _enabled ? _activate : null,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: GestureDetector(
            onTap: _activate,
            onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedOpacity(
              opacity: widget.onPressed == null && !widget.loading ? 0.45 : 1,
              duration: _quick,
              child: AnimatedContainer(
                duration: _quick,
                curve: _enter,
                height: widget.dense ? 40 : 46,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.dense ? 14 : 18,
                ),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: shadows,
                  border: _focused
                      ? Border.all(
                          color: kind == WebButtonKind.primary
                              ? AppColors.textPrimary
                              : AppColors.accentText,
                          width: 2,
                        )
                      : null,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round raised icon button with an optional count.
class WebIconButton extends StatefulWidget {
  const WebIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.count = 0,
    this.size = 44,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int count;
  final double size;
  final Color? color;

  @override
  State<WebIconButton> createState() => _WebIconButtonState();
}

class _WebIconButtonState extends State<WebIconButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final down = _pressed && enabled;
    final s = widget.size;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.count > 0
            ? '${widget.tooltip}, ${widget.count}'
            : widget.tooltip,
        excludeSemantics: true,
        onTap: widget.onPressed,
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowFocusHighlight: (v) => setState(() => _focused = v),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed?.call();
                return null;
              },
            ),
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() {
              _hovered = false;
              _pressed = false;
            }),
            child: GestureDetector(
              onTap: widget.onPressed,
              onTapDown: enabled
                  ? (_) => setState(() => _pressed = true)
                  : null,
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: SizedBox(
                width: s + 8,
                height: s + 8,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: _quick,
                      curve: _enter,
                      width: s,
                      height: s,
                      decoration: BoxDecoration(
                        color: down ? AppColors.surfaceSunken : AppColors.base,
                        shape: BoxShape.circle,
                        boxShadow: down
                            ? const []
                            : AppShadows.raised(
                                _hovered ? NeuDepth.medium : NeuDepth.low,
                              ),
                        border: _focused
                            ? Border.all(color: AppColors.accentText, width: 2)
                            : null,
                      ),
                      child: Icon(
                        widget.icon,
                        size: s * 0.45,
                        color: widget.color ?? AppColors.textPrimary,
                      ),
                    ),
                    if (widget.count > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: WebCount(count: widget.count),
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

/// A real count — unread, in the cart, waiting. No glow, no pulse.
class WebCount extends StatelessWidget {
  const WebCount({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: _quick,
    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
    child: Container(
      key: ValueKey(count),
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: WebText.label(size: 11, color: AppColors.onAccentFill),
      ),
    ),
  );
}

// ─── Status ──────────────────────────────────────────────────────────────────

/// A status as a word with a dot in its tone — the dot and the word both
/// carry it, so it does not rest on colour alone.
class WebPill extends StatelessWidget {
  const WebPill({super.key, required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.readable(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WebText.label(
                size: 12,
                color: ink,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tabs ────────────────────────────────────────────────────────────────────

/// Filter tabs: a track pressed into the canvas with the selected tab
/// standing up out of it. Scrolls sideways when the labels outgrow the page.
class WebTabs extends StatelessWidget {
  const WebTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.counts,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final List<int>? counts;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: NeuSurface(
          style: NeuStyle.inset,
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.all(5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < labels.length; i++)
                _Tab(
                  label: labels[i],
                  count: counts?[i],
                  selected: i == selected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(i);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.selected;
    return Semantics(
      button: true,
      selected: on,
      label: widget.count == null
          ? widget.label
          : '${widget.label}, ${widget.count}',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: _quick,
            curve: _enter,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.base : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: on ? AppShadows.raised(NeuDepth.flat) : const [],
              border: _focused
                  ? Border.all(color: AppColors.accentText, width: 2)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: WebText.label(
                    size: 13.5,
                    color: on
                        ? AppColors.accentText
                        : (_hovered
                              ? AppColors.textPrimary
                              : AppColors.textSecondary),
                    weight: on ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                if (widget.count != null && widget.count! > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${widget.count}',
                    style:
                        WebText.label(
                          size: 12,
                          color: AppColors.textTertiary,
                        ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Inputs ──────────────────────────────────────────────────────────────────

/// The well every web input sits in — ringed with the accent on focus and
/// with the danger tone on an error.
InputDecoration webInputDecoration({
  String? hint,
  IconData? icon,
  Widget? suffix,
  String? helper,
}) {
  NeuInsetInputBorder well([Color? ring, double w = 1.6]) =>
      NeuInsetInputBorder(
        borderSide: ring == null
            ? BorderSide.none
            : BorderSide(color: ring, width: w),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: WebText.body(size: 14.5, color: AppColors.textTertiary),
    helperText: helper,
    helperMaxLines: 3,
    errorMaxLines: 3,
    filled: true,
    fillColor: AppColors.surfaceSunken,
    hoverColor: Colors.transparent,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 19, color: AppColors.textTertiary),
    suffixIcon: suffix,
    border: well(),
    enabledBorder: well(),
    disabledBorder: well(),
    focusedBorder: well(AppColors.accentText),
    errorBorder: well(AppColors.danger, 1),
    focusedErrorBorder: well(AppColors.danger),
  );
}

/// A labelled text field.
class WebField extends StatelessWidget {
  const WebField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.icon,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.obscure = false,
    this.suffix,
    this.onChanged,
    this.enabled = true,
    this.helper,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscure;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String? helper;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: WebText.label(size: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: obscure ? 1 : maxLines,
          obscureText: obscure,
          onChanged: onChanged,
          enabled: enabled,
          readOnly: readOnly,
          onTap: onTap,
          inputFormatters: inputFormatters,
          cursorColor: AppColors.accentText,
          style: WebText.body(size: 15, color: AppColors.textPrimary),
          decoration: webInputDecoration(
            hint: hint,
            icon: icon,
            suffix: suffix,
            helper: helper,
          ),
        ),
      ],
    );
  }
}

/// A search box in a well.
class WebSearch extends StatelessWidget {
  const WebSearch({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.width,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: AppColors.accentText,
        style: WebText.body(size: 14.5, color: AppColors.textPrimary),
        decoration: webInputDecoration(
          hint: hint,
          icon: Icons.search_rounded,
          suffix: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, v, _) => v.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear search',
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Table ───────────────────────────────────────────────────────────────────

/// One column of a [WebTable].
class WebColumn<T> {
  const WebColumn(
    this.label,
    this.cell, {
    this.flex = 1,
    this.align = Alignment.centerLeft,
    this.primary = false,
  });

  final String label;
  final Widget Function(T row) cell;
  final int flex;
  final Alignment align;

  /// On a phone, the column shown as the card's heading.
  final bool primary;
}

/// Rows of data under a header — the website's answer to the app's long
/// card lists. On a phone browser each row becomes a card: the primary
/// column as its heading and the rest as label/value lines.
class WebTable<T> extends StatelessWidget {
  const WebTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.trailing,
  });

  final List<WebColumn<T>> columns;
  final List<T> rows;
  final ValueChanged<T>? onRowTap;

  /// Actions at the end of each row.
  final Widget Function(T row)? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 640) return _cards(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The header in a groove, so it reads as the table's rail.
            WebWell(
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  for (final c in columns)
                    Expanded(
                      flex: c.flex,
                      // The same right inset as the cells below, so a
                      // right-aligned column's header sits over its values.
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Align(
                          alignment: c.align,
                          child: Text(
                            c.label.toUpperCase(),
                            style: WebText.overline(),
                          ),
                        ),
                      ),
                    ),
                  if (trailing != null) const SizedBox(width: 120),
                ],
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              WebHoverCard(
                onTap: onRowTap == null ? null : () => onRowTap!(rows[i]),
                radius: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    for (final c in columns)
                      Expanded(
                        flex: c.flex,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Align(
                            alignment: c.align,
                            child: c.cell(rows[i]),
                          ),
                        ),
                      ),
                    if (trailing != null)
                      SizedBox(
                        width: 120,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: trailing!(rows[i]),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _cards(BuildContext context) {
    final primary =
        columns.where((c) => c.primary).firstOrNull ?? columns.first;
    final rest = columns.where((c) => c != primary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          WebHoverCard(
            onTap: onRowTap == null ? null : () => onRowTap!(rows[i]),
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                primary.cell(rows[i]),
                const SizedBox(height: 10),
                for (final c in rest)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(c.label, style: WebText.body(size: 12.5)),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: c.cell(rows[i]),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (trailing != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: trailing!(rows[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A label and its value on one line — for a record's details.
class WebKeyValue extends StatelessWidget {
  const WebKeyValue(this.label, this.value, {super.key, this.emphasis = false});

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: WebText.body(size: 14))),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: emphasis
                  ? WebText.numeric(size: 18)
                  : WebText.label(size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// A groove across a panel — a divider in the material, not a line on it.
class WebGroove extends StatelessWidget {
  const WebGroove({super.key, this.vertical = 12});
  final double vertical;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: vertical),
    child: NeuSurface(
      style: NeuStyle.inset,
      depth: NeuDepth.flat,
      color: AppColors.surfaceSunken,
      height: 4,
      borderRadius: BorderRadius.circular(2),
      child: const SizedBox.expand(),
    ),
  );
}

/// A photo with rounded corners, or a tile with the initial when there is
/// none — never a stock picture of something the canteen may not sell.
class WebThumb extends StatelessWidget {
  const WebThumb({
    super.key,
    required this.url,
    required this.name,
    this.size = 48,
    this.radius = 14,
  });

  final String? url;
  final String name;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.surfaceSunken,
      alignment: Alignment.center,
      child: Text(
        name.trim().isEmpty ? '·' : name.trim()[0].toUpperCase(),
        style: WebText.title(size: size * 0.38, color: AppColors.accentText),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url!.isEmpty
            ? fallback
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

// ─── Chips ───────────────────────────────────────────────────────────────────

/// Filter chips that wrap onto new lines instead of scrolling sideways, so
/// none is ever hidden past the edge of the page. The selected chip is
/// pressed in with the accent on its label.
class WebChips extends StatelessWidget {
  const WebChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final l in labels)
          WebChip(
            label: l,
            selected: l == selected,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(l);
            },
          ),
      ],
    );
  }
}

class WebChip extends StatefulWidget {
  const WebChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<WebChip> createState() => _WebChipState();
}

class _WebChipState extends State<WebChip> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.selected;
    return Semantics(
      button: true,
      selected: on,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: _quick,
            curve: _enter,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: on ? AppColors.surfaceSunken : AppColors.base,
              borderRadius: BorderRadius.circular(999),
              boxShadow: on
                  ? const []
                  : AppShadows.raised(_hovered ? NeuDepth.low : NeuDepth.flat),
              border: _focused
                  ? Border.all(color: AppColors.accentText, width: 2)
                  : null,
            ),
            child: Text(
              widget.label,
              style: WebText.label(
                size: 13.5,
                color: on ? AppColors.accentText : AppColors.textPrimary,
                weight: on ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
