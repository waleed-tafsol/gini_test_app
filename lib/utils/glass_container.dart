import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Gradient? gradient;
  final Gradient? borderGradient;
  final double blur;
  final double borderWidth;
  final bool isFrostedGlass;
  final double frostedOpacity;
  final Color? shadowColor;
  final double? elevation;
  final Alignment? alignment;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius,
    this.gradient,
    this.borderGradient,
    this.blur = 15.0,
    this.borderWidth = 1.0,
    this.isFrostedGlass = true,
    this.frostedOpacity = 0.12,
    this.shadowColor,
    this.elevation,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      borderRadius: borderRadius ?? BorderRadius.zero,
      gradient: gradient ??
          LinearGradient(
            colors: [
              Colors.white.withOpacity(0.40),
              Colors.white.withOpacity(0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
      border: borderGradient != null
          ? Border.all(
              width: borderWidth,
              color: Colors.transparent,
            )
          : Border.all(
              width: borderWidth,
              color: Colors.white.withOpacity(0.3),
            ),
      boxShadow: elevation != null && elevation! > 0
          ? [
              BoxShadow(
                color: (shadowColor ?? Colors.black).withOpacity(0.2),
                blurRadius: elevation! * 2,
                spreadRadius: 0,
              ),
            ]
          : null,
    );

    Widget container = Container(
      width: width,
      height: height,
      decoration: borderGradient != null
          ? BoxDecoration(
              borderRadius: borderRadius ?? BorderRadius.zero,
              gradient: borderGradient,
            )
          : null,
      padding: borderGradient != null ? EdgeInsets.all(borderWidth) : null,
      child: Container(
        decoration: decoration,
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              decoration: isFrostedGlass
                  ? BoxDecoration(
                      color: Colors.white.withOpacity(frostedOpacity),
                      borderRadius: borderRadius ?? BorderRadius.zero,
                    )
                  : null,
              child: alignment != null
                  ? Align(
                      alignment: alignment!,
                      child: child,
                    )
                  : child,
            ),
          ),
        ),
      ),
    );

    return container;
  }
}

