import 'package:flutter/foundation.dart';

@immutable
class NovaWidgetConfig {
  final bool isEnabled;
  final String? agentName;
  final String? primaryColor;
  final String? secondaryColor;
  final String? profilePicUrl;
  final String? greetingMessage;
  final List<String> suggestedMessages;
  final bool allowEmojis;

  const NovaWidgetConfig({
    required this.isEnabled,
    this.agentName,
    this.primaryColor,
    this.secondaryColor,
    this.profilePicUrl,
    this.greetingMessage,
    this.suggestedMessages = const [],
    this.allowEmojis = true,
  });

  factory NovaWidgetConfig.fromJson(Map<String, dynamic> json) {
    List<String> suggested = [];
    if (json['suggested_messages'] is List) {
      suggested = (json['suggested_messages'] as List)
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }

    return NovaWidgetConfig(
      isEnabled: json['is_enabled'] ?? true,
      agentName: json['agent_name'] as String?,
      primaryColor: json['primary_color'] as String?,
      secondaryColor: json['secondary_color'] as String?,
      profilePicUrl: json['profile_pic_url'] as String?,
      greetingMessage: json['greeting_message'] as String?,
      suggestedMessages: suggested,
      allowEmojis: json['allow_emojis'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_enabled': isEnabled,
      'agent_name': agentName,
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'profile_pic_url': profilePicUrl,
      'greeting_message': greetingMessage,
      'suggested_messages': suggestedMessages,
      'allow_emojis': allowEmojis,
    };
  }
}
