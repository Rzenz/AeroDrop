import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// A user or vendor avatar.
///
/// Falls back to an initial on the accent fill when there is no image, so a
/// missing photo still produces a deliberate-looking mark rather than a grey
/// placeholder box.
class NeuAvatar extends StatelessWidget {
  const NeuAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 44,
    this.color,
    this.onTap,
    this.badge,
  });

  final String? imageUrl;
  final String name;
  final double size;

  /// Fill for the initial fallback. Defaults to the brand accent.
  final Color? color;

  final VoidCallback? onTap;

  /// A small status dot or count rendered bottom-right.
  final Widget? badge;

  String get _initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fill = color ?? AppColors.accentFill;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    Widget avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        boxShadow: AppShadows.raised(NeuDepth.flat),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Decode near display size — avatars in a list are the classic
              // place full-resolution decodes pile up.
              cacheWidth: (size * 3).round(),
              errorBuilder: (_, _, _) => _initialText(fill),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _initialText(fill),
            )
          : _initialText(fill),
    );

    if (badge != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(right: -1, bottom: -1, child: badge!),
        ],
      );
    }

    if (onTap == null) {
      return Semantics(label: name, image: true, child: avatar);
    }

    return Semantics(
      button: true,
      label: name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: avatar,
      ),
    );
  }

  Widget _initialText(Color fill) => Center(
    child: Text(
      _initial,
      style: AppTextStyles.title(
        fontSize: size * 0.38,
        fontWeight: FontWeight.w800,
        color: AppColors.onAccentFill,
      ),
    ),
  );
}

/// A small round status dot, for presence or availability on an avatar.
class NeuStatusDot extends StatelessWidget {
  const NeuStatusDot({super.key, required this.color, this.size = 13});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      // The ring is the canvas colour, which punches the dot out of whatever
      // it sits on instead of blending into it.
      border: Border.all(color: AppColors.base, width: 2),
    ),
  );
}
