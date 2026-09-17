import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

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
  final bool hasMoreHistory;
  final bool isLoadingHistory;

  const NovaChatLoaded({
    required this.messages,
    this.isTyping = false,
    this.isStreaming = false,
    this.remoteConfig,
    this.hasMoreHistory = false,
    this.isLoadingHistory = false,
  });

  NovaChatLoaded copyWith({
    List<NovaChatMessage>? messages,
    bool? isTyping,
    bool? isStreaming,
    NovaWidgetConfig? remoteConfig,
    bool? hasMoreHistory,
    bool? isLoadingHistory,
  }) {
    return NovaChatLoaded(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      isStreaming: isStreaming ?? this.isStreaming,
      remoteConfig: remoteConfig ?? this.remoteConfig,
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
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

  final AudioPlayer _audioPlayer = AudioPlayer();
  Uint8List? _soundBytes;

  bool _drawerOpen = false;
  bool get drawerOpen => _drawerOpen;

  bool _isAllowed = true;
  bool get isAllowed => _isAllowed;

  List<NovaChatMessage> _messages = [];
  List<NovaChatMessage> get messages => List.unmodifiable(_messages);

  bool _isTyping = false;
  bool get isTyping => _isTyping;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  /// True while a history page is being fetched from the server.
  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  /// False once the server returns an empty page, meaning there are no older
  /// messages to load.
  bool _hasMoreHistory = false;
  bool get hasMoreHistory => _hasMoreHistory;

  StreamSubscription<String>? _streamSubscription;

  NovaChatController({
    NovaConfig? config,
    NovaApiService? apiService,
  }) : _config = config ?? Nova.instance.config {
    _apiService = apiService ?? NovaApiService(config: _config);

    if (Nova.isInitialized) {
      _isAllowed = Nova.instance.isAllowed;
    }

    if (Nova.isInitialized && Nova.instance.remoteConfig != null) {
      _remoteConfig = Nova.instance.remoteConfig;
      if (_remoteConfig != null) {
        _isAllowed = _remoteConfig!.isEnabled;
      }
      final primary = _remoteConfig!.primaryColor ?? _config.primaryColor;
      final secondary = _remoteConfig!.secondaryColor ?? _config.secondaryColor;

      if (primary != null && primary.isNotEmpty) {
        _theme = NovaTheme.fromThemeKeyOrHex(
          primary,
          customPrimary: primary,
          customSecondary: secondary,
        );
      } else {
        _theme = NovaTheme.fromThemeKeyOrHex(
          _config.theme,
          customPrimary: _config.primaryColor,
          customSecondary: _config.secondaryColor,
        );
      }
    } else {
      _theme = NovaTheme.fromThemeKeyOrHex(
        _config.theme,
        customPrimary: _config.primaryColor,
        customSecondary: _config.secondaryColor,
      );
    }

    unawaited(_loadSoundPreference());
    unawaited(_preloadSound());
  }

  Future<void> _loadSoundPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'nova_sound_enabled_${_config.apiKey}';
      if (prefs.containsKey(key)) {
        _soundEnabled = prefs.getBool(key) ?? true;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveSoundPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'nova_sound_enabled_${_config.apiKey}';
      await prefs.setBool(key, _soundEnabled);
    } catch (_) {}
  }

  Future<String?> _loadSavedSessionToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'nova_session_token_${_config.apiKey}';
      return prefs.getString(key);
    } catch (e) {
      if (_config.logLevel == NovaLogLevel.debug) {
        debugPrint('[Nova SDK] Failed to load saved session token: $e');
      }
      return null;
    }
  }

  Future<void> _saveSessionToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'nova_session_token_${_config.apiKey}';
      await prefs.setString(key, token);
    } catch (e) {
      if (_config.logLevel == NovaLogLevel.debug) {
        debugPrint('[Nova SDK] Failed to save session token: $e');
      }
    }
  }

  Future<void> _clearSavedSessionToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'nova_session_token_${_config.apiKey}';
      await prefs.remove(key);
    } catch (e) {
      if (_config.logLevel == NovaLogLevel.debug) {
        debugPrint('[Nova SDK] Failed to clear session token: $e');
      }
    }
  }

  Future<List<NovaChatMessage>?> _loadLocalMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'nova_chat_history_${_config.apiKey}';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List raw = jsonDecode(jsonStr) as List;
        final list = raw
            .map((e) => NovaChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        if (_config.logLevel == NovaLogLevel.debug) {
          debugPrint(
              '[Nova SDK] Loaded ${list.length} cached messages from SharedPreferences.');
        }
        return list;
      }
    } catch (e) {
      if (_config.logLevel == NovaLogLevel.debug) {
        debugPrint('[Nova SDK] Failed to load local chat history: $e');
      }
    }
    return null;
  }

  Future<void> _saveLocalMessages(List<NovaChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'nova_chat_history_${_config.apiKey}';
      // Cap local disk storage in SharedPreferences to last 30 messages (~20-30 KB) for 0ms startup
      final capped = messages.length > 30
          ? messages.sublist(messages.length - 30)
          : messages;
      final jsonList = capped.map((m) => m.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
      if (_config.logLevel == NovaLogLevel.debug) {
        debugPrint(
            '[Nova SDK] Saved ${capped.length} messages to SharedPreferences (total in-memory: ${messages.length}).');
      }
    } catch (e) {
      if (_config.logLevel == NovaLogLevel.debug) {
        debugPrint('[Nova SDK] Failed to save local chat history: $e');
      }
    }
  }

  Future<void> _clearLocalMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'nova_chat_history_${_config.apiKey}';
      await prefs.remove(key);
      if (_config.logLevel == NovaLogLevel.debug) {
        debugPrint('[Nova SDK] Cleared local chat history from SharedPreferences.');
      }
    } catch (e) {
      if (_config.logLevel == NovaLogLevel.debug) {
        debugPrint('[Nova SDK] Failed to clear local chat history: $e');
      }
    }
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
          _isAllowed = _remoteConfig!.isEnabled;
          final primary = _remoteConfig!.primaryColor ?? _config.primaryColor;
          final secondary =
              _remoteConfig!.secondaryColor ?? _config.secondaryColor;

          if (primary != null && primary.isNotEmpty) {
            _theme = NovaTheme.fromThemeKeyOrHex(
              primary,
              customPrimary: primary,
              customSecondary: secondary,
            );
          }
        }
      } catch (e) {
        final errStr = e.toString();
        if (errStr.contains('403') ||
            errStr.contains('401') ||
            errStr.contains('Forbidden') ||
            errStr.contains('Unauthorized')) {
          _isAllowed = false;
        }
        if (_config.logLevel == NovaLogLevel.debug) {
          debugPrint('[Nova SDK] Admin config fetch error: $e');
        }
      }

      // 2. Load cached local messages first for instant 0ms rendering
      final localMsgs = await _loadLocalMessages();
      if (localMsgs != null && localMsgs.isNotEmpty) {
        _messages = localMsgs;
      } else {
        _messages = [getStarterGreetingMessage()];
      }

      // Emit loaded state immediately with local cache so UI renders with 0ms delay
      _setState(NovaChatLoaded(
        messages: List.of(_messages),
        isTyping: false,
        isStreaming: false,
        remoteConfig: _remoteConfig,
      ));

      // 3. Fetch visitor session token & full history from backend server
      try {
        String? token = await _loadSavedSessionToken();
        List<NovaChatMessage> remoteHistory = [];

        if (token != null && token.isNotEmpty) {
          try {
            remoteHistory = await _apiService.fetchMessages(token);
            _sessionToken = token;
          } catch (e) {
            final errorStr = e.toString();
            if (errorStr.contains('HTTP 401') ||
                errorStr.contains('HTTP 404')) {
              if (_config.logLevel == NovaLogLevel.debug) {
                debugPrint(
                    '[Nova SDK] Saved session token invalid or expired: $e');
              }
              await _clearSavedSessionToken();
              token = null;
            } else {
              // Network error or offline: retain saved token
              _sessionToken = token;
            }
          }
        }

        if (token == null || token.isEmpty) {
          _sessionToken = await _apiService.fetchSessionToken(publicKey);
          await _saveSessionToken(_sessionToken!);
          try {
            remoteHistory = await _apiService.fetchMessages(_sessionToken!);
          } catch (_) {}
        }

        if (remoteHistory.isNotEmpty) {
          if (_config.logLevel == NovaLogLevel.debug) {
            debugPrint(
                '[Nova SDK] Fetched ${remoteHistory.length} remote messages from server API.');
          }
          _messages = [getStarterGreetingMessage(), ...remoteHistory];
          await _saveLocalMessages(_messages);
          // If the server returned a full page there may be older messages.
          _hasMoreHistory = true;
        }
      } catch (e) {
        if (_config.logLevel == NovaLogLevel.debug) {
          debugPrint('[Nova SDK] Visitor session token fetch error: $e');
        }
      }

      _setState(NovaChatLoaded(
        messages: List.of(_messages),
        isTyping: false,
        isStreaming: false,
        remoteConfig: _remoteConfig,
        hasMoreHistory: _hasMoreHistory,
        isLoadingHistory: false,
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
      timestamp:
          _formatTime(DateTime.now().subtract(const Duration(minutes: 1))),
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
    _playSentSound();

    final botMsgId = 'msg-${DateTime.now().millisecondsSinceEpoch + 1}';
    NovaChatMessage? botMsg;

    final publicKey = await _config.getAuthToken();

    // Ensure session token is resolved
    if (_sessionToken == null || _sessionToken!.isEmpty) {
      try {
        _sessionToken = await _loadSavedSessionToken();
        if (_sessionToken == null || _sessionToken!.isEmpty) {
          _sessionToken = await _apiService.fetchSessionToken(publicKey);
          await _saveSessionToken(_sessionToken!);
        }
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
        final stream =
            _apiService.sendMessageStream(token: activeToken, message: trimmed);
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
          await _saveSessionToken(_sessionToken!);
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
      _playReceivedSound();
    } catch (e) {
      if (_config.logLevel == NovaLogLevel.debug ||
          _config.logLevel == NovaLogLevel.error) {
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
      _playReceivedSound();
    } finally {
      _isTyping = false;
      _isStreaming = false;
      _notifyLoadedState();
    }
  }

  ({String text, List<String> pills}) _generateSmartFallbackReply(
      String userPrompt) {
    final lower = userPrompt.toLowerCase();
    if (lower.contains('color') ||
        lower.contains('theme') ||
        lower.contains('admin')) {
      return (
        text:
            "🎨 **Dynamic Admin Colors & Configuration**:\n\nThe SDK automatically fetches dynamic primary and secondary colors configured in your Kockatoos Admin Panel (`/api/widget/config`).\n\nYou can also override colors locally:\n`NovaConfig(theme: 'emerald')` or `primaryColor: '#059669'`.",
        pills: ["Test Emerald Theme", "Test Ocean Theme", "Test Violet Theme"]
      );
    }
    if (lower.contains('emerald')) {
      setTheme(NovaTheme.fromThemeKeyOrHex('emerald'));
      return (
        text: "✨ Switched to **Emerald & Teal** theme!",
        pills: ["Test Ocean Theme", "Reset Theme"]
      );
    }
    if (lower.contains('ocean')) {
      setTheme(NovaTheme.fromThemeKeyOrHex('ocean'));
      return (
        text: "🌊 Switched to **Royal Ocean & Cyan** theme!",
        pills: ["Test Rose Theme", "Reset Theme"]
      );
    }
    if (lower.contains('reset')) {
      setTheme(NovaTheme.fromThemeKeyOrHex(_config.theme,
          customPrimary: _remoteConfig?.primaryColor));
      return (
        text: "💎 Restored original theme!",
        pills: ["Product Features", "Pricing details"]
      );
    }

    return (
      text:
          "Thanks for your inquiry! I'm processing your request regarding \"$userPrompt\".\n\n*(Note: If testing against a local backend server, verify `baseUrl` points to your backend instance e.g. `http://10.0.2.2:8000` or `http://localhost:8000`)*",
      pills: ["Tell me about features", "How to set colors?", "Contact support"]
    );
  }

  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    notifyListeners();
    _saveSoundPreference();
  }

  Future<void> _preloadSound() async {
    if (_soundBytes != null) return;
    try {
      String? matchedKey;
      try {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        for (final key in manifest.listAssets()) {
          if (key.endsWith('notifications.wav') ||
              key.contains('notifications.wav')) {
            matchedKey = key;
            break;
          }
        }
      } catch (e) {
        if (_config.logLevel == NovaLogLevel.debug) {
          debugPrint('[Nova SDK] AssetManifest lookup error: $e');
        }
      }

      final candidates = <String>[
        if (matchedKey != null) matchedKey,
        'packages/kockatoos_nova_ai_chatbot/assets/sounds/notifications.wav',
        'packages/kockatoos_nova_ai_chatbot/lib/assets/sounds/notifications.wav',
        'lib/assets/sounds/notifications.wav',
        'assets/sounds/notifications.wav',
      ];

      for (final path in candidates) {
        try {
          final data = await rootBundle.load(path);
          _soundBytes = data.buffer.asUint8List();
          if (_config.logLevel == NovaLogLevel.debug) {
            debugPrint('[Nova SDK] Preloaded notification sound from $path');
          }
          return;
        } catch (_) {}
      }

      if (_config.logLevel == NovaLogLevel.debug) {
        debugPrint(
          '[Nova SDK] notifications.wav not found in asset bundle.',
        );
      }
    } catch (e) {
      if (_config.logLevel == NovaLogLevel.debug) {
        debugPrint('[Nova SDK] Failed to preload notification sound: $e');
      }
    }
  }

  Future<void> _playSound({
    required double volume,
    required double playbackRate,
  }) async {
    if (!_soundEnabled) return;
    try {
      if (_soundBytes == null) {
        await _preloadSound();
      }

      if (_soundBytes != null) {
        await _audioPlayer.stop();
        try {
          await _audioPlayer.play(BytesSource(_soundBytes!), volume: volume);
        } catch (_) {
          _audioPlayer.audioCache.prefix = '';
          await _audioPlayer.play(
            AssetSource('packages/kockatoos_nova_ai_chatbot/assets/sounds/notifications.wav'),
            volume: volume,
          );
        }
        if (playbackRate != 1.0) {
          try {
            await _audioPlayer.setPlaybackRate(playbackRate);
          } catch (_) {}
        }
      }
    } catch (e) {
      if (_config.logLevel == NovaLogLevel.debug) {
        debugPrint('[Nova SDK] Failed to play sound effect: $e');
      }
    }
  }

  /// Sent sound effect (similar to web version's playSent):
  /// Uses notifications.wav played slightly faster with a lighter, subtle volume.
  Future<void> _playSentSound() async {
    await _playSound(volume: 0.5, playbackRate: 1.3);
  }

  /// Received sound effect (similar to web version's playReceived):
  /// Uses notifications.wav at full volume and natural chime tempo when bot replies.
  Future<void> _playReceivedSound() async {
    await _playSound(volume: 1.0, playbackRate: 1.0);
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
      try {
        await _apiService.closeConversation(_sessionToken!);
      } catch (_) {}
    }

    await _clearSavedSessionToken();
    await _clearLocalMessages();
    _sessionToken = null;

    try {
      final publicKey = await _config.getAuthToken();
      _sessionToken = await _apiService.fetchSessionToken(publicKey);
      await _saveSessionToken(_sessionToken!);
    } catch (e) {
      if (_config.logLevel == NovaLogLevel.debug) {
        debugPrint('[Nova SDK] Reset session token error: $e');
      }
    }

    _messages = [getStarterGreetingMessage()];
    _hasMoreHistory = false;
    _isLoadingHistory = false;
    _notifyLoadedState();
  }

  /// Loads the page of messages that came before the oldest message currently
  /// in [_messages]. Safe to call from the UI scroll listener — guards against
  /// concurrent fetches and a exhausted history.
  Future<void> loadMoreHistory() async {
    if (_isLoadingHistory || !_hasMoreHistory) return;
    if (_sessionToken == null || _sessionToken!.isEmpty) return;

    // Find the oldest real message ID (skip the synthetic greeting 'init-1').
    final realMessages = _messages.where((m) => m.id != 'init-1').toList();
    if (realMessages.isEmpty) return;

    // The oldest message is at index 1 (after the greeting) in _messages,
    // i.e. the first element of realMessages.
    final oldestId = realMessages.first.id;

    _isLoadingHistory = true;
    _notifyLoadedState();

    try {
      final page = await _apiService.fetchMessages(
        _sessionToken!,
        before: oldestId,
      );

      if (page.isEmpty) {
        // No more history on the server.
        _hasMoreHistory = false;
      } else {
        // Prepend the older page right after the greeting message.
        // _messages layout: [greeting, ...older, ...newer]
        final greeting = _messages.first; // always init-1
        final rest = _messages.sublist(1);
        _messages = [greeting, ...page, ...rest];
        await _saveLocalMessages(_messages);

        if (_config.logLevel == NovaLogLevel.debug) {
          debugPrint(
              '[Nova SDK] Loaded ${page.length} older messages (before $oldestId).');
        }
      }
    } catch (e) {
      if (_config.logLevel == NovaLogLevel.debug ||
          _config.logLevel == NovaLogLevel.error) {
        debugPrint('[Nova SDK] loadMoreHistory error: $e');
      }
    } finally {
      _isLoadingHistory = false;
      _notifyLoadedState();
    }
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
    _saveLocalMessages(_messages);
    _setState(NovaChatLoaded(
      messages: List.of(_messages),
      isTyping: _isTyping,
      isStreaming: _isStreaming,
      remoteConfig: _remoteConfig,
      hasMoreHistory: _hasMoreHistory,
      isLoadingHistory: _isLoadingHistory,
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
    _audioPlayer.dispose();
    super.dispose();
  }
}
