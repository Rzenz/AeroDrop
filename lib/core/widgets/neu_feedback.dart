import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'neu_button.dart';
import 'neu_surface.dart';

/// Tone of a transient message.
enum NeuToneKind { success, error, info, warning }

extension _ToneStyle on NeuToneKind {
  Color get color => switch (this) {
    NeuToneKind.success => AppColors.success,
    NeuToneKind.error => AppColors.danger,
    NeuToneKind.warning => AppColors.warning,
    NeuToneKind.info => AppColors.primary,
  };

  IconData get icon => switch (this) {
    NeuToneKind.success => Icons.check_circle_rounded,
    NeuToneKind.error => Icons.error_rounded,
    NeuToneKind.warning => Icons.warning_rounded,
    NeuToneKind.info => Icons.info_rounded,
  };
}

/// Shows a floating status message.
///
/// One entry point for every transient message in the app, so tone, shape and
/// duration stop being decided per call site. The icon carries the tone as well
/// as the colour, because a red bar alone is not a message anyone can read.
void showNeuSnack(
  BuildContext context,
  String message, {
  NeuToneKind tone = NeuToneKind.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  // Replace rather than queue: a stack of stale toasts is worse than the one
  // message that actually describes the current state.
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: duration,
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.all(AppSpacing.md),
      content: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: AppRadii.brMd,
          border: Border.all(color: tone.color.withValues(alpha: 0.35)),
          boxShadow: AppShadows.floating,
        ),
        child: Row(
          children: [
            Icon(tone.icon, color: tone.color, size: 19),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.body(
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: AppSpacing.xs),
              GestureDetector(
                onTap: () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Text(
                    actionLabel,
                    style: AppTextStyles.label(
                      fontSize: 13,
                      color: AppColors.accentText,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Confirmation dialog.
///
/// Returns true when the user confirms. [destructive] gives the confirm button
/// the danger tone and is required for anything irreversible — cancelling a
/// delivery, deleting a product, signing out.
///
/// Cancel is a full button rather than a text link. The safe option in a
/// destructive dialog should be at least as easy to hit as the dangerous one,
/// and a bare word beside a filled button is neither as visible nor as large a
/// target.
///
/// Pass [onConfirm] for work that takes time. The dialog then stays open with
/// the confirm button in a loading state, and surfaces any error it returns
/// inline rather than closing and firing a snackbar at a screen the user has
/// already navigated away from.
Future<bool> showNeuConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
  Future<String?> Function()? onConfirm,
}) async {
  final tint = destructive ? AppColors.danger : AppColors.primary;

  final result = await showDialog<bool>(
    context: context,
    // While the action runs there is nothing useful a tap outside can do, so
    // the barrier is locked in the builder below rather than here.
    barrierDismissible: onConfirm == null,
    barrierColor: AppColors.bgDark.withValues(alpha: 0.62),
    builder: (ctx) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      tint: tint,
      icon:
          icon ??
          (destructive
              ? Icons.warning_amber_rounded
              : Icons.help_outline_rounded),
      onConfirm: onConfirm,
    ),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    required this.tint,
    required this.icon,
    this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final Color tint;
  final IconData icon;
  final Future<String?> Function()? onConfirm;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _busy = false;
  String? _error;

  /// Outer radius, inner radius and padding are chosen together: 32 outer minus
  /// the 16 of horizontal padding leaves exactly the 16 the buttons use, so the
  /// curves stay concentric instead of drifting apart at the corners.
  static const double _outerRadius = AppRadii.xxl;
  static const double _pad = AppSpacing.md;

  Future<void> _confirm() async {
    final action = widget.onConfirm;
    if (action == null) {
      Navigator.of(context).pop(true);
      return;
    }
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();

    final failure = await action();
    if (!mounted) return;

    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Leaving mid-action would strand the caller waiting on a dialog that no
      // longer exists.
      canPop: !_busy,
      // A plain AlertDialog would be invisible here: its surface is the same
      // colour as the canvas behind it and Material draws no shadow at
      // elevation 0, so the panel needs its own float and rim to read as a
      // separate layer.
      child: Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xl,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(_pad, AppSpacing.xl, _pad, _pad),
          decoration: BoxDecoration(
            color: AppColors.base,
            borderRadius: BorderRadius.circular(_outerRadius),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.floating,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: NeuSurface(
                  style: NeuStyle.inset,
                  depth: NeuDepth.medium,
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  borderRadius: BorderRadius.circular(32),
                  color: Color.alphaBlend(
                    widget.tint.withValues(alpha: 0.12),
                    AppColors.surfaceSunken,
                  ),
                  child: Icon(widget.icon, color: widget.tint, size: 28),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.heading(fontSize: 19),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),
              // The error sits with the action that caused it. AnimatedSize keeps
              // the dialog from jumping when it appears.
              AnimatedSize(
                duration: AppMotion.fast,
                curve: AppMotion.standard,
                alignment: Alignment.topCenter,
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 15,
                              color: AppColors.danger,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _error!,
                                style: AppTextStyles.caption(
                                  fontSize: 12.5,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              NeuButton(
                text: widget.confirmLabel,
                height: 50,
                isLoading: _busy,
                borderRadius: AppRadii.brMd,
                variant: widget.destructive
                    ? NeuButtonVariant.danger
                    : NeuButtonVariant.accent,
                onPressed: _confirm,
              ),
              const SizedBox(height: AppSpacing.xs),
              NeuButton(
                text: widget.cancelLabel,
                height: 50,
                borderRadius: AppRadii.brMd,
                variant: NeuButtonVariant.neutral,
                // Disabled rather than hidden while busy: the button keeping its
                // place stops the dialog resizing mid-action.
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bottom sheet with the app's surface, radius and drag handle.
Future<T?> showNeuSheet<T>(
  BuildContext context, {
  required Widget child,
  String? title,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: AppColors.base,
        borderRadius: AppRadii.brSheet,
        boxShadow: AppShadows.floating,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: AppRadii.brPill,
              ),
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.heading(fontSize: 18)),
          ],
          const SizedBox(height: AppSpacing.md),
          Flexible(child: child),
        ],
      ),
    ),
  );
}

/// The app's loading state.
///
/// A spinner in a raised well rather than a bare indicator floating on the
/// canvas, with optional text so the user knows what is being waited on.
class NeuLoader extends StatelessWidget {
  const NeuLoader({super.key, this.message, this.size = 30});

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NeuSurface(
            depth: NeuDepth.low,
            width: size + 26,
            height: size + 26,
            alignment: Alignment.center,
            borderRadius: BorderRadius.circular((size + 26) / 2),
            child: SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentFill),
                backgroundColor: AppColors.surfaceSunken,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Wraps a destructive tap in a confirmation, then runs it.
///
/// Saves every delete/cancel call site from re-deciding whether to confirm.
Future<void> confirmThen(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() action,
  String confirmLabel = 'Confirm',
  IconData? icon,
}) async {
  final ok = await showNeuConfirm(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    destructive: true,
    icon: icon,
  );
  if (!ok) return;
  HapticFeedback.mediumImpact();
  await action();
}
