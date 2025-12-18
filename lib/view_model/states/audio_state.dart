import '../../models/ai_chat_messages.dart';
import '../../utils/enums.dart';

class AudioState {
  final ScreenType type;
  final bool isAnimationPlaying;
  final List<AiChatMessages> messages;
  final bool isStreamingData;
  final bool isRecording;
  final String statusMessage;
  final String? streamedResponse;

  final String sessionId;

  const AudioState({
    this.type = ScreenType.message,
    this.isAnimationPlaying = false,
    this.messages = const [],
    this.isStreamingData = false,
    this.isRecording = false,
    this.statusMessage = 'Ready',
    this.streamedResponse,
    this.sessionId = ''
  });

  AudioState copyWith({
    ScreenType? type,
    bool? isAnimationPlaying,
    List<AiChatMessages>? messages,
    bool? isStreamingData,
    bool? isRecording,
    String? statusMessage,
    String? streamedResponse,
    String? sessionId
  }) {
    return AudioState(
      type: type ?? this.type,
      isAnimationPlaying: isAnimationPlaying ?? this.isAnimationPlaying,
      messages: messages ?? this.messages,
      isStreamingData: isStreamingData ?? this.isStreamingData,
      isRecording: isRecording ?? this.isRecording,
      statusMessage: statusMessage ?? this.statusMessage,
      streamedResponse: streamedResponse ?? this.streamedResponse,
      sessionId: sessionId?? this.sessionId,
    );
  }
}