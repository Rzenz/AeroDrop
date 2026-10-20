import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../web_breakpoints.dart';
import '../../web_tokens.dart';
import '../../widgets/web_motion.dart';
import '../../../../core/widgets/neu_surface.dart';

/// About us: who built AeroDrop and who it is for.
///
/// Composition: the statement beside the three account types, then the four
/// students who built it — a row of portraits, each named on a frosted plate
/// set into the photo.
///
/// Every claim here comes from the README: the capstone and the three account
/// types. The names and roles are the team's own.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('About Us', style: WebType.meta(color: WebInk.accent)),
        const SizedBox(height: 18),
        Text(
          'Built at UCLM, for the people who study and sell there.',
          style: WebType.title(brk),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'AeroDrop is the capstone project of fourth-year BSIT students at '
            'the University of Cebu Lapu-Lapu and Mandaue. Students, faculty '
            'and staff order from approved campus vendors, and a drone flies '
            'each order to their building.',
            style: WebType.lead(brk),
          ),
        ),
      ],
    );

    const facts = _Accounts();

    final top = brk.isExpanded
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 50, child: RevealOnScroll(child: intro)),
              const SizedBox(width: 64),
              const Expanded(
                flex: 50,
                child: Padding(
                  // Level with the title rather than the marker, so the two
                  // columns share an optical top.
                  padding: EdgeInsets.only(top: 34),
                  child: RevealOnScroll(delay: WebMotion.stagger, child: facts),
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RevealOnScroll(child: intro),
              SizedBox(height: brk.isCompact ? 36 : 48),
              const RevealOnScroll(child: facts),
            ],
          );

    return WebContentFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          top,
          SizedBox(height: brk.isCompact ? 64 : 96),
          const _Team(),
        ],
      ),
    );
  }
}

// ─── Team ────────────────────────────────────────────────────────────────────

class _Member {
  const _Member(this.name, this.role, this.crop, {this.photo});

  final String name;
  final String role;

  /// Which part of the campus photograph sits behind the initials if the
  /// portrait cannot load, so the four fallbacks are not one picture
  /// repeated.
  final Alignment crop;

  /// The member's portrait in `assets/images/team/`. Without one the card
  /// shows the member's initials.
  final String? photo;

  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

const _members = [
  _Member(
    'Kim Andrie Ogdol',
    'Project Manager',
    Alignment(-1, 0),
    photo: 'assets/images/team/kim.jpg',
  ),
  _Member(
    'Erickson Tiu',
    'Hacker',
    Alignment(-0.33, 0),
    photo: 'assets/images/team/erickson.jpg',
  ),
  _Member(
    'Rozencrantz Oñada',
    'Hipster',
    Alignment(0.33, 0),
    photo: 'assets/images/team/rozencrantz.jpg',
  ),
  _Member(
    'Lurinylle Clark Ardiente',
    'Hacker',
    Alignment(1, 0),
    photo: 'assets/images/team/lurinylle.jpg',
  ),
];

/// "Meet our team": four portrait cards in a row, two by two on a tablet or
/// a phone.
class _Team extends StatelessWidget {
  const _Team();

