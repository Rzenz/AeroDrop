import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/neu_input_border.dart';
import '../../../core/widgets/neu_surface.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../web/web_breakpoints.dart';
import '../../web/web_tokens.dart';
import '../../web/widgets/web_motion.dart';

/// The sign-in and registration screens' own kit, built on the website's
/// tokens so that leaving the landing page for a form does not feel like
/// changing products.
///
/// Composition, after the reference: one framed page split in two — the form
/// on the left, set flat on the night canvas with generous space and a large
/// sentence-case title, and the campus photograph on the right, dissolving
/// into the canvas along its inner edge rather than meeting the form at a
/// hard seam. On a phone the photograph becomes a header that fades down
/// into the form.
///
/// The photograph is the one taken at UCLM that the app's welcome screen
/// already uses. It is the only image on these screens, and it is real: the
/// place the drone flies over, not a stock illustration (R-22).
///
/// The material is the app's neumorphic one, in the site's dark palette
/// ([WebInk.web]): fields are wells pressed into the canvas, buttons and the
/// selected segment stand out of it and press in when held, and the
/// photograph is mounted on a raised panel. Focus is always an accent ring,
/// because soft shadows alone do not show where the keyboard is.
///
/// Dials: ENERGY 2 / RHYTHM 1 / MOTION 2. A form is a task, so motion is
/// limited to arrival: the photograph settles in once, the form's rows rise
/// in a short stagger, and nothing loops.

// ─── Tokens ──────────────────────────────────────────────────────────────────

class AuthInk {
  const AuthInk._();

  /// Field fill: one step down from the canvas, the floor of the well.
  static const Color field = AppColors.sunkenDark;
  static const Color fieldFocused = Color(0xFF161E36);

  /// For the few controls identified by their edge alone — an empty
  /// checkbox. 3:1 against the well (WCAG 1.4.11).
  static const Color fieldEdge = Color(0xFF5E6B94);

  static const NeuPalette neu = WebInk.web;

  /// A field's well, optionally ringed — the accent when focused, the danger
  /// tone on an error.
  static NeuInsetInputBorder well([Color? ring, double width = 1.6]) =>
      NeuInsetInputBorder(
        palette: neu,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: ring == null
            ? BorderSide.none
            : BorderSide(color: ring, width: width),
      );

  static const Color danger = AppColors.danger;
}

// ─── Shell ───────────────────────────────────────────────────────────────────

