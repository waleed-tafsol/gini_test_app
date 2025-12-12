import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'audio_provider.dart';
import 'audio_page.dart';
import 'human_model_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize the audio provider connection when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audioProvider = context.read<AudioProvider>();
      await audioProvider.initializeApp();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Consumer<AudioProvider>(
        builder: (context, audioProvider, child) {
          final isConnected = audioProvider.getIsConnected;
          
          return Padding(
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

                SizedBox(height: 40),
                
                // Message button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: isConnected
                        ? () {
                      audioProvider.setScreenType('message');

                      Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AudioPage(),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.message, size: 24),
                    label: const Text(
                      'Message',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Human button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: isConnected
                        ? () {
                      audioProvider.setScreenType('human_model');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HumanModelView(),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.person, size: 24),
                    label: const Text(
                      'Human',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
