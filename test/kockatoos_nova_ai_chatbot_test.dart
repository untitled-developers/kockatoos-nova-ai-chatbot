import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kockatoos_nova_ai_chatbot/kockatoos_nova_ai_chatbot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Nova.reset();
  });

  group('NovaConfig', () {
    test('instantiates correctly with apiKey', () async {
      const config = NovaConfig(
        apiKey: 'test_api_key',
      );

      expect(config.apiKey, 'test_api_key');
      expect(config.baseUrl, 'https://api.kockatoos.com/v1');
      expect(config.timeout, const Duration(seconds: 15));
      expect(await config.getAuthToken(), 'test_api_key');
    });

    test('instantiates correctly with tokenResolver', () async {
      final config = NovaConfig(
        tokenResolver: () async => 'resolved_token',
      );

      expect(await config.getAuthToken(), 'resolved_token');
    });

    test('throws AssertionError if neither apiKey nor tokenResolver provided', () {
      expect(
        () => NovaConfig(),
        throwsA(isA<AssertionError>()),
      );
    });

    test('tokenResolver takes precedence over apiKey in getAuthToken()', () async {
      final config = NovaConfig(
        apiKey: 'static_key',
        tokenResolver: () async => 'dynamic_token',
      );

      expect(await config.getAuthToken(), 'dynamic_token');
    });
  });

  group('Nova Client Singleton', () {
    test('isInitialized returns false prior to initialization', () {
      expect(Nova.isInitialized, isFalse);
    });

    test('accessing instance before initialization throws NovaNotInitializedException', () {
      expect(
        () => Nova.instance,
        throwsA(isA<NovaNotInitializedException>()),
      );
    });

    test('initialize successfully sets instance and isInitialized', () async {
      const config = NovaConfig(apiKey: 'valid_key');
      final nova = await Nova.initialize(config: config);

      expect(Nova.isInitialized, isTrue);
      expect(Nova.instance, same(nova));
      expect(Nova.instance.config.apiKey, 'valid_key');
    });

    test('initialize with empty resolved token throws NovaAuthException', () async {
      final config = NovaConfig(
        tokenResolver: () async => '   ',
      );

      expect(
        () => Nova.initialize(config: config),
        throwsA(isA<NovaAuthException>()),
      );
      expect(Nova.isInitialized, isFalse);
    });

    test('reset clears instance and initialized state', () async {
      const config = NovaConfig(apiKey: 'valid_key');
      await Nova.initialize(config: config);

      expect(Nova.isInitialized, isTrue);

      Nova.reset();

      expect(Nova.isInitialized, isFalse);
      expect(
        () => Nova.instance,
        throwsA(isA<NovaNotInitializedException>()),
      );
    });
  });

  group('NovaException', () {
    test('NovaNotInitializedException outputs formatted toString', () {
      const exception = NovaNotInitializedException('Not ready');
      expect(exception.toString(), 'NovaException: Not ready');
    });

    test('NovaAuthException outputs formatted toString', () {
      const exception = NovaAuthException('Invalid auth');
      expect(exception.toString(), 'NovaException: Invalid auth');
    });
  });

  group('NovaFloatingButton Widget', () {
    testWidgets('renders button and displays SnackBar on tap', (WidgetTester tester) async {
      const config = NovaConfig(apiKey: 'widget_key');
      await Nova.initialize(config: config);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Body')),
            floatingActionButton: NovaFloatingButton(),
          ),
        ),
      );

      expect(find.byType(NovaFloatingButton), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);

      await tester.tap(find.byType(NovaFloatingButton));
      await tester.pumpAndSettle();

      expect(
        find.text('Nova Chat Initialized with token: widget_key'),
        findsOneWidget,
      );
    });
  });
}