/// The page: form beside the photograph on a wide screen, photograph above
/// the form on a narrow one.
///
/// Full-bleed on the website — no frame, no outer margin — so the photograph
/// runs to the window's edges as it does in the reference.
///
/// On a wide screen the form is sized to fit the window without scrolling:
/// fields pair up side by side ([AuthPair]) and the vertical rhythm tightens
/// on shorter windows ([AuthDensity]). A scroll view stays underneath purely
/// as a safety net for a window too short for any sensible fit — content is
/// never clipped to keep the page still. Phones scroll as phones do; the
/// keyboard alone takes half the screen.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.child,
    this.vendor = false,
    this.onBack,
    this.formWidth = 440,
  });

  /// The form column.
  final Widget child;

  /// The vendor door. It warms the photograph's grade from the night blue to
  /// dusk, so switching doors visibly changes the place as well as the title
  /// (state indication); the headings carry the same change in words.
  final bool vendor;

  /// Where the back control goes. Defaults to popping, or to the website's
  /// home when there is nothing to pop (a form opened from a link).
  final VoidCallback? onBack;

  /// The form column's widest measure. Registration passes a wider one so
  /// its paired fields keep a comfortable width each.
  final double formWidth;

  static const double wideBreak = 980;

  void _back(BuildContext context) {
    if (onBack != null) return onBack!();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(kIsWeb ? '/' : '/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    if (size.width >= wideBreak) {
      final panel = size.width * 0.46;
      // The form's side insets grow with the window, as in the reference,
      // so the column sits in from the edge instead of hugging it.
      final inset = ((panel - formWidth) / 2).clamp(40.0, 112.0);

      return Scaffold(
        backgroundColor: WebInk.canvas,
        body: Row(
          children: [
            SizedBox(
              width: panel,
              child: SafeArea(
                right: false,
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        inset,
                        context.authGap(20),
                        inset,
                        0,
                      ),
                      child: _TopBar(onBack: () => _back(context)),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              padding: EdgeInsets.symmetric(horizontal: inset),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                // Centred, as in the reference. Centring
                                // alone re-centres the column the instant
                                // its height changes — between wizard steps,
                                // or when the vendor door hides Google
                                // sign-in — and the heading jumps. The
                                // AnimatedSize turns that into a 280ms glide
                                // (preventing a jarring change), and is off
                                // under reduced motion.
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: context.authGap(28),
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: formWidth,
                                      ),
                                      child: AnimatedSize(
                                        duration:
                                            MediaQuery.disableAnimationsOf(
                                              context,
                                            )
                                            ? Duration.zero
                                            : const Duration(milliseconds: 280),
                                        curve: WebMotion.enter,
                                        alignment: Alignment.topCenter,
                                        child: child,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // The photograph mounted on a raised panel, inset from the
            // window, rather than bled to its edges.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 20, 20, 20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: AuthInk.neu.shadows(NeuDepth.high),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: _CampusPhoto(vendor: vendor, wide: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final gutter = size.width < 380 ? 16.0 : 22.0;
    final photoHeight = (size.height * 0.3).clamp(200.0, 300.0);

    return Scaffold(
      backgroundColor: WebInk.canvas,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: photoHeight + MediaQuery.paddingOf(context).top,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CampusPhoto(vendor: vendor, wide: false),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _TopBar(
                          onBack: () => _back(context),
                          overPhoto: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SafeArea(top: false, child: child),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back on the left, where a reader looks for the way out first; the
/// wordmark on the right, where it signs the page without competing with the
/// heading for the first glance. The wordmark goes home.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, this.overPhoto = false});

  final VoidCallback onBack;

  /// Over the phone header photograph, where a scrim sits behind it.
  final bool overPhoto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          AuthTextLink(
            label: 'Back',
            icon: Icons.arrow_back_rounded,
            color: overPhoto ? WebInk.text : WebInk.textSoft,
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          // Expanded + right alignment, not a Spacer: a Spacer beside a
          // Flexible splits the free space between them and parks the
          // wordmark mid-bar instead of at the edge.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                link: true,
                label: 'AeroDrop home',
                excludeSemantics: true,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.go(kIsWeb ? '/' : '/welcome'),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BrandMark(size: 26, elevated: false),
                        SizedBox(width: 10),
                        Flexible(child: _Wordmark()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) => Text(
    'AeroDrop',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: WebType.action(
      color: WebInk.text,
      weight: FontWeight.w800,
    ).copyWith(fontSize: 16.5, letterSpacing: -0.3),
  );
}

// ─── Photograph ──────────────────────────────────────────────────────────────

/// The campus photograph, graded into the night theme.
///
/// Three layers over the photo, each with one job:
/// 1. A grade: the night (or, for vendors, dusk) sky at low strength, so a
///    daylight photograph of a white building sits in a dark page instead of
///    glaring out of it. It animates between doors.
/// 2. The dissolve: canvas to clear across the inner third, so the photo
///    melts into the form side as the reference's painting does.
/// 3. A floor scrim so the caption reads on any part of the picture.
///
/// It arrives once — a fade with a 4% settle in scale over 1.2s — and then
/// holds still. A slow endless pan would be the loop R-19 rules out.
class _CampusPhoto extends StatelessWidget {
  const _CampusPhoto({
    required this.vendor,
    required this.wide,
    this.backdrop = false,
  });

  final bool vendor;
  final bool wide;

  /// Behind a centred card rather than beside or above a form: the photo
  /// fills the page, graded deeper and vignetted to the canvas at its edges
  /// so the card in the middle reads against a calm field.
  final bool backdrop;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final grade = vendor ? WebSky.dusk.to : WebSky.night.to;

    // The UC sign is left of centre in the source; these keep it in view and
    // clear of the dissolve.
    final focus = backdrop
        ? const Alignment(-0.25, -0.2)
        : (wide ? const Alignment(-0.45, -0.1) : const Alignment(-0.2, -0.3));

    Widget photo = Image.asset(
      'assets/images/uclm_campus.jpg',
      fit: BoxFit.cover,
      alignment: focus,
      // Decoded at display size rather than full resolution.
      cacheWidth: 1400,
      semanticLabel:
          'The University of Cebu Lapu-Lapu and Mandaue campus building',
    );
    if (!reduced) {
      photo = photo
          .animate()
          .fadeIn(duration: 700.ms, curve: WebMotion.enter)
          .scale(
            begin: const Offset(1.04, 1.04),
            end: const Offset(1, 1),
            duration: 1200.ms,
            curve: WebMotion.enter,
          );
    }

    // Clipped, because the 1.04 starting scale would otherwise spill past
    // the photo's edge and over the form while it settles.
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: WebInk.canvas),
          photo,
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: grade),
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 420),
            curve: WebMotion.enter,
            builder: (context, color, _) => ColoredBox(
              color: (color ?? grade).withValues(alpha: backdrop ? 0.5 : 0.38),
            ),
          ),
          // Into the form below (narrow), or into the canvas around the card
          // (backdrop). The wide photograph is mounted on its own panel and
          // needs no dissolve.
          if (backdrop || !wide)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: backdrop
                    ? RadialGradient(
                        radius: 1.1,
                        stops: const [0, 0.55, 1],
                        // Mostly canvas: the card in the middle is cut from
                        // the canvas, and its soft shadows only read against
                        // it.
                        colors: [
                          WebInk.canvas.withValues(alpha: 0.72),
                          WebInk.canvas.withValues(alpha: 0.86),
                          WebInk.canvas.withValues(alpha: 0.97),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: const [0, 0.45, 1],
                        colors: [
                          WebInk.canvas,
                          WebInk.canvas.withValues(alpha: 0.35),
                          WebInk.canvas.withValues(alpha: 0.55),
                        ],
                      ),
              ),
            ),
          if (wide && !backdrop)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 160,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      WebInk.canvas.withValues(alpha: 0.75),
                      WebInk.canvas.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          if (wide)
            Positioned(
              right: 36,
              bottom: 30,
              child: ExcludeSemantics(
                child: Text(
                  'University of Cebu Lapu-Lapu and Mandaue',
                  style: WebType.meta(color: WebInk.textSoft),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Density ─────────────────────────────────────────────────────────────────

extension AuthDensity on BuildContext {
  /// A vertical gap, tightened on a wide but short window — a 13-inch laptop
  /// at 1440×800 — so the form fits it without scrolling. Phones keep the
  /// full rhythm because they scroll anyway.
  double authGap(double gap) {
    final size = MediaQuery.sizeOf(this);
    if (size.width < AuthShell.wideBreak) return gap;
    if (size.height < 760) return gap * 0.5;
    if (size.height < 880) return gap * 0.52;
    if (size.height < 1000) return gap * 0.78;
    return gap;
  }

  /// True on a wide window short enough that fields and headings step down
  /// — anything below a 1000px-tall window, which is most laptops.
  bool get authShort {
    final size = MediaQuery.sizeOf(this);
    return size.width >= AuthShell.wideBreak && size.height < 1000;
  }
}

/// Two controls side by side when there is room for both at a comfortable
/// width, stacked otherwise. Their tops align, so a field and a select of
/// equal height sit on one line.
class AuthPair extends StatelessWidget {
  const AuthPair({
    super.key,
    required this.first,
    required this.second,
    this.gap = 18,
  });

  final Widget first;
  final Widget second;

  /// The vertical gap when stacked.
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 400) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 14),
              Expanded(child: second),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            first,
            SizedBox(height: gap),
            second,
          ],
        );
      },
    );
  }
}

