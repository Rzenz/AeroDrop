import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'neu_surface.dart';

/// A search field.
///
/// Pill-shaped and debossed so it reads as a slot to type into rather than a
/// button to press — the distinction matters on a canvas where everything else
/// is a soft rounded rectangle.
class NeuSearchField extends StatefulWidget {
  const NeuSearchField({
    super.key,
    this.controller,
    this.hintText = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.trailing,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  /// An extra action inside the field — a filter button, a scanner.
  final Widget? trailing;

  @override
  State<NeuSearchField> createState() => _NeuSearchFieldState();
}

class _NeuSearchFieldState extends State<NeuSearchField> {
  TextEditingController? _owned;
  final FocusNode _node = FocusNode();
  bool _hasText = false;

  TextEditingController get _controller =>
      widget.controller ?? (_owned ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onText);
    _node.addListener(_onFocus);
  }

  void _onText() {
    final has = _controller.text.isNotEmpty;
    if (has != _hasText && mounted) setState(() => _hasText = has);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _owned?.dispose();
    _node.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _node.hasFocus;

    return NeuSurface(
      style: NeuStyle.inset,
      depth: NeuDepth.low,
      height: 48,
      borderRadius: AppRadii.brPill,
      color: AppColors.surfaceSunken,
      border: Border.all(
        color: focused ? AppColors.primary : Colors.transparent,
        width: focused ? 2 : 0,
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          Icon(
            Icons.search_rounded,
            size: 19,
            color: focused ? AppColors.primaryText : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _node,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.primaryText,
              style: AppTextStyles.body(
                fontSize: 14.5,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: widget.hintText,
                hintStyle: AppTextStyles.body(
                  fontSize: 14.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          if (_hasText)
            IconButton(
              onPressed: _clear,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.textTertiary,
              tooltip: 'Clear search',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: EdgeInsets.zero,
            ),
          if (widget.trailing != null) widget.trailing!,
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}

/// A horizontal filter strip.
///
/// The selected option is debossed with an accent label, matching how the nav
/// dock marks its current destination — one idea for "this is the active one"
/// across the whole app.
class NeuFilterBar extends StatelessWidget {
  const NeuFilterBar({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.padding,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding ?? EdgeInsets.zero,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) => NeuFilterChip(
          label: options[i],
          selected: i == selectedIndex,
          onTap: () => onSelected(i),
        ),
      ),
    );
  }
}

/// A single filter pill.
class NeuFilterChip extends StatelessWidget {
  const NeuFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional result count shown after the label.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accentText : AppColors.textSecondary;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.label(
            fontSize: 13,
            color: color,
            letterSpacing: 0,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 5),
          Text(
            '$count',
            style: AppTextStyles.label(
              fontSize: 11.5,
              color: selected ? AppColors.accentText : AppColors.textTertiary,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );

    const pad = EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs + 1,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedSwitcher(
          duration: AppMotion.fast,
          child: selected
              ? NeuSurface(
                  key: const ValueKey(true),
                  style: NeuStyle.inset,
                  depth: NeuDepth.flat,
                  borderRadius: AppRadii.brPill,
                  color: AppColors.surfaceSunken,
                  padding: pad,
                  alignment: Alignment.center,
                  child: content,
                )
              // Unselected chips are flat. A row of raised pills stacks four
              // shadows side by side and reads as clutter, which defeats the
              // point of marking one of them.
              : Container(
                  key: const ValueKey(false),
                  padding: pad,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.brPill,
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: content,
                ),
        ),
      ),
    );
  }
}

/// A two-to-four option segmented control, for switching a view rather than
/// filtering a list.
class NeuSegmented extends StatelessWidget {
  const NeuSegmented({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.icons,
  }) : assert(
         icons == null || icons.length == options.length,
         'Give an icon for every option or none at all.',
       );

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// One per option, or null for a text-only control. Use them when the
  /// labels are similar enough that the icon is what tells them apart.
  final List<IconData>? icons;

  /// Height of the visible segment. The tap target is taller — see below.
  static const double _segment = 36;

  /// Padding between the track edge and a segment. Doubles as the extra hit
  /// area that brings the target to the 44pt minimum.
  static const double _inset = 4;

  @override
  Widget build(BuildContext context) {
    return NeuSurface(
      style: NeuStyle.inset,
      depth: NeuDepth.flat,
      borderRadius: AppRadii.brPill,
      color: AppColors.surfaceSunken,
      // Horizontal only. The vertical inset moved inside each segment so the
      // gesture area covers it: the segment reads as 36pt but answers to a
      // 44pt touch, which is the accessibility floor.
      padding: const EdgeInsets.symmetric(horizontal: _inset),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                label: options[i],
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(i);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: _inset),
                    child: _Segment(
                      label: options[i],
                      icon: icons?[i],
                      selected: i == selectedIndex,
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

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, this.icon});

  final String label;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.textPrimary : AppColors.textTertiary;

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      height: NeuSegmented._segment,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        // The selected segment lifts *out* of the sunken track, which is the
        // inverse of the filter chip because here the track is the container,
        // not the canvas.
        color: selected ? AppColors.base : Colors.transparent,
        borderRadius: AppRadii.brPill,
        boxShadow: selected ? AppShadows.raised(NeuDepth.flat) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label(
                fontSize: 13,
                letterSpacing: 0,
                color: fg,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A debossed progress rail. Used for delivery progress, battery, upload.
class NeuProgressBar extends StatelessWidget {
  const NeuProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.semanticLabel,
  });

  /// 0..1. Values outside the range are clamped rather than overflowing.
  final double value;

  final double height;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    final radius = BorderRadius.circular(height / 2);

    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()}%',
      child: NeuSurface(
        style: NeuStyle.inset,
        depth: NeuDepth.flat,
        height: height,
        borderRadius: radius,
        color: AppColors.surfaceSunken,
        child: FractionallySizedBox(
          widthFactor: v,
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            decoration: BoxDecoration(
              color: color ?? AppColors.accentFill,
              borderRadius: radius,
            ),
          ),
        ),
      ),
    );
  }
}
