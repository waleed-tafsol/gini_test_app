import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:gini_test_app/models/ai_chat_messages.dart';
import 'package:gini_test_app/models/socket_message_models.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'permission_handler.dart';
import 'ui_event.dart';
import 'websocket_manager.dart';

class AudioProvider extends ChangeNotifier {
  final String _wsUrl = 'wss://1ee244c26383.ngrok-free.app/ws';
  late final WebSocketManager _webSocketManager;

  String _screenType = 'message';

  void setScreenType(String type) {
    _screenType = type;
    notifyListeners();
  }

  // Animation state tracking
  bool _isAnimationPlaying = false;

  bool get getIsAnimationPlaying => _isAnimationPlaying;

  final List<AiChatMessages> _messages = [];

  // flutter_soloud instance for audio playback
  final SoLoud _soloud = SoLoud.instance;
  bool _soloudInitialized = false;
  dynamic _bufferStream; // Buffer stream for PCM16 playback (SoundSource type)
  SoundHandle? _streamHandle; // Handle for the playing stream
  
  // flutter_recorder package for audio recording
  final Recorder _recorder = Recorder.instance;
  
  StreamSubscription<AudioDataContainer>? _audioInputSubscription;
  bool _isStreamingData = false;

  // Permission handler
  final PermissionHandler _permissionHandler = PermissionHandler();

  // Event stream for UI events
  final StreamController<UIEvent> _uiEventController =
      StreamController<UIEvent>.broadcast();

  Stream<UIEvent> get uiEvents => _uiEventController.stream;

  StreamSubscription<UIEvent>? _uiEventSubscription;
  Function(UIEvent)? _uiEventHandler;

  void _emitEvent(UIEvent event) {
    _uiEventController.add(event);
  }

  void setUIEventHandler(Function(UIEvent) handler) {
    _uiEventHandler = handler;
    // Cancel existing subscription if any
    _uiEventSubscription?.cancel();
    // Create new subscription
    _uiEventSubscription = uiEvents.listen((event) {
      if (_uiEventHandler != null) {
        _uiEventHandler!(event);
      }
    });
  }

  AudioProvider() {
    _webSocketManager = WebSocketManager(url: _wsUrl);
    _webSocketManager.onDataReceived = _handleWebSocketData;
    _webSocketManager.onStatusChanged = (message) => setStatusMessage = message;
    _webSocketManager.onError = (error) {
      setIsConnected = false;
      stopStreamingAudio();
    };
    _webSocketManager.onDisconnected = () {
      setIsConnected = false;
      stopStreamingAudio();
    };
  }

  bool _isRecording = false;

  bool get getIsRecording => _isRecording;

  set setIsRecording(bool value) {
    debugPrint('🔄 setIsRecording called with value: $value (current: $_isRecording)');
    if (_isRecording != value) {
      _isRecording = value;
      debugPrint('✅ _isRecording updated to: $_isRecording');
      notifyListeners();
      debugPrint('✅ notifyListeners() called');
    } else {
      debugPrint('⚠️ _isRecording already $value, skipping update');
    }
  }

  bool get getIsConnected => _webSocketManager.isConnected;

  set setIsConnected(bool value) {
    // This setter is kept for compatibility but the actual state is managed by WebSocketManager
    notifyListeners();
  }

  String _statusMessage = 'Ready';

  String get getStatusMessage => _statusMessage;

  set setStatusMessage(String value) {
    _statusMessage = value;
    notifyListeners();
  }

  String _streamedResponse = '';

  String get getStreamedResponse => _streamedResponse;

  void _appendStreamedResponse(String text) {
    _streamedResponse += text;
    notifyListeners();
  }

  void _clearStreamedResponse() {
    _streamedResponse = '';
    notifyListeners();
  }

  final String _sessionId = 'ue5_session_2D529EFA';
  static const int _sampleRate = 16000; // WebSocket expects 16kHz

  Future<void> initializeApp() async {
    try {
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
      notifyListeners();
    } catch (e) {
      setStatusMessage = 'Initialization failed: $e';
      _emitEvent(ErrorEvent(message: 'Initialization failed: $e'));
    }
  }

