import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';
import 'package:kockatoos_nova_ai_chatbot/kockatoos_nova_ai_chatbot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Nova.reset();
  });

  testWidgets('MyApp renders HomeScreen with NovaFloatingButton and Chat tab', (WidgetTester tester) async {
    await Nova.initialize(
      config: const NovaConfig(
        apiKey: 'test_token_12345',
        theme: 'emerald',
        logLevel: NovaLogLevel.debug,
      ),
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Kockatoos Nova Chatbot App'), findsOneWidget);
    expect(find.text('Welcome to Kockatoos Nova SDK Demo'), findsOneWidget);
    expect(find.byType(NovaFloatingButton), findsOneWidget);

    // Switch to Chat tab
    await tester.tap(find.byIcon(Icons.chat));
    await tester.pumpAndSettle();

    expect(find.byType(NovaChatView), findsOneWidget);
  });
}
