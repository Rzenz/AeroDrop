import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'brand_mark.dart';
import 'neu_surface.dart';

/// The wide-window frame shared by the customer, vendor and admin areas.
///
/// Every screen in the app was drawn for a phone. On a laptop or desktop
/// window those layouts stretched edge to edge: rows a metre long, a bottom
/// dock floating under an empty page. From [WideLayout.breakpoint] the dock
/// becomes a left rail ([WideSidebar]) and the page sits in a centred column
/// sized for what it shows ([WideContent]) — a reading column for lists and
/// forms, the full width for maps and the dashboards that lay out their own
/// grid.
///
/// Both are cut from the app's neumorphic material: the rail shares the
/// page's canvas and separates by depth, not by a rule, and the active
/// destination is pressed into it.
class WideLayout {
  const WideLayout._();

  /// The rail replaces the dock from this width.
  static const double breakpoint = 1100;

  static const double sidebarWidth = 252;

  /// A form or a single record.
  static const double form = 760;

  /// A list of rows — orders, notifications.
  static const double list = 960;

  /// A grid of cards or a data table.
  static const double grid = 1280;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpoint;
}

/// One destination on the rail.
class WideNavEntry {
  const WideNavEntry(
    this.label,
    this.icon,
    this.route, {
    this.badge,
    this.exact = false,
    this.push = false,
  });

  final String label;
  final IconData icon;
  final String route;
  final int? badge;

  /// Active only on exactly [route] — for a role's home, whose path prefixes
  /// every other one.
  final bool exact;

  /// Opens over the current page (with a way back) instead of switching to
  /// it — for pages outside the role's main destinations.
  final bool push;

  bool isActive(String location) =>
      exact ? location == route : location.startsWith(route);
}

/// The left rail: wordmark and role, the signed-in account, destinations,
/// an optional [footer], sign out.
class WideSidebar extends StatelessWidget {
  const WideSidebar({
    super.key,
    required this.location,
    required this.entries,
    required this.onNavigate,
    required this.onSignOut,
    required this.name,
    required this.subtitle,
    this.avatarUrl,
    this.roleLabel,
    this.secondary = const [],
    this.footer,
    this.palette,
    this.homeRoute,
  });

  final String location;
  final List<WideNavEntry> entries;

  /// Below the main destinations, after a gap — settings and the like.
  final List<WideNavEntry> secondary;
  final ValueChanged<WideNavEntry> onNavigate;
  final VoidCallback onSignOut;
  final String name;
  final String subtitle;
  final String? avatarUrl;

  /// "Vendor", "Admin" — omitted for customers, who are the default.
  final String? roleLabel;
  final Widget? footer;

  /// Pins the rail to a palette; the admin console stays dark in either
  /// theme.
  final NeuPalette? palette;
  final String? homeRoute;

  @override
  Widget build(BuildContext context) {
    final p = palette ?? NeuPalette.current;
    return Container(
      width: WideLayout.sidebarWidth,
      color: p.base,
      child: SafeArea(
        right: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 40).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Wordmark(
                      palette: p,
                      roleLabel: roleLabel,
                      onTap: homeRoute == null
                          ? null
                          : () => onNavigate(
                              WideNavEntry('Home', Icons.home, homeRoute!),
                            ),
                    ),
                    const SizedBox(height: 24),
                    _Account(
                      palette: p,
                      name: name,
                      subtitle: subtitle,
                      avatarUrl: avatarUrl,
                    ),
                    const SizedBox(height: 22),
                    for (final e in entries) ...[
                      WideNavItem(
                        entry: e,
                        palette: p,
                        active: e.isActive(location),
                        onTap: () => onNavigate(e),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (secondary.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      for (final e in secondary) ...[
                        WideNavItem(
                          entry: e,
                          palette: p,
                          active: e.isActive(location),
                          onTap: () => onNavigate(e),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                    WideNavItem(
                      entry: const WideNavEntry(
                        'Sign out',
                        Icons.logout_rounded,
                        '',
                      ),
                      palette: p,
                      active: false,
                      tone: p.dark
                          ? AppColors.danger
                          : Color.lerp(AppColors.danger, Colors.black, 0.45),
                      onTap: onSignOut,
                    ),
                    const Spacer(),
                    if (footer != null) ...[
                      const SizedBox(height: 22),
                      footer!,
                    ],
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

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.palette, this.roleLabel, this.onTap});

  final NeuPalette palette;
  final String? roleLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        const BrandMark(size: 32, elevated: false),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'AeroDrop',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.title(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: palette.text,
            ),
          ),
        ),
        if (roleLabel != null) ...[
          const SizedBox(width: 8),
          NeuSurface(
            style: NeuStyle.inset,
            palette: palette,
            depth: NeuDepth.flat,
            borderRadius: BorderRadius.circular(8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              roleLabel!.toUpperCase(),
              style: AppTextStyles.label(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: palette.accentText,
              ).copyWith(letterSpacing: 0.8),
            ),
          ),
        ],
      ],
    );
    if (onTap == null) return row;
    return Semantics(
      link: true,
      label: 'AeroDrop home',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: row),
      ),
    );
  }
}

