import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

  /// SHA-256 fingerprint of the Android signing certificate, or the app's
  /// package name — whichever value was registered in the portal under
  /// "Allowed Android Packages". Use [NovaConfig.autoDetect] to populate this
  /// automatically from [PackageInfo.packageName].
  final String? androidSha256Hash;

  /// The iOS bundle identifier (e.g. `com.example.myapp`). Use
  /// [NovaConfig.autoDetect] to populate this automatically from
  /// [PackageInfo.packageName].
  final String? iosBundleIdentifier;

  const NovaConfig({
    this.apiKey,
    this.tokenResolver,
    this.baseUrl = 'http://10.0.2.2:8000',
    this.origin,
    this.androidSha256Hash,
    this.iosBundleIdentifier,
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

  /// Creates a [NovaConfig] with platform identifiers auto-detected via
  /// [PackageInfo.fromPlatform()]:
  ///
  /// - **iOS** → sets [iosBundleIdentifier] from [PackageInfo.packageName]
  /// - **Android** → sets [androidSha256Hash] from [PackageInfo.packageName]
  ///
  /// Explicit [iosBundleIdentifier] / [androidSha256Hash] arguments take
  /// precedence over the auto-detected value when provided.
  static Future<NovaConfig> autoDetect({
    String? apiKey,
    NovaTokenResolver? tokenResolver,
    String baseUrl = 'http://10.0.2.2:8000',
    String? origin,
    String? androidSha256Hash,
    String? iosBundleIdentifier,
    NovaLogLevel? logLevel,
    Duration timeout = const Duration(seconds: 15),
    String? theme = 'indigo',
    String? primaryColor,
    String? secondaryColor,
    String? agentName,
    String? greetingMessage,
    List<String>? suggestedMessages,
    bool allowEmojis = true,
  }) async {
    assert(
      apiKey != null || tokenResolver != null,
      'Either apiKey or tokenResolver must be provided to NovaConfig.autoDetect.',
    );

    final info = await PackageInfo.fromPlatform();
    final packageName = info.packageName.trim();
    final detectedSignature = info.buildSignature.trim();
    final detectedAndroid =
        detectedSignature.isNotEmpty ? detectedSignature : packageName;

    return NovaConfig(
      apiKey: apiKey,
      tokenResolver: tokenResolver,
      baseUrl: baseUrl,
      origin: origin,
      androidSha256Hash: androidSha256Hash ??
          (defaultTargetPlatform == TargetPlatform.android &&
                  detectedAndroid.isNotEmpty
              ? detectedAndroid
              : null),
      iosBundleIdentifier: iosBundleIdentifier ??
          (defaultTargetPlatform == TargetPlatform.iOS && packageName.isNotEmpty
              ? packageName
              : null),
      logLevel:
          logLevel ?? (kReleaseMode ? NovaLogLevel.none : NovaLogLevel.error),
      timeout: timeout,
      theme: theme,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      agentName: agentName,
      greetingMessage: greetingMessage,
      suggestedMessages: suggestedMessages,
      allowEmojis: allowEmojis,
    );
  }

  /// Normalizes a 64-hex-character SHA-256 fingerprint by stripping colons,
  /// spaces, and dashes and converting to uppercase. Non-hash values (such as
  /// package names) are returned trimmed as-is.
  static String? normalizeSha256(String? value) {
    if (value == null) return null;
    final clean = value.replaceAll(RegExp(r'[^a-fA-F0-9]'), '').toUpperCase();
    return clean.length == 64 ? clean : value.trim();
  }

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
      return {
        'type': 'android_sha256_hash',
        'value': normalizeSha256(androidSha256Hash) ?? androidSha256Hash!.trim(),
      };
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        iosBundleIdentifier != null &&
        iosBundleIdentifier!.trim().isNotEmpty) {
      return {
        'type': 'ios_bundle_identifier',
        'value': iosBundleIdentifier!.trim(),
      };
    }
    if (androidSha256Hash != null && androidSha256Hash!.trim().isNotEmpty) {
      return {
        'type': 'android_sha256_hash',
        'value': normalizeSha256(androidSha256Hash) ?? androidSha256Hash!.trim(),
      };
    }
    if (iosBundleIdentifier != null && iosBundleIdentifier!.trim().isNotEmpty) {
      return {
        'type': 'ios_bundle_identifier',
        'value': iosBundleIdentifier!.trim(),
      };
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
