import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// One element arriving on a shared timeline.
///
/// Every [Entrance] fades and rises the same distance on the same curve and
/// differs only in when it starts. That is what makes a screen read as one
/// movement arriving in order rather than a handful of separate animations
/// that happen to overlap.
///
/// Give it a controller and a [start] position on that controller's 0–1
/// timeline. Prefer [Entrance.stagger] for a list of siblings.
class Entrance extends StatelessWidget {
  const Entrance({
    super.key,
    required this.progress,
    required this.start,
    required this.child,
    this.span = 0.30,
    this.rise = 16,
  });

  /// Places element [index] on the timeline, [gap] apart, from [from].
  ///
  /// Keeps the maths out of the call site so a reordered list does not need
  /// its intervals recomputed by hand.
  factory Entrance.stagger({
    Key? key,
    required Animation<double> progress,
    required int index,
    required Widget child,
    double from = 0.30,
    double gap = 0.06,
    double rise = 16,
  }) => Entrance(
    key: key,
    progress: progress,
    start: from + gap * index,
    rise: rise,
    child: child,
  );

  final Animation<double> progress;

  /// Where this element starts on the parent timeline, 0–1.
  final double start;

  /// How much of the timeline it takes to arrive.
  final double span;

  /// Travel distance in logical pixels. Small on purpose — a long slide reads
  /// as the screen still loading.
  final double rise;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: progress,
      curve: Interval(
        start.clamp(0.0, 1.0),
        math.min(start + span, 1.0),
        curve: AppMotion.enter,
      ),
    );

    return AnimatedBuilder(
      animation: curve,
      // Opacity and transform only, and the subtree is built once and passed
      // through, so a frame costs a composite rather than a rebuild.
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, rise * (1 - curve.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
