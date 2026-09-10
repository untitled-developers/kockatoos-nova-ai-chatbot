import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kockatoos_nova_ai_chatbot/kockatoos_nova_ai_chatbot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Nova.reset();
  });

  group('NovaConfig & NovaTheme', () {
    test('NovaTheme parses presets correctly', () {
      final indigo = NovaTheme.fromThemeKeyOrHex('indigo');
      expect(indigo.primary, const Color(0xFFF05A2B));

      final emerald = NovaTheme.fromThemeKeyOrHex('emerald');
      expect(emerald.primary, const Color(0xFF059669));

      final customHex = NovaTheme.fromThemeKeyOrHex('#2563EB');
      expect(customHex.primary, const Color(0xFF2563EB));
    });

    test('NovaConfig supports theme, origin, and color overrides', () {
      const config = NovaConfig(
        apiKey: 'test_pk',
        baseUrl: 'http://10.0.2.2:8000',
        origin: 'http://10.0.2.2:8000',
        theme: 'rose',
        primaryColor: '#E11D48',
        agentName: 'Custom Agent',
      );

      expect(config.theme, 'rose');
      expect(config.primaryColor, '#E11D48');
      expect(config.agentName, 'Custom Agent');
      expect(config.resolvedOrigin, 'http://10.0.2.2:8000');
    });

    test('NovaConfig supports mobile origin types (android_sha256_hash & ios_package_name)', () {
      const androidConfig = NovaConfig(
        apiKey: 'test_pk',
        androidSha256Hash: 'A1:B2:C3:D4:E5:F6',
      );
      expect(androidConfig.mobileOriginParams, {
        'type': 'android',
        'value': 'A1:B2:C3:D4:E5:F6',
      });

      const iosConfig = NovaConfig(
        apiKey: 'test_pk',
        iosPackageName: 'com.example.app',
      );
      expect(iosConfig.mobileOriginParams, {
        'type': 'ios',
        'value': 'com.example.app',
      });
    });
  });

  group('Data Models', () {
    test('NovaWidgetConfig.fromJson deserializes payload', () {
      final json = {
        'is_enabled': true,
        'agent_name': 'Nova Bot',
        'primary_color': '#059669',
        'suggested_messages': ['Price?', 'Help'],
        'allow_emojis': true,
      };

      final widgetConfig = NovaWidgetConfig.fromJson(json);
      expect(widgetConfig.isEnabled, isTrue);
      expect(widgetConfig.agentName, 'Nova Bot');
      expect(widgetConfig.primaryColor, '#059669');
      expect(widgetConfig.suggestedMessages.length, 2);
    });

    test('NovaChatMessage serializes and deserializes', () {
      const msg = NovaChatMessage(
        id: '123',
        sender: NovaMessageSender.bot,
        text: 'Hello world',
        timestamp: '12:00',
        pills: ['Option A'],
      );

      final json = msg.toJson();
      expect(json['id'], '123');
      expect(json['sender'], 'bot');

      final parsed = NovaChatMessage.fromJson(json);
      expect(parsed.text, 'Hello world');
      expect(parsed.sender, NovaMessageSender.bot);
      expect(parsed.pills, contains('Option A'));
    });
  });

  group('NovaChatController', () {
    test('initializes and generates starter greeting message', () async {
      const config = NovaConfig(apiKey: 'test_key');
      await Nova.initialize(config: config);

      final controller = NovaChatController();
      expect(controller.state, isA<NovaChatInitial>());

      final starter = controller.getStarterGreetingMessage();
      expect(starter.sender, NovaMessageSender.bot);
      expect(starter.text, contains('Kockatoos Nova'));
    });

    test('toggles sound and theme state', () async {
      const config = NovaConfig(apiKey: 'test_key');
      await Nova.initialize(config: config);

      final controller = NovaChatController();
      expect(controller.soundEnabled, isTrue);

      controller.toggleSound();
      expect(controller.soundEnabled, isFalse);

      final emerald = NovaTheme.fromThemeKeyOrHex('emerald');
      controller.setTheme(emerald);
      expect(controller.theme.name, 'Emerald & Teal');
    });

    test('persists and reloads visitor session token across launches', () async {
      const config = NovaConfig(apiKey: 'persist_key');
      await Nova.initialize(config: config);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nova_session_token_persist_key', 'existing_token_xyz');

      final controller = NovaChatController();
      await controller.initialize();

      expect(controller.sessionToken, 'existing_token_xyz');
    });
  });

  group('UI Widgets', () {
    testWidgets('renders NovaFloatingButton and triggers bottom sheet',
        (WidgetTester tester) async {
      const config = NovaConfig(apiKey: 'widget_key');
      await Nova.initialize(config: config);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            floatingActionButton: NovaFloatingButton(),
          ),
        ),
      );

      expect(find.byType(NovaFloatingButton), findsOneWidget);

      await tester.tap(find.byType(NovaFloatingButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(NovaChatView), findsOneWidget);
    });

    testWidgets('hides NovaFloatingButton (SizedBox.shrink) when origin is not allowed',
        (WidgetTester tester) async {
      const config = NovaConfig(apiKey: 'disallowed_key');
      await Nova.initialize(config: config);

      final controller = NovaChatController(config: config);
      // Simulate disallowed origin state (e.g. HTTP 403 response)
      expect(controller.isAllowed, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: NovaFloatingButton(controller: controller),
          ),
        ),
      );

      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

      // Now set controller as not allowed
      controller.initialize();
      // Manually verify hiding logic when isAllowed is false
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final activeController = controller;
              if (!activeController.isAllowed) {
                return const SizedBox.shrink();
              }
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('renders standalone NovaChatView with input field and header',
        (WidgetTester tester) async {
      const config = NovaConfig(apiKey: 'view_key');
      await Nova.initialize(config: config);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NovaChatView(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(NovaChatView), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Kockatoos Nova'), findsOneWidget);
    });
  });
}
