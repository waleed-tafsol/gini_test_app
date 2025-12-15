import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:gini_test_app/bottom_button.dart';
import 'package:provider/provider.dart';

import 'audio_provider.dart';

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
  String srcObj = 'assets/flutter_dash.obj';

  // 3D model controller - now managed locally
  final Flutter3DController _humanModelController = Flutter3DController();
  //bool _previousAnimationState = false;

  @override
  void initState() {
    super.initState();
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

  void _handleAnimationStateChange(bool isAnimationPlaying) {
    // if (isAnimationPlaying != _previousAnimationState) {
    if (isAnimationPlaying) {
      _playTalkingAnimation();
    } else {
      _stopTalkingAnimation();
    }
    //   _previousAnimationState = isAnimationPlaying;
    // }
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
            child: _buildControlButtons(_humanModelController),
          ),
          body: Stack(
            children: [
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
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: Column(
                  children: [
                    // Flexible(
                    //   flex: 1,
                    //   child: Flutter3DViewer.obj(
                    //     src: srcObj,
                    //     //src : 'assets/flutter_dash.obj',
                    //     //src: 'https://raw.githubusercontent.com/m-r-davari/content-holder/refs/heads/master/flutter_3d_controller/flutter_dash_model/flutter_dash.obj',
                    //     scale: 5,
                    //     // Initial scale of obj model
                    //     cameraX: 0,
                    //     // Initial cameraX position of obj model
                    //     cameraY: 0,
                    //     //Initial cameraY position of obj model
                    //     cameraZ: 10,
                    //     //Initial cameraZ position of obj model
                    //     //This callBack will return the loading progress value between 0 and 1.0
                    //     onProgress: (double progressValue) {
                    //       debugPrint('model loading progress : $progressValue');
                    //     },
                    //     //This callBack will call after model loaded successfully and will return model address
                    //     onLoad: (String modelAddress) {
                    //       debugPrint('model loaded : $modelAddress');
                    //     },
                    //     //this callBack will call when model failed to load and will return failure erro
                    //     onError: (String error) {
                    //       debugPrint('model failed to load : $error');
                    //     },
                    //   ),
                    // ),
                    Flexible(
                      flex: 1,
                      child: RepaintBoundary(
                        child: Flutter3DViewer(
                          //If you pass 'true' the flutter_3d_controller will add gesture interceptor layer
                          //to prevent gesture recognizers from malfunctioning on iOS and some Android devices.
                          // the default value is true.
                          activeGestureInterceptor: true,
                          //If you don't pass progressBarColor, the color of defaultLoadingProgressBar will be grey.
                          //You can set your custom color or use [Colors.transparent] for hiding loadingProgressBar.
                          progressBarColor: Colors.orange,
                          //You can disable viewer touch response by setting 'enableTouch' to 'false'
                          enableTouch: true,
                          //This callBack will return the loading progress value between 0 and 1.0
                          onProgress: (double progressValue) {
                            debugPrint('model loading progress : $progressValue');
                          },
                          //This callBack will call after model loaded successfully and will return model address
                          onLoad: (String modelAddress) {
                            debugPrint('model loaded : $modelAddress');
                            _humanModelController.playAnimation();
                          },
                          //this callBack will call when model failed to load and will return failure error
                          onError: (String error) {
                            debugPrint('model failed to load : $error');
                          },
                          //You can have full control of 3d model animations, textures and camera
                          controller: _humanModelController,
                          src: srcGlb,
                          //src: 'assets/business_man.glb', //3D model with different animations
                          //src: 'assets/sheen_chair.glb', //3D model with different textures
                          //src: 'https://modelviewer.dev/shared-assets/models/Astronaut.glb', // 3D model from URL
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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

  Widget _buildControlButtons(Flutter3DController controller) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            controller.playAnimation();
          },
          icon: const Icon(Icons.play_arrow),
        ),
        const SizedBox(height: 4),
        IconButton(
          onPressed: () {
            controller.pauseAnimation();
            controller.pauseRotation();
          },
          icon: const Icon(Icons.pause),
        ),
        const SizedBox(height: 4),
        IconButton(
          onPressed: () {
            controller.resetAnimation();
            controller.stopRotation();
          },
          icon: const Icon(Icons.replay),
        ),
        const SizedBox(height: 4),
        IconButton(
          onPressed: () async {
            List<String> availableAnimations = await controller.getAvailableAnimations();
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
          icon: const Icon(Icons.format_list_bulleted_outlined),
        ),
        const SizedBox(height: 4),
        IconButton(
          onPressed: () async {
            List<String> availableTextures = await controller.getAvailableTextures();
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
          icon: const Icon(Icons.list_alt_rounded),
        ),
        const SizedBox(height: 4),
        IconButton(
          onPressed: () async {
            controller.startRotation(rotationSpeed: 30);
          },
          icon: const Icon(Icons.threed_rotation),
        ),
        const SizedBox(height: 4),
        IconButton(
          onPressed: () {
            controller.setCameraOrbit(20, 20, 5);
          },
          icon: const Icon(Icons.camera_alt_outlined),
        ),
        const SizedBox(height: 4),
        IconButton(
          onPressed: () {
            controller.resetCameraOrbit();
          },
          icon: const Icon(Icons.cameraswitch_outlined),
        ),
        const SizedBox(height: 4),
        IconButton(
          onPressed: () {
            setState(() {
              // Reserved for future model switching
            });
          },
          icon: const Icon(Icons.restore_page_outlined, size: 30),
        ),
      ],
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
