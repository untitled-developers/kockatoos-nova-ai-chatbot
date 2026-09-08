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
  final String? origin;

  const NovaConfig({
    this.apiKey,
    this.tokenResolver,
    this.baseUrl = 'http://10.0.2.2:8000',
    this.origin,
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

  String? get resolvedOrigin {
    if (origin != null && origin!.trim().isNotEmpty) {
      return origin!.trim();
    }
    try {
      final uri = Uri.parse(baseUrl);
      if (uri.hasScheme && uri.hasAuthority) {
        return uri.origin;
      }
    } catch (_) {}
    return null;
  }
}
