import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class AudioProvider extends ChangeNotifier {
  final String _wsUrl = 'wss://echo.websocket.events';
  WebSocketChannel? _channel;

  // sound_stream instances
  final RecorderStream _recorder = RecorderStream();

  final PlayerStream _player = PlayerStream();

  bool _isRecording = false;

  bool get getIsRecording => _isRecording;

  set setIsRecording(bool value) {
    _isRecording = value;
    notifyListeners();
  }

  bool _isConnected = false;

  bool get getIsConnected => _isConnected;

  set setIsConnected(bool value) {
    _isConnected = value;
    notifyListeners();
  }

  String _statusMessage = 'Ready';

  String get getStatusMessage => _statusMessage;

  set setStatusMessage(String value) {
    _statusMessage = value;
    notifyListeners();
  }
  late StreamSubscription<Uint8List>? _audioStreamSubscription;
  StreamSubscription? _socketSubscription;

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
      await _requestPermissions();
      await _initializeAudio();
      await _connectWebSocket();
    } catch (e) {
      setStatusMessage = 'Initialization failed: $e';
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw Exception('Microphone permission denied');
    }
  }

  Future<void> _initializeAudio() async {
    await _recorder.initialize();
    await _player.initialize();
  }

  Future<void> _connectWebSocket() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      _socketSubscription = _channel!.stream.listen(
        _handleWebSocketData,
        onError: (error) {
          setIsConnected = false;
          setStatusMessage = 'WebSocket error: $error';
          stopStreamingAudio();
        },
        onDone: () {
          setIsConnected = false;
          setStatusMessage = 'WebSocket disconnected';
          stopStreamingAudio();
        },
      );

      setIsConnected = true;
      setStatusMessage = 'Connected to WebSocket';
    } catch (e) {
      setIsConnected = false;
      setStatusMessage = 'Failed to connect: $e';
    }
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
      // Handle string messages from server
      print('Server message: $data');
    }
  }

  Future<void> startStreamingAudio() async {
    if (!_isConnected) {
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
          if (_channel != null && _channel!.closeCode == null) {
            try {
              _channel!.sink.add(audioChunk);
            } catch (e) {
              print('Error sending audio chunk: $e');
            }
          }
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
      print('Error stopping audio: $e');
      setStatusMessage = 'Error stopping: $e';
    }
  }

  Future<void> reconnect() async {
    await stopStreamingAudio();
    await disconnectWebSocket();
    await _connectWebSocket();
  }

  Future<void> disconnectWebSocket() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;

    await _channel?.sink.close();
    _channel = null;

    setIsConnected = false;
    setIsRecording = false;
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    stopStreamingAudio();
    disconnectWebSocket();
    _recorder.dispose();
    _player.dispose();
  }
}
