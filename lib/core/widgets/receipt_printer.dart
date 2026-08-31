import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'neu_surface.dart';

/// What the printer is doing.
enum ReceiptPrinterStage {
  /// The order has not resolved yet. No paper.
  processing,

  /// Paper is feeding.
  printing,

  /// Paper is out.
  complete,
}

/// How the paper leaves the machine.
enum ReceiptFeedMotion {
  /// One continuous glide. Correct for a document, wrong for a printer.
  smooth,

  /// Nine discrete line-advances with a hold between each. This is the
  /// default because it is the only one that reads as a machine: a thermal
  /// head steps the platen, stops, steps again. A single smooth glide reads
  /// as a panel sliding in, which is what the receipt is trying not to be.
  stepped,
}

/// A receipt printer: a machine with a status screen, and paper feeding out of
/// a slot in its underside.
///
/// Ported from a React/Motion component. The keyframe table and its timings
/// are carried over exactly — that table is the whole effect, and rounding it
/// into "roughly nine steps" loses the unevenness that sells it. What changed
/// is the skin: the machine is a raised neumorphic body and the screen a
/// debossed well, so it belongs to this app rather than to the grayscale
/// palette it came from.
class ReceiptPrinter extends StatelessWidget {
  const ReceiptPrinter({
    super.key,
    required this.stage,
    required this.paper,
    required this.screen,
    this.header,
    this.feedMotion = ReceiptFeedMotion.stepped,
    this.statusLabel,
  });

  final ReceiptPrinterStage stage;

  /// The printed sheet. Laid out at full height from the first frame; the feed
  /// only moves it.
  final Widget paper;

  /// Content of the debossed panel on the machine's face.
  final Widget screen;

  /// Optional row above the screen — a brand mark, a menu.
  final Widget? header;

  final ReceiptFeedMotion feedMotion;

  /// Overrides the stage's own wording.
  final String? statusLabel;

  /// The machine's corner radius and the padding inside it. The screen's
  /// radius is the difference, so the two curves stay parallel.
  static const double _radius = 24;
  static const double _inset = 12;

  /// The full feed, matching the source component.
  static const Duration feedDuration = Duration(milliseconds: 1750);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Machine(
          radius: _radius,
          inset: _inset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) ...[
                SizedBox(height: 44, child: header),
                const SizedBox(height: AppSpacing.xs),
              ],
              _Screen(
                radius: _radius - _inset,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    screen,
                    const SizedBox(height: AppSpacing.sm),
                    _Status(stage: stage, label: statusLabel),
                  ],
                ),
              ),
            ],
          ),
        ),
        // The output overlaps the machine, so the sheet appears to come from
        // inside it rather than from a seam underneath.
        Transform.translate(
          offset: const Offset(0, -16),
          child: FractionallySizedBox(
            widthFactor: 0.88,
            child: _Output(stage: stage, feedMotion: feedMotion, paper: paper),
          ),
        ),
      ],
    );
  }
}

// ─── Machine ───────────────────────────────────────────────────────────────

/// The printer body, with the paper slot cut into its lower edge.
class _Machine extends StatelessWidget {
  const _Machine({
    required this.radius,
    required this.inset,
    required this.child,
  });

