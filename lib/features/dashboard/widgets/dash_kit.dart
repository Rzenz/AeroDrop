import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/cart_model.dart';
import '../../../core/models/delivery_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/providers/weather_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/neu_surface.dart';
import '../../../core/widgets/drone_svg_painter.dart';
import '../../../core/widgets/wide_shell.dart';
import '../../web/web_tokens.dart';

/// The customer dashboard's kit.
///
/// Composition after the reference: a sidebar, a centre column (search,
/// banner, categories, the food grid) and an order panel on the right. Built
/// on the app's own theme tokens ([AppColors]), so it follows the customer's
/// light or dark setting like every other screen in the app, and borrowing
/// the landing page's language where colour carries meaning: the sky
/// gradients ([WebSky]) for the one banner and a single filled action per
/// surface.
///
/// The material is the app's neumorphic one ([AppShadows], [NeuSurface]):
/// cards and buttons are raised out of the canvas, inputs and the selected
/// chip are pressed into it, and structure comes from that depth rather than
/// from hairlines.
///
/// Every value on these surfaces is real — products, prices, the cart, the
/// active drone delivery, campus weather. The reference's discount prices,
/// "Dine in / Take away" and "Upgrade" promo have no counterpart in AeroDrop
/// and are not imitated (R-38).

// ─── Tokens ──────────────────────────────────────────────────────────────────

class Dash {
  const Dash._();

  /// The sidebar appears from this width; below it the bottom dock does the
  /// same job.
  static const double sidebarBreak = WideLayout.breakpoint;

  /// The order panel joins the dashboard from this width; below it the cart
  /// stays one tap away on the dock's centre button.
  static const double panelBreak = 1320;

  static const double sidebarWidth = WideLayout.sidebarWidth;
  static const double panelWidth = 360;

  static const Curve enter = Cubic(0.2, 0, 0, 1);
  static const Duration quick = Duration(milliseconds: 160);

  /// The one hairline left, between the cart and its total.
  static Color get rule => AppColors.border;

  static String peso(double v) => '₱${v.toStringAsFixed(2)}';

