import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketManager {
  final String url;
  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Callbacks
  Function(dynamic data)? onDataReceived;
  Function(String message)? onStatusChanged;
  Function(dynamic error)? onError;
  VoidCallback? onDisconnected;

  WebSocketManager({required this.url});

  Future<void> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _socketSubscription = _channel!.stream.listen(
        (data) {
          if (onDataReceived != null) {
            onDataReceived!(data);
          }
        },
        onError: (error) {
          _isConnected = false;
          if (onError != null) {
            onError!(error);
          }
          if (onStatusChanged != null) {
            onStatusChanged!('WebSocket error: $error');
          }
        },
        onDone: () {
          _isConnected = false;
          if (onDisconnected != null) {
            onDisconnected!();
          }
          if (onStatusChanged != null) {
            onStatusChanged!('WebSocket disconnected');
          }
        },
      );

      _isConnected = true;
      if (onStatusChanged != null) {
        onStatusChanged!('Connected to WebSocket');
      }
    } catch (e) {
      _isConnected = false;
      if (onStatusChanged != null) {
        onStatusChanged!('Failed to connect: $e');
      }
    }
  }

  void send(dynamic data) {
    if (_channel != null && _channel!.closeCode == null && _isConnected) {
      try {
        _channel!.sink.add(data);
      } catch (e) {
        print('Error sending data: $e');
        if (onError != null) {
          onError!(e);
        }
      }
    }
  }

  Future<void> disconnect() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;

    await _channel?.sink.close();
    _channel = null;

    _isConnected = false;
  }

  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }

  void dispose() {
    disconnect();
  }
}
