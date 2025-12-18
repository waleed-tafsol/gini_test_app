import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tafsol_genie_app/utils/enums.dart';

import '../../view_model/notifiers/audio_notifier.dart';
import 'audio_page.dart';
import 'human_model_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
      appBar: AppBar(title: const Text('Home')),
      body: Consumer(
        builder: (context, ref, child) {
          final state = ref.watch(audioProvider);
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: audioNotifier.getIsConnected
                        ? Colors.green[50]
                        : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: audioNotifier.getIsConnected
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: ${state.statusMessage}',
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
                              color: audioNotifier.getIsConnected
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            audioNotifier.getIsConnected
                                ? 'Connected'
                                : 'Disconnected',
                            style: TextStyle(
                              color: audioNotifier.getIsConnected
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
                        onPressed: audioNotifier.getIsConnected
                            ? null
                            : () => audioNotifier.reconnect(),
                        icon: Icon(Icons.wifi, size: 20),
                        label: Text(
                          audioNotifier.getIsConnected
                              ? 'Connected'
                              : 'Reconnect',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: audioNotifier.getIsConnected
                              ? Colors.green
                              : Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: audioNotifier.getIsConnected
                            ? audioNotifier.disconnectWebSocket
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
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: audioNotifier.getIsConnected
                        ? () {
                      audioNotifier.callSessionId();
                    }
                        : null,
                    icon: const Icon(Icons.message, size: 24),
                    label: const Text(
                      'Get Session ID',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Message button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: audioNotifier.getIsConnected && state.sessionId.isNotEmpty
                        ? () {
                            audioNotifier.setScreenType(ScreenType.message);

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
                    onPressed: audioNotifier.getIsConnected && state.sessionId.isNotEmpty
                        ? () {
                            audioNotifier.setScreenType(ScreenType.humanModel);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HumanModelView(),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.person, size: 24),
                    label: const Text('Human', style: TextStyle(fontSize: 18)),
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
