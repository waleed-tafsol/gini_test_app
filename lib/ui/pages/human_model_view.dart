import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifiers/audio_notifier.dart';
import '../widgets/bottom_button.dart';

class HumanModelView extends StatefulWidget {
  const HumanModelView({super.key});

  @override
  State<HumanModelView> createState() => _HumanModelViewState();
}

class _HumanModelViewState extends State<HumanModelView> {
  String? chosenAnimation;
  String? chosenTexture;
  bool changeModel = false;
  String srcGlb = 'assets/business_man.glb';

  // 3D model controller - now managed locally
  final Flutter3DController _humanModelController = Flutter3DController();

  // Camera controller
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isCameraInitializing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _playTalkingAnimation();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Listen to model loaded events
      _humanModelController.onModelLoaded.addListener(() {
        debugPrint(
          'model is loaded : ${_humanModelController.onModelLoaded.value}',
        );
      });
    });
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Use back camera
        final backCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );

        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _isCameraInitializing = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _handleAnimationStateChange(bool isAnimationPlaying) {
    if (isAnimationPlaying) {
      _playTalkingAnimation();
    } else {
      _stopTalkingAnimation();
    }
  }

  void _playTalkingAnimation() {
    try {
      _humanModelController.playAnimation(
        animationName: 'Rig|cycle_talking',
        loopCount: 0, // 0 means infinite loop
      );
    } catch (e) {
      debugPrint('Error playing talking animation: $e');
    }
  }

  void _stopTalkingAnimation() {
    try {
      _humanModelController.stopAnimation();
    } catch (e) {
      debugPrint('Error stopping animation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to animation state changes from AudioProvider
    return Consumer(
      // selector: (_, provider) => provider.getIsAnimationPlaying,
      // shouldRebuild: (previous, next) => previous != next,
      builder: (context, ref, child) {
        final bool isAnimationPlaying = ref.watch(
          audioProvider.select((state) => state.isAnimationPlaying),
        );
        // React to animation state changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _handleAnimationStateChange(isAnimationPlaying);
          }
        });

        return Scaffold(
          body: Stack(
            children: [
              // Camera background - full screen
              if (_isCameraInitialized && _cameraController != null)
                SizedBox.expand(child: CameraPreview(_cameraController!))
              else if (_isCameraInitializing)
                const Center(child: CircularProgressIndicator())
              else
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: Text(
                      'Camera not available',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),

              // 3D Model overlay - fullscreen
              SizedBox.expand(
                child: RepaintBoundary(
                  child: Flutter3DViewer(
                    activeGestureInterceptor: true,
                    progressBarColor: Colors.orange,
                    enableTouch: true,
                    onProgress: (double progressValue) {
                      debugPrint('model loading progress : $progressValue');
                    },
                    onLoad: (String modelAddress) {
                      debugPrint('model loaded : $modelAddress');
                      _humanModelController.playAnimation();
                    },
                    onError: (String error) {
                      debugPrint('model failed to load : $error');
                    },
                    controller: _humanModelController,
                    src: srcGlb,
                  ),
                ),
              ),

              // Control buttons overlay - top right
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 10,
                child: RepaintBoundary(
                  child: _buildControlButtons(_humanModelController),
                ),
              ),

              // Bottom button overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: RepaintBoundary(child: BottomButton()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButtons(Flutter3DController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              controller.playAnimation();
            },
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            tooltip: 'Play Animation',
          ),
          const SizedBox(height: 4),
          IconButton(
            onPressed: () {
              controller.pauseAnimation();
              controller.pauseRotation();
            },
            icon: const Icon(Icons.pause, color: Colors.white),
            tooltip: 'Pause Animation',
          ),
          const SizedBox(height: 4),
          IconButton(
            onPressed: () {
              controller.resetAnimation();
              controller.stopRotation();
            },
            icon: const Icon(Icons.replay, color: Colors.white),
            tooltip: 'Reset Animation',
          ),
          const SizedBox(height: 4),
          IconButton(
            onPressed: () async {
              List<String> availableAnimations = await controller
                  .getAvailableAnimations();
              debugPrint(
                'Animations : $availableAnimations --- Length : ${availableAnimations.length}',
              );
              chosenAnimation = await showPickerDialog(
                'Animations',
                availableAnimations,
                chosenAnimation,
              );
              //Play animation with loop count
              controller.playAnimation(
                animationName: chosenAnimation,
                loopCount: 1,
              );
            },
            icon: const Icon(
              Icons.format_list_bulleted_outlined,
              color: Colors.white,
            ),
            tooltip: 'Select Animation',
          ),
          const SizedBox(height: 4),
          IconButton(
            onPressed: () async {
              List<String> availableTextures = await controller
                  .getAvailableTextures();
              debugPrint(
                'Textures : $availableTextures --- Length : ${availableTextures.length}',
              );
              chosenTexture = await showPickerDialog(
                'Textures',
                availableTextures,
                chosenTexture,
              );
              controller.setTexture(textureName: chosenTexture ?? '');
            },
            icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
            tooltip: 'Select Texture',
          ),
          const SizedBox(height: 4),
          IconButton(
            onPressed: () async {
              controller.startRotation(rotationSpeed: 30);
            },
            icon: const Icon(Icons.threed_rotation, color: Colors.white),
            tooltip: 'Start Rotation',
          ),
          const SizedBox(height: 4),
          IconButton(
            onPressed: () {
              controller.setCameraOrbit(20, 20, 5);
            },
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
            tooltip: 'Set Camera Orbit',
          ),
          const SizedBox(height: 4),
          IconButton(
            onPressed: () {
              controller.resetCameraOrbit();
            },
            icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
            tooltip: 'Reset Camera',
          ),
          const SizedBox(height: 4),
          IconButton(
            onPressed: () {
              setState(() {
                // Reserved for future model switching
              });
            },
            icon: const Icon(
              Icons.restore_page_outlined,
              color: Colors.white,
              size: 30,
            ),
            tooltip: 'Restore',
          ),
        ],
      ),
    );
  }

  Future<String?> showPickerDialog(
    String title,
    List<String> inputList, [
    String? chosenItem,
  ]) async {
    return await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SizedBox(
          height: 250,
          child: inputList.isEmpty
              ? Center(child: Text('$title list is empty'))
              : ListView.separated(
                  itemCount: inputList.length,
                  padding: const EdgeInsets.only(top: 16),
                  itemBuilder: (ctx, index) {
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context, inputList[index]);
                      },
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${index + 1}'),
                            Text(inputList[index]),
                            Icon(
                              chosenItem == inputList[index]
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (ctx, index) {
                    return const Divider(
                      color: Colors.grey,
                      thickness: 0.6,
                      indent: 10,
                      endIndent: 10,
                    );
                  },
                ),
        );
      },
    );
  }
}