  Future<void> _initializeAudio() async {
    // Initialize SoLoud for audio playback
    try {
      if (!_soloudInitialized) {
        await _soloud.init();
        _soloudInitialized = true;
        debugPrint('✅ SoLoud initialized successfully');
        
        // Set up buffer stream for PCM16 playback (no WAV conversion needed!)
        _bufferStream = await _soloud.setBufferStream(
          maxBufferSizeBytes: 1024 * 1024 * 10, // 10MB max buffer
          bufferingType: BufferingType.preserved,
          bufferingTimeNeeds: 0.1, // 100ms buffer for real-time playback
          sampleRate: _sampleRate,
          channels: Channels.mono,
          format: BufferType.s16le, // Signed 16-bit PCM little endian
        );
        debugPrint('✅ Buffer stream initialized for PCM16 playback');
      }
    } catch (e) {
      debugPrint('❌ Error initializing SoLoud: $e');
    }
    
    // Initialize flutter_recorder
    try {
      _recorder.init(
        format: PCMFormat.s16le, // 16-bit PCM format
        sampleRate: _sampleRate,
        channels: RecorderChannels.mono, // Mono
      );
      debugPrint('✅ Recorder initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Recorder: $e');
    }
  }

  List<AiChatMessages> get getMessages => _messages;

  void addMessage(AiChatMessages message) {
    _messages.add(message);
    notifyListeners();
  }

