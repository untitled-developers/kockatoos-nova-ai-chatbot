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
  final String? androidSha256Hash;
  final String? iosPackageName;

  const NovaConfig({
    this.apiKey,
    this.tokenResolver,
    this.baseUrl = 'http://10.0.2.2:8000',
    this.origin,
    this.androidSha256Hash,
    this.iosPackageName,
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

  Map<String, String>? get mobileOriginParams {
    if (defaultTargetPlatform == TargetPlatform.android &&
        androidSha256Hash != null &&
        androidSha256Hash!.trim().isNotEmpty) {
      return {'type': 'android', 'value': androidSha256Hash!.trim()};
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        iosPackageName != null &&
        iosPackageName!.trim().isNotEmpty) {
      return {'type': 'ios', 'value': iosPackageName!.trim()};
    }
    if (androidSha256Hash != null && androidSha256Hash!.trim().isNotEmpty) {
      return {'type': 'android', 'value': androidSha256Hash!.trim()};
    }
    if (iosPackageName != null && iosPackageName!.trim().isNotEmpty) {
      return {'type': 'ios', 'value': iosPackageName!.trim()};
    }
    return null;
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