  static TextStyle display(double size, {Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: size * -0.03,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle title({double size = 16, Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.2,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle body({double size = 14, Color? color, FontWeight? weight}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w400,
        height: 1.45,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle label({double size = 13, Color? color}) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: color ?? AppColors.textPrimary,
  );

  static TextStyle money({double size = 17, Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: color ?? AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

/// Entrance for dashboard blocks: rise 12px and fade, staggered 40ms by
/// index and capped, so a long grid does not take seconds to arrive
/// (`animate`: 30–80ms stagger). Once, on first build; off under reduced
/// motion.
extension DashReveal on Widget {
  Widget dashReveal(BuildContext context, int index) {
    if (Dash.reduced(context)) return this;
    final delay = (60 + index.clamp(0, 12) * 40).ms;
    return animate()
        .fadeIn(delay: delay, duration: 380.ms, curve: Dash.enter)
        .move(
          begin: const Offset(0, 12),
          end: Offset.zero,
          delay: delay,
          duration: 460.ms,
          curve: Dash.enter,
        );
  }
}

// ─── Identity ────────────────────────────────────────────────────────────────
//
// The wide-window rail itself lives in features/shared/role_frame.dart, shared
// with the vendor and admin areas.

/// "Good morning" etc. Plain words: the previous version appended a weather
/// emoji to each, which is decoration (R-04).
String dashGreeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// A count on a nav entry or icon. It marks a real number — unread
/// notifications, orders in progress — and carries no glow or pulse (R-31).
class DashBadge extends StatelessWidget {
  const DashBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        style: Dash.label(size: 11, color: AppColors.onAccentFill),
      ),
    );
  }
}

class DashAvatar extends StatelessWidget {
  const DashAvatar({super.key, this.name, this.url, this.size = 40});

  final String? name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = (name ?? '').trim().isEmpty
        ? 'A'
        : name!.trim()[0].toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: Dash.title(size: size * 0.4, color: AppColors.onAccentFill),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.accentFill,
        shape: BoxShape.circle,
      ),
      child: url != null && url!.isNotEmpty
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}

// ─── Weather ─────────────────────────────────────────────────────────────────

/// Campus weather, in the slot where the reference sells an upgrade. It is
/// the one piece of context that changes whether an order flies at all.
/// The dot marks the real dispatch state; it does not pulse (R-31).
class DashWeatherCard extends ConsumerWidget {
  const DashWeatherCard({super.key, this.compact = false});

  /// One line, for the phone layout.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider);
    final hasReading = w.id != null;
    // With no reading the provider's default status is not a fact about the
    // sky, so the card says it has no reading rather than claiming drones
    // are grounded (R-38).
    final status = hasReading ? w.safetyStatus : 'unknown';
    final (label, line, tone) = switch (status) {
      'unknown' => (
        w.isLoading ? 'Checking' : 'No reading yet',
        'The dispatch check reads campus weather before every flight.',
        AppColors.textTertiary,
      ),
      'grounded' => (
        'Grounded',
        'Drones are not flying right now.',
        AppColors.danger,
      ),
      'caution' => (
        'Caution',
        'Flights run slower in this wind.',
        AppColors.warning,
      ),
      _ => ('Clear to fly', 'Drones are flying normally.', AppColors.success),
    };
    final reading = hasReading
        ? '${w.temperatureDisplay} · ${w.windDisplay}'
        : (w.isLoading
              ? 'Loading campus weather…'
              : 'Updates every 15 minutes');

    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
    );

    if (compact) {
      // Status and reading on two lines rather than squeezed into one: on a
      // phone, one line cut both off.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.base,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.raised(),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 6), child: dot),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Campus weather: $label', style: Dash.label(size: 13.5)),
                  const SizedBox(height: 2),
                  Text(reading, style: Dash.body(size: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.base,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.raised(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Campus weather', style: Dash.body(size: 12.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              dot,
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Dash.title(size: 16, color: AppColors.readable(tone)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(line, style: Dash.body(size: 13)),
          const SizedBox(height: 10),
          Text(
            reading,
            style: Dash.label(
              size: 13,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

// ─── Top bar ─────────────────────────────────────────────────────────────────

/// Search, cart and notifications — the reference's top row. Search filters
/// the dashboard's own grid as you type; the cart and bell carry live counts.
class DashTopBar extends ConsumerWidget {
  const DashTopBar({
    super.key,
    required this.controller,
    required this.onSearch,
    this.showCart = true,
    this.leading,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearch;

  /// Hidden when the order panel is on screen, which already is the cart.
  final bool showCart;

  /// The greeting on the phone layout, where there is no sidebar.
  final Widget? leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);

    // Pressed into the canvas: an input is a well you type into.
    final search = NeuSurface(
      style: NeuStyle.inset,
      depth: NeuDepth.low,
      color: AppColors.surfaceSunken,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      borderRadius: BorderRadius.circular(16),
      alignment: Alignment.center,
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onSearch,
              textInputAction: TextInputAction.search,
              style: Dash.body(size: 14.5, color: AppColors.textPrimary),
              cursorColor: AppColors.accentText,
              decoration: InputDecoration(
                // The app theme fills and outlines inputs; this field sits
                // inside its own box, so both are switched off here.
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Search food or a canteen',
                hintStyle: Dash.body(size: 14.5, color: AppColors.textTertiary),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, v, _) => v.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear search',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () {
                      controller.clear();
                      onSearch('');
                    },
                  ),
          ),
        ],
      ),
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCart) ...[
          ValueListenableBuilder<List<CartItem>>(
            valueListenable: cartNotifier,
            builder: (context, cart, _) => DashIconButton(
              icon: Icons.shopping_bag_outlined,
              tooltip: 'Cart',
              count: cart.fold<int>(0, (s, i) => s + i.quantity),
              onTap: () => context.push('/user/cart'),
            ),
          ),
          const SizedBox(width: 10),
        ],
        DashIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          count: unread,
          onTap: () => context.push('/user/notifications'),
        ),
      ],
    );

    if (leading != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: leading!),
              const SizedBox(width: 12),
              actions,
            ],
          ),
          const SizedBox(height: 16),
          search,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: search),
        const SizedBox(width: 14),
        actions,
      ],
    );
  }
}

class DashIconButton extends StatefulWidget {
  const DashIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.count = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int count;

  @override
  State<DashIconButton> createState() => _DashIconButtonState();
}

