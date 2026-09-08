import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kockatoos_nova_ai_chatbot/kockatoos_nova_ai_chatbot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(config.resolvedOrigin, 'https://app.kockatoos.com');
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
      await tester.pumpAndSettle();

      expect(find.byType(NovaChatView), findsOneWidget);
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

      await tester.pumpAndSettle();

      expect(find.byType(NovaChatView), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Kockatoos Nova'), findsOneWidget);
    });
  });
}
