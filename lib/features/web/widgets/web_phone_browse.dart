import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../web_tokens.dart';
import 'web_motion.dart';

/// A campus canteen the hero points at, shared by the sky tiles outside the
/// phone and the store rows inside it.
class WebCanteen {
  const WebCanteen(
    this.name,
    this.sky, {
    required this.search,
    required this.photo,
  });

  /// As shown on the tile and in the phone.
  final String name;
  final WebSky sky;

  /// The tile's photograph, and the store's picture in the phone.
  final String photo;

  /// The building, as typed into the Shop's store search. That search
  /// matches a vendor's name or building, so it travels to
  /// `/user/shop?search=` and opens the Shop already narrowed to it.
  final String search;
}

/// The app's Shop screen in a tilted phone — the hero's one piece of product
/// imagery, and the page's most elevated element.
///
/// The screen keeps the app's own dark surface tokens rather than being
/// restyled to suit the page. It is a drawing of the real Shop screen's
/// layout: the Stores / All products switch, the search field, the category
/// chips and the store list.
///
/// The store rows are the four campus canteens the hero tiles name, each with
/// its building beneath, as the real store list shows it.
///
/// [focus] links the phone to the tiles around it: hover a tile and its chip
/// is selected here while the other canteens step back. That is the purpose
/// of the motion (state indication), and why it runs on hover only.
class WebPhoneBrowse extends StatelessWidget {
  const WebPhoneBrowse({
    super.key,
    required this.width,
    required this.canteens,
    required this.focus,
    this.tilt = true,
  });

  final double width;
  final List<WebCanteen> canteens;
  final ValueNotifier<String?> focus;

  /// The reference's three-quarter lean. Turned off on phones, where the
  /// device is narrow enough that foreshortening makes the screen unreadable.
  final bool tilt;

  /// The screen is laid out at this size and scaled to [width], so the
  /// interior keeps its proportions at every breakpoint instead of reflowing.
  static const Size _design = Size(300, 640);
  static const double _bezel = 9;

  double get height => width * (_design.height / _design.width);

  @override
  Widget build(BuildContext context) {
    final device = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(_bezel),
      decoration: BoxDecoration(
        color: const Color(0xFF05070D),
        borderRadius: BorderRadius.circular(46),
        boxShadow: WebElevation.hero,
        // A one-pixel edge light so the frame separates from the night
        // canvas; without it the black bezel disappears into the page.
        border: Border.all(color: const Color(0xFF2B3354)),
      ),
      child: ClipRRect(
        // Concentric: 46 outer minus the 9px bezel leaves 37.
        borderRadius: BorderRadius.circular(37),
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox.fromSize(
            size: _design,
            child: ValueListenableBuilder<String?>(
              valueListenable: focus,
              builder: (context, focused, _) =>
                  _ShopScreen(canteens: canteens, focused: focused),
            ),
          ),
        ),
      ),
    );

    final framed = Semantics(
      image: true,
      label: 'The AeroDrop Shop screen listing the campus canteens',
      excludeSemantics: true,
      child: RepaintBoundary(child: device),
    );

    if (!tilt) return framed;

    // Perspective first, then the lean. The top tips away from the viewer and
    // the whole device turns counter-clockwise, which is the reference's pose.
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0009)
        ..rotateX(0.38)
        ..rotateZ(-0.34),
      child: framed,
    );
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class _ShopScreen extends StatelessWidget {
  const _ShopScreen({required this.canteens, required this.focused});

  final List<WebCanteen> canteens;

  /// Name of the canteen whose tile is under attention, if any.
  final String? focused;

  static const _gutter = 18.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgDark,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 50),
                const _AppBar(),
                const SizedBox(height: 16),
                const _ModeSwitch(),
                const SizedBox(height: 12),
                const _SearchField(),
                const SizedBox(height: 12),
                // One chip per canteen, matching the tiles around the phone.
                // Hovering a tile selects its chip and the row slides it
                // into view.
                _ChipRow(
                  labels: ['All', for (final c in canteens) c.name],
                  selected: focused ?? 'All',
                ),
                const SizedBox(height: 14),
                for (final c in canteens) ...[
                  _StoreRow(
                    canteen: c,
                    dimmed: focused != null && focused != c.name,
                  ),
                  const SizedBox(height: 9),
                ],
              ],
            ),
          ),
          // The island sits over the content like the real hardware.
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 86,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF05070D),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const Positioned(left: 16, right: 16, bottom: 16, child: _Dock()),
        ],
      ),
    );
  }
}

TextStyle _ui(double size, FontWeight weight, Color color) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