class _DashIconButtonState extends State<DashIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.count > 0
            ? '${widget.tooltip}, ${widget.count}'
            : widget.tooltip,
        onTap: widget.onTap,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: Dash.quick,
                    width: 48,
                    height: 48,
                    // Raised at rest, lifted on hover, pressed flat into the
                    // canvas while held.
                    decoration: BoxDecoration(
                      color: _pressed
                          ? AppColors.surfaceSunken
                          : AppColors.base,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _pressed
                          ? const []
                          : AppShadows.raised(
                              _hovered ? NeuDepth.medium : NeuDepth.low,
                            ),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 21,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (widget.count > 0)
                    Positioned(
                      top: -5,
                      right: -5,
                      // The count changes with the cart; a scale-in makes
                      // that change noticeable at the edge of vision.
                      child: AnimatedSwitcher(
                        duration: Dash.quick,
                        transitionBuilder: (child, a) =>
                            ScaleTransition(scale: a, child: child),
                        child: DashBadge(
                          key: ValueKey(widget.count),
                          count: widget.count,
                        ),
                      ),
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

// ─── Banner ──────────────────────────────────────────────────────────────────

/// The reference's promotion banner, carrying AeroDrop's one real promise
/// instead of a discount: order from a campus canteen and watch the drone
/// fly it in. The night sky gradient is the app icon's own (the landing
/// page's night tile), the one place on the dashboard with full colour.
class DashBanner extends StatelessWidget {
  const DashBanner({super.key, required this.onBrowse, this.compact = false});

  final VoidCallback onBrowse;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const sky = WebSky.night;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: sky.gradient,
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        boxShadow: AppShadows.raised(NeuDepth.medium),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final art = constraints.maxWidth >= 560;
          return Stack(
            children: [
              if (art)
                Positioned(
                  right: 28,
                  top: 0,
                  bottom: 0,
                  child: _BannerDrone(size: constraints.maxWidth * 0.2),
                ),
              Padding(
                padding: EdgeInsets.all(compact ? 22 : 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: art
                            ? constraints.maxWidth * 0.62
                            : double.infinity,
                      ),
                      child: Text(
                        'Lunch from a campus canteen, flown to your building.',
                        style: Dash.display(
                          compact ? 22 : 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Text(
                        'Pick something below, check out, and follow the '
                        'drone on the map until it lands.',
                        style: Dash.body(
                          size: compact ? 13.5 : 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 16 : 22),
                    _BannerButton(label: 'Browse canteens', onTap: onBrowse),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BannerButton extends StatefulWidget {
  const _BannerButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_BannerButton> createState() => _BannerButtonState();
}

class _BannerButtonState extends State<_BannerButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
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
          child: AnimatedScale(
            scale: _pressed && !Dash.reduced(context) ? 0.96 : 1,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: Dash.quick,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              decoration: BoxDecoration(
                color: _hovered ? const Color(0xFFE6ECFF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.label,
                style: Dash.label(
                  size: 14.5,
                  color: const Color(0xFF1F2F7A),
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The drone in the banner's corner, carrying a parcel. It arrives once —
/// flying in from the left and settling — the dashboard's one delight
/// moment, and then holds still.
class _BannerDrone extends StatelessWidget {
  const _BannerDrone({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final drone = ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: size * 0.9,
              height: size * 0.9,
              child: CustomPaint(
                painter: DroneSvgPainter(
                  animationValue: 0,
                  lineColor: Colors.white,
                  accentColor: WebSky.noon.from,
                ),
              ),
            ),
            Container(width: 1.5, height: size * 0.08, color: Colors.white70),
            Container(
              width: size * 0.18,
              height: size * 0.14,
              decoration: BoxDecoration(
                gradient: WebSky.afternoon.gradient,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
    if (Dash.reduced(context)) return drone;
    return drone
        .animate()
        .fadeIn(delay: 250.ms, duration: 500.ms)
        .move(
          begin: const Offset(-80, -24),
          end: Offset.zero,
          delay: 250.ms,
          duration: 1000.ms,
          curve: Dash.enter,
        );
  }
}

// ─── Categories ──────────────────────────────────────────────────────────────

/// The category chips. The selected chip is pressed in, with the accent on
/// its label; the change is a 160ms transition — chips are tapped often, so no more motion
/// than that (`animate`: tens-per-day tier).
class DashCategoryChips extends StatelessWidget {
  const DashCategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // Room around the chips for their shadows, which the list would
    // otherwise clip flat.
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        clipBehavior: Clip.none,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final c = categories[i];
          final on = c == selected;
          return Semantics(
            button: true,
            selected: on,
            label: c,
            onTap: () => onSelected(c),
            excludeSemantics: true,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(c);
                },
                child: AnimatedContainer(
                  duration: Dash.quick,
                  curve: Dash.enter,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  // The selected chip is pressed into the canvas, the rest
                  // stand slightly out of it.
                  decoration: BoxDecoration(
                    color: on ? AppColors.surfaceSunken : AppColors.base,
                    borderRadius: BorderRadius.circular(23),
                    boxShadow: on ? const [] : AppShadows.raised(NeuDepth.flat),
                  ),
                  child: Text(
                    c,
                    style: Dash.label(
                      size: 14,
                      color: on ? AppColors.accentText : AppColors.textPrimary,
                    ).copyWith(
                      fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Product card ────────────────────────────────────────────────────────────

/// One product: picture, name, canteen, price, and the add button.
///
/// Fixed text lines (one each, ellipsised) so every card in a row is the
/// same height whatever the product is called — no ragged grid. The add
/// button turns into a quantity once the product is in the cart, so the card
/// itself confirms the add (feedback), and the cart counts above change too.
class DashProductCard extends StatefulWidget {
  const DashProductCard({
    super.key,
    required this.product,
    required this.inCart,
    required this.onOpen,
    required this.onAdd,
  });

  final ProductModel product;

  /// How many of this product are in the cart.
  final int inCart;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  @override
  State<DashProductCard> createState() => _DashProductCardState();
}

class _DashProductCardState extends State<DashProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final soldOut = p.stock <= 0 || !p.isAvailable;
    final lift = _hovered && !Dash.reduced(context);

    return Semantics(
      button: true,
      label: '${p.name} from ${p.vendorName}, ${Dash.peso(p.price)}',
      onTap: widget.onOpen,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onOpen,
          child: AnimatedContainer(
            duration: Dash.quick,
            curve: Dash.enter,
            transform: Matrix4.translationValues(0, lift ? -3 : 0, 0),
            // Raised from the canvas; hovering lifts it further. The photo
            // is set into the card with a margin, like a print mounted on
            // board, rather than bled to its edges.
            decoration: BoxDecoration(
              color: AppColors.base,
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppShadows.raised(
                lift ? NeuDepth.medium : NeuDepth.low,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: _ProductImage(product: p),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Two lines reserved for every name, so a long one
                      // wraps instead of being cut, and short ones leave the
                      // same space — every card in a row stays one height.
                      SizedBox(
                        height:
                            MediaQuery.textScalerOf(context).scale(15) *
                                1.25 *
                                2 +
                            1,
                        child: Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Dash.title(size: 15),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // The canteen, also given two reserved lines:
                      // "Engineering Building Canteen" does not fit one at
                      // phone width.
                      SizedBox(
                        height:
                            MediaQuery.textScalerOf(context).scale(12.5) *
                                1.45 *
                                2 +
                            1,
                        child: Text(
                          p.vendorName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Dash.body(size: 12.5),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                Dash.peso(p.price),
                                style: Dash.money(size: 17),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _AddButton(
                            count: widget.inCart,
                            // Sold out, or every unit in stock is already in
                            // the cart: the button stops rather than adding
                            // what the canteen cannot supply.
                            soldOut: soldOut || widget.inCart >= p.stock,
                            onAdd: widget.onAdd,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product});
  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    // No photo: a sky tile with the first letter, picked from the name so a
    // product keeps its colour between visits. Not a stock food picture,
    // which would show something the canteen may not sell (R-38).
    final sky = WebSky.values[product.name.hashCode.abs() % 4];
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(gradient: sky.gradient),
      child: Center(
        child: Text(
          product.name.isEmpty ? '·' : product.name[0].toUpperCase(),
          style: Dash.display(34, color: sky.ink),
        ),
      ),
    );
    final soldOut = product.stock <= 0 || !product.isAvailable;

    return Stack(
      fit: StackFit.expand,
      children: [
        product.imageUrl.isEmpty
            ? placeholder
            : Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : placeholder,
              ),
        if (product.hasReviews)
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: Color(0xFFFFC857),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    product.rating.toStringAsFixed(1),
                    style: Dash.label(size: 11.5, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        if (soldOut)
          ColoredBox(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Text(
                'Sold out',
                style: Dash.label(size: 13, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddButton extends StatefulWidget {
  const _AddButton({
    required this.count,
    required this.soldOut,
    required this.onAdd,
  });

  final int count;
  final bool soldOut;
  final VoidCallback onAdd;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.soldOut;
    final inCart = widget.count > 0;

    return Semantics(
      button: true,
      enabled: enabled,
      label: !enabled && inCart
          ? '${widget.count} in cart, no more in stock'
          : (inCart ? 'Add another, ${widget.count} in cart' : 'Add to cart'),
      onTap: enabled ? widget.onAdd : null,
      excludeSemantics: true,
      child: GestureDetector(
        // Its own tap, so adding does not also open the product.
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onAdd();
              }
            : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed && !Dash.reduced(context) ? 0.9 : 1,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: Dash.quick,
            curve: Dash.enter,
            height: 36,
            constraints: const BoxConstraints(minWidth: 36),
            padding: EdgeInsets.symmetric(horizontal: inCart ? 10 : 0),
            decoration: BoxDecoration(
              color: enabled ? AppColors.accentFill : AppColors.surfaceSunken,
              borderRadius: BorderRadius.circular(18),
              boxShadow: enabled && !_pressed
                  ? AppShadows.raised(NeuDepth.flat)
                  : const [],
            ),
            child: AnimatedSwitcher(
              duration: Dash.quick,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: Tween(begin: 0.6, end: 1.0).animate(a),
                  child: child,
                ),
              ),
              child: inCart
                  ? Row(
                      key: ValueKey('n${widget.count}'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: enabled
                              ? AppColors.onAccentFill
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${widget.count}',
                          style: Dash.label(
                            size: 13.5,
                            color: enabled
                                ? AppColors.onAccentFill
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      Icons.add_rounded,
                      key: const ValueKey('add'),
                      size: 20,
                      color: enabled
                          ? AppColors.onAccentFill
                          : AppColors.textTertiary,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Active delivery ─────────────────────────────────────────────────────────

/// The drone currently carrying this customer's order, with its progress.
class DashDeliveryCard extends StatelessWidget {
  const DashDeliveryCard({super.key, required this.delivery});

  final DeliveryModel delivery;

  @override
  Widget build(BuildContext context) {
    final status = switch (delivery.status) {
      DeliveryStatus.inTransit => 'In flight',
      DeliveryStatus.assigning => 'Assigning a drone',
      _ => 'Waiting to dispatch',
    };
    final progress = delivery.status == DeliveryStatus.inTransit
        ? delivery.progress.clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.base,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.raised(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: WebSky.night.gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CustomPaint(
                    painter: DroneSvgPainter(
                      animationValue: 0,
                      lineColor: Colors.white,
                      accentColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status, style: Dash.title(size: 15)),
                    Text(
                      delivery.packageName.isEmpty
                          ? 'Your order'
                          : delivery.packageName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Dash.body(size: 13),
                    ),
                  ],
                ),
              ),
              if (delivery.eta.isNotEmpty)
                Text(delivery.eta, style: Dash.label(size: 13)),
            ],
          ),
          const SizedBox(height: 14),
          NeuSurface(
            style: NeuStyle.inset,
            depth: NeuDepth.flat,
            color: AppColors.surfaceSunken,
            height: 8,
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Dash.enter,
              builder: (context, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.accentFill,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: DashTextLink(
              label: 'Track it live',
              onTap: () => context.go('/user/track'),
            ),
          ),
        ],
      ),
    );
  }
}

class DashTextLink extends StatefulWidget {
  const DashTextLink({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<DashTextLink> createState() => _DashTextLinkState();
}

class _DashTextLinkState extends State<DashTextLink> {
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
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              widget.label,
              style: Dash.label(
                size: 13.5,
                color: _hovered ? AppColors.textPrimary : AppColors.accentText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Order panel ─────────────────────────────────────────────────────────────

/// The reference's "Order Details", built on the live cart: each line with
/// a quantity stepper, the subtotal, and checkout. Lines slide in when added
/// and the panel's height glides as they come and go, so nothing jumps.
///
/// The delivery fee is not shown as a number here, because it depends on the
/// drop-off building and the parcel's weight, which are chosen at checkout.
class DashOrderPanel extends StatelessWidget {
  const DashOrderPanel({super.key, this.activeDelivery});

  final DeliveryModel? activeDelivery;

  @override
  Widget build(BuildContext context) {
    // A raised slab beside the grid rather than a ruled-off column.
    return Container(
      width: Dash.panelWidth,
      margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.base,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.raised(NeuDepth.medium),
      ),
      child: SafeArea(
        left: false,
        child: ValueListenableBuilder<List<CartItem>>(
          valueListenable: cartNotifier,
          builder: (context, cart, _) {
            final count = cart.fold<int>(0, (s, i) => s + i.quantity);
            final total = cart.fold<double>(0, (s, i) => s + i.subtotal);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Your order', style: Dash.display(22)),
                      ),
                      if (cart.isNotEmpty)
                        DashTextLink(
                          label: 'Clear',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            cartNotifier.clear();
                          },
                        ),
                    ],
                  ),
                ),
                if (activeDelivery != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                    child: DashDeliveryCard(delivery: activeDelivery!),
                  ),
                const SizedBox(height: 18),
                Expanded(
                  child: cart.isEmpty
                      ? const _EmptyCart()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                          itemCount: cart.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => _CartLine(
                            key: ValueKey(cart[i].productId),
                            item: cart[i],
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // A groove, not a line: the total sits in the same
                      // material as everything above it.
                      NeuSurface(
                        style: NeuStyle.inset,
                        depth: NeuDepth.flat,
                        color: AppColors.surfaceSunken,
                        height: 4,
                        borderRadius: BorderRadius.circular(2),
                        child: const SizedBox.expand(),
                      ),
                      const SizedBox(height: 16),
                      _SummaryRow(
                        label: count == 1 ? '1 item' : '$count items',
                        value: Dash.peso(total),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Delivery fee is worked out at checkout from your '
                        'building and the parcel weight.',
                        style: Dash.body(size: 12.5),
                      ),
                      const SizedBox(height: 16),
                      _CheckoutButton(
                        enabled: cart.isNotEmpty,
                        total: total,
                        onTap: () => context.push('/user/checkout'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 34,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Your cart is empty',
            style: Dash.title(size: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + on anything in the grid to add it here.',
            style: Dash.body(size: 13.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({super.key, required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final line = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.base,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.raised(),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: item.imageUrl.isEmpty
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: WebSky
                            .values[item.productName.hashCode.abs() % 4]
                            .gradient,
                      ),
                    )
                  : Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          ColoredBox(color: AppColors.surfaceSunken),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Dash.label(size: 13.5),
                ),
                const SizedBox(height: 4),
                Text(Dash.peso(item.subtotal), style: Dash.money(size: 15)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Stepper(item: item),
        ],
      ),
    );
    if (Dash.reduced(context)) return line;
    return line
        .animate()
        .fadeIn(duration: 260.ms, curve: Dash.enter)
        .move(
          begin: const Offset(16, 0),
          end: Offset.zero,
          duration: 300.ms,
          curve: Dash.enter,
        );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String label, VoidCallback onTap) => Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        radius: 18,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 17, color: AppColors.textPrimary),
        ),
      ),
    );

    return NeuSurface(
      style: NeuStyle.inset,
      depth: NeuDepth.low,
      color: AppColors.surfaceSunken,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          step(
            item.quantity <= 1
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            item.quantity <= 1 ? 'Remove ${item.productName}' : 'One less',
            () => cartNotifier.decrement(item.productId),
          ),
          SizedBox(
            width: 22,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: Dash.label(
                size: 13.5,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          step(
            Icons.add_rounded,
            'One more',
            () => cartNotifier.increment(item.productId),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Dash.body(size: 14))),
        AnimatedSwitcher(
          duration: Dash.quick,
          child: Text(value, key: ValueKey(value), style: Dash.money(size: 18)),
        ),
      ],
    );
  }
}

class _CheckoutButton extends StatefulWidget {
  const _CheckoutButton({
    required this.enabled,
    required this.total,
    required this.onTap,
  });

  final bool enabled;
  final double total;
  final VoidCallback onTap;

  @override
  State<_CheckoutButton> createState() => _CheckoutButtonState();
}

class _CheckoutButtonState extends State<_CheckoutButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Checkout',
      onTap: enabled ? widget.onTap : null,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          onTap: enabled ? widget.onTap : null,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed && !Dash.reduced(context) ? 0.97 : 1,
            duration: const Duration(milliseconds: 100),
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.45,
              duration: Dash.quick,
              child: AnimatedContainer(
                duration: Dash.quick,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _hovered && enabled
                      ? AppColors.primary
                      : AppColors.accentFill,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: enabled && !_pressed
                      ? AppShadows.raised()
                      : const [],
                ),
                child: Text(
                  'Checkout',
                  style: Dash.label(
                    size: 15,
                    color: _hovered && enabled
                        ? Colors.white
                        : AppColors.onAccentFill,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
