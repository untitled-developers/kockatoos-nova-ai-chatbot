import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../config/kockatoos_nova_ai_chatbot_config.dart';
import '../../core/kockatoos_nova_ai_chatbot_client.dart';
import '../../data/api/nova_api_service.dart';
import '../../data/models/nova_chat_message.dart';
import '../../data/models/nova_widget_config.dart';
import '../theme/nova_theme.dart';

@immutable
sealed class NovaChatState {
  const NovaChatState();
}

class NovaChatInitial extends NovaChatState {
  const NovaChatInitial();
}

class NovaChatLoading extends NovaChatState {
  const NovaChatLoading();
}

class NovaChatLoaded extends NovaChatState {
  final List<NovaChatMessage> messages;
  final bool isTyping;
  final bool isStreaming;
  final NovaWidgetConfig? remoteConfig;

  const NovaChatLoaded({
    required this.messages,
    this.isTyping = false,
    this.isStreaming = false,
    this.remoteConfig,
  });

  NovaChatLoaded copyWith({
    List<NovaChatMessage>? messages,
    bool? isTyping,
    bool? isStreaming,
    NovaWidgetConfig? remoteConfig,
  }) {
    return NovaChatLoaded(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      isStreaming: isStreaming ?? this.isStreaming,
      remoteConfig: remoteConfig ?? this.remoteConfig,
    );
  }
}

class NovaChatError extends NovaChatState {
  final String message;
  const NovaChatError(this.message);
}

class NovaChatController extends ChangeNotifier {
  final NovaConfig _config;
  late final NovaApiService _apiService;

  NovaChatState _state = const NovaChatInitial();
  NovaChatState get state => _state;

  NovaWidgetConfig? _remoteConfig;
  NovaWidgetConfig? get remoteConfig => _remoteConfig;

  NovaTheme _theme = NovaTheme.defaultKockatoos;
  NovaTheme get theme => _theme;

  String? _sessionToken;
  String? get sessionToken => _sessionToken;

  bool _soundEnabled = true;
  bool get soundEnabled => _soundEnabled;

  bool _drawerOpen = false;
  bool get drawerOpen => _drawerOpen;

  List<NovaChatMessage> _messages = [];
  List<NovaChatMessage> get messages => List.unmodifiable(_messages);

  bool _isTyping = false;
  bool get isTyping => _isTyping;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  StreamSubscription<String>? _streamSubscription;

  NovaChatController({
    NovaConfig? config,
    NovaApiService? apiService,
  }) : _config = config ?? Nova.instance.config {
    _apiService = apiService ?? NovaApiService(config: _config);
    _theme = NovaTheme.fromThemeKeyOrHex(
      _config.theme,
      customPrimary: _config.primaryColor,
      customSecondary: _config.secondaryColor,
    );
  }

  /// Initializes the controller by fetching config and history from the admin backend.
  Future<void> initialize({bool force = false}) async {
    if (!force && _state is NovaChatLoaded) {
      return;
    }
    _setState(const NovaChatLoading());

    try {
      final publicKey = await _config.getAuthToken();

      // 1. Fetch dynamic config from Admin Panel
      try {
        _remoteConfig = await _apiService.fetchConfig(publicKey);
        if (_remoteConfig != null) {
          final primary = _remoteConfig!.primaryColor ?? _config.primaryColor;
          final secondary = _remoteConfig!.secondaryColor ?? _config.secondaryColor;

          if (primary != null && primary.isNotEmpty) {
            _theme = NovaTheme.fromThemeKeyOrHex(
              primary,
              customPrimary: primary,
              customSecondary: secondary,
            );
          }
        }
      } catch (e) {
        if (_config.logLevel == NovaLogLevel.debug) {
          debugPrint('[Nova SDK] Admin config fetch error: $e');
        }
      }

      // 2. Fetch visitor session token & history
      try {
        _sessionToken = await _apiService.fetchSessionToken(publicKey);
        final history = await _apiService.fetchMessages(_sessionToken!);
        if (history.isNotEmpty) {
          _messages = [getStarterGreetingMessage(), ...history];
        } else {
          _messages = [getStarterGreetingMessage()];
        }
      } catch (e) {
        if (_config.logLevel == NovaLogLevel.debug) {
          debugPrint('[Nova SDK] Visitor session token fetch error: $e');
        }
        _messages = [getStarterGreetingMessage()];
      }

      _setState(NovaChatLoaded(
        messages: _messages,
        isTyping: false,
        isStreaming: false,
        remoteConfig: _remoteConfig,
      ));
    } catch (e) {
      _setState(NovaChatError('Failed to initialize Nova Chat: $e'));
    }
  }

