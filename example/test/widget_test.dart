import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';
import 'package:kockatoos_nova_ai_chatbot/kockatoos_nova_ai_chatbot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Nova.reset();
  });

  testWidgets('MyApp renders main app bar and NovaFloatingButton', (WidgetTester tester) async {
    await Nova.initialize(
      config: const NovaConfig(
        apiKey: 'test_token_12345',
        logLevel: NovaLogLevel.debug,
      ),
    );

    await tester.pumpWidget(const MyApp());

    expect(find.text('Nova Package Local Test'), findsOneWidget);
    expect(find.text('Main Application Screen'), findsOneWidget);
    expect(find.byType(NovaFloatingButton), findsOneWidget);
  });
}
