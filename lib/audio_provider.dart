import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:gini_test_app/models/ai_chat_messages.dart';
import 'package:gini_test_app/models/socket_message_models.dart';
import 'package:sound_stream/sound_stream.dart';
import 'permission_handler.dart';
import 'ui_event.dart';
import 'websocket_manager.dart';

class AudioProvider extends ChangeNotifier {
  final String _wsUrl = 'wss://9e1459dc03e5.ngrok-free.app/ws';
  late final WebSocketManager _webSocketManager;

   String _screenType = 'message';

  void setScreenType(String type) {
    _screenType = type;
    notifyListeners();
  }

  Flutter3DController _humanModelController = Flutter3DController();

  Flutter3DController get getHumanModelController => _humanModelController;

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
    if (data == null) return;
    if (data.isEmpty) return;

    if (data is String) {
      try {
        final jsonData = jsonDecode(data) as Map<String, dynamic>;
        final type = jsonData['type'] as String?;
        if (type == null) {
          return;
        }
        else {
          if (_screenType == 'message') {
           if (type == "interrupt_acknowledged") {
            _handelInteruptAcknowledged();
          } else if (type == "final_transcript") {
            _handelFinalTranscript(jsonData);
          } else if (type == "tts_complete") {
            _handelTTSComplete();
          } else if (type == "streamed_response") {
            _handelStreamedResponse(jsonData);
          }
          }
          else if (type == 'audio_pcm_ready') {
            _handelAudioPcmReady(jsonData);
            if(_screenType == 'human_model'){
                _humanModelController.playAnimation(
                  animationName: 'Rig|cycle_talking',
                  loopCount: 1,
                );

            }
          }
        };




      } catch (e) {
        print('Error parsing WebSocket message: $e');
        print('Raw data: $data');
      }
    }
  }

  void _handelAudioPcmReady(Map<String, dynamic> jsonData) {
    final pcmDataBase64 = jsonData['pcm_data'] as String?;

    if (pcmDataBase64 != null && pcmDataBase64.isNotEmpty) {
      final pcmData = base64Decode(pcmDataBase64);
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
  }

  void _handelStreamedResponse(Map<String, dynamic> jsonData) {
    final response = jsonData['response'] as String?;
    if (response != null && response.isNotEmpty) {
      _appendStreamedResponse(response);
    }
  }

  void _handelFinalTranscript(Map<String, dynamic> jsonData) {
    addMessage(AiChatMessages(role: 'user', content: jsonData['text']));
  }

  void _handelTTSComplete() {
    addMessage(AiChatMessages(role: 'ai', content: "Intrupted"));
  }

  void _handelInteruptAcknowledged() {
    _player.stop();
    setStatusMessage = 'Audio stream interrupted';
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
          print('Audio stream error: $error');
          stopStreamingAudio();
        },
      );
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
      final endChatEvent = AudioEndMessageModel(sessionId: _sessionId);
      final jsonString = jsonEncode(endChatEvent.toJson());
      _webSocketManager.send(jsonString);
      await _recorder.stop();
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      await _player.stop();
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
      final interuptEvent = InteruptEventModel(sessionId: _sessionId);
      final jsonString = jsonEncode(interuptEvent.toJson());
      _webSocketManager.send(jsonString);
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
    _uiEventSubscription?.cancel();
    _uiEventSubscription = null;
    _uiEventHandler = null;
    _webSocketManager.dispose();
    _recorder.dispose();
    _player.dispose();
    _uiEventController.close();
  }
}
