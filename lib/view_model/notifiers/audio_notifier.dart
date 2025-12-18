import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../models/ai_chat_messages.dart';
import '../../models/permission_handler.dart';
import '../../models/socket_message_models.dart';
import '../../models/ui_event.dart';
import '../../services/websocket_service.dart';
import '../states/audio_state.dart';
import 'base_notifier.dart';
import '../../utils/enums.dart';

final audioProvider = NotifierProvider.autoDispose(() => AudioNotifier());

class AudioNotifier extends BaseNotifier<AudioState> {
  final String _wsUrl = 'wss://genie-api-test.devcustomprojects.online/ws';
  late final WebSocketService _webSocketManager;
  final SoLoud _soloud = SoLoud.instance;
  bool _soloudInitialized = false;
  dynamic _bufferStream; // Buffer stream for PCM16 playback (SoundSource type)
  SoundHandle? _streamHandle; // Handle for the playing stream
  Timer? _audioCompletionTimer; // Timer to track when audio playback completes
  int _totalAudioBytes = 0; // Track total audio bytes for duration calculation
  final Recorder _recorder = Recorder.instance;
  StreamSubscription<AudioDataContainer>? _audioInputSubscription;
  final PermissionHandler _permissionHandler = PermissionHandler();
  final StreamController<UIEvent> _uiEventController =
      StreamController<UIEvent>.broadcast();
  StreamSubscription<UIEvent>? _uiEventSubscription;
  Function(UIEvent)? _uiEventHandler;


  void setSessionId(String value) {
    state = state.copyWith(sessionId: value);
  }

