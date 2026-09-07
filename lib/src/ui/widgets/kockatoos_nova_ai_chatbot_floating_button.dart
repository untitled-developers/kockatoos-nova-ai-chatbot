import 'package:flutter/material.dart';

import '../../core/kockatoos_nova_ai_chatbot_client.dart';
import '../controllers/nova_chat_controller.dart';
import 'nova_chat_view.dart';

class NovaFloatingButton extends StatelessWidget {
  final NovaChatController? controller;

  const NovaFloatingButton({
    super.key,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final activeController = controller ?? NovaChatController(config: Nova.instance.config);
    final theme = activeController.theme;

    return FloatingActionButton(
      backgroundColor: theme.primary,
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return FractionallySizedBox(
              heightFactor: 0.85,
              child: NovaChatView(
                controller: activeController,
                isModal: true,
                onClose: () => Navigator.of(context).pop(),
              ),
            );
          },
        );
      },
      child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
    );
  }
}
