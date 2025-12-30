import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tafsol_genie_app/models/message_data.dart';

import '../../models/ai_chat_messages.dart';
import '../../models/permission_handler.dart';
import '../../models/socket_message_models.dart';
import '../../models/ui_event.dart';
import '../../services/websocket_service.dart';
import '../../utils/enums.dart';
import '../states/audio_state.dart';
import 'base_notifier.dart';

final audioProvider = NotifierProvider.autoDispose(() => AudioNotifier());

class AudioNotifier extends BaseNotifier<AudioState> {
  final String _wsUrl = 'wss://genie-api-test.devcustomprojects.online/ws';
  late final WebSocketService _webSocketManager;
  AudioSession? _audioSession;
  
  // Audio playback state
  bool _pcmSoundInitialized = false;
  bool _isPlaying = false;
  final Queue<Uint8List> _audioQueue = Queue<Uint8List>();
  Timer? _audioCompletionTimer;
  Timer? _fallbackFeedTimer;
  int _totalAudioBytes = 0;
  DateTime? _lastCallbackTime;
  DateTime? _fallbackTimerStartTime;
  
  // Audio recording
  final Recorder _recorder = Recorder.instance;
  StreamSubscription<AudioDataContainer>? _audioInputSubscription;
  
  // UI events
  final PermissionHandler _permissionHandler = PermissionHandler();
  final StreamController<UIEvent> _uiEventController =
      StreamController<UIEvent>.broadcast();
  StreamSubscription<UIEvent>? _uiEventSubscription;
  Function(UIEvent)? _uiEventHandler;
  
  static const int _sampleRate = 16000;

  AudioNotifier() : super(AudioState()) {
    _webSocketManager = WebSocketService(
      url: _wsUrl,
      onDataReceived: _handleWebSocketData,
      onStatusChanged: (message) => setStatusMessage = message,
      onError: (error) => stopStreamingAudio(),
      onDisconnected: stopStreamingAudio,
    );
  }

  void setSessionId(String value) {
    state = state.copyWith(sessionId: value);
  }

  void setScreenType(ScreenType type) {
    state = state.copyWith(type: type);
  }

  Stream<UIEvent> get uiEvents => _uiEventController.stream;

  void _emitEvent(UIEvent event) {
    _uiEventController.add(event);
  }

  void setUIEventHandler(Function(UIEvent) handler) {
    _uiEventHandler = handler;
    _uiEventSubscription?.cancel();
    _uiEventSubscription = uiEvents.listen((event) {
      _uiEventHandler?.call(event);
    });
  }

  set setIsRecording(bool value) {
    if (state.isRecording != value) {
      state = state.copyWith(isRecording: value);
    }
  }

  set setStatusMessage(String value) {
    state = state.copyWith(statusMessage: value);
  }

  void _appendStreamedResponse(String text) {
    final current = state.streamedResponse;
    state = state.copyWith(
      streamedResponse: current != null ? current + text : text,
    );
  }

  void _clearStreamedResponse() {
    state = state.copyWith(streamedResponse: '');
  }

  Future<void> initializeApp() async {
    return await runSafely(() async {
      setStatusMessage = 'Initializing...';
      
      final permissionResult = await _permissionHandler.requestPermissions();
      if (!permissionResult.isGranted) {
        if (permissionResult.isPermanentlyDenied) {
          _emitEvent(
            PermissionPermanentlyDeniedEvent(
              permissionName: permissionResult.permissionName,
              message:
                  '${permissionResult.permissionName} permission is required. '
                  'Please enable it in the app settings.',
            ),
          );
        } else {
          _emitEvent(
            PermissionDeniedEvent(
              permissionName: permissionResult.permissionName,
              message: '${permissionResult.permissionName} permission denied',
            ),
          );
        }
        setStatusMessage = 'Initialization failed: Permission denied';
        return;
      }

      await _initializeAudio();
      await _webSocketManager.connect();
      state = state.copyWith(isConnected: true);
    });
  }

