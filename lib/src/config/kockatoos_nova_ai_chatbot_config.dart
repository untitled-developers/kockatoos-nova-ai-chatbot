import 'package:flutter/foundation.dart';

typedef NovaTokenResolver = Future<String> Function();

enum NovaLogLevel { none, error, debug }

@immutable
class NovaConfig {
  final String? apiKey;
  final NovaTokenResolver? tokenResolver;
  final String baseUrl;
  final NovaLogLevel logLevel;
  final Duration timeout;
  final String? theme;
  final String? primaryColor;
  final String? secondaryColor;
  final String? agentName;
  final String? greetingMessage;
  final List<String>? suggestedMessages;
  final bool allowEmojis;

  const NovaConfig({
    this.apiKey,
    this.tokenResolver,
    this.baseUrl = 'https://api.kockatoos.com/v1',
    this.logLevel = kReleaseMode ? NovaLogLevel.none : NovaLogLevel.error,
    this.timeout = const Duration(seconds: 15),
    this.theme = 'indigo',
    this.primaryColor,
    this.secondaryColor,
    this.agentName,
    this.greetingMessage,
    this.suggestedMessages,
    this.allowEmojis = true,
  }) : assert(
          apiKey != null || tokenResolver != null,
          'Either apiKey or tokenResolver must be provided to NovaConfig.',
        );

  Future<String> getAuthToken() async {
    if (tokenResolver != null) {
      return await tokenResolver!();
    }
    return apiKey!;
  }
}
