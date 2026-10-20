import 'package:flutter/material.dart';

import '../web_tokens.dart';
import 'web_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';

/// The page's filled control.
///
/// Light on the night canvas, so it is the brightest thing in the chrome
/// without needing a glow. Hover takes the accent rather than lifting — a
/// colour change at 160ms is the right size of feedback for something
/// hovered tens of times a visit.
///
/// [onPanel] is the variant for the closing panel, where the fill is already
/// brand blue: white fill, deep indigo text.
class WebFilledAction extends StatelessWidget {
  const WebFilledAction({
    super.key,
    required this.label,
    required this.onTap,
    this.onPanel = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool onPanel;

  /// The nav bar's size: shorter, so it sits on the bar's centre line beside
  /// text links.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fill = onPanel ? WebInk.onPanel : WebInk.accent;
    final hoverFill = onPanel ? WebInk.text : AppColors.accentLight;

    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: HoverLift(
        onTap: onTap,
        lift: 0,
        builder: (context, hovered, child) => AnimatedContainer(
          duration: WebMotion.hover,
          curve: WebMotion.enter,
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 18, vertical: 11)
              : const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
          // Raised out of the canvas in the accent; hover lifts it. On the
          // download panel's colour it stays flat — the panel's own shadow
          // is the depth there.
          decoration: BoxDecoration(
            color: hovered ? hoverFill : fill,
            // Concentric with the label's line box rather than a full pill:
            // at this size a capsule reads soft (R-11).
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            boxShadow: onPanel
                ? null
                : WebInk.web.shadows(hovered ? NeuDepth.medium : NeuDepth.low),
          ),
          child: child,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: WebType.action(color: WebInk.canvas, weight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// The secondary action: a label with a rule under it that takes the accent
/// on hover. No circled play triangle — there is no video, and a play button
/// that scrolls the page is a promise the page does not keep.
class WebRuledAction extends StatefulWidget {
  const WebRuledAction({
    super.key,
    required this.label,
    required this.onTap,
    this.onPanel = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool onPanel;

  @override
  State<WebRuledAction> createState() => _WebRuledActionState();
}

class _WebRuledActionState extends State<WebRuledAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.onPanel ? WebInk.onPanel : WebInk.text;
    final hover = widget.onPanel ? WebInk.onPanel : WebInk.accent;

    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          // The label sizes the Stack and the rule is laid against it. An
          // unsized rule in a Column stretches to the widest width it is
          // offered, which pushed this action onto its own line in a Wrap.
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.5),
                child: AnimatedDefaultTextStyle(
                  duration: WebMotion.hover,
                  curve: WebMotion.enter,
                  style: WebType.action(
                    color: _hovered ? hover : base,
                    weight: FontWeight.w600,
                  ),
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: WebMotion.hover,
                  curve: WebMotion.enter,
                  height: 1.5,
                  color: _hovered ? hover : base.withValues(alpha: 0.32),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
