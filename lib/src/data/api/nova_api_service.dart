import 'dart:async';
import 'dart:convert';
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

  String get _baseUrl => _config.baseUrl.endsWith('/')
      ? _config.baseUrl.substring(0, _config.baseUrl.length - 1)
      : _config.baseUrl;

  /// Fetches remote widget configuration using the public key.
  Future<NovaWidgetConfig> fetchConfig(String publicKey) async {
    final uri = Uri.parse('$_baseUrl/api/widget/config?key=${Uri.encodeComponent(publicKey)}');
    final response = await _client.get(uri).timeout(_config.timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch widget configuration: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return NovaWidgetConfig.fromJson(data);
  }

  /// Obtains a new visitor session token.
  Future<String> fetchSessionToken(String publicKey) async {
    final uri = Uri.parse('$_baseUrl/api/widget/session');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'key': publicKey}),
        )
        .timeout(_config.timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to create widget session: ${response.statusCode}');
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
    final uri = Uri.parse('$_baseUrl/api/widget/messages');
    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'token': token}),
        )
        .timeout(_config.timeout);

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
    final uri = Uri.parse('$_baseUrl/api/widget/send');
    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';
    request.body = jsonEncode({
      'token': token,
      'message': message,
    });

    final response = await _client.send(request);

    if (response.statusCode == 401) {
      throw Exception('401_UNAUTHORIZED');
    }

    if (response.statusCode != 200) {
      throw Exception('Server error status: ${response.statusCode}');
    }

    final lines = response.stream
        .transform(utf8.decoder)
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
      final uri = Uri.parse('$_baseUrl/api/widget/conversations/close');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(_config.timeout);

      return response.statusCode == 200 || response.statusCode == 204 || response.statusCode == 401;
    } catch (_) {
      return false;
    }
  }
}
