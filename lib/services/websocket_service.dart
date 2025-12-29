import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message_data.dart';

class WebSocketService {
  final String url;
  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Callbacks
  final ValueSetter<MessageData>? onDataReceived;
  final Function(String message)? onStatusChanged;
  final Function(dynamic error)? onError;
  final VoidCallback? onDisconnected;

  WebSocketService({
    required this.url,
    this.onDataReceived,
    this.onStatusChanged,
    this.onError,
    this.onDisconnected,
  });

  Future<void> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _socketSubscription = _channel!.stream.listen(
        (data) {
          // Log all received websocket data
          if (data is String) {
            try {
              final decoded = jsonDecode(data);
              developer.log(
                '📥 [WebSocket] Received JSON: ${jsonEncode(decoded)}',
                name: 'WebSocketService',
              );
              
              if (onDataReceived != null) {
                onDataReceived!(MessageData.fromJson(decoded));
              }
            } catch (e) {
              developer.log(
                '📥 [WebSocket] Received (raw): ${data.length > 500 ? data.substring(0, 500) + "..." : data}',
                name: 'WebSocketService',
              );
              
              if (onDataReceived != null && data.isNotEmpty) {
                try {
                  onDataReceived!(MessageData.fromJson(jsonDecode(data)));
                } catch (parseError) {
                  developer.log(
                    '❌ [WebSocket] Failed to parse message: $parseError',
                    name: 'WebSocketService',
                    error: parseError,
                  );
                }
              }
            }
          } else {
            developer.log(
              '📥 [WebSocket] Received binary data: ${data.runtimeType}, size: ${data is List ? data.length : "unknown"}',
              name: 'WebSocketService',
            );
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
        // Log all sent websocket data
        if (data is String) {
          try {
            final decoded = jsonDecode(data);
            developer.log(
              '📤 [WebSocket] Sending JSON: ${jsonEncode(decoded)}',
              name: 'WebSocketService',
            );
          } catch (e) {
            developer.log(
              '📤 [WebSocket] Sending (raw): ${data.length > 500 ? data.substring(0, 500) + "..." : data}',
              name: 'WebSocketService',
            );
          }
        } else {
          developer.log(
            '📤 [WebSocket] Sending binary data: ${data.runtimeType}',
            name: 'WebSocketService',
          );
        }

        _channel!.sink.add(data);
      } catch (e) {
        developer.log(
          '❌ [WebSocket] Error sending data: $e',
          name: 'WebSocketService',
          error: e,
        );
        if (onError != null) {
          onError!(e);
        }
      }
    } else {
      developer.log(
        '⚠️ [WebSocket] Cannot send: channel=${_channel != null}, connected=$_isConnected',
        name: 'WebSocketService',
      );
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
