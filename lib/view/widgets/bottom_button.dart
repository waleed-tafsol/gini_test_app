import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../view_model/notifiers/audio_notifier.dart';



class BottomButton extends ConsumerStatefulWidget {
  const BottomButton({super.key});

  @override
  ConsumerState<BottomButton> createState() => _BottomButtonState();
}

class _BottomButtonState extends ConsumerState<BottomButton>
    with SingleTickerProviderStateMixin {
  bool _wasRecording = false;

  late Animation<double> _pulseAnimation;
  late AnimationController _recordingAnimationController;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _recordingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _recordingAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _recordingAnimationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioNotifier = ref.read(audioProvider.notifier);
    return Consumer(
      builder: (_, ref, _) {
        final isRecording = ref.watch(
          audioProvider.select((state) => state.isRecording),
        );
        if (isRecording != _wasRecording) {
          _wasRecording = isRecording;
          if (isRecording) {
            _recordingAnimationController.repeat(reverse: true);
          } else {
            _recordingAnimationController.stop();
            _recordingAnimationController.reset();
          }
        }
        return Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTapDown: (details) {
                  if (audioNotifier.getIsConnected && !isRecording) {
                    audioNotifier.startStreamingAudio();
                  }
                },
                onTapUp: (details) {
                  if (isRecording) {
                    audioNotifier.stopStreamingAudio();
                  }
                },
                onTapCancel: () {
                  if (isRecording) {
                    audioNotifier.stopStreamingAudio();
                  }
                },
                child: isRecording
                    ? AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 80 * _pulseAnimation.value,
                            height: 80 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                            child: Center(
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red,
                                ),
                                child: Icon(
                                  Icons.mic,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: audioNotifier.getIsConnected
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: audioNotifier.getIsConnected
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            child: Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
              ),
              SizedBox(width: 40),
              GestureDetector(
                onTap: () async {
                  await audioNotifier.interruptStreamingAudio();
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: audioNotifier.getIsConnected
                        ? Colors.orange.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: audioNotifier.getIsConnected
                            ? Colors.orange
                            : Colors.grey,
                      ),
                      child: Icon(
                        Icons.pause_presentation,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