  void _handleWebSocketData(dynamic data) {
    if (data == null) return;
    if (data.isEmpty) return;

    if (data is String) {
      try {
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
          if (_screenType == 'message') {
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
              _handelInteruptAcknowledged();
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
              if (!_isAnimationPlaying) {
                _isAnimationPlaying = true;
                // Defer notifyListeners to avoid blocking audio processing
                Future.microtask(() => notifyListeners());
              }
            }
            else if (type == "tts_complete") {
              debugPrint('✅ [WebSocket] Handling: tts_complete');
              if ( _isAnimationPlaying) {
               // _isAnimationPlaying = false;
                notifyListeners();
              }
            }
          }
        }
      } catch (e) {
        debugPrint('❌ [WebSocket Error] Error parsing WebSocket message: $e');
        debugPrint('❌ [WebSocket Error] Raw data: $data');
      }
    } else {
      debugPrint(
        '⚠️ [WebSocket] Received non-string data: ${data.runtimeType}',
      );
    }
  }

  // Audio processing for playback using flutter_soloud
  // Note: We play only the latest audio, not queued chunks

  void _handelAudioPcmReady(Map<String, dynamic> jsonData) {
    final pcmDataBase64 = jsonData['pcm_data'] as String?;

    if (pcmDataBase64 != null && pcmDataBase64.isNotEmpty) {
      // Stop current playback and clear old audio when new audio arrives

      // Decode in isolate to prevent blocking main thread
      compute(_decodeBase64Audio, pcmDataBase64).then((pcmData) {
        if (pcmData != null) {
          // Play only the latest audio chunk (don't queue old chunks)
          _playPcmChunk(pcmData);
        }
      }).catchError((e) {
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
    try {
      // Dispose old buffer stream
      if (_bufferStream != null) {
        await _soloud.disposeSource(_bufferStream!);
        _bufferStream = null;
      }
      
      // Create a new buffer stream
      _bufferStream = await _soloud.setBufferStream(
        maxBufferSizeBytes: 1024 * 1024 * 10, // 10MB max buffer
        bufferingType: BufferingType.preserved,
        bufferingTimeNeeds: 0.1, // 100ms buffer for real-time playback
        sampleRate: _sampleRate,
        channels: Channels.mono,
        format: BufferType.s16le, // Signed 16-bit PCM little endian
      );
      debugPrint('🔄 Reset buffer stream for new audio');
    } catch (e) {
      debugPrint('Error resetting buffer stream: $e');
    }
  }


  Future<void> _playPcmChunk(Uint8List pcmData) async {
    try {
      // Play PCM16 data directly using buffer stream (no WAV conversion needed!)
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
      
      debugPrint('📢 Added PCM16 chunk to stream (${pcmData.length} bytes)');
    } catch (e) {
      debugPrint('Error playing PCM chunk: $e');
    }
  }

  // Static function for isolate processing
  static Uint8List? _decodeBase64Audio(String base64Data) {
    try {
      return base64Decode(base64Data);
    } catch (e) {
      return null;
    }
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
    addMessage(AiChatMessages(role: 'ai', content: jsonData['full_response']));
  }

  void _handelSessionStarted(Map<String, dynamic> jsonData) {
    // Handle session_started message
    // This typically indicates the WebSocket session is ready
    debugPrint('✅ [WebSocket] Session started: ${jsonData.toString()}');
    setStatusMessage = 'Session started - Ready to stream';
  }

  void _handelInteruptAcknowledged() {
    // Stop recording
    _recorder.stopStreamingData();
    _isStreamingData = false;
    _audioInputSubscription?.cancel();
    _audioInputSubscription = null;
    
    // Stop playback
    if (_streamHandle != null) {
      _soloud.stop(_streamHandle!);
      _streamHandle = null;
    }
    
    _stopTalkingAnimation();
    setStatusMessage = 'Audio stream interrupted';
  }

  void _stopTalkingAnimation() {
    if (_isAnimationPlaying) {
      _isAnimationPlaying = false;
      notifyListeners();
    }
  }

  Future<void> startStreamingAudio() async {
    _stopCurrentPlayback();
    debugPrint('🎤 startStreamingAudio called');
    
    if (!_webSocketManager.isConnected) {
      debugPrint('❌ WebSocket not connected');
      setStatusMessage = 'Not connected to WebSocket';
      return;
    }

    if (_isRecording) {
      debugPrint('⚠️ Already recording, ignoring start request');
      return;
    }

    try {
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
        sessionId: _sessionId,
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
        _isStreamingData = true;
        debugPrint('✅ Audio streaming started');
        
        // Set recording state immediately after starting
        setIsRecording = true;
        debugPrint('✅ Recording state set to true, _isRecording = $_isRecording');
        
        // Listen to audio stream and send to WebSocket
        _audioInputSubscription = _recorder.uint8ListStream.listen(
          (audioDataContainer) {
            if (!_isRecording) {
              debugPrint('⚠️ Received audio data but _isRecording is false');
              return;
            }
            
            // Get raw PCM16 data from the container
            // The data is already in the format specified during init (s16le)
            final audioData = audioDataContainer.rawData;
            
            // Send audio data to WebSocket
            final msgEvent = AudioMessageModel(
              sessionId: _sessionId,
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
            if (_isRecording) {
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
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error in startStreamingAudio: $e');
      debugPrint('Stack trace: $stackTrace');
      setStatusMessage = 'Failed to start: $e';
      await stopStreamingAudio();
    }
  }


  Future<void> stopStreamingAudio() async {
    if (!_isRecording) return;

    try {
      final endChatEvent = AudioEndMessageModel(sessionId: _sessionId);
      final jsonString = jsonEncode(endChatEvent.toJson());
      _webSocketManager.send(jsonString);
      
      // Stop recording
      if (_isStreamingData) {
        _recorder.stopStreamingData();
        _isStreamingData = false;
      }
      await _audioInputSubscription?.cancel();
      _audioInputSubscription = null;
      
      // Stop any ongoing playback
      if (_streamHandle != null) {
        await _soloud.stop(_streamHandle!);
        _streamHandle = null;
      }
      
      _stopTalkingAnimation();
      setIsRecording = false;
      setStatusMessage = 'Recording stopped';
    } catch (e) {
      debugPrint('Error stopping audio: $e');
      setStatusMessage = 'Error stopping: $e';
    }
  }

  Future<void> interruptStreamingAudio() async {
    try {
      // Stop recording
      if (_isStreamingData) {
        _recorder.stopStreamingData();
        _isStreamingData = false;
      }
      await _audioInputSubscription?.cancel();
      _audioInputSubscription = null;
      
      // Stop playback
      if (_streamHandle != null) {
        await _soloud.stop(_streamHandle!);
        _streamHandle = null;
      }
      
      // Clear audio queue when interrupting
      _stopTalkingAnimation();
      final interuptEvent = InteruptEventModel(sessionId: _sessionId);
      final jsonString = jsonEncode(interuptEvent.toJson());
      _webSocketManager.send(jsonString);
      setStatusMessage = 'Recording interrupted';
    } catch (e) {
      debugPrint('Error stopping audio: $e');
      setStatusMessage = 'Error stopping: $e';
    }
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
    notifyListeners();
  }

  Future<void> disconnectWebSocket() async {
    await _webSocketManager.disconnect();
    setIsRecording = false;
    notifyListeners();
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
}
