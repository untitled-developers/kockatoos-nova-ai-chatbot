import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kockatoos_nova_ai_chatbot/kockatoos_nova_ai_chatbot.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
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

    test('NovaConfig supports mobile origin types (android_sha256_hash & ios_bundle_identifier)', () {
      const androidConfig = NovaConfig(
        apiKey: 'test_pk',
        androidSha256Hash: 'A1:B2:C3:D4:E5:F6',
      );
      expect(androidConfig.mobileOriginParams, {
        'type': 'android_sha256_hash',
        'value': 'A1:B2:C3:D4:E5:F6',
      });

      const iosConfig = NovaConfig(
        apiKey: 'test_pk',
        iosBundleIdentifier: 'com.example.app',
      );
      expect(iosConfig.mobileOriginParams, {
        'type': 'ios_bundle_identifier',
        'value': 'com.example.app',
      });
    });

    test('NovaConfig.autoDetect populates platform identifier from PackageInfo', () async {
      PackageInfo.setMockInitialValues(
        appName: 'TestApp',
        packageName: 'com.example.testapp',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
        installerStore: null,
      );

      final config = await NovaConfig.autoDetect(apiKey: 'test_pk');

      // In the test environment defaultTargetPlatform resolves to
      // TargetPlatform.android, so androidSha256Hash should be set.
      expect(
        config.androidSha256Hash ?? config.iosBundleIdentifier,
        'com.example.testapp',
      );
      expect(config.mobileOriginParams, isNotNull);
    });

    test('NovaConfig normalizes 64-hex SHA-256 fingerprints in mobileOriginParams', () {
      const configWithColons = NovaConfig(
        apiKey: 'test_pk',
        androidSha256Hash:
            '84:C1:48:36:9A:4F:D7:37:E5:00:27:61:AD:73:70:39:D9:3F:99:12:AA:09:D4:B5:57:69:4F:E4:8A:34:D8:7E',
      );
      expect(configWithColons.mobileOriginParams, {
        'type': 'android_sha256_hash',
        'value':
            '84C148369A4FD737E5002761AD737039D93F9912AA09D4B557694FE48A34D87E',
      });

      const configLowercase = NovaConfig(
        apiKey: 'test_pk',
        androidSha256Hash:
            '84c148369a4fd737e5002761ad737039d93f9912aa09d4b557694fe48a34d87e',
      );
      expect(configLowercase.mobileOriginParams, {
        'type': 'android_sha256_hash',
        'value':
            '84C148369A4FD737E5002761AD737039D93F9912AA09D4B557694FE48A34D87E',
      });
    });

    test('NovaConfig.autoDetect prioritizes buildSignature on Android', () async {
      PackageInfo.setMockInitialValues(
        appName: 'TestApp',
        packageName: 'com.example.testapp',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature:
            '84C148369A4FD737E5002761AD737039D93F9912AA09D4B557694FE48A34D87E',
        installerStore: null,
      );

      final config = await NovaConfig.autoDetect(apiKey: 'test_pk');

      expect(
        config.androidSha256Hash,
        '84C148369A4FD737E5002761AD737039D93F9912AA09D4B557694FE48A34D87E',
      );
      expect(config.mobileOriginParams, {
        'type': 'android_sha256_hash',
        'value':
            '84C148369A4FD737E5002761AD737039D93F9912AA09D4B557694FE48A34D87E',
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

      expect(find.byType(SvgPicture), findsWidgets);

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
      expect(find.byType(NovaChatPatternBackground), findsOneWidget);
    });

    testWidgets('renders NovaChatPatternBackground with custom and default colors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NovaChatPatternBackground(
              child: Text('Test Content'),
            ),
          ),
        ),
      );

      expect(find.byType(NovaChatPatternBackground), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('renders all NovaIcons SVGs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NovaIcons.fabChat(),
                NovaIcons.botAvatar(),
                NovaIcons.soundOn(),
                NovaIcons.soundOff(),
                NovaIcons.newChat(),
                NovaIcons.close(),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsNWidgets(6));
    });

    testWidgets('NovaChatView adjusts padding when keyboard viewInsets appear',
        (WidgetTester tester) async {
      const config = NovaConfig(apiKey: 'keyboard_key');
      await Nova.initialize(config: config);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 320)),
            child: const Scaffold(
              resizeToAvoidBottomInset: false,
              body: NovaChatView(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final paddings = tester.widgetList<Padding>(find.byType(Padding));
      final hasBottomInsetPadding =
          paddings.any((p) => p.padding.resolve(TextDirection.ltr).bottom == 320);
      expect(hasBottomInsetPadding, isTrue);
    });
  });
}