// ─── Form header ─────────────────────────────────────────────────────────────

/// The form's own title and one line under it — the reference's large
/// sentence-case greeting. Plus Jakarta Sans at display weight rather than
/// the landing page's wide uppercase face: a form is read up close, and an
/// uppercase wide title this close to the fields would shout over them.
class AuthHeading extends StatelessWidget {
  const AuthHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.inCard = false,
  });

  final String title;
  final String? subtitle;

  /// Inside an [AuthCard]: one step down from the page heading, because the
  /// card's own edge already frames it.
  final bool inCard;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AuthShell.wideBreak;
    final height = MediaQuery.sizeOf(context).height;
    final size = inCard
        ? (wide ? 36.0 : 30.0)
        : !wide
        ? 34.0
        : (height < 880 ? 36.0 : (context.authShort ? 42.0 : 48.0));
    // A card sits in the middle of the page, so its heading centres with it.
    final align = inCard ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment: inCard
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: align,
          style: GoogleFonts.plusJakartaSans(
            fontSize: size,
            fontWeight: FontWeight.w800,
            height: 1.04,
            letterSpacing: size * -0.035,
            color: WebInk.text,
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: wide ? 12 : 8),
          Text(
            subtitle!,
            textAlign: align,
            style: WebType.lead(
              wide ? WebBreak.expanded : WebBreak.compact,
              color: WebInk.textSoft,
            ).copyWith(fontSize: wide ? 18 : 15.5, height: 1.45),
          ),
        ],
      ],
    );
  }
}

