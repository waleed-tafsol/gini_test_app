import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../utils/glass_container.dart';

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
          Positioned.fill(
            child: Image.asset(
              'assets/background4.jpg',
              fit: BoxFit.cover,
            ),
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
                                child: Consumer(
                                  builder: (context, ref, child) {
                                    final messages = ref.watch(
                                      audioProvider.select(
                                        (state) => state.messages,
                                      ),
                                    );
                                    return messages.isEmpty
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
                                                          child: _AutoHeightGlassContainer(
                                                            child: Padding(
                                                              padding: EdgeInsets.symmetric(
                                                                horizontal: 20.w,
                                                                vertical: 10.h,
                                                              ),
                                                              child: Column(
                                                                mainAxisSize: MainAxisSize.min,
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    isUser ? 'You' : 'AI',
                                                                    style: TextStyle(
                                                                      fontSize: 11.sp,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: Colors.white,
                                                                      letterSpacing: 0.5.w,
                                                                    ),
                                                                  ),
                                                                  SizedBox(height: 6.h),
                                                                  Text(
                                                                    message.content,
                                                                    style: TextStyle(
                                                                      fontSize: 14.sp,
                                                                      color: Colors.white,
                                                                    ),
                                                                  ),
                                                                ],
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
                                          );
                                  },
                                ),
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
              child: _AutoHeightGlassContainer(
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
            );
          },
        ),
      ),
    );
  }
}

class _AutoHeightGlassContainer extends StatefulWidget {
  final Widget child;

  const _AutoHeightGlassContainer({required this.child});

  @override
  State<_AutoHeightGlassContainer> createState() => _AutoHeightGlassContainerState();
}

class _AutoHeightGlassContainerState extends State<_AutoHeightGlassContainer> {
  final GlobalKey _contentKey = GlobalKey();
  double? _contentHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureContent());
  }

  @override
  void didUpdateWidget(_AutoHeightGlassContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-measure when content changes
    if (oldWidget.child != widget.child) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureContent());
    }
  }

  void _measureContent() {
    final RenderBox? renderBox = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final height = renderBox.size.height;
      if (_contentHeight == null || (_contentHeight! - height).abs() > 1.0) {
        setState(() {
          _contentHeight = height;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite 
            ? constraints.maxWidth 
            : double.infinity;
        
        // If we haven't measured yet, render content to measure it
        if (_contentHeight == null) {
          return SizedBox(
            width: width,
            child: widget.child,
            key: _contentKey,
          );
        }

        // Once measured, render GlassContainer with measured height
        return GlassContainer(
          width: width,
          //height: _contentHeight! + 5, // Add small buffer for padding/margins
          borderRadius: BorderRadius.circular(20.r),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.40),
              Colors.white.withOpacity(0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderGradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.60),
              Colors.white.withOpacity(0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          blur: 15,
          borderWidth: 1.0,
          isFrostedGlass: true,
          frostedOpacity: 0.12,
          child: widget.child,
        );
      },
    );
  }
}
