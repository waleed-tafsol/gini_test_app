import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../view_model/notifiers/audio_notifier.dart';
import '../widgets/animated_wrapper.dart';
import '../widgets/bottom_button.dart';

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
          Image.asset(
            'assets/background.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          // Backdrop filter with blur
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 10.0.h,
                  horizontal: 20.w,
                ),
                child: Stack(
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
                            child: Consumer(
                              builder: (context, ref, child) {
                                final messages = ref.watch(
                                  audioProvider.select(
                                    (state) => state.messages,
                                  ),
                                );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: messages.isEmpty
                                          ? Center(
                                              child: Text(
                                                'No messages yet',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            )
                                          : Builder(
                                              builder: (context) {
                                                // Show messages in normal order (oldest at top, newest at bottom)
                                                return ListView.builder(
                                                  controller: _scrollController,
                                                  cacheExtent: 1000,
                                                  padding: EdgeInsets.symmetric(
                                                    // horizontal: 16,
                                                    vertical: 12.h,
                                                  ),
                                                  itemCount: messages.length,
                                                  itemBuilder: (context, index) {
                                                    // index 0 = oldest message (at top), last index = latest (at bottom)
                                                    final message =
                                                        messages[index];
                                                    final isUser =
                                                        message.role == 'user';
                                                    final messageKey =
                                                        'msg_$index';

                                                    return Padding(
                                                      key: ValueKey(messageKey),
                                                      padding: EdgeInsets.only(
                                                        bottom: 12.h,
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            isUser
                                                            ? MainAxisAlignment
                                                                  .start
                                                            : MainAxisAlignment
                                                                  .end,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          if (!isUser) Spacer(),
                                                          Flexible(
                                                            flex: 2,
                                                            child: LiquidGlassLayer(
                                                              settings: LiquidGlassSettings(
                                                                thickness: 30.r,
                                                                // glassColor: isUser
                                                                //     ? Color(0x4D0000FF) // Blue tint
                                                                //     : Color(0x4D00FF00), // Green tint
                                                                lightIntensity:
                                                                    1,
                                                              ),
                                                              child: LiquidGlass(
                                                                shape: LiquidRoundedSuperellipse(
                                                                  borderRadius:
                                                                      40.r,
                                                                ),
                                                                child: Padding(
                                                                  padding: EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        20.w,
                                                                    vertical:
                                                                        10.h,
                                                                  ),
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Text(
                                                                        isUser
                                                                            ? 'You'
                                                                            : 'AI',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              11.sp,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          color:
                                                                              Colors.white,
                                                                          letterSpacing:
                                                                              0.5.w,
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                        height:
                                                                            6.h,
                                                                      ),
                                                                      Text(
                                                                        message
                                                                            .content,
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              14.sp,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
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
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    RepaintBoundary(child: BottomButton()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
              child: LiquidGlassLayer(
                settings: LiquidGlassSettings(
                  thickness: 50.r,
                  glassColor: Color(0x1AFFFFFF),
                  lightIntensity: 1,
                ),
                child: LiquidGlass(
                  shape: LiquidRoundedSuperellipse(borderRadius: 50.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 30.0.w,
                      vertical: 20.h,
                    ),
                    child: Column(
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
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              'Player Status',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18.sp,
                                color: Colors.white,
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
                                color: isRecording
                                    ? Colors.green
                                    : Colors.grey[300],
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        // Streamed response
                        if (streamedResponse?.isNotEmpty ?? false) ...[
                          SizedBox(height: 16.h),
                          Container(
                            height: 1.h,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'Streaming Response:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.sp,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            streamedResponse!,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
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
