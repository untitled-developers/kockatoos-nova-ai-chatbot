# Kockatoos Nova AI Chatbot SDK (`kockatoos_nova_ai_chatbot`)

Official Flutter SDK for integrating the **Kockatoos Nova AI Chatbot** into Flutter mobile and web applications.

## Features

- ⚡ **Easy Initialization**: Configure with API key or dynamic token resolver.
- 🎨 **Floating Chat Button**: Ready-to-use widget (`NovaFloatingButton`) for launching chat dialogs.
- 🛡️ **Type-Safe Exceptions**: Explicit exception hierarchy (`NovaNotInitializedException`, `NovaAuthException`).

## Getting Started

Add the package dependency to your `pubspec.yaml`:

```yaml
dependencies:
  kockatoos_nova_ai_chatbot:
    path: ../kockatoos_nova_ai_chatbot # Or git/pub package reference
```

## Usage

Initialize `Nova` in your `main()` method before launching `runApp()`:

```dart
import 'package:flutter/material.dart';
import 'package:kockatoos_nova_ai_chatbot/kockatoos_nova_ai_chatbot.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Nova.initialize(
    config: const NovaConfig(
      apiKey: 'YOUR_API_KEY',
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
        appBar: AppBar(title: const Text('Kockatoos Nova Chat')),
        body: const Center(child: Text('App Content')),
        floatingActionButton: const NovaFloatingButton(),
      ),
    );
  }
}
```

## Additional Information

For issues, contributions, and documentation, visit the [Kockatoos Repository](https://github.com/untitled-developers/kockatoos-nova-ai-chatbot).
