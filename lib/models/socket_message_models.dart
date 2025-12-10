class AudioMessageModel {
  final String type;
  final String sessionId;
  final String audio;
  final int sampleRate;

  AudioMessageModel({
    this.type = "audio_data",
    required this.sessionId,
    required this.audio,
    this.sampleRate = 16000,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'session_id': sessionId,
      'audio': audio,
      'sample_rate': sampleRate,
    };
  }
}

class AudioEndMessageModel {
  final String type;
  final String sessionId;

  AudioEndMessageModel({this.type = "audio_end", required this.sessionId});

  Map<String, dynamic> toJson() {
    return {'type': type, 'session_id': sessionId};
  }
}
