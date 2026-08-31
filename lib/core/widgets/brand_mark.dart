import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';

/// The AeroDrop app mark.
///
/// Renders the real icon artwork — the same file the launcher icons are cut
/// from — so the mark inside the app and the one on the home screen are the
/// same object rather than two drawings that merely resemble each other.
///
/// The corner radius matches the icon's own proportion, which is what makes
/// them read as identical at a glance.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56, this.elevated = true});

  final double size;

  /// Lifts the mark off the canvas. Turn off when it sits inside another
  /// raised surface, where a second shadow only muddies the edge.
  final bool elevated;

  static const String asset = 'assets/images/brand_mark.png';

  /// The app icon's corner radius as a fraction of its side.
  static const double _radiusRatio = 0.24;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * _radiusRatio);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Semantics(
      label: 'AeroDrop',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          // Sits behind the artwork so the corners are the brand blue rather
          // than a transparent notch while the image decodes.
          gradient: AppColors.brandGradient,
          borderRadius: radius,
          boxShadow: elevated
              ? [
                  ...AppShadows.raised(NeuDepth.medium),
                  ...AppShadows.glow(AppColors.primary, alpha: 0.22),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Decode at display size. The source is 256px and the mark renders
          // between 34 and 92pt, so a full decode would be pure waste.
          cacheWidth: (size * dpr).round(),
          filterQuality: FilterQuality.medium,
          // If the asset is ever missing, the gradient behind still reads as
          // the brand rather than showing a broken-image glyph.
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The mark beside the wordmark, for headers and app bars.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    required this.title,
    required this.titleStyle,
    this.markSize = 34,
    this.tagline,
    this.taglineStyle,
  });

  final String title;
  final TextStyle titleStyle;
  final double markSize;
  final String? tagline;
  final TextStyle? taglineStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BrandMark(size: markSize, elevated: false),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: titleStyle, maxLines: 1),
              if (tagline != null)
                Text(
                  tagline!,
                  style: taglineStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
