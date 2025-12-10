import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sound_stream/sound_stream.dart';
import 'permission_handler.dart';
import 'ui_event.dart';
import 'websocket_manager.dart';

class AudioProvider extends ChangeNotifier {
  final String _wsUrl = 'wss://4aba4e330cf3.ngrok-free.app/ws';
  late final WebSocketManager _webSocketManager;

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

  late StreamSubscription<Uint8List>? _audioStreamSubscription;

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

  Future<void> sendTestMessage() async {
    if (_webSocketManager.isConnected) {
      _webSocketManager.send({
        "type": "audio_data",

        "session_id": "uuid-string",

        "audio": "base64-encoded-pcm16-data",

        "sample_rate": 16000,
      });
    } else {
      setStatusMessage = 'WebSocket not connected';
    }
  }

  Future<void> _initializeAudio() async {
    await _recorder.initialize(sampleRate: 16000);
    await _player.initialize();
  }

  void _handleWebSocketData(dynamic data) {
    if (data is Uint8List) {
      try {
        _player.writeChunk(data);
      } catch (e) {
        if (kDebugMode) {
          print('Error writing to player: $e');
        }
      }
    } else if (data is String) {
      // Handle string messages from server
      if (kDebugMode) {
        print('Server message: $data');
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

      // Start recorder
      await _recorder.start();

      // Subscribe to audio stream and send to WebSocket
      _audioStreamSubscription = _recorder.audioStream.listen(
        (audioChunk) {
          _webSocketManager.send(audioChunk);
        },
        onError: (error) {
          if (kDebugMode) {
            print('Audio stream error: $error');
          }
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
      // Stop recorder
      await _recorder.stop();

      // Cancel audio stream subscription
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      // Stop player
      await _player.stop();

      setIsRecording = false;
      setStatusMessage = 'Recording stopped';
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping audio: $e');
      }
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
