import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
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
  final SoLoud _soloud = SoLoud.instance;
  bool _soloudInitialized = false;
  dynamic _bufferStream;
  SoundHandle? _streamHandle;
  Timer? _audioCompletionTimer;
  Timer? _fallbackFeedTimer;
  int _totalAudioBytes = 0;

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
      if (!_soloudInitialized) {
        await _soloud.init(sampleRate: _sampleRate);
        _soloudInitialized = true;
        debugPrint(
          '✅ SoLoud initialized successfully with sample rate: $_sampleRate',
        );

        // Set global volume to maximum (important for iOS)
        _soloud.setGlobalVolume(1.0);
        debugPrint('🔊 Set global volume to 1.0');

        // Set up buffer stream for PCM16 playback
        // Use preserved buffering for streaming audio to maintain continuity
        _bufferStream = _soloud.setBufferStream(
          maxBufferSizeBytes: 1024 * 1024 * 10, // 10MB max buffer
          bufferingType:
              BufferingType.preserved, // Preserved for continuous streaming
          bufferingTimeNeeds: 0.1, // 100ms buffer for real-time playback
          sampleRate: _sampleRate,
          channels: Channels.mono,
          format: BufferType.s16le, // Signed 16-bit PCM little endian
        );
        debugPrint(
          '✅ Buffer stream initialized for PCM16 playback (preserved buffering)',
        );
      }
      if (_audioSession == null) {
        _audioSession = await AudioSession.instance;
        await _audioSession!.configure(
          AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
            avAudioSessionCategoryOptions:
                AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.duckOthers,
            avAudioSessionMode: AVAudioSessionMode.defaultMode,
            avAudioSessionRouteSharingPolicy:
                AVAudioSessionRouteSharingPolicy.defaultPolicy,
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

      await _recorder.init(
        format: PCMFormat.s16le,
        sampleRate: _sampleRate,
        channels: RecorderChannels.mono,
      );
    });
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
      compute(
        base64Decode,
        pcmDataBase64,
      ).then((pcmData) => _playPcmChunk(pcmData)).catchError((e, stackTrace) {
        developer.log(
          'Error processing audio chunk: $e',
          error: e,
          stackTrace: stackTrace,
        );
      });
    }
  }

  void _stopCurrentPlayback() {
    // Stop current playback
    if (_streamHandle != null) {
      try {
        _soloud.stop(_streamHandle!);
        _streamHandle = null;
        debugPrint('🛑 Stopped current playback for new audio');
      } catch (e) {
        debugPrint('Error stopping playback: $e');
      }
    }

    // Reset the buffer stream to clear old audio data
    _resetBufferStream();
  }

  Future<void> _resetBufferStream() async {
    return await runSafely(() async {
      // Dispose old buffer stream
      if (_bufferStream != null) {
        try {
          await _soloud.disposeSource(_bufferStream!);
          _bufferStream = null;
          debugPrint('🗑️ Disposed old buffer stream');
        } catch (e) {
          debugPrint('⚠️ Error disposing buffer stream: $e');
        }
      }

      // Create a new buffer stream
      _bufferStream = _soloud.setBufferStream(
        maxBufferSizeBytes: 1024 * 1024 * 10, // 10MB max buffer
        bufferingType:
            BufferingType.preserved, // Preserved for continuous streaming
        bufferingTimeNeeds: 0.1, // 100ms buffer for real-time playback
        sampleRate: _sampleRate,
        channels: Channels.mono,
        format: BufferType.s16le, // Signed 16-bit PCM little endian
      );
      _totalAudioBytes = 0; // Reset audio byte counter
      debugPrint('🔄 Reset buffer stream for new audio');
    });
  }

  Future<void> _playPcmChunk(Uint8List pcmData) async {
    return await runSafely(() async {
      // Play PCM16 data directly using buffer stream (no WAV conversion needed!)
      if (_bufferStream == null) {
        debugPrint('⚠️ Buffer stream not initialized');
        return;
      }

      // Ensure SoLoud is initialized before playback
      if (!_soloudInitialized) {
        debugPrint('⚠️ SoLoud not initialized, initializing now...');
        await _initializeAudio();
      }

      // Start playing if not already playing
      if (_streamHandle == null) {
        try {
          // Set global volume before playing (important for iOS)
          _soloud.setGlobalVolume(1.0);
          debugPrint('🔊 Set global volume to 1.0 before playback');

          // Start playback
          _streamHandle = await _soloud.play(_bufferStream!);
          debugPrint(
            '📢 Started PCM16 stream playback, handle: $_streamHandle',
          );

          // Set volume for the specific stream handle (important for iOS)
          if (_streamHandle != null) {
            _soloud.setVolume(_streamHandle!, 1.0);
            debugPrint(
              '🔊 Set playback volume to 1.0 for handle $_streamHandle',
            );

            // Also set pan to center (mono audio)
            _soloud.setPan(_streamHandle!, 0.0);
            debugPrint('🎚️ Set pan to center (0.0) for mono audio');
          }
        } catch (e) {
          debugPrint('❌ Error starting playback: $e');
          // Try to reinitialize if playback fails
          if (!_soloudInitialized) {
            await _initializeAudio();
            _soloud.setGlobalVolume(1.0);
            _streamHandle = await _soloud.play(_bufferStream!);
            if (_streamHandle != null) {
              _soloud.setVolume(_streamHandle!, 1.0);
              _soloud.setPan(_streamHandle!, 0.0);
            }
            debugPrint('📢 Retried playback after reinitialization');
          }
        }
      }

      // Add PCM16 data directly to the buffer stream
      try {
        _soloud.addAudioDataStream(_bufferStream!, pcmData);
        debugPrint('✅ Added ${pcmData.length} bytes to audio stream');
      } catch (e) {
        debugPrint('❌ Error adding audio data to stream: $e');
        // If adding data fails, try to restart playback
        try {
          if (_streamHandle != null) {
            await _soloud.stop(_streamHandle!);
            _streamHandle = null;
          }
          _soloud.setGlobalVolume(1.0);
          _streamHandle = await _soloud.play(_bufferStream!);
          if (_streamHandle != null) {
            _soloud.setVolume(_streamHandle!, 1.0);
            _soloud.setPan(_streamHandle!, 0.0);
            _soloud.addAudioDataStream(_bufferStream!, pcmData);
            debugPrint('✅ Retried adding audio data after restarting playback');
          }
        } catch (retryError) {
          debugPrint('❌ Error retrying audio data: $retryError');
          return;
        }
      }

      // Track total audio bytes and calculate duration
      _totalAudioBytes += pcmData.length;

      // Calculate duration: PCM16 = 2 bytes per sample, sample rate = 16000
      // Duration in seconds = (bytes / 2) / sampleRate
      final durationSeconds = (_totalAudioBytes / 2) / _sampleRate;

      // Cancel previous timer if exists
      _audioCompletionTimer?.cancel();

      // Set timer to stop animation when audio playback completes
      // Add small buffer (100ms) to ensure audio finishes playing
      _audioCompletionTimer = Timer(
        Duration(milliseconds: (durationSeconds * 1000).round() + 100),
        () {
          if (state.isAnimationPlaying) {
            state = state.copyWith(isAnimationPlaying: false);
            debugPrint('🎬 Animation stopped - audio playback complete');
          }
        },
      );

      debugPrint(
        '📢 Added PCM16 chunk to stream (${pcmData.length} bytes, total: $_totalAudioBytes bytes, duration: ${durationSeconds.toStringAsFixed(2)}s)',
      );
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
        developer.log(
          'Error starting audio recording: $e',
          error: e,
          stackTrace: stackTrace,
        );
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
      setStatusMessage =
          'Permission denied, please grant permission in settings';
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

    _cleanupSoloud();
    _webSocketManager.dispose();
    _uiEventController.close();
  }

  Future<void> _cleanupSoloud() async {
    if (_soloudInitialized) {
      try {
        // Dispose all active sources
        // Stop and dispose buffer stream
        if (_streamHandle != null) {
          try {
            await _soloud.stop(_streamHandle!);
          } catch (e) {
            debugPrint('Error stopping stream: $e');
          }
          _streamHandle = null;
        }
        if (_bufferStream != null) {
          try {
            await _soloud.disposeSource(_bufferStream!);
          } catch (e) {
            debugPrint('Error disposing buffer stream: $e');
          }
          _bufferStream = null;
        }

        _soloudInitialized = false;
        debugPrint('✅ SoLoud sources disposed');
      } catch (e) {
        debugPrint('Error disposing SoLoud: $e');
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
