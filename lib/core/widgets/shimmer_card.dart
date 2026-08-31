import 'package:flutter/material.dart';

import 'loading_skeleton.dart';

/// Row-shaped loading placeholder. Kept as a distinct name because screens
/// refer to it by this one; the implementation lives in [SkeletonCard].
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key, this.height = 84, this.borderRadius});

  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) => SkeletonCard(height: height);
}

/// A stack of [ShimmerCard]s for list-level loading states.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 4, this.cardHeight = 84});

  final int count;
  final double cardHeight;

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(count, (_) => ShimmerCard(height: cardHeight)),
  );
}
