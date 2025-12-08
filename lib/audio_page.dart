import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'audio_provider.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Access the Provider here after the first build frame
      await context.read<AudioProvider>().initializeApp();
    });
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
                    color: audioProvider.getIsConnected ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: audioProvider.getIsConnected ? Colors.green : Colors.red,
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
                              color: audioProvider.getIsConnected ? Colors.green : Colors.red,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            audioProvider.getIsConnected ? 'Connected' : 'Disconnected',
                            style: TextStyle(
                              color: audioProvider.getIsConnected ? Colors.green : Colors.red,
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
                        onPressed: audioProvider.getIsConnected ? null : audioProvider.reconnect,
                        icon: Icon(Icons.wifi, size: 20),
                        label: Text(audioProvider.getIsConnected ? 'Connected' : 'Reconnect'),
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
                        onPressed: audioProvider.getIsConnected ? audioProvider.disconnectWebSocket : null,
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
                ElevatedButton(
                  onPressed: audioProvider.getIsConnected && !audioProvider.getIsRecording
                      ? audioProvider.startStreamingAudio
                      : audioProvider.getIsRecording
                      ? audioProvider.stopStreamingAudio
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: audioProvider.getIsRecording
                        ? Colors.red
                        : (audioProvider.getIsConnected ? Colors.green : Colors.grey),
                    padding: EdgeInsets.symmetric(vertical: 16),
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
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
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
                            color: audioProvider.getIsRecording ? Colors.green : Colors.grey,
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
