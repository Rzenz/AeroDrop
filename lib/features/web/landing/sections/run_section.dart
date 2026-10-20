import 'package:flutter/material.dart';

import '../../web_breakpoints.dart';
import '../../web_tokens.dart';
import '../../widgets/web_motion.dart';

/// What happens between placing an order and the drone landing.
///
/// Five stages as a ruled list, not five cards. A card grid gives every stage
/// the same visual weight; a list lets the clearance stage be three times the
/// height of its neighbours because it genuinely does three times the work.
/// The numerals are the only ornament, and they are information.
class RunSection extends StatelessWidget {
  const RunSection({super.key});

  static const _stages = <_Stage>[
    _Stage(
      'You order',
      'Pick a vendor, add items to the cart, choose the building you want it '
          'flown to, and pay by card or on delivery.',
    ),
    _Stage(
      'The vendor prepares it',
      'They confirm the order, prepare it, then mark it ready for pickup. '
          'Stock comes off the shelf at that moment, not before.',
    ),
    _Stage(
      'Pre-flight clearance',
      'Four conditions are checked before anything leaves the hub. If one '
          'fails the order waits on the ground rather than flying.',
      checks: [
        'Campus weather is not grounded',
        'A drone is available and idle',
        'Its battery is at 15 percent or more',
        'Total cargo is under the 0.5 kg payload',
      ],
    ),
    _Stage(
      'It flies the run',
      'Hub to the vendor, vendor to your building. Position, altitude, speed '
          'and battery stream to your screen the whole way.',
    ),
    _Stage(
      'It returns to base',
      'The delivery is logged, your receipt is issued, and the drone flies '
          'itself back to the hub to recharge.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    return WebContentFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Asymmetric opener: the marker sits in its own narrow column and
          // the title starts where the list's title column will start, so the
          // heading and the rows below share one vertical edge.
          RevealOnScroll(
            child: brk.isExpanded
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 92, child: _Marker('The run')),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Text(
                            'Five stages, and nothing flies until the fourth '
                            'one clears.',
                            style: WebType.title(brk),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Marker('The run'),
                      const SizedBox(height: 18),
                      Text(
                        'Five stages, and nothing flies until the fourth one '
                        'clears.',
                        style: WebType.title(brk),
                      ),
                    ],
                  ),
          ),
          SizedBox(height: brk.isCompact ? 48 : 76),
          const WebRule(),
          for (var i = 0; i < _stages.length; i++)
            RevealOnScroll(
              delay: WebMotion.stagger * (i.clamp(0, 3)),
              child: Column(
                children: [_StageRow(_stages[i], i), const WebRule()],
              ),
            ),
        ],
      ),
    );
  }
}

class _Stage {
  const _Stage(this.title, this.body, {this.checks = const []});
  final String title;
  final String body;
  final List<String> checks;
}

class _Marker extends StatelessWidget {
  const _Marker(this.label);
  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: WebType.meta(color: WebInk.accent));
}

/// One row. Hovering tints the numeral and nudges the row's content a few
/// pixels right, which is enough to say the list is alive without turning
/// every row into a button — none of these rows are clickable.
class _StageRow extends StatefulWidget {
  const _StageRow(this.stage, this.index);

  final _Stage stage;
  final int index;

  @override
  State<_StageRow> createState() => _StageRowState();
}

class _StageRowState extends State<_StageRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);
    final number = (widget.index + 1).toString().padLeft(2, '0');

    final numeral = AnimatedDefaultTextStyle(
      duration: WebMotion.hover,
      curve: WebMotion.enter,
      style: WebType.numeral(
        brk,
        color: _hovered ? WebInk.accent : WebInk.textFaint,
      ),
      child: Text(number),
    );

    final title = Text(widget.stage.title, style: WebType.entry(brk));

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.stage.body, style: WebType.body()),
        if (widget.stage.checks.isNotEmpty) ...[
          const SizedBox(height: 20),
          for (var i = 0; i < widget.stage.checks.length; i++) ...[
            if (i > 0) const SizedBox(height: 11),
            _Check(widget.stage.checks[i]),
          ],
        ],
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: WebMotion.hover,
        curve: WebMotion.enter,
        padding: EdgeInsets.fromLTRB(
          _hovered && brk.isExpanded ? 6 : 0,
          brk.isCompact ? 28 : 38,
          0,
          brk.isCompact ? 28 : 38,
        ),
        child: brk.isExpanded
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 92, child: numeral),
                  Expanded(flex: 34, child: title),
                  const SizedBox(width: 40),
                  Expanded(
                    flex: 52,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: body,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 44, child: numeral),
                      Expanded(child: title),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: body,
                  ),
                ],
              ),
      ),
    );
  }
}

/// A clearance condition. The dash is a typographic list bullet, not an icon —
/// a green tick beside each one would read as "already passed", which is a
/// state this page cannot know.
class _Check extends StatelessWidget {
  const _Check(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 11, right: 14),
          child: Container(width: 14, height: 1.5, color: WebInk.accent),
        ),
        Expanded(
          child: Text(
            label,
            style: WebType.body(color: WebInk.text).copyWith(fontSize: 15),
          ),
        ),
      ],
    );
  }
}