// ─── Reveal ──────────────────────────────────────────────────────────────────

extension AuthReveal on Widget {
  /// The form's entrance: each row rises 12px and fades in, 50ms after the
  /// one above it (`animate`: 30–80ms stagger), after the tile has started to
  /// resolve. Off under reduced motion.
  Widget authReveal(BuildContext context, int index) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return this;
    final delay = (180 + index.clamp(0, 10) * 50).ms;
    return animate()
        .fadeIn(delay: delay, duration: 420.ms, curve: WebMotion.enter)
        .move(
          begin: const Offset(0, 12),
          end: Offset.zero,
          delay: delay,
          duration: 520.ms,
          curve: WebMotion.enter,
        );
  }
}

// ─── Field ───────────────────────────────────────────────────────────────────

/// A labelled text field: label above, a hairline well below. The outline
/// takes the accent on focus and the danger tone on error; the leading icon
/// follows the outline, so focus has a second, colour-independent cue in the
/// icon's position next to the caret.
///
/// Parameters match `NeuTextField`, so a form moves between the two by
/// changing one name.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.labelText,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.onChanged,
    this.textInputAction,
    this.focusNode,
    this.readOnly = false,
    this.inputFormatters,
    this.enabled = true,
    this.onTap,
    this.autofillHints,
    this.helperText,
    this.maxLength,
  });

  final String labelText;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool readOnly;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final VoidCallback? onTap;
  final Iterable<String>? autofillHints;
  final String? helperText;
  final int? maxLength;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  FocusNode? _owned;
  FocusNode get _node => widget.focusNode ?? (_owned ??= FocusNode());
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted && _node.hasFocus != _focused) {
      setState(() => _focused = _node.hasFocus);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.labelText,
          style: WebType.meta(
            color: _focused ? WebInk.text : WebInk.textSoft,
          ).copyWith(fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          focusNode: _node,
          validator: widget.validator,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          onChanged: widget.onChanged,
          textInputAction: widget.textInputAction,
          readOnly: widget.readOnly,
          inputFormatters: widget.inputFormatters,
          enabled: widget.enabled,
          onTap: widget.onTap,
          autofillHints: widget.autofillHints,
          maxLength: widget.maxLength,
          cursorColor: WebInk.accent,
          style: WebType.body(color: WebInk.text).copyWith(fontSize: 15),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: WebType.body(
              color: WebInk.textFaint,
            ).copyWith(fontSize: 15),
            helperText: widget.helperText,
            helperStyle: WebType.meta(),
            helperMaxLines: 3,
            errorStyle: WebType.meta(
              color: AuthInk.danger,
            ).copyWith(fontSize: 12.5),
            errorMaxLines: 3,
            filled: true,
            fillColor: _focused ? AuthInk.fieldFocused : AuthInk.field,
            hoverColor: Colors.transparent,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: context.authShort ? 13 : 16,
            ),
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(
                    widget.prefixIcon,
                    size: 19,
                    color: _focused ? WebInk.accent : WebInk.textFaint,
                  ),
            suffixIcon: widget.suffixIcon,
            counterStyle: WebType.meta(),
            border: AuthInk.well(),
            enabledBorder: AuthInk.well(),
            disabledBorder: AuthInk.well(),
            focusedBorder: AuthInk.well(WebInk.accent),
            errorBorder: AuthInk.well(AuthInk.danger, 1),
            focusedErrorBorder: AuthInk.well(AuthInk.danger),
          ),
        ),
      ],
    );
  }
}

/// The eye toggle for a password field.
class AuthObscureToggle extends StatelessWidget {
  const AuthObscureToggle({
    super.key,
    required this.obscured,
    required this.onPressed,
  });

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: obscured ? 'Show password' : 'Hide password',
    onPressed: onPressed,
    icon: Icon(
      obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      size: 19,
      color: WebInk.textSoft,
    ),
  );
}

