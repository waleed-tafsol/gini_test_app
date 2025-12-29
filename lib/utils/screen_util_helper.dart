import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Helper class to safely get ScreenUtil values and prevent Infinity/NaN errors
class ScreenUtilHelper {
  /// Safely gets width value, returns fallback if invalid
  static double safeWidth(double value, [double fallback = 0.0]) {
    try {
      final result = value.w;
      return result.isFinite && result > 0 ? result : fallback;
    } catch (e) {
      return fallback;
    }
  }

  /// Safely gets height value, returns fallback if invalid
  static double safeHeight(double value, [double fallback = 0.0]) {
    try {
      final result = value.h;
      return result.isFinite && result > 0 ? result : fallback;
    } catch (e) {
      return fallback;
    }
  }

  /// Safely gets radius value, returns fallback if invalid
  static double safeRadius(double value, [double fallback = 0.0]) {
    try {
      final result = value.r;
      return result.isFinite && result >= 0 ? result : fallback;
    } catch (e) {
      return fallback;
    }
  }

  /// Safely gets font size value, returns fallback if invalid
  static double safeFontSize(double value, [double fallback = 14.0]) {
    try {
      final result = value.sp;
      return result.isFinite && result > 0 ? result : fallback;
    } catch (e) {
      return fallback;
    }
  }

  /// Ensures a double value is finite, returns fallback if not
  static double ensureFinite(double value, double fallback) {
    return value.isFinite && !value.isNaN ? value : fallback;
  }

  /// Wraps a widget to ensure it only builds when constraints are valid
  static Widget safeGlassContainer({
    required Widget child,
    required BuildContext context,
    double? width,
    double? height,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if constraints are valid
        if (!constraints.maxWidth.isFinite || 
            !constraints.maxHeight.isFinite ||
            constraints.maxWidth.isInfinite ||
            constraints.maxHeight.isInfinite) {
          // Return a simple container if constraints are invalid
          return Container(
            width: width?.isFinite == true ? width : constraints.maxWidth.isFinite ? constraints.maxWidth : 100,
            height: height?.isFinite == true ? height : constraints.maxHeight.isFinite ? constraints.maxHeight : 100,
            child: child,
          );
        }
        return child;
      },
    );
  }
}

