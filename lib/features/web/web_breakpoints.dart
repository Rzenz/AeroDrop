import 'package:flutter/widgets.dart';

/// Layout breakpoints for the AeroDrop marketing site.
///
/// The mobile app uses [AppSpacing.tablet]/[AppSpacing.desktop], which are
/// tuned for a phone-first product. A marketing page has a different problem:
/// its hero is a three-column composition that has to collapse twice, so it
/// needs a band between "phone" and "full desktop" where the feature strip
/// drops below the hero but the headline keeps its display size.
enum WebBreak {
  /// < 720 — single column, stacked.
  compact,

  /// 720–1119 — two columns: copy beside the visual, feature strip below.
  medium,

  /// >= 1120 — the full three-column hero from the design.
  expanded,
}

extension WebBreakX on WebBreak {
  bool get isCompact => this == WebBreak.compact;
  bool get isMedium => this == WebBreak.medium;
  bool get isExpanded => this == WebBreak.expanded;

  /// True for anything narrower than the full desktop composition.
  bool get stacksHero => this != WebBreak.expanded;

  /// Horizontal page gutter. Grows with the viewport so the content column
  /// stays optically centred rather than pinned to the edges.
  double get gutter => switch (this) {
    WebBreak.compact => 20,
    WebBreak.medium => 40,
    WebBreak.expanded => 64,
  };

  /// Vertical rhythm between major sections.
  ///
  /// Deliberately not one value: the page alternates generous and tight
  /// spacing so sections read as a sequence rather than a single strip.
  double get sectionGap => switch (this) {
    WebBreak.compact => 72,
    WebBreak.medium => 104,
    WebBreak.expanded => 136,
  };
}

/// The widest the content column is allowed to grow. Past this the page keeps
/// centring but stops stretching, so line length stays readable on a 27".
const double kWebContentMaxWidth = 1240;

WebBreak webBreakOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 720) return WebBreak.compact;
  if (width < 1120) return WebBreak.medium;
  return WebBreak.expanded;
}

/// Centres a section's content at [kWebContentMaxWidth] and applies the
/// breakpoint's gutter. Every section on the page sits inside one of these so
/// their left edges line up exactly.
class WebContentFrame extends StatelessWidget {
  const WebContentFrame({
    super.key,
    required this.child,
    this.maxWidth = kWebContentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + brk.gutter * 2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: brk.gutter),
          child: child,
        ),
      ),
    );
  }
}