// ─── Dropdown ────────────────────────────────────────────────────────────────

/// A labelled select in the same well as [AuthField].
class AuthDropdown<T> extends StatelessWidget {
  const AuthDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AuthWell(
      label: label,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: WebInk.raised,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: WebInk.textSoft,
          ),
          style: WebType.body(color: WebInk.text).copyWith(fontSize: 15),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// The field well without a text input inside it — for a select, a loading
/// line, or an error with a retry.
class AuthWell extends StatelessWidget {
  const AuthWell({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: WebType.meta(color: WebInk.textSoft).copyWith(fontSize: 13),
        ),
        const SizedBox(height: 8),
        NeuSurface(
          style: NeuStyle.inset,
          palette: AuthInk.neu,
          color: AuthInk.field,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            // The same height as an [AuthField] in either density, so a
            // field and a select paired by [AuthPair] line up.
            constraints: BoxConstraints(minHeight: context.authShort ? 46 : 52),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: child,
          ),
        ),
      ],
    );
  }
}

// ─── Buttons ─────────────────────────────────────────────────────────────────

enum AuthButtonVariant {
  /// The form's one filled action: the accent, raised out of the canvas.
  primary,

  /// Cut from the canvas itself, raised. For the alternatives — Google,
  /// Back.
  secondary,
}

/// A full-width action, raised out of the canvas. Hover lifts it; pressing
/// pushes it into the canvas (its shadow goes and its fill drops a step) and
/// settles it at 0.97 — 0.96 on a button this wide moves its edges far
/// enough to read as a jump. Disabled is dimmed and flat, not hidden.
class AuthButton extends StatefulWidget {
  const AuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.leading,
    this.variant = AuthButtonVariant.primary,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  /// A custom mark before the label, such as the Google "G".
  final Widget? leading;
  final AuthButtonVariant variant;

  @override
  State<AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<AuthButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _activate() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.variant == AuthButtonVariant.primary;
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final down = _pressed && _enabled;
    final fill = primary
        ? (down
              ? AppColors.accentDark
              : (_hovered && _enabled ? AppColors.accentLight : WebInk.accent))
        : (down ? AuthInk.field : WebInk.canvas);
    final ink = primary ? WebInk.canvas : WebInk.text;
    final shadows = !_enabled || down
        ? const <BoxShadow>[]
        : AuthInk.neu.shadows(_hovered ? NeuDepth.medium : NeuDepth.low);

    final label = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: ink),
          )
        else ...[
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 10),
          ] else if (widget.icon != null) ...[
            Icon(widget.icon, size: 18, color: ink),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WebType.action(
                color: ink,
                weight: FontWeight.w700,
              ).copyWith(fontSize: 15),
            ),
          ),
        ],
      ],
    );

    return FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
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
        child: Semantics(
          button: true,
          enabled: _enabled,
          label: widget.text,
          onTap: _enabled ? _activate : null,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: _activate,
            onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed && !reduced ? 0.97 : 1,
              duration: WebMotion.press,
              curve: WebMotion.enter,
              child: AnimatedOpacity(
                opacity: widget.onPressed == null && !widget.isLoading
                    ? 0.45
                    : 1,
                duration: WebMotion.hover,
                child: AnimatedContainer(
                  duration: WebMotion.hover,
                  curve: WebMotion.enter,
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: shadows,
                    border: _focused
                        ? Border.all(
                            color: primary ? WebInk.text : WebInk.accent,
                            width: 2,
                          )
                        : null,
                  ),
                  child: label,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An inline text action: "Forgot password?", "Create an account", "Back".
class AuthTextLink extends StatefulWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color = WebInk.accent,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color color;

  @override
  State<AuthTextLink> createState() => _AuthTextLinkState();
}

class _AuthTextLinkState extends State<AuthTextLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? WebInk.text : widget.color;
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
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Padding(
            // A 44pt-tall target around a 15pt line of text.
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 17, color: color),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: WebMotion.hover,
                    style: WebType.action(
                      color: color,
                      weight: FontWeight.w600,
                    ),
                    child: Text(widget.label),
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

/// "Already have an account? Sign in" — one sentence, the link at the end.
class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(question, style: WebType.body().copyWith(fontSize: 14.5)),
        AuthTextLink(label: action, onTap: onTap),
      ],
    );
  }
}

