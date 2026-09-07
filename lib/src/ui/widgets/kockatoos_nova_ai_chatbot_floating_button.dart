import 'package:flutter/material.dart';

import '../../core/kockatoos_nova_ai_chatbot_client.dart';

class NovaFloatingButton extends StatelessWidget {
  const NovaFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Access guard check
    final nova = Nova.instance;

    return FloatingActionButton(
      backgroundColor: Theme.of(context).primaryColor,
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nova Chat Initialized with token: ${nova.config.apiKey}',
            ),
          ),
        );
      },
      child: const Icon(Icons.chat_bubble_outline),
    );
  }
}
