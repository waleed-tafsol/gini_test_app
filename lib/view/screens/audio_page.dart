import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../view_model/notifiers/audio_notifier.dart';
import '../widgets/bottom_button.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Two-Way Audio Demo (flutter_soloud)')),
      body: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RepaintBoundary(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final state = ref.watch(
                          audioProvider.select(
                            (state) =>
                                (state.isRecording, state.streamedResponse),
                          ),
                        );
                        final isRecording = state.$1;
                        final streamedResponse = state.$2;

                        return Card(
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
                                  isRecording
                                      ? '🟢 Live - Streaming to WebSocket'
                                      : '⏹️ Stopped',
                                  style: TextStyle(
                                    color: isRecording
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                                // Streamed response
                                if (streamedResponse?.isNotEmpty ?? false) ...[
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
                                    streamedResponse!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildMessages(),
                ],
              ),
            ),
            RepaintBoundary(child: BottomButton()),
          ],
        ),
      ),
    );
  }

  RepaintBoundary _buildMessages() {
    return RepaintBoundary(
      child: Consumer(
        builder: (context, ref, child) {
          final messages = ref.watch(
            audioProvider.select((state) => state.messages),
          );
          return Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Messages',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        cacheExtent: 1000,
                        physics: NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