// ─── Segmented ───────────────────────────────────────────────────────────────

/// Two or more choices with a thumb that slides to the selection — the same
/// control as the landing page's platform switch, so the two read as one
/// system.
class AuthSegmented extends StatelessWidget {
  const AuthSegmented({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.icons,
  });

  final List<String> options;
  final List<IconData>? icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        // A track pressed into the canvas, with the selected segment
        // standing up out of it. 5px of track around the thumb on each side.
        final segment = (constraints.maxWidth - 10) / options.length;
        return NeuSurface(
          style: NeuStyle.inset,
          palette: AuthInk.neu,
          color: AuthInk.field,
          height: context.authShort ? 48 : 52,
          padding: const EdgeInsets.all(5),
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                curve: WebMotion.enter,
                left: segment * selectedIndex,
                top: 0,
                bottom: 0,
                width: segment,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: WebInk.canvas,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AuthInk.neu.shadows(NeuDepth.flat),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < options.length; i++)
                    SizedBox(
                      width: segment,
                      child: _Segment(
                        label: options[i],
                        icon: icons?[i],
                        selected: i == selectedIndex,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSelected(i);
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Segment extends StatefulWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ink = widget.selected ? WebInk.accent : WebInk.textSoft;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.label,
        onTap: widget.onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: _focused
                  ? Border.all(color: WebInk.accent, width: 2)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 17, color: ink),
                    const SizedBox(width: 8),
                  ],
                  AnimatedDefaultTextStyle(
                    duration: WebMotion.hover,
                    curve: WebMotion.enter,
                    style: WebType.action(color: ink, weight: FontWeight.w700),
                    child: Text(widget.label, maxLines: 1),
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

// ─── Check ───────────────────────────────────────────────────────────────────

/// A checkbox and its sentence as one target. Empty, the box is a small
/// well; ticked, it stands up out of the canvas in the accent, and the tick
/// scales in from 0.25 with a 4px blur (`better-ui`, contextual
/// icon) — the state also reads from the fill, without the motion.
class AuthCheck extends StatelessWidget {
  const AuthCheck({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: label,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!value);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: WebMotion.hover,
                  curve: WebMotion.enter,
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: ShapeDecoration(
                    color: value ? WebInk.accent : AuthInk.field,
                    shape: value
                        ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          )
                        : NeuInsetInputBorder(
                            palette: AuthInk.neu,
                            distance: 1.5,
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: AuthInk.fieldEdge,
                            ),
                          ),
                    shadows: value
                        ? AuthInk.neu.shadows(NeuDepth.flat)
                        : const [],
                  ),
                  child: AnimatedSwitcher(
                    duration: WebMotion.hover,
                    transitionBuilder: (child, a) => ScaleTransition(
                      scale: Tween(begin: 0.25, end: 1.0).animate(a),
                      child: FadeTransition(opacity: a, child: child),
                    ),
                    child: value
                        ? const Icon(
                            Icons.check_rounded,
                            key: ValueKey(true),
                            size: 15,
                            color: WebInk.canvas,
                          )
                        : const SizedBox.shrink(key: ValueKey(false)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: WebType.body(
                      color: WebInk.textSoft,
                    ).copyWith(fontSize: 14, height: 1.5),
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

// ─── Divider ─────────────────────────────────────────────────────────────────

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    const rule = Expanded(child: WebRule());
    return Row(
      children: [
        rule,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('or', style: WebType.meta()),
        ),
        rule,
      ],
    );
  }
}

// ─── Steps ───────────────────────────────────────────────────────────────────

/// The vendor application's progress: one labelled segment per step. Done
/// and current segments fill; the current label is full-strength text. The
/// fill slides along as you advance, which shows the direction of travel.
class AuthSteps extends StatelessWidget {
  const AuthSteps({super.key, required this.labels, required this.current});

  final List<String> labels;

