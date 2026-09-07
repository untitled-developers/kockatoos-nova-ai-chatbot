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

  const NovaConfig({
    this.apiKey,
    this.tokenResolver,
    this.baseUrl = 'https://api.kockatoos.com/v1',
    this.logLevel = kReleaseMode ? NovaLogLevel.none : NovaLogLevel.error,
    this.timeout = const Duration(seconds: 15),
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
