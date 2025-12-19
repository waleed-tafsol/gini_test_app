enum ScreenType { message, humanModel }

enum MessageType {
  sessionIdAcknowledged,
  audioPcmReady,
  sessionStarted,
  interruptAcknowledged,
  ttsComplete,
  streamedResponse,
  finalTranscript,
}
