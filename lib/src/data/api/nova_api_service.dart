import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/kockatoos_nova_ai_chatbot_config.dart';
import '../models/nova_chat_message.dart';
import '../models/nova_widget_config.dart';

class NovaApiService {
  final NovaConfig _config;
  final http.Client _client;

  NovaApiService({
    required NovaConfig config,
    http.Client? client,
  })  : _config = config,
        _client = client ?? http.Client();

  Map<String, String> _buildHeaders([Map<String, String>? base]) {
    final headers = <String, String>{...?base};
    final origin = _config.resolvedOrigin;
    if (origin != null && origin.isNotEmpty) {
      headers['Origin'] = origin;
    }
    return headers;
  }

  Uri _buildUri(String endpointPath, [Map<String, String>? queryParams]) {
    var base = _config.baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/v1')) {
      base = base.substring(0, base.length - 3);
      while (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }
    }
    if (base.endsWith('/api')) {
      base = base.substring(0, base.length - 4);
      while (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }
    }

    final cleanEndpoint = endpointPath.startsWith('/') ? endpointPath : '/$endpointPath';
    var urlString = '$base$cleanEndpoint';

    if (queryParams != null && queryParams.isNotEmpty) {
      final query = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      urlString += '?$query';
    }

    if (_config.logLevel == NovaLogLevel.debug) {
      debugPrint('[Nova SDK] API Request URL: $urlString');
    }

    return Uri.parse(urlString);
  }

  /// Fetches remote widget configuration using the public key.
  Future<NovaWidgetConfig> fetchConfig(String publicKey) async {
    final uri = _buildUri('/api/widget/config', {'key': publicKey});
    final response = await _client.get(uri, headers: _buildHeaders()).timeout(_config.timeout);

    if (_config.logLevel == NovaLogLevel.debug) {
      debugPrint('[Nova SDK] fetchConfig status: ${response.statusCode}, body: ${response.body}');
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch widget configuration (HTTP ${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return NovaWidgetConfig.fromJson(data);
  }

  /// Obtains a new visitor session token.
  Future<String> fetchSessionToken(String publicKey) async {
    final uri = _buildUri('/api/widget/session');
    final response = await _client
        .post(
          uri,
          headers: _buildHeaders({'Content-Type': 'application/json'}),
          body: jsonEncode({'key': publicKey}),
        )
        .timeout(_config.timeout);

    if (_config.logLevel == NovaLogLevel.debug) {
      debugPrint('[Nova SDK] fetchSessionToken status: ${response.statusCode}, body: ${response.body}');
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to create widget session (HTTP ${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Received empty visitor session token.');
    }
    return token;
  }

  /// Fetches existing chat history for the visitor session token.
  Future<List<NovaChatMessage>> fetchMessages(String token) async {
    final uri = _buildUri('/api/widget/messages');
    final response = await _client
        .post(
          uri,
          headers: _buildHeaders({
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          }),
          body: jsonEncode({'token': token}),
        )
        .timeout(_config.timeout);

    if (_config.logLevel == NovaLogLevel.debug) {
      debugPrint('[Nova SDK] fetchMessages status: ${response.statusCode}');
    }

    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawList = data['messages'];
    if (rawList is List) {
      return rawList.map((e) => NovaChatMessage.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Sends a message and streams SSE response deltas.
  Stream<String> sendMessageStream({
    required String token,
    required String message,
  }) async* {
    final uri = _buildUri('/api/widget/send');
    final request = http.Request('POST', uri);
    request.headers.addAll(_buildHeaders({
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    }));
    request.body = jsonEncode({
      'token': token,
      'message': message,
    });

    if (_config.logLevel == NovaLogLevel.debug) {
      debugPrint('[Nova SDK] Streaming message to $uri');
    }

    final response = await _client.send(request);

    if (response.statusCode == 401) {
      throw Exception('401_UNAUTHORIZED');
    }

    if (response.statusCode != 200) {
      throw Exception('Server error status (HTTP ${response.statusCode})');
    }

    final lines = response.stream
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty) continue;
      if (!line.startsWith('data: ')) continue;

      final payload = line.substring(6).trim();
      if (payload == '[DONE]') break;

      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        if (data['type'] == 'text_delta') {
          final delta = data['delta'] as String?;
          if (delta != null && delta.isNotEmpty) {
            yield delta;
          }
        }
      } catch (_) {
        // Continue processing subsequent lines if JSON parsing fails for a single line
      }
    }
  }

  /// Closes the visitor conversation session.
  Future<bool> closeConversation(String token) async {
    try {
      final uri = _buildUri('/api/widget/conversations/close');
      final response = await _client
          .post(
            uri,
            headers: _buildHeaders({'Content-Type': 'application/json'}),
            body: jsonEncode({'token': token}),
          )
          .timeout(_config.timeout);

      return response.statusCode == 200 || response.statusCode == 204 || response.statusCode == 401;
    } catch (_) {
      return false;
    }
  }
}
