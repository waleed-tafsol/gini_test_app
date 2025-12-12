import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:gini_test_app/models/ai_chat_messages.dart';
import 'package:sound_stream/sound_stream.dart';

import 'permission_handler.dart';
import 'ui_event.dart';
import 'websocket_manager.dart';

class AudioProvider extends ChangeNotifier {
  final String _wsUrl = 'wss://9e1459dc03e5.ngrok-free.app/ws';
  late final WebSocketManager _webSocketManager;

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

  void _emitEvent(UIEvent event) {
    _uiEventController.add(event);
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

  String? _sessionId;
  static const int _sampleRate = 16000;

  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  void play() {
    _isPlaying = true;
    notifyListeners();
  }

  void pause() {
    _isPlaying = false;
    notifyListeners();
  }

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
    if (data is Uint8List) {
      try {
        _player.writeChunk(data);
      } catch (e) {
        print('Error writing to player: $e');
      }
    } else if (data is String) {
      try {
        // Parse JSON response
        final jsonData = jsonDecode(data) as Map<String, dynamic>;
        final type = jsonData['type'] as String?;

        if (type == 'audio_pcm_ready') {
          // Extract pcm_data from the response
          final pcmDataBase64 = jsonData['pcm_data'] as String?;
          
          if (pcmDataBase64 != null && pcmDataBase64.isNotEmpty) {
            // Decode base64 to Uint8List
            final pcmData = base64Decode(pcmDataBase64);
            
            // Write to player
            _player.start();
            _player.writeChunk(pcmData);
            // Optionally log chunk info
            final chunkIdx = jsonData['chunk_idx'];
            final text = jsonData['text'] as String?;
            if (text != null && text.isNotEmpty) {
              print('Received audio chunk $chunkIdx with text: $text');
            } else {
              print('Received audio chunk $chunkIdx');
            }
          }
        } else {
          // Handle other message types
          print('Server message: $data');
        }
        if(type == "final_transcript"){
          addMessage(AiChatMessages(role: 'user', content: jsonData['text']));
        }
        if(type == "tts_complete"){
          _player.stop();
          addMessage(AiChatMessages(role: 'ai', content: jsonData['full_response']));
        }
        if(type == "streamed_response"){
          final response = jsonData['response'] as String?;
          if (response != null && response.isNotEmpty) {
            _appendStreamedResponse(response);
          }
        }
      } catch (e) {
        print('Error parsing WebSocket message: $e');
        print('Raw data: $data');
      }
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
      
      // Clear previous streamed response for new session
      _clearStreamedResponse();

      // Generate a new session ID for this streaming session
      //TODO: persist session id for reconnection
      _sessionId = 'ue5_session_2D529EFA';

      final jsonPayload = {
        'type': 'start',
        'session_id': _sessionId,
        'sample_rate': _sampleRate,
        'channels':1,
        'chunk_duration_seconds':0,
        'audio_format': 'pcm16',
      };

      // Convert to JSON string and send
      final jsonString = jsonEncode(jsonPayload);
      _webSocketManager.send(jsonString);

      // Start recorder
      await _recorder.start();

      // Subscribe to audio stream and send to WebSocket
      _audioStreamSubscription = _recorder.audioStream.listen(
            (audioChunk) {
          // Convert audio chunk to base64
          final base64Audio = base64Encode(audioChunk);

          // Create JSON payload
          final jsonPayload = {
            'type': 'audio',
            'session_id': _sessionId,
            'data': base64Audio,
            'sample_rate': _sampleRate,
            'channels':1,
            'format': 'pcm16',
          };

          // Convert to JSON string and send
          final jsonString = jsonEncode(jsonPayload);
          _webSocketManager.send(jsonString);
        },
        onError: (error) {
          print('Audio stream error: $error');
          stopStreamingAudio();
        },
      );

      // Start player
      await _player.start();

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
      final jsonPayload = {
        'type': 'end',
        'session_id': _sessionId,
      };

      // Convert to JSON string and send
      final jsonString = jsonEncode(jsonPayload);
      _webSocketManager.send(jsonString);
      // Stop recorder
      await _recorder.stop();

      // Cancel audio stream subscription
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      // Stop player
      await _player.stop();

      // Clear session ID
     // _sessionId = null;

      setIsRecording = false;
      setStatusMessage = 'Recording stopped';
    } catch (e) {
      print('Error stopping audio: $e');
      setStatusMessage = 'Error stopping: $e';
    }
  }

  Future<void> interruptStreamingAudio() async {
    try {
       _player.stop();

      final jsonPayload = {
        'type': 'interrupt',
        'session_id': _sessionId,
      };
      // Convert to JSON string and send
      final jsonString = jsonEncode(jsonPayload);
      _webSocketManager.send(jsonString);
      // Stop recorder

      // Cancel audio stream subscription


      // Stop player

      // Clear session ID
      // _sessionId = null;

      setStatusMessage = 'Recording interrupted';
    } catch (e) {
      print('Error stopping audio: $e');
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
    _webSocketManager.dispose();
    _recorder.dispose();
    _player.dispose();
    _uiEventController.close();
  }
}
