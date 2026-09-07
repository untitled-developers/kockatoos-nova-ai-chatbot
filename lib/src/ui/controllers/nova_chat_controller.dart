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

  /// Initializes the controller by fetching config and history.
  Future<void> initialize() async {
    _setState(const NovaChatLoading());

    try {
      final token = await _config.getAuthToken();

      try {
        _remoteConfig = await _apiService.fetchConfig(token);
        if (_remoteConfig != null) {
          _theme = NovaTheme.fromThemeKeyOrHex(
            _config.theme,
            customPrimary: _remoteConfig!.primaryColor ?? _config.primaryColor,
            customSecondary: _remoteConfig!.secondaryColor ?? _config.secondaryColor,
          );
        }
      } catch (_) {
        // Fall back to local config if remote config fails
      }

      try {
        _sessionToken = await _apiService.fetchSessionToken(token);
        final history = await _apiService.fetchMessages(_sessionToken!);
        if (history.isNotEmpty) {
          _messages = [getStarterGreetingMessage(), ...history];
        } else {
          _messages = [getStarterGreetingMessage()];
        }
      } catch (_) {
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
    final greetingText = _config.greetingMessage ??
        _remoteConfig?.greetingMessage ??
        "👋 Hi there! I'm the **Kockatoos Nova**.\n\nI can help you explore our features, answer questions, or connect you with our team. How can I help you today?";

    final defaultPills = [
      "🚀 What can this chatbot do?",
      "🎨 How do I set color schema by code?",
      "💳 Tell me about pricing",
      "🤖 Test a bot response"
    ];

    final pills = _config.suggestedMessages ?? _remoteConfig?.suggestedMessages ?? defaultPills;

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

    try {
      final token = _sessionToken ?? await _config.getAuthToken();

      Stream<String> stream;
      try {
        stream = _apiService.sendMessageStream(token: token, message: trimmed);
      } catch (e) {
        if (e.toString().contains('401_UNAUTHORIZED')) {
          final pubKey = await _config.getAuthToken();
          _sessionToken = await _apiService.fetchSessionToken(pubKey);
          stream = _apiService.sendMessageStream(token: _sessionToken!, message: trimmed);
        } else {
          rethrow;
        }
      }

      await for (final delta in stream) {
        if (botMsg == null) {
          _isTyping = false;
          _isStreaming = true;
          botMsg = NovaChatMessage(
            id: botMsgId,
            sender: NovaMessageSender.bot,
            text: delta,
            timestamp: _formatTime(DateTime.now()),
            isStreaming: true,
          );
          _messages.add(botMsg);
        } else {
          final updatedText = botMsg.text + delta;
          botMsg = botMsg.copyWith(text: updatedText);
          final index = _messages.indexWhere((m) => m.id == botMsgId);
          if (index != -1) {
            _messages[index] = botMsg;
          }
        }
        _notifyLoadedState();
      }

      if (botMsg != null) {
        final index = _messages.indexWhere((m) => m.id == botMsgId);
        if (index != -1) {
          _messages[index] = botMsg.copyWith(isStreaming: false);
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
      _messages.add(NovaChatMessage(
        id: botMsgId,
        sender: NovaMessageSender.bot,
        text: 'Could not reach the server. Please check your connection and try again.',
        timestamp: _formatTime(DateTime.now()),
      ));
    } finally {
      _isTyping = false;
      _isStreaming = false;
      _notifyLoadedState();
    }
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
