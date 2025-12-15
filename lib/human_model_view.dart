import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:o3d/o3d.dart';
import 'package:gini_test_app/bottom_button.dart';
import 'package:provider/provider.dart';

import 'audio_provider.dart';

class HumanModelView extends StatefulWidget {
  const HumanModelView({super.key});

  @override
  State<HumanModelView> createState() => _HumanModelViewState();
}

class _HumanModelViewState extends State<HumanModelView> {
  // O3D controller for animation control
  final O3DController _o3dController = O3DController();
  
  String srcGlb = 'assets/business_man.glb';
  bool _isAnimationPlaying = false;

  @override
  void initState() {
    super.initState();
  }

  void _handleAnimationStateChange(bool isAnimationPlaying) {
    if (isAnimationPlaying != _isAnimationPlaying) {
      setState(() {
        _isAnimationPlaying = isAnimationPlaying;
      });
      
      if (isAnimationPlaying) {
        _playTalkingAnimation();
      } else {
        _stopTalkingAnimation();
      }
    }
  }

  void _playTalkingAnimation() {
    try {
      // o3d supports direct animation control via controller.play()
      // Play animation with infinite loop (0 repetitions means infinite)
      _o3dController.play();
      debugPrint('🎬 Starting talking animation');
    } catch (e) {
      debugPrint('Error playing talking animation: $e');
    }
  }

  void _stopTalkingAnimation() {
    try {
      // Pause the animation
      _o3dController.pause();
      debugPrint('🛑 Stopping talking animation');
    } catch (e) {
      debugPrint('Error stopping animation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to animation state changes from AudioProvider
    return Selector<AudioProvider, bool>(
      selector: (_, provider) => provider.getIsAnimationPlaying,
      shouldRebuild: (previous, next) => previous != next, // Only rebuild when state actually changes
      builder: (context, isAnimationPlaying, child) {
        // React to animation state changes - use addPostFrameCallback to defer
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _handleAnimationStateChange(isAnimationPlaying);
          }
        });

        return Scaffold(
          floatingActionButton: RepaintBoundary(
            child: _buildControlButtons(),
          ),
          body: Stack(
            children: [
              // 3D Model Viewer
              Container(
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  gradient: RadialGradient(
                    colors: [Color(0xffffffff), Colors.grey],
                    stops: [0.1, 1.0],
                    radius: 0.7,
                    center: Alignment.center,
                  ),
                ),
                child: RepaintBoundary(
                  child: O3D.asset(
                    src: srcGlb,
                    controller: _o3dController,
                    ar: true, // Enable AR mode
                    autoRotate: false,
                    cameraControls: true,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
              // Bottom button
              Padding(
                padding: const EdgeInsets.only(bottom: 30.0),
                child: RepaintBoundary(
                  child: BottomButton(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play animation button
        IconButton(
          onPressed: () {
            setState(() {
              _isAnimationPlaying = true;
            });
            _playTalkingAnimation();
          },
          icon: const Icon(Icons.play_arrow),
          tooltip: 'Play Animation',
        ),
        const SizedBox(height: 4),
        // Stop animation button
        IconButton(
          onPressed: () {
            setState(() {
              _isAnimationPlaying = false;
            });
            _stopTalkingAnimation();
          },
          icon: const Icon(Icons.pause),
          tooltip: 'Stop Animation',
        ),
      ],
    );
  }
}
