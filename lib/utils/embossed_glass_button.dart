import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

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
    return GestureDetector(
      onTap: () {
        widget.onPressed();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        width: widget.width.w,
        height: widget.height.h,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
        child: LiquidGlassLayer(
          settings: LiquidGlassSettings(
            thickness: 50.w,
            glassColor: Color(0x1AFFFFFF),
            lightIntensity: 1,
          ),
          child: LiquidGlass(
            shape: LiquidRoundedSuperellipse(borderRadius: 50.r),
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
          ),
        ),
      ),
    );
  }
}
