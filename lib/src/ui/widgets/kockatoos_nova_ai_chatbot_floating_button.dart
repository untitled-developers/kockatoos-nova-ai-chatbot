import 'package:flutter/material.dart';

import '../../core/kockatoos_nova_ai_chatbot_client.dart';
import '../controllers/nova_chat_controller.dart';
import '../theme/nova_theme.dart';
import 'nova_chat_view.dart';

class NovaFloatingButton extends StatefulWidget {
  final NovaChatController? controller;

  const NovaFloatingButton({
    super.key,
    this.controller,
  });

  @override
  State<NovaFloatingButton> createState() => _NovaFloatingButtonState();
}

class _NovaFloatingButtonState extends State<NovaFloatingButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScaleAnimation;
  late final Animation<double> _pulseOpacityAnimation;
  NovaChatController? _internalController;
  bool _isPressed = false;

  NovaChatController? get _effectiveController {
    if (widget.controller != null) return widget.controller;
    if (!Nova.isInitialized) return null;
    return _internalController ??= NovaChatController(config: Nova.instance.config);
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseScaleAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _pulseOpacityAnimation = Tween<double>(begin: 0.35, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Nova.isInitialized && !Nova.instance.isAllowed) {
      return const SizedBox.shrink();
    }

    final activeController = _effectiveController;
    if (activeController != null && !activeController.isAllowed) {
      return const SizedBox.shrink();
    }

    final theme = activeController?.theme ?? NovaTheme.defaultKockatoos;

    return AnimatedScale(
      scale: _isPressed ? 0.92 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          if (activeController == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Nova SDK is not initialized. Please call `await Nova.initialize(...)` in your main() function before using NovaFloatingButton.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
            return;
          }

          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: false,
            backgroundColor: Colors.transparent,
            builder: (context) {
              return FractionallySizedBox(
                heightFactor: 0.88,
                child: NovaChatView(
                  controller: activeController,
                  isModal: true,
                  onClose: () => Navigator.of(context).pop(),
                ),
              );
            },
          );
        },
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Outer Soft Pulsing Ring
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseScaleAnimation.value,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.primary.withValues(alpha: _pulseOpacityAnimation.value),
                      ),
                    ),
                  );
                },
              ),
              // Main Floating Button
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [theme.gradientFrom, theme.gradientTo],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primary.withValues(alpha: 0.38),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              // Online Notification Badge
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