class _AppBar extends StatelessWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Shop',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.textPrimaryDark,
            ),
          ),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.cardDark2,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.shopping_bag_outlined,
            size: 17,
            color: AppColors.textPrimaryDark,
          ),
        ),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch();

  @override
  Widget build(BuildContext context) {
    Widget half(String label, {required bool on}) => Expanded(
      child: Container(
        alignment: Alignment.center,
        decoration: on
            ? BoxDecoration(
                color: AppColors.cardDark2,
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Text(
          label,
          style: _ui(
            11.5,
            on ? FontWeight.w700 : FontWeight.w500,
            on ? AppColors.textPrimaryDark : AppColors.textSecondaryDark,
          ),
        ),
      ),
    );

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.sunkenDark,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [half('Stores', on: true), half('All products', on: false)],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.sunkenDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 16,
            color: AppColors.textTertiaryDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Search campus stores or buildings',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: _ui(11, FontWeight.w400, AppColors.textTertiaryDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// The chip row. It is wider than the screen, as in the app, so when a chip
/// off the right edge is selected the row slides to bring it in — the same
/// thing the app's horizontal list does when you tap a chip near the edge.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.labels, required this.selected});

  final List<String> labels;
  final String selected;

  static const double _height = 30;
  static const double _gap = 6;
  static const double _padX = 12;

  static TextStyle _style(bool on) => _ui(
    11,
    FontWeight.w600,
    on ? AppColors.bgDark : AppColors.textSecondaryDark,
  );

  /// Chip widths, measured once per build. Six short labels, so this is
  /// cheaper than a second layout pass.
  List<double> _widths() => [
    for (final label in labels)
      (TextPainter(
            text: TextSpan(text: label, style: _style(true)),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout()).width +
          _padX * 2,
  ];

  @override
  Widget build(BuildContext context) {
    final widths = _widths();
    final index = labels.indexOf(selected).clamp(0, labels.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxWidth;
        final total =
            widths.fold<double>(0, (a, w) => a + w) +
            _gap * (labels.length - 1);
        var left = 0.0;
        for (var i = 0; i < index; i++) {
          left += widths[i] + _gap;
        }
        // Keep the selected chip fully in view with one chip's worth of
        // context to its left, never scrolling past either end.
        final maxShift = (total - viewport).clamp(0.0, double.infinity);
        final shift = (left - widths.first - _gap).clamp(0.0, maxShift);

        return SizedBox(
          height: _height,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: shift),
                duration: const Duration(milliseconds: 320),
                curve: WebMotion.enter,
                builder: (context, dx, child) =>
                    Transform.translate(offset: Offset(-dx, 0), child: child),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < labels.length; i++) ...[
                      if (i > 0) const SizedBox(width: _gap),
                      _Chip(
                        label: labels[i],
                        on: labels[i] == selected,
                        style: _style(labels[i] == selected),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.style});

  final String label;
  final bool on;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: WebMotion.hover,
      curve: WebMotion.enter,
      height: _ChipRow._height,
      padding: const EdgeInsets.symmetric(horizontal: _ChipRow._padX),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? AppColors.accent : AppColors.cardDark2,
        borderRadius: BorderRadius.circular(15),
      ),
      child: AnimatedDefaultTextStyle(
        duration: WebMotion.hover,
        curve: WebMotion.enter,
        style: style,
        child: Text(label, maxLines: 1),
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({required this.canteen, required this.dimmed});

  final WebCanteen canteen;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: dimmed ? 0.32 : 1,
      duration: WebMotion.hover,
      curve: WebMotion.enter,
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.cardDark2,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // The store's thumbnail is the same photograph as its tile
            // outside the phone, so the row and the tile read as one thing.
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                canteen.photo,
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                cacheWidth: 126,
                excludeFromSemantics: true,
                // Without the photo the slot keeps the canteen's colour.
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: canteen.sky.gradient.colors.first),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    canteen.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ui(12, FontWeight.w700, AppColors.textPrimaryDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    canteen.search,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ui(
                      11,
                      FontWeight.w500,
                      AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiaryDark,
            ),
          ],
        ),
      ),
    );
  }
}

/// The app's floating nav dock, with Shop active.
class _Dock extends StatelessWidget {
  const _Dock();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, {bool on = false}) => Container(
      width: 44,
      height: 36,
      decoration: on
          ? BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(18),
            )
          : null,
      child: Icon(
        icon,
        size: 19,
        color: on ? AppColors.bgDark : AppColors.textSecondaryDark,
      ),
    );

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.sunkenDark,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          item(Icons.home_rounded),
          item(Icons.storefront_rounded, on: true),
          item(Icons.receipt_long_rounded),
          item(Icons.person_rounded),
        ],
      ),
    );
  }
}