  Future<void> _initializeAudio() async {
    return await runSafely(() async {
      // Initialize and configure audio_session FIRST (before flutter_pcm_sound)
      // This ensures our settings are applied before flutter_pcm_sound sets up
      if (_audioSession == null) {
        _audioSession = await AudioSession.instance;
        await _audioSession!.configure(
          AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
            avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.duckOthers,
            avAudioSessionMode: AVAudioSessionMode.defaultMode,
            avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
            avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
            androidAudioAttributes: const AndroidAudioAttributes(
              contentType: AndroidAudioContentType.speech,
              flags: AndroidAudioFlags.none,
              usage: AndroidAudioUsage.voiceCommunication,
            ),
            androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
            androidWillPauseWhenDucked: false,
          ),
        );
        developer.log(
          '✅ Audio session configured (before flutter_pcm_sound)',
          name: 'AudioNotifier',
        );
      }
      
      if (!_pcmSoundInitialized) {
        FlutterPcmSound.setLogLevel(LogLevel.verbose);
        
        await FlutterPcmSound.setup(
          sampleRate: _sampleRate,
          channelCount: 1,
          iosAudioCategory: IosAudioCategory.playAndRecord,
          iosAllowBackgroundAudio: false,
        ).onError((err, stackTrace) {
          developer.log('FlutterPcmSound.setup error: $err',
              error: err, stackTrace: stackTrace);
        });
        
        // iOS needs larger buffer for smooth playback
        final threshold = Platform.isIOS ? (_sampleRate ~/ 2) : (_sampleRate ~/ 10);
        await FlutterPcmSound.setFeedThreshold(threshold).onError((err, stackTrace) {
          developer.log('FlutterPcmSound.setFeedThreshold error: $err',
              error: err, stackTrace: stackTrace);
        });
        
        FlutterPcmSound.setFeedCallback(_onFeedCallback);
        _pcmSoundInitialized = true;
        
        // Reconfigure audio session AFTER flutter_pcm_sound setup
        // This ensures our settings (especially defaultToSpeaker) take precedence
        if (Platform.isIOS) {
          await _audioSession!.configure(
            AudioSessionConfiguration(
              avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
              avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker |
                  AVAudioSessionCategoryOptions.allowBluetooth |
                  AVAudioSessionCategoryOptions.duckOthers,
              avAudioSessionMode: AVAudioSessionMode.defaultMode,
              avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
              avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
              androidAudioAttributes: const AndroidAudioAttributes(
                contentType: AndroidAudioContentType.speech,
                flags: AndroidAudioFlags.none,
                usage: AndroidAudioUsage.voiceCommunication,
              ),
              androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
              androidWillPauseWhenDucked: false,
            ),
          );
          developer.log(
            '✅ Audio session reconfigured after flutter_pcm_sound setup',
            name: 'AudioNotifier',
          );
        }
      }
      
      await _recorder.init(
        format: PCMFormat.s16le,
        sampleRate: _sampleRate,
        channels: RecorderChannels.mono,
      );
    });
  }
  
  void _onFeedCallback(int remainingFrames) async {
    _lastCallbackTime = DateTime.now();
    
    if (_isPlaying && _audioQueue.isNotEmpty) {
      final pcmData = _audioQueue.removeFirst();
      await _feedAudioData(pcmData);
    } else if (remainingFrames == 0 && _isPlaying && _audioQueue.isEmpty) {
      _isPlaying = false;
      _fallbackFeedTimer?.cancel();
      _fallbackFeedTimer = null;
      if (state.isAnimationPlaying) {
        state = state.copyWith(isAnimationPlaying: false);
      }
    }
  }
  
  Future<void> _feedAudioData(Uint8List pcmData) async {
    // Don't feed if not playing or not initialized
    if (!_isPlaying || !_pcmSoundInitialized) {
      return;
    }
    
    try {
      final int16List = pcmData.buffer.asInt16List();
      if (int16List.isNotEmpty) {
        final pcmArray = PcmArrayInt16.fromList(int16List.toList());
        await FlutterPcmSound.feed(pcmArray).onError((err, stackTrace) {
          // OSStatus -66628 (kAudioUnitErr_CannotDoInCurrentContext) means audio unit is not ready
          // OSStatus -50 (kAudio_ParamError) means parameter error - audio unit might not be initialized
          final errStr = err.toString();
          if (errStr.contains('-66628') || errStr.contains('-50') || errStr.contains('AudioUnitError')) {
            developer.log(
              '⚠️ FlutterPcmSound.feed error (audio unit not ready): $err',
              name: 'AudioNotifier',
            );
            // Don't stop playing immediately - might recover on next chunk
            // Only stop if we get multiple errors
          } else {
            developer.log('FlutterPcmSound.feed error: $err',
                error: err, stackTrace: stackTrace);
          }
        });
      }
    } catch (e, stackTrace) {
      developer.log('Error feeding audio data: $e', error: e, stackTrace: stackTrace);
    }
  }
  
  void _startFallbackFeedTimer() {
    _fallbackFeedTimer?.cancel();
    _fallbackTimerStartTime = DateTime.now();
    _lastCallbackTime = null;
    
    // Very aggressive intervals for real-time feeding
    final interval = Platform.isIOS ? 10 : 15; // Very frequent checks
    final callbackTimeout = Platform.isIOS ? 30 : 50; // Very short timeout
    final waitTime = Platform.isIOS ? 20 : 30; // Very short wait
    
    _fallbackFeedTimer = Timer.periodic(Duration(milliseconds: interval), (timer) {
      if (!_isPlaying || _audioQueue.isEmpty) {
        timer.cancel();
        _fallbackFeedTimer = null;
        _fallbackTimerStartTime = null;
        return;
      }
      
      final now = DateTime.now();
      
      if (_lastCallbackTime != null) {
        final timeSinceLastCallback = now.difference(_lastCallbackTime!).inMilliseconds;
        if (timeSinceLastCallback > callbackTimeout) {
          _feedFromQueue();
        }
      } else if (_fallbackTimerStartTime != null) {
        final timeSinceStart = now.difference(_fallbackTimerStartTime!).inMilliseconds;
        if (timeSinceStart > waitTime) {
          _feedFromQueue();
        }
      }
    });
    
    // Feed immediately if callback hasn't fired (very short delay for real-time)
    if (_audioQueue.isNotEmpty) {
      Future.delayed(Duration(milliseconds: Platform.isIOS ? 10 : 15), () {
        if (_isPlaying && _audioQueue.isNotEmpty && _lastCallbackTime == null) {
          _feedFromQueue();
        }
      });
    }
  }
  
  Future<void> _feedFromQueue() async {
    if (!_isPlaying || _audioQueue.isEmpty) return;
    
    // Feed multiple chunks if available for smoother playback
    int chunksFed = 0;
    final maxChunksPerFeed = Platform.isIOS ? 2 : 1;
    
    while (_isPlaying && _audioQueue.isNotEmpty && chunksFed < maxChunksPerFeed) {
      final pcmData = _audioQueue.removeFirst();
      await _feedAudioData(pcmData);
      chunksFed++;
    }
  }

  void addMessage(AiChatMessages message) {
    state = state.copyWith(messages: [message, ...state.messages]);
  }

  Future<void> _handleWebSocketData(MessageData message) async {
    return await runSafely(() async {
      // Log the full socket response
      developer.log(
        '📥 [Socket Response] Type: ${message.type}, Data: ${message.data}',
        name: 'AudioNotifier',
      );
      
      final type = message.type;
      if (type == null) {
        developer.log(
          '⚠️ [Socket Response] Message type is null, data: ${message.data}',
          name: 'AudioNotifier',
        );
        return;
      }

      if (type == MessageType.sessionIdAcknowledged) {
        final sessionId = message.data['session_id'] as String?;
        developer.log(
          '🆔 [SessionIdAcknowledged] Session ID: ${sessionId ?? "null"}',
          name: 'AudioNotifier',
        );
        if (sessionId != null) setSessionId(sessionId);
        return;
      }

      if (state.type == ScreenType.message) {
        switch (type) {
          case MessageType.audioPcmReady:
            _handelAudioPcmReady(message.data);
            break;
          case MessageType.sessionStarted:
            _handelSessionStarted(message.data);
            break;
          case MessageType.interruptAcknowledged:
            _handelInterruptAcknowledged();
            break;
          case MessageType.ttsComplete:
            _handelTTSComplete(message.data);
            break;
          case MessageType.streamedResponse:
            _handelStreamedResponse(message.data);
            break;
          case MessageType.finalTranscript:
            _handelFinalTranscript(message.data);
            break;
          default:
            break;
        }
      } else {
        if (type == MessageType.audioPcmReady) {
          _handelAudioPcmReady(message.data);
          if (!state.isAnimationPlaying) {
            state = state.copyWith(isAnimationPlaying: true);
          }
        }
      }
    });
  }

  void _handelAudioPcmReady(Map<String, dynamic> jsonData) {
    developer.log(
      '🎵 [AudioPcmReady] Received audio data, size: ${jsonData['pcm_data']?.toString().length ?? 0}',
      name: 'AudioNotifier',
    );
    
    final pcmDataBase64 = jsonData['pcm_data'] as String?;

    if (pcmDataBase64 != null && pcmDataBase64.isNotEmpty) {
      // Don't stop current playback - just add new chunk to queue for continuous playback
      compute(base64Decode, pcmDataBase64)
          .then((pcmData) => _playPcmChunk(pcmData))
          .catchError((e, stackTrace) {
            developer.log('Error processing audio chunk: $e',
                error: e, stackTrace: stackTrace);
          });
    }
  }

  void _stopCurrentPlayback({bool silent = false}) {
    // Only log if there was actually playback happening
    final wasPlaying = _isPlaying || _audioQueue.isNotEmpty || state.isAnimationPlaying;
    
    // Stop playback immediately by setting flag and clearing queue
    _isPlaying = false;

    _fallbackFeedTimer?.cancel();
    _fallbackFeedTimer = null;
    _fallbackTimerStartTime = null;
    _audioQueue.clear();
    _totalAudioBytes = 0;
    _lastCallbackTime = null;
    
    // Note: We don't release FlutterPcmSound here because:
    // 1. It causes OSStatus -66628 errors when trying to feed data after release
    // 2. Stopping data feed and clearing queue is sufficient to stop playback
    // 3. The audio will stop naturally when the buffer empties
    // If we need to release, it should be done in dispose() only
    
    // Stop animation immediately
    if (state.isAnimationPlaying) {
      state = state.copyWith(isAnimationPlaying: false);
    }
    
    // Only log if there was actual playback and not silent mode
    if (wasPlaying && !silent) {
      developer.log(
        '🛑 Audio playback stopped (queue cleared, feeding stopped)',
        name: 'AudioNotifier',
      );
    }
  }

  Future<void> _playPcmChunk(Uint8List pcmData) async {
    return await runSafely(() async {
      if (!_pcmSoundInitialized) {
        await _initializeAudio();
      }

      // Add chunk to queue first
      _audioQueue.add(pcmData);
      _totalAudioBytes += pcmData.length;

      // If not playing, start playback
      // Use a lock-like mechanism to prevent multiple simultaneous starts
      if (!_isPlaying) {
        try {
          _isPlaying = true;
          
          // Ensure audio session is configured before playback (iOS)
          // We try to reconfigure, but if it fails with OSStatus 2003329396,
          // that's okay - it means the session is already active and configured
          if (_audioSession != null && Platform.isIOS) {
            try {
              await _audioSession!.configure(
                AudioSessionConfiguration(
                  avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
                  avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker |
                      AVAudioSessionCategoryOptions.allowBluetooth |
                      AVAudioSessionCategoryOptions.duckOthers,
                  avAudioSessionMode: AVAudioSessionMode.defaultMode,
                  avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
                  avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
                  androidAudioAttributes: const AndroidAudioAttributes(
                    contentType: AndroidAudioContentType.speech,
                    flags: AndroidAudioFlags.none,
                    usage: AndroidAudioUsage.voiceCommunication,
                  ),
                  androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
                  androidWillPauseWhenDucked: false,
                ),
              );
              developer.log(
                '✅ Audio session configured for playback (iOS)',
                name: 'AudioNotifier',
              );
            } catch (e, stackTrace) {
              // OSStatus 2003329396 means session is already active - that's fine
              final errStr = e.toString();
              if (errStr.contains('2003329396')) {
                developer.log(
                  'ℹ️ Audio session already active (continuing)',
                  name: 'AudioNotifier',
                );
              } else {
                developer.log(
                  '⚠️ Error configuring audio session (continuing): $e',
                  name: 'AudioNotifier',
                  error: e,
                  stackTrace: stackTrace,
                );
              }
            }
          }
          
          // Start FlutterPcmSound immediately for real-time playback
          // Minimal delay to ensure audio session is ready
          await Future.delayed(Duration(milliseconds: Platform.isIOS ? 20 : 10));
          
          try {
            FlutterPcmSound.start();
            developer.log(
              '▶️ FlutterPcmSound started, queue size: ${_audioQueue.length}',
              name: 'AudioNotifier',
            );
          } catch (e, stackTrace) {
            // OSStatus -50 (kAudio_ParamError) can occur if audio unit isn't ready
            final errStr = e.toString();
            if (errStr.contains('-50') || errStr.contains('AudioUnitError')) {
              developer.log(
                '⚠️ FlutterPcmSound.start error (retrying): $e',
                name: 'AudioNotifier',
              );
              // Wait a bit and retry
              await Future.delayed(Duration(milliseconds: 50));
              try {
                FlutterPcmSound.start();
                developer.log('✅ FlutterPcmSound started on retry', name: 'AudioNotifier');
              } catch (e2) {
                developer.log('❌ FlutterPcmSound.start failed after retry: $e2', name: 'AudioNotifier');
                _isPlaying = false;
                return;
              }
            } else {
              developer.log('❌ FlutterPcmSound.start error: $e', error: e, stackTrace: stackTrace);
              _isPlaying = false;
              return;
            }
          }
          
          // Minimal delay to ensure audio unit is ready (reduced for real-time)
          await Future.delayed(Duration(milliseconds: Platform.isIOS ? 10 : 5));
          
          // Feed first chunk immediately for real-time playback
          if (_audioQueue.isNotEmpty && _isPlaying) {
            final chunk = _audioQueue.removeFirst();
            await _feedAudioData(chunk);
          }
          
          // Start aggressive fallback timer for continuous real-time feeding
          _startFallbackFeedTimer();
        } catch (e, stackTrace) {
          developer.log('Error starting playback: $e', error: e, stackTrace: stackTrace);
          _isPlaying = false;
          return;
        }
      } else {
        // If already playing, feed this chunk immediately for real-time playback
        // This ensures chunks are played as soon as they arrive
        if (_isPlaying && _audioQueue.isNotEmpty) {
          // Feed immediately without waiting
          final chunk = _audioQueue.removeFirst();
          await _feedAudioData(chunk);
          
          // Also trigger fallback timer to ensure continuous feeding
          if (_fallbackFeedTimer == null) {
            _startFallbackFeedTimer();
          }
        }
      }

      // Calculate duration and set completion timer
      if (_totalAudioBytes > 0 && _sampleRate > 0) {
        final durationSeconds = (_totalAudioBytes / 2) / _sampleRate;
        if (durationSeconds.isFinite && durationSeconds > 0) {
          _audioCompletionTimer?.cancel();
          _audioCompletionTimer = Timer(
            Duration(milliseconds: (durationSeconds * 1000).round() + 100),
            () {
              if (state.isAnimationPlaying) {
                state = state.copyWith(isAnimationPlaying: false);
              }
            },
          );
        }
      }
    });
  }

  void _handelStreamedResponse(Map<String, dynamic> jsonData) {
    final response = jsonData['response'] as String?;
    developer.log(
      '💬 [StreamedResponse] Response: ${response ?? "null"}',
      name: 'AudioNotifier',
    );
    if (response != null && response.isNotEmpty) {
      Future.microtask(() => _appendStreamedResponse(response));
    }
  }

  void _handelFinalTranscript(Map<String, dynamic> jsonData) {
    final text = jsonData['text'] as String?;
    developer.log(
      '📝 [FinalTranscript] Text: ${text ?? "null"}',
      name: 'AudioNotifier',
    );
    if (text != null) {
      addMessage(AiChatMessages(role: 'user', content: text));
    }
  }

  void _handelTTSComplete(Map<String, dynamic> jsonData) {
    final fullResponse = jsonData['full_response'] as String?;
    developer.log(
      '✅ [TTSComplete] Full response: ${fullResponse ?? "null"}',
      name: 'AudioNotifier',
    );
    if (fullResponse == null || fullResponse.isEmpty) {
      addMessage(AiChatMessages(role: 'ai', content: 'Interrupted'));
    } else {
      addMessage(AiChatMessages(role: 'ai', content: fullResponse));
    }
  }

  void _handelSessionStarted(Map<String, dynamic> jsonData) {
    developer.log(
      '🚀 [SessionStarted] Session started, data: $jsonData',
      name: 'AudioNotifier',
    );
    setStatusMessage = 'Session started - Ready to stream';
  }

  void _handelInterruptAcknowledged() {
    developer.log(
      '⏹️ [InterruptAcknowledged] Interrupt acknowledged by server',
      name: 'AudioNotifier',
    );
    _recorder.stopStreamingData();
    state = state.copyWith(isStreamingData: false);
    _audioInputSubscription?.cancel();
    _audioInputSubscription = null;

    _stopCurrentPlayback();
    _audioCompletionTimer?.cancel();
    _audioCompletionTimer = null;
    _totalAudioBytes = 0;

    _stopTalkingAnimation();
    setStatusMessage = 'Audio stream interrupted';
  }

  void _stopTalkingAnimation() {
    if (state.isAnimationPlaying) {
      state = state.copyWith(isAnimationPlaying: false);
    }
  }

  Future<void> startStreamingAudio() async {
    return await runSafely(() async {
      // Silently stop any existing playback before starting recording
      _stopCurrentPlayback(silent: true);

      if (!_webSocketManager.isConnected) {
        setStatusMessage = 'Not connected to WebSocket';
        return;
      }

      if (state.isRecording) return;

      setStatusMessage = 'Starting audio stream...';
      _clearStreamedResponse();

      final permissionResult = await _permissionHandler.requestPermissions();
      if (!permissionResult.isGranted) {
        setStatusMessage = 'Microphone permission required';
        return;
      }

      final startEvent = StartAudioMessageModel(
        sessionId: state.sessionId,
        sampleRate: _sampleRate,
      );
      _webSocketManager.send(jsonEncode(startEvent.toJson()));

      try {
        _recorder.start();
        _recorder.startStreamingData();
        state = state.copyWith(isStreamingData: true);
        setIsRecording = true;

        _audioInputSubscription = _recorder.uint8ListStream.listen(
          (audioDataContainer) {
            if (!state.isRecording) return;

            final msgEvent = AudioMessageModel(
              sessionId: state.sessionId,
              audio: audioDataContainer.rawData,
              sampleRate: _sampleRate,
            );
            _webSocketManager.send(jsonEncode(msgEvent.toJson()));
          },
          onError: (error) {
            developer.log('Audio stream error: $error');
            stopStreamingAudio();
          },
          onDone: () {
            if (state.isRecording) {
              stopStreamingAudio();
            }
          },
        );
        setStatusMessage = 'Recording and streaming...';
      } catch (e, stackTrace) {
        developer.log('Error starting audio recording: $e',
            error: e, stackTrace: stackTrace);
        setStatusMessage = 'Failed to start audio recording: $e';
        setIsRecording = false;
      }
    });
  }

  Future<void> stopStreamingAudio() async {
    return await runSafely(() async {
      if (!state.isRecording) return;

      final endChatEvent = AudioEndMessageModel(sessionId: state.sessionId);
      _webSocketManager.send(jsonEncode(endChatEvent.toJson()));

      if (state.isStreamingData) {
        _recorder.stopStreamingData();
        state = state.copyWith(isStreamingData: false);
      }
      await _audioInputSubscription?.cancel();
      _audioInputSubscription = null;

      _stopCurrentPlayback();
      _audioCompletionTimer?.cancel();
      _audioCompletionTimer = null;
      _totalAudioBytes = 0;

      _stopTalkingAnimation();
      setIsRecording = false;
      setStatusMessage = 'Recording stopped';
    });
  }

  void callSessionId() {
    final startEvent = SessionGeneratorModel(type: 'session_id');
    _webSocketManager.send(jsonEncode(startEvent.toJson()));
  }

  Future<void> interruptStreamingAudio() async {
    return await runSafely(() async {
      developer.log(
        '⏹️ Interrupting audio stream - stopping playback immediately',
        name: 'AudioNotifier',
      );
      
      // Stop audio playback FIRST (immediate)
      _stopCurrentPlayback();
      _audioCompletionTimer?.cancel();
      _audioCompletionTimer = null;
      _totalAudioBytes = 0;
      
      // Then stop recording
      if (state.isStreamingData) {
        _recorder.stopStreamingData();
        state = state.copyWith(isStreamingData: false);
      }
      await _audioInputSubscription?.cancel();
      _audioInputSubscription = null;

      _stopTalkingAnimation();
      final interruptEvent = InterruptEventModel(sessionId: state.sessionId);
      _webSocketManager.send(jsonEncode(interruptEvent.toJson()));
      setStatusMessage = 'Recording interrupted';
    });
  }

  Future<void> reconnect() async {
    final permissionResult = await _permissionHandler.requestPermissions();

    if (!permissionResult.isGranted) {
      if (permissionResult.isPermanentlyDenied) {
        _emitEvent(
          PermissionPermanentlyDeniedEvent(
            permissionName: permissionResult.permissionName,
            message:
                '${permissionResult.permissionName} permission is required. '
                'Please enable it in the app settings.',
          ),
        );
      } else {
        _emitEvent(
          PermissionDeniedEvent(
            permissionName: permissionResult.permissionName,
            message: '${permissionResult.permissionName} permission denied',
          ),
        );
      }
      setStatusMessage = 'Permission denied, please grant permission in settings';
      return;
    }

    await stopStreamingAudio();
    await _webSocketManager.reconnect();
    state = state.copyWith(isConnected: true);
  }

  Future<void> disconnectWebSocket() async {
    await _webSocketManager.disconnect();
    setIsRecording = false;
    state = state.copyWith(isConnected: false);
  }

  @override
  void dispose() {
    super.dispose();
    stopStreamingAudio();
    _uiEventSubscription?.cancel();
    _uiEventSubscription = null;
    _uiEventHandler = null;
    _audioInputSubscription?.cancel();
    _audioInputSubscription = null;
    _fallbackFeedTimer?.cancel();
    _fallbackFeedTimer = null;

    _cleanupPcmSound();
    _webSocketManager.dispose();
    _uiEventController.close();
  }

  Future<void> _cleanupPcmSound() async {
    if (_pcmSoundInitialized) {
      try {
        if (_isPlaying) {
          _isPlaying = false;
        }
        
        FlutterPcmSound.release().onError((err, stackTrace) {
          developer.log('FlutterPcmSound.release error: $err',
              error: err, stackTrace: stackTrace);
        });
        
        FlutterPcmSound.setFeedCallback(null);
        _audioQueue.clear();
        _totalAudioBytes = 0;
        _pcmSoundInitialized = false;
      } catch (e) {
        developer.log('Error disposing FlutterPcmSound: $e');
      }
    }
  }

  @override
  void onError(String msg) {
    setStatusMessage = 'Initialization failed: $msg';
    _emitEvent(ErrorEvent(message: 'Initialization failed: $msg'));
    super.onError(msg);
  }
}
