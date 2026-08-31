import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'neu_surface.dart';

/// The app's text input.
///
/// Rendered as a debossed well — the one place the neumorphic language maps
/// exactly onto meaning, since "type into here" and "recessed" are the same
/// idea. Focus adds a full-contrast brand ring rather than a tint, because a
/// soft glow is not a reliable focus indicator for anyone with low vision.
class NeuTextField extends StatefulWidget {
  const NeuTextField({
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
  State<NeuTextField> createState() => _NeuTextFieldState();
}

class _NeuTextFieldState extends State<NeuTextField> {
  FocusNode? _ownedNode;
  bool _focused = false;
  String? _error;

  FocusNode get _node => widget.focusNode ?? (_ownedNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant NeuTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode?.removeListener(_onFocusChange);
      _ownedNode?.removeListener(_onFocusChange);
      _node.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() => _focused = _node.hasFocus);
  }

  @override
  void dispose() {
    // Only the externally supplied node is left alone; the owned one is ours
    // to tear down.
    widget.focusNode?.removeListener(_onFocusChange);
    _ownedNode?.removeListener(_onFocusChange);
    _ownedNode?.dispose();
    super.dispose();
  }

  Color get _ringColor {
    if (_error != null) return AppColors.danger;
    if (_focused) return AppColors.primary;
    return Colors.transparent;
  }

  Color get _iconColor {
    if (_error != null) return AppColors.danger;
    if (_focused) return AppColors.primaryText;
    return AppColors.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled;
    final labelColor = _error != null
        ? AppColors.danger
        : (_focused ? AppColors.primaryText : AppColors.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.labelText.isNotEmpty) ...[
          AnimatedDefaultTextStyle(
            duration: AppMotion.fast,
            style: AppTextStyles.label(fontSize: 12.5, color: labelColor),
            child: Text(widget.labelText),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Opacity(
          opacity: disabled ? 0.55 : 1,
          // A 2pt lift on focus. Transform, so nothing below it reflows and
          // the row keeps its height — the field just comes forward slightly
          // as you tap into it, which is the whole feedback.
          child: AnimatedSlide(
            offset: _focused ? const Offset(0, -0.022) : Offset.zero,
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              decoration: BoxDecoration(
                borderRadius: AppRadii.brMd,
                // A soft brand halo *in addition to* the ring — the ring does the
                // accessible work, the halo does the polish.
                boxShadow: _focused && _error == null
                    ? AppShadows.glow(AppColors.primary, alpha: 0.18)
                    : null,
              ),
              child: NeuSurface(
                style: NeuStyle.inset,
                depth: NeuDepth.low,
                borderRadius: AppRadii.brMd,
                color: AppColors.surfaceSunken,
                border: Border.all(
                  color: _ringColor,
                  width: _ringColor == Colors.transparent ? 0 : 2,
                ),
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _node,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  maxLines: widget.obscureText ? 1 : widget.maxLines,
                  maxLength: widget.maxLength,
                  onChanged: widget.onChanged,
                  textInputAction: widget.textInputAction,
                  readOnly: widget.readOnly,
                  enabled: widget.enabled,
                  onTap: widget.onTap,
                  autofillHints: widget.autofillHints,
                  inputFormatters: widget.inputFormatters,
                  cursorColor: AppColors.primaryText,
                  style: AppTextStyles.body(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  // The validator result is mirrored into local state so the
                  // well's ring and icon can turn red too, not just the message.
                  validator: widget.validator == null
                      ? null
                      : (value) {
                          final result = widget.validator!(value);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _error != result) {
                              setState(() => _error = result);
                            }
                          });
                          return result;
                        },
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: AppTextStyles.body(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                    prefixIcon: widget.prefixIcon == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.md,
                              right: AppSpacing.sm,
                            ),
                            child: Icon(
                              widget.prefixIcon,
                              size: 20,
                              color: _iconColor,
                            ),
                          ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0),
                    suffixIcon: widget.suffixIcon,
                    filled: false,
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: widget.prefixIcon == null ? AppSpacing.md : 0,
                      vertical: AppSpacing.md,
                    ),
                    // Borders live on the NeuSurface so the inner shadow is not
                    // clipped by an outline; these are all no-ops on purpose.
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Error takes precedence over helper text; both occupy the same slot
        // so the field does not jump when validation fires.
        AnimatedSize(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          alignment: Alignment.topLeft,
          child: (_error ?? widget.helperText) == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xxs + 2,
                    left: AppSpacing.xxs,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 14,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          _error ?? widget.helperText!,
                          style: AppTextStyles.caption(
                            fontSize: 12,
                            color: _error != null
                                ? AppColors.danger
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