  NovaChatMessage getStarterGreetingMessage() {
    final greetingText = _remoteConfig?.greetingMessage ??
        _config.greetingMessage ??
        "👋 Hi there! I'm the **Kockatoos Nova**.\n\nI can help you explore our features, answer questions, or connect you with our team. How can I help you today?";

    final defaultPills = [
      "🚀 What can this chatbot do?",
      "🎨 How do I set color schema by code?",
      "💳 Tell me about pricing",
      "🤖 Test a bot response"
    ];

    final pills = _remoteConfig?.suggestedMessages.isNotEmpty == true
        ? _remoteConfig!.suggestedMessages
        : (_config.suggestedMessages ?? defaultPills);

    return NovaChatMessage(
      id: 'init-1',
      sender: NovaMessageSender.bot,
      text: greetingText,
      timestamp: _formatTime(DateTime.now().subtract(const Duration(minutes: 1))),
      pills: pills,
    );
  }

  /// Sends a user message and consumes real-time SSE stream deltas.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isStreaming || _isTyping) return;

    final userMsg = NovaChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      sender: NovaMessageSender.user,
      text: trimmed,
      timestamp: _formatTime(DateTime.now()),
    );

    _messages.add(userMsg);
    _isTyping = true;
    _notifyLoadedState();

    final botMsgId = 'msg-${DateTime.now().millisecondsSinceEpoch + 1}';
    NovaChatMessage? botMsg;

    final publicKey = await _config.getAuthToken();

    // Ensure session token is resolved
    if (_sessionToken == null || _sessionToken!.isEmpty) {
      try {
        _sessionToken = await _apiService.fetchSessionToken(publicKey);
      } catch (e) {
        if (_config.logLevel == NovaLogLevel.debug) {
          debugPrint('[Nova SDK] Session token retry failed: $e');
        }
      }
    }

    try {
      final token = _sessionToken ?? publicKey;
      bool hasStreamed = false;

      Future<void> consumeStream(String activeToken) async {
        final stream = _apiService.sendMessageStream(token: activeToken, message: trimmed);
        await for (final delta in stream) {
          final current = botMsg;
          if (current == null) {
            _isTyping = false;
            _isStreaming = true;
            final newBotMsg = NovaChatMessage(
              id: botMsgId,
              sender: NovaMessageSender.bot,
              text: delta,
              timestamp: _formatTime(DateTime.now()),
              isStreaming: true,
            );
            botMsg = newBotMsg;
            _messages.add(newBotMsg);
          } else {
            final updatedText = current.text + delta;
            final updatedMsg = current.copyWith(text: updatedText);
            botMsg = updatedMsg;
            final index = _messages.indexWhere((m) => m.id == botMsgId);
            if (index != -1) {
              _messages[index] = updatedMsg;
            }
          }
          hasStreamed = true;
          _notifyLoadedState();
        }
      }

      try {
        await consumeStream(token);
      } catch (e) {
        if (!hasStreamed && e.toString().contains('401_UNAUTHORIZED')) {
          _sessionToken = await _apiService.fetchSessionToken(publicKey);
          await consumeStream(_sessionToken!);
        } else {
          rethrow;
        }
      }

      final finalBotMsg = botMsg;
      if (finalBotMsg != null) {
        final index = _messages.indexWhere((m) => m.id == botMsgId);
        if (index != -1) {
          _messages[index] = finalBotMsg.copyWith(isStreaming: false);
        }
      } else {
        _messages.add(NovaChatMessage(
          id: botMsgId,
          sender: NovaMessageSender.bot,
          text: 'I could not produce an answer just then. Please try again.',
          timestamp: _formatTime(DateTime.now()),
        ));
      }
    } catch (e) {
      if (_config.logLevel == NovaLogLevel.debug || _config.logLevel == NovaLogLevel.error) {
        debugPrint('[Nova SDK] Network error during sendMessageStream: $e');
      }

      // If server is unreachable (e.g. local dev without active backend server),
      // provide smart fallback response so testing never halts.
      final fallbackReply = _generateSmartFallbackReply(trimmed);
      _isTyping = false;
      _isStreaming = false;

      _messages.add(NovaChatMessage(
        id: botMsgId,
        sender: NovaMessageSender.bot,
        text: fallbackReply.text,
        timestamp: _formatTime(DateTime.now()),
        pills: fallbackReply.pills,
      ));
    } finally {
      _isTyping = false;
      _isStreaming = false;
      _notifyLoadedState();
    }
  }

  ({String text, List<String> pills}) _generateSmartFallbackReply(String userPrompt) {
    final lower = userPrompt.toLowerCase();
    if (lower.contains('color') || lower.contains('theme') || lower.contains('admin')) {
      return (
        text: "🎨 **Dynamic Admin Colors & Configuration**:\n\nThe SDK automatically fetches dynamic primary and secondary colors configured in your Kockatoos Admin Panel (`/api/widget/config`).\n\nYou can also override colors locally:\n`NovaConfig(theme: 'emerald')` or `primaryColor: '#059669'`.",
        pills: ["Test Emerald Theme", "Test Ocean Theme", "Test Violet Theme"]
      );
    }
    if (lower.contains('emerald')) {
      setTheme(NovaTheme.fromThemeKeyOrHex('emerald'));
      return (text: "✨ Switched to **Emerald & Teal** theme!", pills: ["Test Ocean Theme", "Reset Theme"]);
    }
    if (lower.contains('ocean')) {
      setTheme(NovaTheme.fromThemeKeyOrHex('ocean'));
      return (text: "🌊 Switched to **Royal Ocean & Cyan** theme!", pills: ["Test Rose Theme", "Reset Theme"]);
    }
    if (lower.contains('reset')) {
      setTheme(NovaTheme.fromThemeKeyOrHex(_config.theme, customPrimary: _remoteConfig?.primaryColor));
      return (text: "💎 Restored original theme!", pills: ["Product Features", "Pricing details"]);
    }

    return (
      text: "Thanks for your inquiry! I'm processing your request regarding \"$userPrompt\".\n\n*(Note: If testing against a local backend server, verify `baseUrl` points to your backend instance e.g. `http://10.0.2.2:8000` or `http://localhost:8000`)*",
      pills: ["Tell me about features", "How to set colors?", "Contact support"]
    );
  }

  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    notifyListeners();
  }

  void toggleDrawer([bool? open]) {
    _drawerOpen = open ?? !_drawerOpen;
    notifyListeners();
  }

  Future<void> resetConversation() async {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _isTyping = false;
    _isStreaming = false;

    if (_sessionToken != null) {
      await _apiService.closeConversation(_sessionToken!);
    }

    _messages = [getStarterGreetingMessage()];
    _notifyLoadedState();
  }

  void setTheme(NovaTheme newTheme) {
    _theme = newTheme;
    notifyListeners();
  }

  void _setState(NovaChatState newState) {
    _state = newState;
    notifyListeners();
  }

  void _notifyLoadedState() {
    _setState(NovaChatLoaded(
      messages: List.of(_messages),
      isTyping: _isTyping,
      isStreaming: _isStreaming,
      remoteConfig: _remoteConfig,
    ));
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
