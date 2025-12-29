import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'glass_container.dart';
import 'screen_util_helper.dart';

class EmbossedGlassButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final IconData? icon;

  const EmbossedGlassButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width = 200,
    this.height = 60,
    this.icon,
  });

  @override
  State<EmbossedGlassButton> createState() => _EmbossedGlassButtonState();
}

class _EmbossedGlassButtonState extends State<EmbossedGlassButton> {
  //bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final safeWidth = ScreenUtilHelper.safeWidth(widget.width, widget.width);
    final safeHeight = ScreenUtilHelper.safeHeight(widget.height, widget.height);
    final finalWidth = safeWidth.isFinite && safeWidth > 0 ? safeWidth : widget.width;
    final finalHeight = safeHeight.isFinite && safeHeight > 0 ? safeHeight : widget.height;
    
    return GestureDetector(
      onTap: () {
        widget.onPressed();
      },
      child: SizedBox(
        width: finalWidth,
        height: finalHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!constraints.maxWidth.isFinite || 
                !constraints.maxHeight.isFinite ||
                constraints.maxWidth <= 0 ||
                constraints.maxHeight <= 0) {
              return Container(
                width: finalWidth,
                height: finalHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50.0),
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Center(
                  child: widget.icon != null
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(widget.icon, color: Colors.white, size: 22),
                            SizedBox(width: 10),
                            Text(
                              widget.text,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          widget.text,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              );
            }
            
            return GlassContainer(
              borderRadius: BorderRadius.circular(
                ScreenUtilHelper.safeRadius(50.0, 50.0),
              ),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.40),
                  Colors.white.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderGradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.60),
                  Colors.white.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              blur: 15,
              borderWidth: 1.0,
              isFrostedGlass: true,
              frostedOpacity: 0.12,
              child: Center(
                child: widget.icon != null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(widget.icon, color: Colors.white, size: 22.sp),
                          SizedBox(width: 10.w),
                          Text(
                            widget.text,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5.w,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        widget.text,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5.w,
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
