import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'custom_app_bar.dart';

/// The standard screen shell.
///
/// Gives every screen the same canvas, gutter and bottom clearance so a user
/// moving between them never sees the layout shift underneath the content.
/// Screens inside a shell with a floating nav dock pass [hasBottomDock] so
/// their last item is not hidden behind it.
class NeuScaffold extends StatelessWidget {
  const NeuScaffold({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.action,
    this.showBackButton = true,
    this.onBackPressed,
    this.appBar,
    this.floatingActionButton,
    this.bottomBar,
    this.hasBottomDock = false,
    this.padded = true,
    this.onRefresh,
  });

  final Widget body;
  final String? title;
  final String? subtitle;
  final Widget? action;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  /// Overrides the generated header entirely.
  final PreferredSizeWidget? appBar;

  final Widget? floatingActionButton;

  /// A pinned action area above the bottom edge — "Place order", "Save".
  final Widget? bottomBar;

  final bool hasBottomDock;

  /// Applies the responsive page gutter. Turn off for edge-to-edge content
  /// like full-bleed lists or maps.
  final bool padded;

  /// Wires pull-to-refresh when supplied.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpacing.pageGutter(context);

    Widget content = body;
    if (padded) {
      content = Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: content,
      );
    }

    if (onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: onRefresh!,
        color: AppColors.accentFill,
        backgroundColor: AppColors.surfaceRaised,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.base,
      extendBody: hasBottomDock,
      appBar:
          appBar ??
          (title == null
              ? null
              : CustomAppBar(
                  title: title!,
                  subtitle: subtitle,
                  action: action,
                  showBackButton: showBackButton,
                  onBackPressed: onBackPressed,
                )),
      body: SafeArea(top: false, bottom: !hasBottomDock, child: content),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  AppSpacing.xs,
                  gutter,
                  AppSpacing.sm,
                ),
                child: bottomBar,
              ),
            ),
    );
  }
}