  static const int _sampleRate = 16000; // WebSocket expects 16kHz

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
      if (_uiEventHandler != null) {
        _uiEventHandler!(event);
      }
    });
  }

  AudioNotifier() : super(AudioState()) {
    _webSocketManager = WebSocketService(url: _wsUrl);
    _webSocketManager.onDataReceived = _handleWebSocketData;
    _webSocketManager.onStatusChanged = (message) => setStatusMessage = message;
    _webSocketManager.onError = (error) {
      stopStreamingAudio();
    };
    _webSocketManager.onDisconnected = () {
      stopStreamingAudio();
    };
  }

  set setIsRecording(bool value) {
    debugPrint(
      '🔄 setIsRecording called with value: $value (current: ${state.isRecording})',
    );
    if (state.isRecording != value) {
      state = state.copyWith(isRecording: value);
      debugPrint('✅ _isRecording updated to: ${state.isRecording}');
      debugPrint('✅ notifyListeners() called');
    } else {
      debugPrint('⚠️ _isRecording already $value, skipping update');
    }
  }

  bool get getIsConnected => _webSocketManager.isConnected;

  set setStatusMessage(String value) {
    state = state.copyWith(statusMessage: value);
  }

  void _appendStreamedResponse(String text) {
    final String? data = state.streamedResponse;
    state = state.copyWith(streamedResponse: data != null ? data + text : text);
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
                  '${permissionResult.permissionName} permission is required for this app to function properly. '
                  'It has been permanently denied. Please enable it in the app settings.',
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
    });
  }

  Future<void> _initializeAudio() async {
    // Initialize SoLoud for audio playback
    return await runSafely(() async {
      if (!_soloudInitialized) {
        await _soloud.init();
        _soloudInitialized = true;
        debugPrint('✅ SoLoud initialized successfully');

        // Set up buffer stream for PCM16 playback (no WAV conversion needed!)
        _bufferStream = _soloud.setBufferStream(
          maxBufferSizeBytes: 1024 * 1024 * 10,
          // 10MB max buffer
          bufferingType: BufferingType.preserved,
          bufferingTimeNeeds: 0.1,
          // 100ms buffer for real-time playback
          sampleRate: _sampleRate,
          channels: Channels.mono,
          format: BufferType.s16le, // Signed 16-bit PCM little endian
        );
        debugPrint('✅ Buffer stream initialized for PCM16 playback');
      }
      _recorder.init(
        format: PCMFormat.s16le, // 16-bit PCM format
        sampleRate: _sampleRate,
        channels: RecorderChannels.mono, // Mono
      );
      debugPrint('✅ Recorder initialized successfully');
    });
  }

  void addMessage(AiChatMessages message) {
    state = state.copyWith(messages: [message, ...state.messages]);
  }

  Future<void> _handleWebSocketData(dynamic data) async {
    return await runSafely(() async {
      if (data == null) return;
      if (data.isEmpty) return;

      if (data is String) {
        // Parse JSON - defer to microtask for non-audio messages to reduce main thread blocking
        final jsonData = jsonDecode(data) as Map<String, dynamic>;
        final type = jsonData['type'] as String?;

        // Reduced logging - only log non-audio messages to avoid spam
        if (type != 'audio_pcm_ready') {
          debugPrint('📨 [WebSocket] Type: ${type ?? "unknown"}');
        }

        if (type == null) {
          debugPrint('⚠️ [WebSocket] Warning: Message type is null');
          return;
        } else {
          // Handle audio_pcm_ready - starts animation with loop count 0

          // Handle final_transcript - stops animation

          // Handle other message types
          if(type == 'session_id_acknowledged'){
            final sessionId = jsonData['session_id'] as String?;
            setSessionId(sessionId!);

            return;
          }
          if (state.type == ScreenType.message) {
            if (type == 'audio_pcm_ready') {
              final chunkIdx = jsonData['chunk_idx'];
              debugPrint(
                '🔊 [WebSocket] Handling: audio_pcm_ready - chunk_idx: $chunkIdx',
              );
              _handelAudioPcmReady(jsonData);
            } else if (type == "session_started") {
              debugPrint('✅ [WebSocket] Handling: session_started');
              _handelSessionStarted(jsonData);
            } else if (type == "interrupt_acknowledged") {
              debugPrint('🛑 [WebSocket] Handling: interrupt_acknowledged');
              _handelInterruptAcknowledged();
            } else if (type == "tts_complete") {
              debugPrint('✅ [WebSocket] Handling: tts_complete');
              _handelTTSComplete(jsonData);
            } else if (type == "streamed_response") {
              debugPrint(
                '📝 [WebSocket] Handling: streamed_response - ${jsonData['response']}',
              );
              _handelStreamedResponse(jsonData);
            } else if (type == "final_transcript") {
              debugPrint(
                '💬 [WebSocket] Handling: final_transcript - ${jsonData['text']}',
              );
              _handelFinalTranscript(jsonData);
            } else {
              debugPrint(
                '❓ [WebSocket] Unhandled message type in message screen: $type',
              );
            }
          } else {
            if (type == 'audio_pcm_ready') {
              // Process audio without blocking - no debug print for every chunk
              _handelAudioPcmReady(jsonData);
              // Throttle animation state updates - only update once when starting
              if (!state.isAnimationPlaying) {
                state = state.copyWith(isAnimationPlaying: true);
              }
            } else if (type == "tts_complete") {
              debugPrint('✅ [WebSocket] Handling: tts_complete');
            }
          }
        }
      } else {
        debugPrint(
          '⚠️ [WebSocket] Received non-string data: ${data.runtimeType}',
        );
      }
    });
  }

  // Audio processing for playback using flutter_soloud
  // Note: We play only the latest audio, not queued chunks

  void _handelAudioPcmReady(Map<String, dynamic> jsonData) {
    final pcmDataBase64 = jsonData['pcm_data'] as String?;

    if (pcmDataBase64 != null && pcmDataBase64.isNotEmpty) {
      // Stop current playback and clear old audio when new audio arrives

      // Decode in isolate to prevent blocking main thread
      compute(base64Decode, pcmDataBase64)
          .then((pcmData) {
            // Play only the latest audio chunk (don't queue old chunks)
            _playPcmChunk(pcmData);
          })
          .catchError((e) {
            debugPrint('Error processing audio chunk: $e');
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
        await _soloud.disposeSource(_bufferStream!);
        _bufferStream = null;
      }

      // Create a new buffer stream
      _bufferStream = _soloud.setBufferStream(
        maxBufferSizeBytes: 1024 * 1024 * 10,
        // 10MB max buffer
        bufferingType: BufferingType.preserved,
        bufferingTimeNeeds: 0.1,
        // 100ms buffer for real-time playback
        sampleRate: _sampleRate,
        channels: Channels.mono,
        format: BufferType.s16le, // Signed 16-bit PCM little endian
      );
      debugPrint('🔄 Reset buffer stream for new audio');
    });
  }

  Future<void> _playPcmChunk(Uint8List pcmData) async {
    return await runSafely(() async {
      // Play PCM16 data directly using buffer stream (no WAVgi conversion needed!)
      if (_bufferStream == null) {
        debugPrint('⚠️ Buffer stream not initialized');
        return;
      }

      // Start playing if not already playing
      if (_streamHandle == null) {
        _streamHandle = await _soloud.play(_bufferStream!);
        debugPrint('📢 Started PCM16 stream playback, handle: $_streamHandle');
      }

      // Add PCM16 data directly to the buffer stream (returns void, not awaitable)
      _soloud.addAudioDataStream(_bufferStream!, pcmData);

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
    if (response != null && response.isNotEmpty) {
      // Batch UI updates to reduce main thread work
      Future.microtask(() {
        _appendStreamedResponse(response);
      });
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
    // Handle session_started message
    // This typically indicates the WebSocket session is ready
    debugPrint('✅ [WebSocket] Session started: ${jsonData.toString()}');
    setStatusMessage = 'Session started - Ready to stream';
  }

  void _handelInterruptAcknowledged() {
    // Stop recording
    _recorder.stopStreamingData();
    state = state.copyWith(isStreamingData: false);
    _audioInputSubscription?.cancel();
    _audioInputSubscription = null;

    // Stop playback
    if (_streamHandle != null) {
      _soloud.stop(_streamHandle!);
      _streamHandle = null;
    }

    // Cancel audio completion timer
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
      debugPrint('🎤 startStreamingAudio called');

      if (!_webSocketManager.isConnected) {
        debugPrint('❌ WebSocket not connected');
        setStatusMessage = 'Not connected to WebSocket';
        return;
      }

      if (state.isRecording) {
        debugPrint('⚠️ Already recording, ignoring start request');
        return;
      }

      setStatusMessage = 'Starting audio stream...';
      _clearStreamedResponse();

      // Check permissions before starting
      final permissionResult = await _permissionHandler.requestPermissions();
      if (!permissionResult.isGranted) {
        debugPrint('❌ Microphone permission not granted');
        setStatusMessage = 'Microphone permission required';
        return;
      }

      final startEvent = StartAudioMessageModel(
        sessionId: state.sessionId,
        sampleRate: _sampleRate,
      );
      final jsonString = jsonEncode(startEvent.toJson());
      _webSocketManager.send(jsonString);
      debugPrint('📤 Sent start event to WebSocket');

      // Start recording using flutter_recorder package
      try {
        debugPrint('🎵 Attempting to start audio recording...');

        // Start the capture device
        _recorder.start();
        debugPrint('✅ Recorder capture device started');

        // Start streaming audio data
        _recorder.startStreamingData();
        state = state.copyWith(isStreamingData: true);
        debugPrint('✅ Audio streaming started');

        // Set recording state immediately after starting
        setIsRecording = true;
        debugPrint(
          '✅ Recording state set to true, _isRecording = ${state.isRecording}',
        );

        // Listen to audio stream and send to WebSocket
        _audioInputSubscription = _recorder.uint8ListStream.listen(
          (audioDataContainer) {
            if (!state.isRecording) {
              debugPrint('⚠️ Received audio data but _isRecording is false');
              return;
            }

            // Get raw PCM16 data from the container
            // The data is already in the format specified during init (s16le)
            final audioData = audioDataContainer.rawData;

            // Send audio data to WebSocket
            final msgEvent = AudioMessageModel(
              sessionId: state.sessionId,
              audio: audioData,
              sampleRate: _sampleRate,
            );
            final jsonString = jsonEncode(msgEvent.toJson());
            _webSocketManager.send(jsonString);
          },
          onError: (error) {
            debugPrint('Audio stream error: $error');
            stopStreamingAudio();
          },
          onDone: () {
            debugPrint('⚠️ Audio input stream closed');
            if (state.isRecording) {
              stopStreamingAudio();
            }
          },
        );
        debugPrint('✅ Audio input subscription created');
        setStatusMessage = 'Recording and streaming...';
      } catch (e, stackTrace) {
        debugPrint('❌ Error starting audio recording: $e');
        debugPrint('Stack trace: $stackTrace');
        setStatusMessage = 'Failed to start audio recording: $e';
        setIsRecording = false;
        return;
      }
    });
  }

  Future<void> stopStreamingAudio() async {
    return await runSafely(() async {
      if (!state.isRecording) return;

      final endChatEvent = AudioEndMessageModel(sessionId: state.sessionId);
      final jsonString = jsonEncode(endChatEvent.toJson());
      _webSocketManager.send(jsonString);

      // Stop recording
      if (state.isStreamingData) {
        _recorder.stopStreamingData();
        state = state.copyWith(isStreamingData: false);
      }
      await _audioInputSubscription?.cancel();
      _audioInputSubscription = null;

      // Stop any ongoing playback
      if (_streamHandle != null) {
        await _soloud.stop(_streamHandle!);
        _streamHandle = null;
      }

      // Cancel audio completion timer
      _audioCompletionTimer?.cancel();
      _audioCompletionTimer = null;
      _totalAudioBytes = 0;

      _stopTalkingAnimation();
      setIsRecording = false;
      setStatusMessage = 'Recording stopped';
    });
  }

  void callSessionId(){
    final startEvent = SessionGeneratorModel(
      type: 'session_id',
    );
    final jsonString = jsonEncode(startEvent.toJson());
    _webSocketManager.send(jsonString);
  }


  Future<void> interruptStreamingAudio() async {
    return await runSafely(() async {
      // Stop recording
      if (state.isStreamingData) {
        _recorder.stopStreamingData();
        state = state.copyWith(isStreamingData: false);
      }
      await _audioInputSubscription?.cancel();
      _audioInputSubscription = null;

      // Stop playback
      if (_streamHandle != null) {
        await _soloud.stop(_streamHandle!);
        _streamHandle = null;
      }

      // Cancel audio completion timer
      _audioCompletionTimer?.cancel();
      _audioCompletionTimer = null;
      _totalAudioBytes = 0;

      _stopTalkingAnimation();
      final interruptEvent = InterruptEventModel(sessionId: state.sessionId);
      final jsonString = jsonEncode(interruptEvent.toJson());
      _webSocketManager.send(jsonString);
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
                '${permissionResult.permissionName} permission is required for this app to function properly. '
                'It has been permanently denied. Please enable it in the app settings.',
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
  }

  Future<void> disconnectWebSocket() async {
    await _webSocketManager.disconnect();
    setIsRecording = false;
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

    // Clean up SoLoud - dispose all active sources and temp files
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


