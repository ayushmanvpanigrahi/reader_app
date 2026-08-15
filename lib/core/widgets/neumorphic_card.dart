import 'package:flutter/material.dart';
import '../theme/neumorphic_decorations.dart';

/// A versatile Neomorphic Card container with soft lighting effects,
/// customizable depth, curvature, and embossed/debossed states.
class NeumorphicCard extends StatelessWidget {
  final Widget? child;
  final double borderRadius;
  final double depth;
  final NeumorphicShape shape;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? color;
  final Border? border;
  final VoidCallback? onTap;
  final bool isCircle;
  final AlignmentGeometry? alignment;
  final Clip clipBehavior;

  const NeumorphicCard({
    super.key,
    this.child,
    this.borderRadius = 16.0,
    this.depth = 4.0,
    this.shape = NeumorphicShape.embossed,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.color,
    this.border,
    this.onTap,
    this.isCircle = false,
    this.alignment,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    Widget current = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      alignment: alignment,
      clipBehavior: clipBehavior,
      decoration: NeumorphicDecorations.boxDecoration(
        context: context,
        shape: shape,
        borderRadius: borderRadius,
        depth: depth,
        color: color,
        border: border,
        isCircle: isCircle,
      ),
      child: child,
    );

    if (onTap != null) {
      current = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: current,
      );
    }

    return current;
  }
}
