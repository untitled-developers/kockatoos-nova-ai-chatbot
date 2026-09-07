import 'package:flutter/foundation.dart';

enum NovaMessageSender { user, bot }

@immutable
class NovaChatMessage {
  final String id;
  final NovaMessageSender sender;
  final String text;
  final String timestamp;
  final List<String>? pills;
  final bool isStreaming;

  const NovaChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.pills,
    this.isStreaming = false,
  });

  NovaChatMessage copyWith({
    String? id,
    NovaMessageSender? sender,
    String? text,
    String? timestamp,
    List<String>? pills,
    bool? isStreaming,
  }) {
    return NovaChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      pills: pills ?? this.pills,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  factory NovaChatMessage.fromJson(Map<String, dynamic> json) {
    final senderStr = (json['sender'] ?? 'bot').toString().toLowerCase();
    List<String>? pillsList;
    if (json['pills'] is List) {
      pillsList = (json['pills'] as List).map((e) => e.toString()).toList();
    }

    return NovaChatMessage(
      id: json['id']?.toString() ?? 'msg-${DateTime.now().millisecondsSinceEpoch}',
      sender: senderStr == 'user' ? NovaMessageSender.user : NovaMessageSender.bot,
      text: json['text']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      pills: pillsList,
      isStreaming: json['isStreaming'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender == NovaMessageSender.user ? 'user' : 'bot',
      'text': text,
      'timestamp': timestamp,
      if (pills != null) 'pills': pills,
      'isStreaming': isStreaming,
    };
  }
}
