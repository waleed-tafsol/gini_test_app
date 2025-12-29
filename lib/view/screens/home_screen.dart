import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../utils/glass_container.dart';

import '../../utils/embossed_glass_button.dart';
import '../../utils/enums.dart';
import '../../utils/screen_util_helper.dart';
import '../../view_model/notifiers/audio_notifier.dart';
import '../widgets/animated_wrapper.dart';
import 'audio_page.dart';
import 'human_model_view.dart';

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
              'assets/background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
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
                            child: EmbossedGlassButton(
                              text: 'Get Session ID',
                              icon: CupertinoIcons
                                  .arrow_right_arrow_left_square_fill,
                              onPressed: () {
                                audioNotifier.callSessionId();
                              },
                              width: double.infinity,
                            ),
                          ),

                        SizedBox(height: 20.h),
                        // Message button
                        if (state.isConnected && state.sessionId.isNotEmpty)
                          AnimatedWrapper(
                            animationType: AnimationType.slideRight,
                            duration: const Duration(seconds: 2),
                            child: EmbossedGlassButton(
                              text: 'Message',
                              icon: CupertinoIcons.chat_bubble_2_fill,
                              onPressed: () {
                                audioNotifier.setScreenType(ScreenType.message);

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AudioPage(),
                                  ),
                                );
                              },
                              width: double.infinity,
                            ),
                          ),

                        SizedBox(height: 20.h),

                        // Human button
                        if (state.isConnected && state.sessionId.isNotEmpty)
                          AnimatedWrapper(
                            animationType: AnimationType.slideRight,
                            duration: const Duration(seconds: 3),
                            child: EmbossedGlassButton(
                              text: 'Human',
                              icon: Icons.person,
                              onPressed: () {
                                audioNotifier.setScreenType(
                                  ScreenType.humanModel,
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const HumanModelView(),
                                  ),
                                );
                              },
                              width: double.infinity,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
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
    final size = ScreenUtilHelper.safeHeight(180.0, 180.0);
    final safeSize = size.isFinite && size > 0 ? size : 180.0;

    return GestureDetector(
      onTap: () {
        widget.onPressed();
      },
      child: SizedBox(
        width: safeSize,
        height: safeSize,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Ensure constraints are valid before building GlassContainer
            if (!constraints.maxWidth.isFinite || 
                !constraints.maxHeight.isFinite ||
                constraints.maxWidth <= 0 ||
                constraints.maxHeight <= 0) {
              return Container(
                width: safeSize,
                height: safeSize,
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
              shape: BoxShape.circle,
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
                  size: ScreenUtilHelper.safeFontSize(80.0, 80.0),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
