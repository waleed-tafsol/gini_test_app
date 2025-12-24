import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tafsol_genie_app/view/screens/home_screen.dart';

void main() => runApp(ProviderScope(child: const MyApp()));

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Size getDesignSize({required BuildContext context}) {
    // Get the actual screen size
    final window = View.of(context);
    final size = window.physicalSize / window.devicePixelRatio;
    // Return appropriate design size based on screen width
    if (size.width >= 1200) {
      log('LARGE: ${size.width}');
      return Size(1200, 1600);
      // Large tablets/Desktop
    } else if (size.width >= 800) {
      log('MEDIUM: ${size.width}');
      return Size(768, 1024); // Tablets
    } else if (size.width >= 600) {
      log('SMALL: ${size.width}');
      return Size(600, 900); // Small tablets
    } else {
      log('DEFAULT: ${size.width} ${size.height}');
      return const Size(390, 844);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: getDesignSize(context: context),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) {
        return MaterialApp(title: 'Genie', home: const HomeScreen());
      },
    );
  }
}
