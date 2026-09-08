import 'package:flutter/widgets.dart';

import '../config/kockatoos_nova_ai_chatbot_config.dart';
import '../data/api/nova_api_service.dart';
import '../data/models/nova_widget_config.dart';
import 'kockatoos_nova_ai_chatbot_exception.dart';

class Nova {
  Nova._();

  static Nova? _instance;
  late final NovaConfig _config;
  NovaWidgetConfig? _remoteConfig;
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

      // Pre-fetch dynamic remote widget config from backend before UI renders
      try {
        final apiService = NovaApiService(config: config);
        nova._remoteConfig = await apiService.fetchConfig(token);
      } catch (e) {
        if (config.logLevel == NovaLogLevel.debug) {
          debugPrint('[Nova SDK] Pre-fetch remote config notice: $e');
        }
      }
    } catch (e) {
      throw NovaAuthException('Failed to resolve auth token: $e');
    }

    nova._isInitialized = true;
    _instance = nova;

    return nova;
  }

  NovaConfig get config => _config;
  NovaWidgetConfig? get remoteConfig => _remoteConfig;

  static void reset() {
    _instance?._isInitialized = false;
    _instance?._remoteConfig = null;
    _instance = null;
  }
}