  static const _gap = 22.0;

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Meet our team', style: WebType.title(brk)),
        const SizedBox(height: 14),
        Text(
          'Fourth-year BSIT students at the University of Cebu Lapu-Lapu and '
          'Mandaue.',
          style: WebType.lead(brk),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RevealOnScroll(child: header),
        SizedBox(height: brk.isCompact ? 28 : 40),
        LayoutBuilder(
          builder: (context, box) {
            final columns = brk.isExpanded ? 4 : 2;
            final gap = brk.isCompact ? 14.0 : _gap;
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            final style = _nameStyle(brk);
            // Every plate in the grid gets the same number of name lines —
            // the most any name needs at this width — so a long name wrapping
            // does not make its plate taller than its neighbours'.
            final scaler = MediaQuery.textScalerOf(context);
            var lines = 1;
            for (final m in _members) {
              final painter = TextPainter(
                text: TextSpan(text: m.name, style: style),
                textDirection: TextDirection.ltr,
                textScaler: scaler,
                maxLines: 2,
              )..layout(maxWidth: width - _TeamCard.plateInset * 2 - 28);
              if (painter.computeLineMetrics().length > 1) lines = 2;
              painter.dispose();
            }
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < _members.length; i++)
                  SizedBox(
                    width: width,
                    child: RevealOnScroll(
                      delay: WebMotion.stagger * i,
                      child: _TeamCard(
                        member: _members[i],
                        nameLines: lines,
                        nameStyle: style,
                        compact: brk.isCompact,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static TextStyle _nameStyle(WebBreak brk) => GoogleFonts.plusJakartaSans(
    fontSize: brk.isCompact ? 14.5 : 17,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.2,
    color: WebInk.text,
  );
}

/// One member: the portrait fills a raised card, and the name and role sit
/// on a frosted plate set into its foot. Hover lifts the card a level and
/// eases the portrait in by 4% — the photo responds, the plate holds still.
class _TeamCard extends StatefulWidget {
  const _TeamCard({
    required this.member,
    required this.nameLines,
    required this.nameStyle,
    required this.compact,
  });

  final _Member member;
  final int nameLines;
  final TextStyle nameStyle;
  final bool compact;

  static const plateInset = 10.0;

  @override
  State<_TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<_TeamCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final lift = _hovered && !reduced;
    final radius = BorderRadius.circular(widget.compact ? 22 : 28);
    final scaler = MediaQuery.textScalerOf(context);
    final nameHeight =
        scaler.scale(widget.nameStyle.fontSize!) *
            widget.nameStyle.height! *
            widget.nameLines +
        1;

    // If a portrait cannot load: the campus, under a flat dark wash, with
    // the member's initials over it.
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: WebInk.canvas,
        image: DecorationImage(
          image: const AssetImage(WebPhoto.campus),
          onError: WebPhoto.ignore,
          fit: BoxFit.cover,
          alignment: m.crop,
          colorFilter: ColorFilter.mode(
            WebInk.canvas.withValues(alpha: 0.62),
            BlendMode.srcOver,
          ),
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.25),
        child: Text(
          m.initials,
          style: WebType.displayAt(
            widget.compact ? 40 : 56,
            color: WebInk.text,
          ),
        ),
      ),
    );

    final portrait = m.photo == null
        ? placeholder
        : Image.asset(
            m.photo!,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.35),
            errorBuilder: (_, _, _) => placeholder,
          );

    final plate = ClipRRect(
      borderRadius: BorderRadius.circular(widget.compact ? 14 : 18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: widget.compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: WebPhoto.plate,
            borderRadius: BorderRadius.circular(widget.compact ? 14 : 18),
            border: Border.all(color: WebInk.text.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: nameHeight,
                child: Center(
                  child: Text(
                    m.name,
                    textAlign: TextAlign.center,
                    maxLines: widget.nameLines,
                    style: widget.nameStyle,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                m.role,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WebType.body(
                  color: WebInk.textSoft,
                ).copyWith(fontSize: widget.compact ? 12.5 : 14, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: '${m.name}, ${m.role}',
      image: true,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: WebMotion.enter,
          transform: Matrix4.translationValues(0, lift ? -6 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: WebInk.web.shadows(
              lift ? NeuDepth.high : NeuDepth.medium,
            ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: AspectRatio(
              // Taller on a phone, where the two-line plate takes more of
              // the card, so the face and chin above it stay clear.
              aspectRatio: widget.compact ? 0.62 : 0.82,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedScale(
                    scale: lift ? 1.04 : 1,
                    duration: const Duration(milliseconds: 480),
                    curve: WebMotion.enter,
                    child: portrait,
                  ),
                  Positioned(
                    left: _TeamCard.plateInset,
                    right: _TeamCard.plateInset,
                    bottom: _TeamCard.plateInset,
                    child: plate,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The three account types, as three small raised cards, each with its icon
/// set into a well. On a phone they stack, because three columns of two-word
/// headings at 340px stop reading as a set.
class _Accounts extends StatelessWidget {
  const _Accounts();

  static const _items = [
    (
      'Students, faculty, staff',
      'Browse, order, and follow the drone in.',
      Icons.school_outlined,
    ),
    (
      'Vendors',
      'Approved by an administrator, then sell and fulfil.',
      Icons.storefront_outlined,
    ),
    (
      'Administrators',
      'Run the fleet, the weather status and approvals.',
      Icons.admin_panel_settings_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    Widget item((String, String, IconData) entry) => NeuSurface(
      palette: WebInk.web,
      depth: NeuDepth.low,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          NeuSurface(
            style: NeuStyle.inset,
            palette: WebInk.web,
            color: WebInk.web.sunken,
            width: 40,
            height: 40,
            borderRadius: BorderRadius.circular(12),
            alignment: Alignment.center,
            child: Icon(entry.$3, size: 20, color: WebInk.accent),
          ),
          const SizedBox(height: 14),
          Text(
            entry.$1,
            style: WebType.action(color: WebInk.text, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(entry.$2, style: WebType.body().copyWith(fontSize: 14.5)),
        ],
      ),
    );

    final header = Text('One sign-in, three accounts', style: WebType.meta());

    if (brk.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 18),
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: item(_items[i])),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) const SizedBox(width: 18),
                Expanded(child: item(_items[i])),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
