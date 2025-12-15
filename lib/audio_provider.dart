import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:gini_test_app/models/ai_chat_messages.dart';
import 'package:gini_test_app/models/socket_message_models.dart';
import 'package:sound_stream/sound_stream.dart';
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

  // sound_stream instances
  final RecorderStream _recorder = RecorderStream();

  final PlayerStream _player = PlayerStream();

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
    _isRecording = value;
    notifyListeners();
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

  late StreamSubscription<Uint8List>? _audioStreamSubscription;

  final String _sessionId = 'ue5_session_2D529EFA';
  static const int _sampleRate = 16000;

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
    await _recorder.initialize();
    await _player.initialize();
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
            }
            if (type == "interrupt_acknowledged") {
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
              if (_screenType == 'human_model' && !_isAnimationPlaying) {
                _isAnimationPlaying = true;
                // Defer notifyListeners to avoid blocking audio processing
                Future.microtask(() => notifyListeners());
              }
            } else if (type == "tts_complete") {
              debugPrint('✅ [WebSocket] Handling: tts_complete');
              if (_screenType == 'human_model' && _isAnimationPlaying) {
                _isAnimationPlaying = false;
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

  bool _playerStarted = false;
  
  // Audio processing queue to prevent UI blocking
  final List<Uint8List> _audioChunkQueue = [];
  bool _isProcessingAudioQueue = false;
  static const int _maxQueueSize = 50; // Prevent memory issues

  void _handelAudioPcmReady(Map<String, dynamic> jsonData) {
    final pcmDataBase64 = jsonData['pcm_data'] as String?;

    if (pcmDataBase64 != null && pcmDataBase64.isNotEmpty) {
      // Decode in isolate to prevent blocking main thread
      compute(_decodeBase64Audio, pcmDataBase64).then((pcmData) {
        if (pcmData != null) {
          // Add to queue instead of writing directly
          _enqueueAudioChunk(pcmData);
        }
      }).catchError((e) {
        debugPrint('Error processing audio chunk: $e');
      });
    }
  }

  void _enqueueAudioChunk(Uint8List pcmData) {
    // Prevent queue from growing too large
    if (_audioChunkQueue.length >= _maxQueueSize) {
      debugPrint('⚠️ Audio queue full, dropping chunk');
      return;
    }

    _audioChunkQueue.add(pcmData);
    
    // Start processing queue if not already processing
    if (!_isProcessingAudioQueue) {
      _processAudioQueue();
    }
  }

  void _processAudioQueue() {
    if (_audioChunkQueue.isEmpty) {
      _isProcessingAudioQueue = false;
      return;
    }

    _isProcessingAudioQueue = true;

    // Process chunks asynchronously using scheduleMicrotask
    // This allows UI to remain responsive between chunks
    scheduleMicrotask(() {
      if (_audioChunkQueue.isEmpty) {
        _isProcessingAudioQueue = false;
        return;
      }

      try {
        // Start player only once
        if (!_playerStarted) {
          _player.start();
          _playerStarted = true;
        }

        // Process one chunk at a time
        final chunk = _audioChunkQueue.removeAt(0);
        _player.writeChunk(chunk);

        // Continue processing queue asynchronously
        // This prevents blocking the main thread
        Future.microtask(() => _processAudioQueue());
      } catch (e) {
        debugPrint('Error writing audio chunk: $e');
        _isProcessingAudioQueue = false;
      }
    });
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

  void _handelInteruptAcknowledged() {
    _player.stop();
    _playerStarted = false;
    // Clear audio queue when interrupted
    _audioChunkQueue.clear();
    _isProcessingAudioQueue = false;
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
    if (!_webSocketManager.isConnected) {
      setStatusMessage = 'Not connected to WebSocket';
      return;
    }

    if (_isRecording) return;

    try {
      setStatusMessage = 'Starting audio stream...';
      _clearStreamedResponse();
      final startEvent = StartAudioMessageModel(
        sessionId: _sessionId,
        sampleRate: _sampleRate,
      );
      final jsonString = jsonEncode(startEvent.toJson());
      _webSocketManager.send(jsonString);
      await _recorder.start();
      _audioStreamSubscription = _recorder.audioStream.listen(
        (audioChunk) {
          final msgEvent = AudioMessageModel(
            sessionId: _sessionId,
            audio: audioChunk,
            sampleRate: _sampleRate,
          );
          final jsonString = jsonEncode(msgEvent.toJson());
          _webSocketManager.send(jsonString);
        },
        onError: (error) {
          debugPrint('Audio stream error: $error');
          stopStreamingAudio();
        },
      );
      await _player.start();
      _playerStarted = true;
      setIsRecording = true;
      setStatusMessage = 'Recording and streaming...';
    } catch (e) {
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
      await _recorder.stop();
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      await _player.stop();
      _playerStarted = false;
      // Clear audio queue when stopping
      _audioChunkQueue.clear();
      _isProcessingAudioQueue = false;
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
      _player.stop();
      _playerStarted = false;
      // Clear audio queue when interrupting
      _audioChunkQueue.clear();
      _isProcessingAudioQueue = false;
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
    _webSocketManager.dispose();
    _recorder.dispose();
    _player.dispose();
    _uiEventController.close();
  }
}
