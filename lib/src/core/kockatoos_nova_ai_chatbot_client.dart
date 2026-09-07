import 'package:flutter/widgets.dart';

import '../config/kockatoos_nova_ai_chatbot_config.dart';
import 'kockatoos_nova_ai_chatbot_exception.dart';

class Nova {
  Nova._();

  static Nova? _instance;
  late final NovaConfig _config;
  bool _isInitialized = false;

  static Nova get instance {
    if (_instance == null || !_instance!._isInitialized) {
      throw const NovaNotInitializedException(
        'Nova SDK has not been initialized. '
        'Call `await Nova.initialize(...)` before using Nova.',
      );
    }
    return _instance!;
  }

  static bool get isInitialized => _instance?._isInitialized ?? false;

  static Future<Nova> initialize({
    required NovaConfig config,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    final nova = _instance ?? Nova._();
    nova._config = config;

    try {
      final token = await config.getAuthToken();
      if (token.trim().isEmpty) {
        throw const NovaAuthException('Resolved token is empty.');
      }
    } catch (e) {
      throw NovaAuthException('Failed to resolve auth token: $e');
    }

    nova._isInitialized = true;
    _instance = nova;

    return nova;
  }

  NovaConfig get config => _config;

  static void reset() {
    _instance?._isInitialized = false;
    _instance = null;
  }
}
