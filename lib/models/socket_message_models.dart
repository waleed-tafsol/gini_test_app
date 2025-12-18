import 'dart:convert';
import 'dart:typed_data';

class AudioMessageModel {
  final String type;
  final String sessionId;
  final Uint8List audio;
  final int sampleRate;
  final int channels;
  final String format;

  AudioMessageModel({
    this.type = "audio",
    required this.sessionId,
    required this.audio,
    this.sampleRate = 16000,
    this.channels = 1,
    this.format = "pcm16",
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'session_id': sessionId,
      'data': base64Encode(audio),
      'sample_rate': sampleRate,
      'channels': channels,
      'format': format,
    };
  }
}

class StartAudioMessageModel {
  final String type;
  final String sessionId;
  final int sampleRate;
  final int channels;
  final int chunkDurationSeconds;
  final String audioFormat;

  StartAudioMessageModel({
    this.type = "start",
    required this.sessionId,
    this.sampleRate = 16000,
    this.channels = 1,
    this.chunkDurationSeconds = 0,
    this.audioFormat = "pcm16",
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'session_id': sessionId,
      'sample_rate': sampleRate,
      'channels': channels,
      'chunk_duration_seconds': chunkDurationSeconds,
      'audio_format': audioFormat,
    };
  }
}

class AudioEndMessageModel {
  final String type;
  final String sessionId;

  AudioEndMessageModel({this.type = "end", required this.sessionId});

  Map<String, dynamic> toJson() {
    return {'type': type, 'session_id': sessionId};
  }
}

class InterruptEventModel {
  final String type;
  final String sessionId;
  final String timestamp = DateTime.now().toIso8601String();

  InterruptEventModel({this.type = "interrupt", required this.sessionId});

  Map<String, dynamic> toJson() {
    return {'type': type, 'session_id': sessionId, 'timestamp': timestamp};
  }
}

class SessionGeneratorModel {
  final String type;

  SessionGeneratorModel({ required this.type});

  Map<String, dynamic> toJson() {
    return {'type': type};
  }
}