  final double radius;
  final double inset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(inset, inset, inset, inset + 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.raised(NeuDepth.medium),
      ),
      child: Stack(
        children: [
          child,
          // The slot. A debossed bar on the machine's underside — the one
          // place an inset well is describing something literal.
          Positioned(
            left: 12,
            right: 12,
            bottom: -12,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.sunkenDark,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.neuShadow.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dark panel on the machine's face.
class _Screen extends StatelessWidget {
  const _Screen({required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NeuSurface(
      style: NeuStyle.inset,
      depth: NeuDepth.low,
      borderRadius: BorderRadius.circular(radius),
      color: AppColors.surfaceSunken,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: child,
    );
  }
}

/// Spinner or tick, and a line of text that swaps as the stage changes.
class _Status extends StatelessWidget {
  const _Status({required this.stage, this.label});

  final ReceiptPrinterStage stage;
  final String? label;

  static const _labels = {
    ReceiptPrinterStage.processing: 'Processing your order',
    ReceiptPrinterStage.printing: 'Printing your receipt',
    ReceiptPrinterStage.complete: 'Order complete',
  };

  @override
  Widget build(BuildContext context) {
    final done = stage == ReceiptPrinterStage.complete;
    final text = label ?? _labels[stage]!;

    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            // Scale from 0.94, never from zero: the indicator is swapping
            // identity, not appearing from nothing.
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: done
                ? const Icon(
                    Icons.check_circle_rounded,
                    key: ValueKey(true),
                    size: 18,
                    color: AppColors.success,
                  )
                : SizedBox(
                    key: const ValueKey(false),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.accentText,
                      backgroundColor: AppColors.border,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.28),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              text,
              key: ValueKey(text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label(
                fontSize: 12.5,
                letterSpacing: 0,
                color: done ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Output ────────────────────────────────────────────────────────────────

/// The window the paper travels through.
///
/// The sheet is translated by a fraction of its own height inside a clip, so
/// nothing above the slot is ever drawn. Transform and opacity only — the
/// sheet is measured once and never relaid out while it feeds.
class _Output extends StatefulWidget {
  const _Output({
    required this.stage,
    required this.feedMotion,
    required this.paper,
  });

  final ReceiptPrinterStage stage;
  final ReceiptFeedMotion feedMotion;
  final Widget paper;

  @override
  State<_Output> createState() => _OutputState();
}

class _OutputState extends State<_Output> with SingleTickerProviderStateMixin {
  late final AnimationController _feed;

  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _feed = AnimationController(
      vsync: this,
      duration: ReceiptPrinter.feedDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first sync happens here, not in initState: it reads the reduced
    // motion setting, and MediaQuery is not available until dependencies are
    // resolved.
    if (_armed) return;
    _armed = true;
    _sync(initial: true);
  }

  @override
  void didUpdateWidget(covariant _Output old) {
    super.didUpdateWidget(old);
    if (old.stage != widget.stage) _sync();
  }

  /// Drives the controller from the stage, so the printer is a function of
  /// its state rather than of whoever called play() last.
  void _sync({bool initial = false}) {
    switch (widget.stage) {
      case ReceiptPrinterStage.processing:
        _feed.value = 0;
      case ReceiptPrinterStage.printing:
        if (!_reduced) {
          _feed.forward(from: 0);
        } else {
          _feed.value = 1;
        }
      case ReceiptPrinterStage.complete:
        // Jumping to the end only matters when the stage skips printing; a
        // feed already running is left to finish.
        if (initial || !_feed.isAnimating) _feed.value = 1;
    }
  }

  bool get _reduced => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  /// The feed table, carried over from the source component.
  ///
  /// Ten advances separated by nine holds. The advances are not even — they
  /// start small, lengthen through the middle and shorten again at the end,
  /// which is what stops it reading as a metronome.
  static final Animatable<double> _stepped = TweenSequence<double>([
    ..._advance(-1.00, -0.91),
    ..._hold(-0.91),
    ..._advance(-0.91, -0.81),
    ..._hold(-0.81),
    ..._advance(-0.81, -0.70),
    ..._hold(-0.70),
    ..._advance(-0.70, -0.58),
    ..._hold(-0.58),
    ..._advance(-0.58, -0.45),
    ..._hold(-0.45),
    ..._advance(-0.45, -0.32),
    ..._hold(-0.32),
    ..._advance(-0.32, -0.20),
    ..._hold(-0.20),
    ..._advance(-0.20, -0.10),
    ..._hold(-0.10),
    ..._advance(-0.10, -0.03),
    ..._hold(-0.03),
    TweenSequenceItem(tween: Tween(begin: -0.03, end: 0.0), weight: 55),
  ]);

  /// One line-feed: 75 thousandths of the run, linear, because the platen
  /// turns at a constant rate.
  static List<TweenSequenceItem<double>> _advance(double from, double to) => [
    TweenSequenceItem(
      tween: Tween(begin: from, end: to),
      weight: 75,
    ),
  ];

  /// The pause between lines: 30 thousandths, holding still.
  static List<TweenSequenceItem<double>> _hold(double at) => [
    TweenSequenceItem(tween: ConstantTween(at), weight: 30),
  ];

  /// The continuous alternative, on the source component's own ease.
  static final Animatable<double> _smooth = Tween<double>(
    begin: -1,
    end: 0,
  ).chain(CurveTween(curve: const Cubic(0.77, 0, 0.175, 1)));

  @override
  Widget build(BuildContext context) {
    final hasPaper = widget.stage != ReceiptPrinterStage.processing;
    final track = widget.feedMotion == ReceiptFeedMotion.stepped
        ? _stepped
        : _smooth;
    final offset = _feed.drive(track);

    return AnimatedOpacity(
      opacity: hasPaper ? 1 : 0,
      duration: const Duration(milliseconds: 160),
      curve: AppMotion.enter,
      child: ClipRect(
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: offset,
              // The sheet is built once and passed through, so a frame costs
              // a composite and nothing else.
              child: widget.paper,
              builder: (context, child) => FractionalTranslation(
                translation: Offset(0, offset.value),
                child: child,
              ),
            ),
            // The slot's shadow, cast on whatever is currently under it.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.neuShadow.withValues(alpha: 0.55),
                        AppColors.neuShadow.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Paper ─────────────────────────────────────────────────────────────────

/// Clips a sheet's lower edge into the tooth pattern a receipt is torn from.
///
/// Forty teeth, four deep, from the source component. A clip rather than a
/// painted overlay so the silhouette is genuinely toothed — a drawn zig-zag
/// in the paper's own colour breaks the moment anything sits behind it.
class ReceiptTornEdgeClipper extends CustomClipper<Path> {
  const ReceiptTornEdgeClipper({this.teeth = 40, this.depth = 4});

  final int teeth;
  final double depth;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - depth);

    final step = size.width / teeth;
    for (var i = teeth - 1; i >= 0; i--) {
      path.lineTo(step * i + step / 2, size.height);
      path.lineTo(step * i, size.height - depth);
    }

    path
      ..lineTo(0, size.height - depth)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(ReceiptTornEdgeClipper old) =>
      old.teeth != teeth || old.depth != depth;
}
