import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'audio_provider.dart';

class BottomButton extends StatefulWidget {
  const BottomButton({super.key});

  @override
  _BottomButtonState createState() => _BottomButtonState();
}

class _BottomButtonState extends State<BottomButton> with SingleTickerProviderStateMixin{
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

    return Consumer<AudioProvider>(
        builder: (_, audioProvider, _) {
          final isRecording = audioProvider.getIsRecording;
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
                  if (audioProvider.getIsConnected &&
                      !audioProvider.getIsRecording) {
                    audioProvider.startStreamingAudio();
                  }
                },
                onTapUp: (details) {
                  if (audioProvider.getIsRecording) {
                    audioProvider.stopStreamingAudio();
                  }
                },
                onTapCancel: () {
                  if (audioProvider.getIsRecording) {
                    audioProvider.stopStreamingAudio();
                  }
                },
                child: audioProvider.getIsRecording
                    ? AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 80 * _pulseAnimation.value,
                      height: 80 * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withOpacity(0.3),
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
                    color: audioProvider.getIsConnected
                        ? Colors.green.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.3),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: audioProvider.getIsConnected
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
              SizedBox(width: 40,),
              GestureDetector(
                  onTap: () async {
                    await audioProvider.interruptStreamingAudio();
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: audioProvider.getIsConnected
                          ? Colors.orange.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                    ),
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: audioProvider.getIsConnected
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
                  )
              ),

            ],
          ),
        );
      }
    );
  }
}