class _Account extends StatelessWidget {
  const _Account({
    required this.palette,
    required this.name,
    required this.subtitle,
    this.avatarUrl,
  });

  final NeuPalette palette;
  final String name;
  final String subtitle;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return NeuSurface(
      palette: palette,
      depth: NeuDepth.low,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          WideAvatar(name: name, url: avatarUrl, size: 42, palette: palette),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 12.5,
                    color: palette.textSoft,
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

/// A round avatar: the photo when there is one, otherwise the initial on
/// the accent fill.
class WideAvatar extends StatelessWidget {
  const WideAvatar({
    super.key,
    required this.name,
    this.url,
    this.size = 40,
    this.palette,
  });

  final String name;
  final String? url;
  final double size;
  final NeuPalette? palette;

  @override
  Widget build(BuildContext context) {
    final p = palette ?? NeuPalette.current;
    final initial = name.trim().isEmpty ? 'A' : name.trim()[0].toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: AppTextStyles.title(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: p.onAccentFill,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: p.accentFill, shape: BoxShape.circle),
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

/// A destination on the rail. Resting, it is printed on the canvas; hovered,
/// it lifts; active, it is pressed into the canvas with the accent on its
/// icon — the same raised-to-inset move as every button in the app.
class WideNavItem extends StatefulWidget {
  const WideNavItem({
    super.key,
    required this.entry,
    required this.active,
    required this.onTap,
    this.palette,
    this.tone,
  });

  final WideNavEntry entry;
  final bool active;
  final VoidCallback onTap;
  final NeuPalette? palette;
  final Color? tone;

  @override
  State<WideNavItem> createState() => _WideNavItemState();
}

class _WideNavItemState extends State<WideNavItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette ?? NeuPalette.current;
    final active = widget.active;
    final badge = widget.entry.badge ?? 0;
    final iconColor = widget.tone ?? (active ? p.accentText : p.textSoft);
    final textColor = widget.tone ?? (active ? p.text : p.textSoft);

    final content = Row(
      children: [
        Icon(widget.entry.icon, size: 20, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        if (badge > 0) WideBadge(count: badge, palette: p),
      ],
    );

    final radius = BorderRadius.circular(14);
    final Widget surface;
    if (active) {
      surface = NeuSurface(
        key: const ValueKey('active'),
        style: NeuStyle.inset,
        palette: p,
        depth: NeuDepth.low,
        color: p.sunken,
        borderRadius: radius,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: content,
      );
    } else {
      surface = AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: p.base,
          borderRadius: radius,
          boxShadow: _hovered ? p.shadows(NeuDepth.flat) : const [],
        ),
        child: content,
      );
    }

    return Semantics(
      button: true,
      selected: active,
      label: widget.entry.label,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
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
          child: DecoratedBox(
            // Keyboard focus gets a visible ring: soft shadows alone do not
            // show where focus is.
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: _focused
                  ? Border.all(color: p.accentText, width: 2)
                  : null,
            ),
            child: surface,
          ),
        ),
      ),
    );
  }
}

/// A real count on a destination — unread alerts, orders waiting. No glow.
class WideBadge extends StatelessWidget {
  const WideBadge({super.key, required this.count, this.palette});

  final int count;
  final NeuPalette? palette;

  @override
  Widget build(BuildContext context) {
    final p = palette ?? NeuPalette.current;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.accentFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTextStyles.label(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: p.onAccentFill,
        ),
      ),
    );
  }
}
