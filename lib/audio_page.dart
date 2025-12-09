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

class _AudioPageState extends State<AudioPage> {
  StreamSubscription<UIEvent>? _uiEventSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audioProvider = context.read<AudioProvider>();
      _uiEventSubscription = audioProvider.uiEvents.listen(_handleUIEvent);
      await audioProvider.initializeApp();
    });
  }

  @override
  void dispose() {
    _uiEventSubscription?.cancel();
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
        return Scaffold(
          appBar: AppBar(
            title: const Text('Two-Way Audio Demo (sound_stream)'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
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

                // Audio control button
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
                  child: Container(
                    width: double.infinity, // Or set a specific width
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: audioProvider.getIsRecording
                          ? Colors.red
                          : (audioProvider.getIsConnected
                                ? Colors.green
                                : Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          audioProvider.getIsRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                        ),
                        SizedBox(width: 10),
                        Text(
                          audioProvider.getIsRecording
                              ? 'Stop Streaming'
                              : 'Start Recording & Streaming',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                // Player status
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
                        // Player status can be shown here if you have status streams
                        // For now, show recording status
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
                      ],
                    ),
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
