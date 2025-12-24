import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:tafsol_genie_app/utils/enums.dart';

import '../../utils/embossed_glass_button.dart';
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
          Image.asset(
            'assets/background.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(audioProvider);
                  return Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 40),
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
                        SizedBox(height: 40),
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

                        const SizedBox(height: 20),
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

                        const SizedBox(height: 20),

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
    final size = 180.0; // Huge circular button size

    return GestureDetector(
      onTap: () {
        widget.onPressed();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle),
        child: LiquidGlassLayer(
          settings: LiquidGlassSettings(
            thickness: 100,
            glassColor: Color(0x1AFFFFFF),
            lightIntensity: 1,
            // saturation: 1.2,
          ),
          child: LiquidGlass(
            shape: LiquidOval(),
            child: Center(
              child: Icon(
                widget.isConnected
                    ? CupertinoIcons.bolt_fill
                    : CupertinoIcons.bolt_slash_fill,
                color: Colors.white,
                size: 80,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
