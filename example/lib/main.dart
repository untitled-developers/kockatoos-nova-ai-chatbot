import 'package:flutter/material.dart';
import 'package:kockatoos_nova_ai_chatbot/kockatoos_nova_ai_chatbot.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Nova
  await Nova.initialize(
    config: const NovaConfig(
      apiKey: 'test_token_12345',
      logLevel: NovaLogLevel.debug,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Nova Package Local Test')),
        body: const Center(child: Text('Main Application Screen')),
        floatingActionButton: const NovaFloatingButton(),
      ),
    );
  }
}
