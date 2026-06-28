import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StaggeredList extends StatelessWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final int delayMs;

  const StaggeredList({
    super.key,
    required this.children,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.delayMs = 60,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: children.length,
      itemBuilder: (context, index) {
        return children[index]
            .animate()
            .fadeIn(
              delay: (index * delayMs).ms,
              duration: 400.ms,
              curve: Curves.easeOut,
            )
            .slideY(
              begin: 0.15,
              end: 0,
              delay: (index * delayMs).ms,
              duration: 400.ms,
              curve: Curves.easeOut,
            );
      },
    );
  }
}

class StaggeredColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final int delayMs;

  const StaggeredColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.mainAxisSize = MainAxisSize.max,
    this.delayMs = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: List.generate(children.length, (index) {
        return children[index]
            .animate()
            .fadeIn(
              delay: (index * delayMs).ms,
              duration: 400.ms,
              curve: Curves.easeOut,
            )
            .slideY(
              begin: 0.12,
              end: 0,
              delay: (index * delayMs).ms,
              duration: 400.ms,
              curve: Curves.easeOut,
            );
      }),
    );
  }
}
