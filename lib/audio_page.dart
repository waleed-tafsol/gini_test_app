import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'audio_provider.dart';
import 'ui_event.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage>
    with SingleTickerProviderStateMixin {
  StreamSubscription<UIEvent>? _uiEventSubscription;
  late AnimationController _recordingAnimationController;
  late Animation<double> _pulseAnimation;
  bool _wasRecording = false;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audioProvider = context.read<AudioProvider>();
      _uiEventSubscription = audioProvider.uiEvents.listen(_handleUIEvent);
      await audioProvider.initializeApp();
    });
  }

  @override
  void dispose() {
    _uiEventSubscription?.cancel();
    _recordingAnimationController.dispose();
    super.dispose();
  }

  void _handleUIEvent(UIEvent event) {
    if (!mounted) return;

    if (event is PermissionPermanentlyDeniedEvent) {
      _showPermissionPermanentlyDeniedDialog(event);
    } else if (event is PermissionDeniedEvent) {
      _showPermissionDeniedDialog(event);
    } else if (event is ErrorEvent) {
      _showErrorDialog(event);
    } else if (event is ConfirmationDialogEvent) {
      _showConfirmationDialog(event);
    }
  }

  Future<void> _showPermissionPermanentlyDeniedDialog(
    PermissionPermanentlyDeniedEvent event,
  ) async {
    if (!mounted) return;

    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: Text(event.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );

    if (shouldOpenSettings == true) {
      await openAppSettings();
    }
  }

  Future<void> _showPermissionDeniedDialog(PermissionDeniedEvent event) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Denied'),
          content: Text(event.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showErrorDialog(ErrorEvent event) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(event.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showConfirmationDialog(ConfirmationDialogEvent event) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(event.title),
          content: Text(event.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(event.cancelText),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(event.confirmText),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (_, audioProvider, __) {
        // Update animation state based on recording status
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

        return Scaffold(
          appBar: AppBar(
            title: const Text('Two-Way Audio Demo (sound_stream)'),
          ),
          body: Padding(
            padding: const EdgeInsets.only(top: 20.0,left: 20.0,right: 20.0,bottom: 30.0),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: audioProvider.getIsConnected
                            ? Colors.green[50]
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: audioProvider.getIsConnected
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: ${audioProvider.getStatusMessage}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: audioProvider.getIsConnected
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                audioProvider.getIsConnected
                                    ? 'Connected'
                                    : 'Disconnected',
                                style: TextStyle(
                                  color: audioProvider.getIsConnected
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // Control buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: audioProvider.getIsConnected
                                ? null
                                : () => audioProvider.reconnect(),
                            icon: Icon(Icons.wifi, size: 20),
                            label: Text(
                              audioProvider.getIsConnected
                                  ? 'Connected'
                                  : 'Reconnect',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: audioProvider.getIsConnected
                                  ? Colors.green
                                  : Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: audioProvider.getIsConnected
                                ? audioProvider.disconnectWebSocket
                                : null,
                            icon: Icon(Icons.wifi_off, size: 20),
                            label: Text('Disconnect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Player Status',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            // Recording status
                            Text(
                              audioProvider.getIsRecording
                                  ? '🟢 Live - Streaming to WebSocket'
                                  : '⏹️ Stopped',
                              style: TextStyle(
                                color: audioProvider.getIsRecording
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                            // Streamed response
                            if (audioProvider.getStreamedResponse.isNotEmpty) ...[
                              SizedBox(height: 12),
                              Divider(),
                              SizedBox(height: 8),
                              Text(
                                'Streaming Response:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                audioProvider.getStreamedResponse,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    // Messages list - using Selector to only rebuild when messages change
                    Expanded(
                      child: Selector<AudioProvider, List<dynamic>>(
                        selector: (_, provider) => provider.getMessages,
                        builder: (context, messages, child) {
                          return Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text(
                                    'Messages',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: messages.isEmpty
                                      ? Center(
                                          child: Text(
                                            'No messages yet',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 14,
                                            ),
                                          ),
                                        )
                                      : Builder(
                                          builder: (context) {
                                            // Reverse the list so newest messages appear at the top
                                            final reversedMessages = List.from(messages.reversed);
                                            return ListView.builder(
                                              cacheExtent: 1000,
                                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              itemCount: reversedMessages.length,
                                              itemBuilder: (context, index) {
                                                // index 0 = newest message (at top of screen)
                                                final message = reversedMessages[index];
                                                final isUser = message.role == 'user';

                                                // Use a stable key based on original index
                                                final originalIndex = messages.length - 1 - index;
                                                final messageKey = 'msg_$originalIndex';

                                                return Padding(
                                              key: ValueKey(messageKey),
                                              padding: EdgeInsets.only(bottom: 12),
                                              child: Row(
                                                mainAxisAlignment: isUser
                                                    ? MainAxisAlignment.start
                                                    : MainAxisAlignment.end,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (!isUser) Spacer(),
                                                  Flexible(
                                                    flex: 2,
                                                    child: Container(
                                                      padding: EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: isUser
                                                            ? Colors.blue[100]
                                                            : Colors.green[100],
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            isUser ? 'You' : 'AI',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: isUser
                                                                  ? Colors.blue[800]
                                                                  : Colors.green[800],
                                                            ),
                                                          ),
                                                          SizedBox(height: 4),
                                                          Text(
                                                            message.content,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.black87,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  if (isUser) Spacer(),
                                                ],
                                              ),
                                            );
                                              },
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
                Align(
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
                ),

              ],
            ),
          ),
        );
      },
    );
  }
}
