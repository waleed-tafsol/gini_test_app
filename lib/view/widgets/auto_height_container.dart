import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../utils/glass_container.dart';

class AutoHeightGlassContainer extends StatefulWidget {
  final Widget child;

  const AutoHeightGlassContainer({super.key, required this.child});

  @override
  State<AutoHeightGlassContainer> createState() =>
      AutoHeightGlassContainerState();
}

class AutoHeightGlassContainerState extends State<AutoHeightGlassContainer> {
  final GlobalKey _contentKey = GlobalKey();
  double? _contentHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureContent());
  }

  @override
  void didUpdateWidget(AutoHeightGlassContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-measure when content changes
    if (oldWidget.child != widget.child) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureContent());
    }
  }

  void _measureContent() {
    final RenderBox? renderBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final height = renderBox.size.height;
      if (_contentHeight == null || (_contentHeight! - height).abs() > 1.0) {
        setState(() {
          _contentHeight = height;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;

        // If we haven't measured yet, render content to measure it
        if (_contentHeight == null) {
          return SizedBox(width: width, key: _contentKey, child: widget.child);
        }

        // Once measured, render GlassContainer with measured height
        return GlassContainer(
          width: width,
          //height: _contentHeight! + 5, // Add small buffer for padding/margins
          borderRadius: BorderRadius.circular(20.r),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.40),
              Colors.white.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderGradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.60),
              Colors.white.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          blur: 15,
          borderWidth: 1.0,
          isFrostedGlass: true,
          frostedOpacity: 0.12,
          child: widget.child,
        );
      },
    );
  }
}
