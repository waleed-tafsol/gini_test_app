import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../utils/glass_container.dart';

import '../../utils/enums.dart';
import '../../view_model/notifiers/audio_notifier.dart';
import '../widgets/animated_wrapper.dart';
import 'audio_page.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<AnimatedWrapperState> _animationKey =
      GlobalKey<AnimatedWrapperState>();

  @override
  void initState() {
    super.initState();
    // Initialize the audio provider connection when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(audioProvider.notifier).initializeApp();
    });
  }

  @override
  Widget build(BuildContext context) {
    final audioNotifier = ref.read(audioProvider.notifier);
    return Scaffold(
      //appBar: AppBar(title: const Text('Home')),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background4.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(audioProvider);
              return Padding(
                padding: EdgeInsets.all(20.0.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 40.h),
                    // Huge circular connect button
                    Center(
                      child: AnimatedWrapper(
                        key: _animationKey,
                        animationType: AnimationType.rotate,
                        child: _CircularConnectButton(
                          isConnected: state.isConnected,
                          onPressed: () {
                            // Trigger animation on press
                            _animationKey.currentState?.play();
                            if (state.isConnected) {
                              audioNotifier.disconnectWebSocket();
                            } else {
                              audioNotifier.reconnect();
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 40.h),
                    if (state.isConnected)
                      AnimatedWrapper(
                        animationType: AnimationType.slideRight,
                        duration: const Duration(seconds: 1),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth.isFinite
                                ? constraints.maxWidth
                                : MediaQuery.of(context).size.width;
                            return GestureDetector(
                              onTap: () {
                                audioNotifier.callSessionId();
                              },
                              child: GlassContainer(
                                width: width,
                                height: 60.h,
                                borderRadius: BorderRadius.circular(12.0.r),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.60),
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.arrow_right_arrow_left_square_fill,
                                        color: Colors.white,
                                        size: 22.sp,
                                      ),
                                      SizedBox(width: 10.w),
                                      Text(
                                        'Get Session ID',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5.w,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    SizedBox(height: 20.h),
                    // Message button
                    if (state.isConnected && state.sessionId.isNotEmpty)
                      AnimatedWrapper(
                        animationType: AnimationType.slideRight,
                        duration: const Duration(seconds: 2),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth.isFinite
                                ? constraints.maxWidth
                                : MediaQuery.of(context).size.width;
                            return GestureDetector(
                              onTap: () {
                                audioNotifier.setScreenType(ScreenType.message);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AudioPage(),
                                  ),
                                );
                              },
                              child: GlassContainer(
                                width: width,
                                height: 60.h,
                                borderRadius: BorderRadius.circular(12.0.r),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.60),
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.chat_bubble_2_fill,
                                        color: Colors.white,
                                        size: 22.sp,
                                      ),
                                      SizedBox(width: 10.w),
                                      Text(
                                        'Message',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5.w,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    SizedBox(height: 20.h),

                    // Human button
                    if (state.isConnected && state.sessionId.isNotEmpty)
                      AnimatedWrapper(
                        animationType: AnimationType.slideRight,
                        duration: const Duration(seconds: 3),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth.isFinite
                                ? constraints.maxWidth
                                : MediaQuery.of(context).size.width;
                            return GestureDetector(
                              onTap: () {
                                // audioNotifier.setScreenType(
                                //   ScreenType.humanModel,
                                // );
                                // Navigator.push(
                                //   context,
                                //   MaterialPageRoute(
                                //     builder: (context) =>
                                //         const HumanModelView(),
                                //   ),
                                // );
                              },
                              child: GlassContainer(
                                width: width,
                                height: 60.h,
                                borderRadius: BorderRadius.circular(12.0.r),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.60),
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 22.sp,
                                      ),
                                      SizedBox(width: 10.w),
                                      Text(
                                        'Human',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5.w,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _CircularConnectButton extends StatefulWidget {
  final bool isConnected;
  final VoidCallback onPressed;

  const _CircularConnectButton({
    required this.isConnected,
    required this.onPressed,
  });

  @override
  State<_CircularConnectButton> createState() => _CircularConnectButtonState();
}

class _CircularConnectButtonState extends State<_CircularConnectButton> {
  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: () {
        widget.onPressed();
      },
      child: SizedBox(
        width: 180.w,
        height: 180.w,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Ensure constraints are valid before building GlassContainer
            if (!constraints.maxWidth.isFinite || 
                !constraints.maxHeight.isFinite ||
                constraints.maxWidth <= 0 ||
                constraints.maxHeight <= 0) {
              return Container(
                width: 180.w,
                height: 180.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Center(
                  child: Icon(
                    widget.isConnected
                        ? CupertinoIcons.bolt_fill
                        : CupertinoIcons.bolt_slash_fill,
                    color: Colors.white,
                    size: 80.0,
                  ),
                ),
              );
            }
            
            return GlassContainer(
              width: 180.w,
              height: 180.w,
              borderRadius: BorderRadius.circular(90.w),
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
              elevation: 3.0,
              isFrostedGlass: true,
              shadowColor: Colors.black.withOpacity(0.20),
              alignment: Alignment.center,
              frostedOpacity: 0.12,
              child: Center(
                child: Icon(
                  widget.isConnected
                      ? CupertinoIcons.bolt_fill
                      : CupertinoIcons.bolt_slash_fill,
                  color: Colors.white,
                  size: 80.sp,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
