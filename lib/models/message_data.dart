import 'package:tafsol_genie_app/utils/string_utils.dart';

import '../utils/enums.dart';

class MessageData {
  final MessageType? type;
  final Map<String, dynamic> data;
  final String? timestamp;

  const MessageData({this.type, required this.data, this.timestamp});

  factory MessageData.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String?)?.toCamelCase();
    return MessageData(
      type: type != null ? MessageType.values.byName(type) : null,
      data: json..remove('type'),
      timestamp: json['timestamp'],
    );
  }
}
