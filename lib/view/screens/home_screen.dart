import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

import '../../models/sessions_response_model.dart';
import '../../utils/enums.dart';
import '../../utils/glass_container.dart';
import '../../view_model/notifiers/audio_notifier.dart';
import '../widgets/animated_wrapper.dart';
import 'audio_page.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<AnimatedWrapperState> _animationKey =
      GlobalKey<AnimatedWrapperState>();

  @override
  void initState() {
    super.initState();
    // Initialize the audio provider connection when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(audioProvider.notifier).initializeApp();
    });
  }

  Future<void> _fetchAndShowSessionIds(
    BuildContext context,
    AudioNotifier audioNotifier,
  ) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Make API call
      final response = await http
          .get(
            Uri.parse(
              'https://genie-api-test.devcustomprojects.online/api/list-sessions',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      // Close loading indicator
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final sessionsResponse = SessionsResponse.fromJson(data);

        if (sessionsResponse.sessions.isEmpty) {
          // Show message if no session IDs found
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('No Sessions'),
                content: const Text('No session IDs found.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } else {
          // Show dialog with session IDs
          if (context.mounted) {
            await _showSessionIdDialog(
              context,
              sessionsResponse.sessions,
              audioNotifier,
            );
          }
        }
      } else {
        // Show error message
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: Text(
                'Failed to fetch session IDs: ${response.statusCode}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // Close loading indicator if still open
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to fetch session IDs: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _showSessionIdDialog(
    BuildContext context,
    List<Session> sessions,
    AudioNotifier audioNotifier,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: GlassContainer(
            width: MediaQuery.of(context).size.width * 0.9,
            borderRadius: BorderRadius.circular(20.r),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.60),
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
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Session ID',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.black87),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        return InkWell(
                          onTap: () {
                            audioNotifier.setSessionId(session.sessionId);
                            audioNotifier.callSessionId();
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            margin: EdgeInsets.only(bottom: 8.h),
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        session.name,
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.black87,
                                      size: 16.sp,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  session.sessionId,
                                  style: TextStyle(
                                    color: Colors.black87.withOpacity(0.7),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.w,
                                        vertical: 4.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: session.state == 'idle'
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.orange.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                      ),
                                      child: Text(
                                        session.state.toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      '${session.clientCount} client(s)',
                                      style: TextStyle(
                                        color: Colors.black87.withOpacity(0.6),
                                        fontSize: 11.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioNotifier = ref.read(audioProvider.notifier);
    return Scaffold(
      //appBar: AppBar(title: const Text('Home')),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background5.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Consumer(
              builder: (context, ref, child) {
                final state = ref.watch(audioProvider);
                return Padding(
                  padding: EdgeInsets.all(20.0.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 40.h),
                      // Huge circular connect button
                      Center(
                        child: AnimatedWrapper(
                          key: _animationKey,
                          animationType: AnimationType.rotate,
                          child: _CircularConnectButton(
                            isConnected: state.isConnected,
                            onPressed: () {
                              // Trigger animation on press
                              _animationKey.currentState?.play();
                              if (state.isConnected) {
                                audioNotifier.disconnectWebSocket();
                              } else {
                                audioNotifier.reconnect();
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 40.h),
                      if (state.isConnected)
                        AnimatedWrapper(
                          animationType: AnimationType.slideRight,
                          duration: const Duration(seconds: 1),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth.isFinite
                                  ? constraints.maxWidth
                                  : MediaQuery.of(context).size.width;
                              return GestureDetector(
                                onTap: () async {
                                  await _fetchAndShowSessionIds(
                                    context,
                                    audioNotifier,
                                  );
                                },
                                child: GlassContainer(
                                  width: width,
                                  // height: 70.h,
                                  borderRadius: BorderRadius.circular(12.0.r),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.60),
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
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          CupertinoIcons
                                              .arrow_right_arrow_left_square_fill,
                                          color: Colors.black87,
                                          size: 22.sp,
                                        ),
                                        SizedBox(width: 10.w),
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Get Session ID',
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5.w,
                                              ),
                                            ),
                                            if (state.sessionId.isNotEmpty)
                                              Text(
                                                'Active Id: ${state.sessionId}',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.5.w,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      SizedBox(height: 20.h),
                      // Message button
                      if (state.isConnected && state.sessionId.isNotEmpty)
                        AnimatedWrapper(
                          animationType: AnimationType.slideRight,
                          duration: const Duration(seconds: 2),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth.isFinite
                                  ? constraints.maxWidth
                                  : MediaQuery.of(context).size.width;
                              return GestureDetector(
                                onTap: () {
                                  audioNotifier.setScreenType(
                                    ScreenType.message,
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AudioPage(),
                                    ),
                                  );
                                },
                                child: GlassContainer(
                                  width: width,
                                  height: 60.h,
                                  borderRadius: BorderRadius.circular(12.0.r),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.60),
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
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          CupertinoIcons.chat_bubble_2_fill,
                                          color: Colors.black87,
                                          size: 22.sp,
                                        ),
                                        SizedBox(width: 10.w),
                                        Text(
                                          'Message',
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5.w,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      //  SizedBox(height: 20.h),

                      /* // Human button
                    if (state.isConnected && state.sessionId.isNotEmpty)
                      AnimatedWrapper(
                        animationType: AnimationType.slideRight,
                        duration: const Duration(seconds: 3),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth.isFinite
                                ? constraints.maxWidth
                                : MediaQuery.of(context).size.width;
                            return GestureDetector(
                              onTap: () {
                                // audioNotifier.setScreenType(
                                //   ScreenType.humanModel,
                                // );
                                // Navigator.push(
                                //   context,
                                //   MaterialPageRoute(
                                //     builder: (context) =>
                                //         const HumanModelView(),
                                //   ),
                                // );
                              },
                              child: GlassContainer(
                                width: width,
                                height: 60.h,
                                borderRadius: BorderRadius.circular(12.0.r),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.60),
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
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person,
                                        color: Colors.black87,
                                        size: 22.sp,
                                      ),
                                      SizedBox(width: 10.w),
                                      Text(
                                        'Human',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5.w,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          ),
                        ),*/
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularConnectButton extends StatefulWidget {
  final bool isConnected;
  final VoidCallback onPressed;

  const _CircularConnectButton({
    required this.isConnected,
    required this.onPressed,
  });

  @override
  State<_CircularConnectButton> createState() => _CircularConnectButtonState();
}

class _CircularConnectButtonState extends State<_CircularConnectButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onPressed();
      },
      child: SizedBox(
        width: 180.w,
        height: 180.w,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Ensure constraints are valid before building GlassContainer
            if (!constraints.maxWidth.isFinite ||
                !constraints.maxHeight.isFinite ||
                constraints.maxWidth <= 0 ||
                constraints.maxHeight <= 0) {
              return Container(
                width: 180.w,
                height: 180.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Center(
                  child: Icon(
                    widget.isConnected
                        ? CupertinoIcons.bolt_fill
                        : CupertinoIcons.bolt_slash_fill,
                    color: Colors.black87,
                    size: 80.0,
                  ),
                ),
              );
            }

            return GlassContainer(
              width: 180.w,
              height: 180.w,
              borderRadius: BorderRadius.circular(90.w),
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
              elevation: 3.0,
              isFrostedGlass: true,
              shadowColor: Colors.black.withOpacity(0.20),
              alignment: Alignment.center,
              frostedOpacity: 0.12,
              child: Center(
                child: Icon(
                  widget.isConnected
                      ? CupertinoIcons.bolt_fill
                      : CupertinoIcons.bolt_slash_fill,
                  color: Colors.black87,
                  size: 80.sp,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
