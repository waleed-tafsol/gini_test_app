import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
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
  static const int _iosChunksToPreFeed = 5;
  static const int _androidChunksToPreFeed = 1;

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
    try {
      final int16List = pcmData.buffer.asInt16List();
      if (int16List.isNotEmpty) {
        final pcmArray = PcmArrayInt16.fromList(int16List.toList());
        await FlutterPcmSound.feed(pcmArray).onError((err, stackTrace) {
          developer.log('FlutterPcmSound.feed error: $err',
              error: err, stackTrace: stackTrace);
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
    
    final interval = Platform.isIOS ? 50 : 100;
    final callbackTimeout = Platform.isIOS ? 200 : 500;
    final waitTime = Platform.isIOS ? 150 : 300;
    
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
    
    // iOS: Feed immediately after delay if callback hasn't fired
    if (Platform.isIOS && _audioQueue.isNotEmpty) {
      Future.delayed(Duration(milliseconds: 150), () {
        if (_isPlaying && _audioQueue.isNotEmpty && _lastCallbackTime == null) {
          _feedFromQueue();
        }
      });
    }
  }
  
  Future<void> _feedFromQueue() async {
    if (!_isPlaying || _audioQueue.isEmpty) return;
    
    final pcmData = _audioQueue.removeFirst();
    await _feedAudioData(pcmData);
  }

  void addMessage(AiChatMessages message) {
    state = state.copyWith(messages: [message, ...state.messages]);
  }

  Future<void> _handleWebSocketData(MessageData message) async {
    return await runSafely(() async {
      final type = message.type;
      if (type == null) return;

      if (type == MessageType.sessionIdAcknowledged) {
        final sessionId = message.data['session_id'] as String?;
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
    final pcmDataBase64 = jsonData['pcm_data'] as String?;

    if (pcmDataBase64 != null && pcmDataBase64.isNotEmpty) {
      _stopCurrentPlayback();

      compute(base64Decode, pcmDataBase64)
          .then((pcmData) => _playPcmChunk(pcmData))
          .catchError((e, stackTrace) {
            developer.log('Error processing audio chunk: $e',
                error: e, stackTrace: stackTrace);
          });
    }
  }

  void _stopCurrentPlayback() {
    if (_isPlaying) {
      _isPlaying = false;
    }

    _fallbackFeedTimer?.cancel();
    _fallbackFeedTimer = null;
    _fallbackTimerStartTime = null;
    _audioQueue.clear();
    _totalAudioBytes = 0;
    _lastCallbackTime = null;
  }

  Future<void> _playPcmChunk(Uint8List pcmData) async {
    return await runSafely(() async {
      if (!_pcmSoundInitialized) {
        await _initializeAudio();
      }

      _audioQueue.add(pcmData);
      _totalAudioBytes += pcmData.length;

      if (!_isPlaying) {
        try {
          _isPlaying = true;
          
          // Pre-feed chunks before starting (iOS needs more)
          final chunksToFeed = Platform.isIOS
              ? _iosChunksToPreFeed
              : _androidChunksToPreFeed;
          int chunksFed = 0;
          
          while (_audioQueue.isNotEmpty && chunksFed < chunksToFeed) {
            final chunk = _audioQueue.removeFirst();
            await _feedAudioData(chunk);
            chunksFed++;
          }
          
          if (chunksFed == 0) {
            _isPlaying = false;
            return;
          }
          
          await Future.delayed(Duration(milliseconds: Platform.isIOS ? 100 : 50));
          
          FlutterPcmSound.start();
          _startFallbackFeedTimer();
        } catch (e, stackTrace) {
          developer.log('Error starting playback: $e', error: e, stackTrace: stackTrace);
          _isPlaying = false;
          return;
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
    if (response != null && response.isNotEmpty) {
      Future.microtask(() => _appendStreamedResponse(response));
    }
  }

  void _handelFinalTranscript(Map<String, dynamic> jsonData) {
    addMessage(AiChatMessages(role: 'user', content: jsonData['text']));
  }

  void _handelTTSComplete(Map<String, dynamic> jsonData) {
    if (jsonData['full_response'] == '') {
      addMessage(AiChatMessages(role: 'ai', content: 'Interrupted'));
    } else {
      addMessage(
        AiChatMessages(role: 'ai', content: jsonData['full_response']),
      );
    }
  }

  void _handelSessionStarted(Map<String, dynamic> jsonData) {
    setStatusMessage = 'Session started - Ready to stream';
  }

  void _handelInterruptAcknowledged() {
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
      _stopCurrentPlayback();

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
