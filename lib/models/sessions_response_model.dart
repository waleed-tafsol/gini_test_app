class Session {
  final String sessionId;
  final String name;
  final String createdAt;
  final int clientCount;
  final String state;
  final String createdBy;

  Session({
    required this.sessionId,
    required this.name,
    required this.createdAt,
    required this.clientCount,
    required this.state,
    required this.createdBy,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      sessionId: json['session_id'] as String,
      name: json['name'] as String,
      createdAt: json['created_at'] as String,
      clientCount: json['client_count'] as int,
      state: json['state'] as String,
      createdBy: json['created_by'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'name': name,
      'created_at': createdAt,
      'client_count': clientCount,
      'state': state,
      'created_by': createdBy,
    };
  }
}

class SessionsResponse {
  final List<Session> sessions;
  final int totalCount;
  final String timestamp;

  SessionsResponse({
    required this.sessions,
    required this.totalCount,
    required this.timestamp,
  });

  factory SessionsResponse.fromJson(Map<String, dynamic> json) {
    return SessionsResponse(
      sessions: (json['sessions'] as List<dynamic>)
          .map((session) => Session.fromJson(session as Map<String, dynamic>))
          .toList(),
      totalCount: json['total_count'] as int,
      timestamp: json['timestamp'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessions': sessions.map((session) => session.toJson()).toList(),
      'total_count': totalCount,
      'timestamp': timestamp,
    };
  }
}





