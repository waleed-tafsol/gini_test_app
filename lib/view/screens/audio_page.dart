import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tafsol_genie_app/models/ai_chat_messages.dart';

import '../../view_model/notifiers/audio_notifier.dart';
import '../widgets/animated_wrapper.dart';
import '../widgets/auto_height_container.dart';
import '../widgets/bottom_button.dart';
import '../widgets/chat_message.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset('assets/background5.jpg', fit: BoxFit.cover),
          ),
          // Backdrop filter with blur
          Positioned.fill(
            child: SizedBox.expand(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 10.0.h,
                  horizontal: 20.w,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Player Status Card - Use Selector to only rebuild when status changes
                            _buildPlayerStatusCard(),
                            SizedBox(height: 20.h),
                            // Messages list - using Selector to only rebuild when messages change
                            Expanded(
                              child: RepaintBoundary(
                                child: _buildChatMessages(),
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: RepaintBoundary(child: BottomButton()),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Consumer _buildChatMessages() {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(
          audioProvider.select(
            (state) => (state.messages, state.streamedResponse),
          ),
        );
        final messages = state.$1;
        final streamedResponse = state.$2;
        return messages.isEmpty
            ? Center(
                child: Text(
                  'No messages yet',
                  style: TextStyle(color: Colors.black87, fontSize: 14),
                ),
              )
            : ListView(
                controller: ref.read(audioProvider.notifier).scrollController,
                padding: EdgeInsets.only(bottom: 100.h),
                reverse: true,
                children: [
                  if (streamedResponse != null)
                    ChatMessage(
                      message: AiChatMessages(
                        role: 'ai',
                        content: streamedResponse,
                      ),
                    ),
                  for (final message in messages) ChatMessage(message: message),
                ],
              );
        // : ListView.builder(
        //     controller: _scrollController,
        //     cacheExtent: 1000,
        //     padding: EdgeInsets.symmetric(vertical: 12.h),
        //     itemCount: messages.length,
        //     itemBuilder: (context, index) {
        //       return ChatMessage(message: messages[index]);
        //     },
        //   );
      },
    );
  }

  Widget _buildPlayerStatusCard() {
    return SafeArea(
      child: RepaintBoundary(
        child: Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(
              audioProvider.select(
                (state) => (state.isRecording, state.streamedResponse),
              ),
            );
            final isRecording = state.$1;
            final streamedResponse = state.$2;

            return AnimatedWrapper(
              animationType: AnimationType.fadeIn,
              duration: const Duration(milliseconds: 500),
              child: AutoHeightGlassContainer(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 30.0.w,
                    vertical: 20.h,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        spacing: 10.w,
                        children: [
                          GestureDetector(
                            onTap: Navigator.of(context).pop,
                            child: SizedBox(
                              width: 35.w,
                              child: Icon(
                                Icons.arrow_back,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            'Player Status',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18.sp,
                              color: Colors.black87,
                              letterSpacing: 0.5.w,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      // Recording status
                      Row(
                        children: [
                          SizedBox(width: 45.w),
                          Container(
                            width: 12.w,
                            height: 12.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isRecording ? Colors.green : Colors.grey,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            isRecording
                                ? 'Live - Streaming to WebSocket'
                                : 'Stopped',
                            style: TextStyle(
                              color: isRecording ? Colors.green : Colors.black,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      // Streamed response
                      // if (streamedResponse?.isNotEmpty ?? false) ...[
                      //   SizedBox(height: 16.h),
                      //   Container(
                      //     height: 1.h,
                      //     color: Colors.white.withValues(alpha: 0.3),
                      //   ),
                      //   SizedBox(height: 12.h),
                      //   Text(
                      //     'Streaming Response:',
                      //     style: TextStyle(
                      //       fontWeight: FontWeight.w600,
                      //       fontSize: 12.sp,
                      //       color: Colors.black87,
                      //     ),
                      //   ),
                      //   SizedBox(height: 8.h),
                      //   Text(
                      //     streamedResponse!,
                      //     style: TextStyle(
                      //       fontSize: 14.sp,
                      //       color: Colors.black87,
                      //     ),
                      //   ),
                      // ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