  /// One-based.
  final int current;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      label: 'Step $current of ${labels.length}: ${labels[current - 1]}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A groove in the canvas that fills with the accent.
                  NeuSurface(
                    style: NeuStyle.inset,
                    palette: AuthInk.neu,
                    depth: NeuDepth.flat,
                    color: AuthInk.field,
                    height: 6,
                    borderRadius: BorderRadius.circular(3),
                    child: AnimatedFractionallySizedBox(
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 360),
                      curve: WebMotion.enter,
                      alignment: Alignment.centerLeft,
                      widthFactor: i < current ? 1 : 0,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: WebInk.accent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      style: WebType.meta(
                        color: i == current - 1
                            ? WebInk.text
                            : (i < current
                                  ? WebInk.textSoft
                                  : WebInk.textFaint),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Password meter ──────────────────────────────────────────────────────────

/// How strong a new password is, in one line of fixed height.
///
/// It replaces a checklist that grew by five rows as soon as typing began,
/// shoving the rest of the form down mid-keystroke. Here the space is
/// reserved from the start and only its contents change: five segments for
/// the five rules, a word for the grade, and the next rule still unmet, so
/// the advice is one specific thing rather than a list to scan.
class AuthPasswordMeter extends StatelessWidget {
  const AuthPasswordMeter({super.key, required this.password});

  final String password;

  static final _rules = <(String, bool Function(String))>[
    ('Use at least 8 characters', (p) => p.length >= 8),
    ('Add an uppercase letter', (p) => p.contains(RegExp(r'[A-Z]'))),
    ('Add a lowercase letter', (p) => p.contains(RegExp(r'[a-z]'))),
    ('Add a number', (p) => p.contains(RegExp(r'[0-9]'))),
    (
      'Add a symbol such as ! or #',
      (p) => p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final met = _rules.where((r) => r.$2(password)).length;
    final next = _rules.where((r) => !r.$2(password)).firstOrNull?.$1;
    final empty = password.isEmpty;

    final (grade, tone) = switch (met) {
      <= 2 => ('Weak', AppColors.danger),
      <= 4 => ('Medium', AppColors.warning),
      _ => ('Strong', AppColors.success),
    };

    return Semantics(
      liveRegion: true,
      label: empty
          ? 'Password strength'
          : 'Password strength: $grade.${next == null ? '' : ' $next.'}',
      excludeSemantics: true,
      child: SizedBox(
        height: 36,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              children: [
                for (var i = 0; i < _rules.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: AnimatedContainer(
                      duration: WebMotion.hover,
                      curve: WebMotion.enter,
                      height: 5,
                      decoration: ShapeDecoration(
                        color: !empty && i < met ? tone : AuthInk.field,
                        shape: NeuInsetInputBorder(
                          palette: AuthInk.neu,
                          distance: 1.2,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    empty
                        ? 'At least 8 characters, mixed case, a number.'
                        : (next ?? 'Good to go.'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WebType.meta().copyWith(fontSize: 12),
                  ),
                ),
                if (!empty) ...[
                  const SizedBox(width: 8),
                  Text(
                    grade,
                    style: WebType.meta(color: tone).copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Centred shell ───────────────────────────────────────────────────────────

/// The page for a short, single task — entering a code. The campus photo
/// fills the window behind one card in the middle; the top bar is the same
/// as the sign-in page's, so the two read as one flow.
///
/// The photograph sits far back, graded almost to the canvas, so the card
/// in the middle — cut from the canvas and raised out of it — reads as the
/// one thing on the page to act on.
class AuthCenterShell extends StatelessWidget {
  const AuthCenterShell({super.key, required this.child, this.onBack});

  final Widget child;
  final VoidCallback? onBack;

  void _back(BuildContext context) {
    if (onBack != null) return onBack!();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= AuthShell.wideBreak;
    final gutter = size.width < 380 ? 16.0 : (wide ? 40.0 : 22.0);

    return Scaffold(
      backgroundColor: WebInk.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _CampusPhoto(vendor: false, wide: wide, backdrop: true),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
                  child: _TopBar(onBack: () => _back(context), overPhoto: true),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: AuthCard(child: child),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The card: the canvas raised to its highest depth. It materialises once —
/// blur, scale and opacity settle together (`apple-design`: materialise,
/// don't just fade) — and its height glides when its content changes rather
/// than jumping.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final compact = MediaQuery.sizeOf(context).width < 520;

    Widget card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: WebInk.canvas,
          borderRadius: BorderRadius.circular(30),
          boxShadow: AuthInk.neu.shadows(NeuDepth.high),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Builder(
            builder: (context) => Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 22 : 40,
                compact ? 28 : 40,
                compact ? 22 : 40,
                compact ? 24 : 32,
              ),
              child: AnimatedSize(
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: WebMotion.enter,
                alignment: Alignment.topCenter,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    if (reduced) return card;
    return card
        .animate()
        .fadeIn(duration: 420.ms, curve: WebMotion.enter)
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          duration: 560.ms,
          curve: WebMotion.enter,
        )
        .blur(
          begin: const Offset(6, 6),
          end: Offset.zero,
          duration: 520.ms,
          curve: WebMotion.enter,
        );
  }
}

// ─── Code input ──────────────────────────────────────────────────────────────

/// A one-time code, drawn as one cell per digit but typed into a single
/// field underneath. One field rather than six means a pasted code lands
/// whole, the browser's and the phone's one-time-code autofill work, and
/// backspace simply deletes — none of which survive six separate fields.
///
/// Motion: a digit settles into its cell (scale 0.8 → 1 with a fade, 160ms);
/// the cell the next digit goes into carries the accent outline; a rejected
/// code shakes the row once (state feedback) and outlines it in the danger
/// tone, which also tells the story without the motion.
class AuthCodeInput extends StatefulWidget {
  const AuthCodeInput({
    super.key,
    required this.controller,
    required this.length,
    this.onCompleted,
    this.onChanged,
    this.errorTick = 0,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;

  /// Increment to shake the row — once per rejected code.
  final int errorTick;
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  @override
  State<AuthCodeInput> createState() => _AuthCodeInputState();
}

class _AuthCodeInputState extends State<AuthCodeInput>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    widget.controller.addListener(_onText);
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant AuthCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.errorTick != oldWidget.errorTick && !reduced) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final active = _focus.hasFocus
        ? text.length.clamp(0, widget.length - 1)
        : -1;

    final cells = Row(
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          if (i > 0) SizedBox(width: i == widget.length ~/ 2 ? 16 : 8),
          Expanded(
            child: _CodeCell(
              digit: i < text.length ? text[i] : null,
              active: i == active && text.length < widget.length,
              error: widget.hasError,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      textField: true,
      label: 'Verification code, ${widget.length} digits',
      value: text,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          // Three decaying swings, 8px at the start.
          final dx = math.sin(t * math.pi * 6) * 8 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Stack(
          children: [
            cells,
            // The real field: invisible, covering the cells, so a tap on any
            // cell focuses it and the platform sees one text input.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  onChanged: (value) {
                    widget.onChanged?.call(value);
                    if (value.length == widget.length) {
                      widget.onCompleted?.call(value);
                    }
                  },
                  onSubmitted: (value) {
                    if (value.length == widget.length) {
                      widget.onCompleted?.call(value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeCell extends StatelessWidget {
  const _CodeCell({
    required this.digit,
    required this.active,
    required this.error,
  });

  final String? digit;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final edge = error ? AuthInk.danger : WebInk.accent;

    // A well per digit. Only the cell the next digit goes into, or every
    // cell of a rejected code, is ringed.
    return AnimatedContainer(
      duration: WebMotion.hover,
      curve: WebMotion.enter,
      height: 60,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: active ? AuthInk.fieldFocused : AuthInk.field,
        shape: AuthInk.well(active || error ? edge : null),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: WebMotion.enter),
            ),
            child: child,
          ),
        ),
        child: digit == null
            ? const SizedBox.shrink(key: ValueKey('empty'))
            : Text(
                digit!,
                key: ValueKey(digit),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: WebInk.text,
                ),
              ),
      ),
    );
  }
}

// ─── Resend ──────────────────────────────────────────────────────────────────

/// "Didn't get it? Resend in 0:42", then a Resend link once the wait is over.
/// Tabular figures keep the line still as the countdown's digits change.
class AuthResendLine extends StatelessWidget {
  const AuthResendLine({
    super.key,
    required this.secondsLeft,
    required this.sending,
    required this.onResend,
  });

  final int secondsLeft;
  final bool sending;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final m = secondsLeft ~/ 60;
    final s = (secondsLeft % 60).toString().padLeft(2, '0');
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text("Didn't get it?", style: WebType.body().copyWith(fontSize: 14.5)),
        if (secondsLeft > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Resend in $m:$s',
              style: WebType.action(
                color: WebInk.textSoft,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          )
        else
          AuthTextLink(
            label: sending ? 'Sending…' : 'Resend code',
            onTap: sending ? () {} : onResend,
          ),
      ],
    );
  }
}
