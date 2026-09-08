import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../config/kockatoos_nova_ai_chatbot_config.dart';
import '../../core/kockatoos_nova_ai_chatbot_client.dart';
import '../../data/models/nova_chat_message.dart';
import '../controllers/nova_chat_controller.dart';
import '../theme/nova_theme.dart';

class NovaChatView extends StatefulWidget {
  final NovaChatController? controller;
  final VoidCallback? onClose;
  final bool isModal;

  const NovaChatView({
    super.key,
    this.controller,
    this.onClose,
    this.isModal = false,
  });

  @override
  State<NovaChatView> createState() => _NovaChatViewState();
}

class _NovaChatViewState extends State<NovaChatView> {
  late final NovaChatController _controller;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _showScrollBottom = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else if (Nova.isInitialized) {
      _controller = NovaChatController(config: Nova.instance.config);
    } else {
      _controller = NovaChatController(
        config: NovaConfig(apiKey: 'uninitialized', logLevel: NovaLogLevel.none),
      );
    }

    _controller.addListener(_onControllerUpdate);
    _scrollController.addListener(_onScroll);

    if (_controller.state is NovaChatInitial) {
      _controller.initialize().then((_) {
        _scrollToBottom(true);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(true);
      });
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
      if (_controller.isStreaming || _controller.isTyping) {
        _scrollToBottom(true);
      } else {
        _scrollToBottomIfNearEnd();
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final shouldShow = (maxScroll - currentScroll) > 120;
    if (shouldShow != _showScrollBottom) {
      setState(() {
        _showScrollBottom = shouldShow;
      });
    }
  }

  void _scrollToBottom([bool force = false]) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (!force && _showScrollBottom) return;

      void performScroll() {
        if (!_scrollController.hasClients) return;
        final maxScroll = _scrollController.position.maxScrollExtent;
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );

        _scrollTimer?.cancel();
        _scrollTimer = Timer(const Duration(milliseconds: 220), () {
          if (mounted && _scrollController.hasClients) {
            final newMax = _scrollController.position.maxScrollExtent;
            if ((newMax - _scrollController.position.pixels).abs() > 4) {
              _scrollController.jumpTo(newMax);
            }
          }
        });
      }

      performScroll();
    });
  }

  void _scrollToBottomIfNearEnd() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if ((maxScroll - currentScroll) < 150) {
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _controller.theme;
    final state = _controller.state;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: !widget.isModal,
        bottom: true,
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: Stack(
                children: [
                  _buildBody(state, theme),
                  if (_showScrollBottom)
                    Positioned(
                      bottom: 12,
                      right: 16,
                      child: FloatingActionButton.small(
                        heroTag: 'nova_scroll_bottom',
                        backgroundColor: theme.primary,
                        elevation: 3,
                        onPressed: () => _scrollToBottom(true),
                        child: const Icon(Icons.arrow_downward, color: Colors.white, size: 18),
                      ),
                    ),
                ],
              ),
            ),
            _buildInputBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(NovaTheme theme) {
    final agentName = _controller.remoteConfig?.agentName ??
        Nova.instance.config.agentName ??
        'Kockatoos Nova';

    final profilePicUrl = _controller.remoteConfig?.profilePicUrl;

    Widget avatarChild;
    if (profilePicUrl != null && profilePicUrl.trim().isNotEmpty) {
      avatarChild = ClipOval(
        child: Image.network(
          profilePicUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22),
        ),
      );
    } else {
      avatarChild = const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22);
    }

    final isEnabled = _controller.remoteConfig?.isEnabled ?? true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.gradientFrom, theme.gradientTo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: avatarChild,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agentName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isEnabled ? const Color(0xFF10B981) : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isEnabled ? 'Online • Usually replies instantly' : 'Offline • Disabled by admin',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isEnabled ? const Color(0xFF64748B) : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _controller.soundEnabled ? Icons.volume_up : Icons.volume_off,
              color: const Color(0xFF64748B),
            ),
            tooltip: 'Toggle sound',
            onPressed: _controller.toggleSound,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            tooltip: 'New Conversation',
            onPressed: _confirmResetConversation,
          ),
          if (widget.onClose != null || widget.isModal)
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF64748B)),
              tooltip: 'Close chat',
              onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(NovaChatState state, NovaTheme theme) {
    if (state is NovaChatLoading || state is NovaChatInitial) {
      return Center(
        child: CircularProgressIndicator(color: theme.primary),
      );
    }

    if (state is NovaChatError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
                onPressed: () => _controller.initialize(),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (state is NovaChatLoaded) {
      final msgs = state.messages;
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: msgs.length + (state.isTyping ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < msgs.length) {
            return _AnimatedMessageBubble(
              key: ValueKey(msgs[index].id),
              child: _buildMessageBubble(msgs[index], theme),
            );
          } else {
            return _buildTypingIndicator(theme);
          }
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMessageBubble(NovaChatMessage msg, NovaTheme theme) {
    final isUser = msg.sender == NovaMessageSender.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.gradientFrom, theme.gradientTo],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? theme.userBubbleBg : theme.botBubbleBg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildMessageTextContent(msg, isUser, theme),
                ),
                const SizedBox(height: 4),
                Text(
                  msg.timestamp,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
                if (!isUser && msg.pills != null && msg.pills!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: msg.pills!.map((pill) {
                      return InkWell(
                        onTap: () {
                          _controller.sendMessage(pill);
                          _scrollToBottom(true);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.primaryLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            pill,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(NovaTheme theme) {
    final agentName = _controller.remoteConfig?.agentName ??
        Nova.instance.config.agentName ??
        'Kockatoos Nova';

    return _AnimatedMessageBubble(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _PulsingAvatarRing(
              theme: theme,
              profilePicUrl: _controller.remoteConfig?.profilePicUrl,
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.botBubbleBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$agentName is typing',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 8),
                  _AnimatedBouncingDots(color: theme.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(NovaTheme theme) {
    final isEnabled = _controller.remoteConfig?.isEnabled ?? true;
    final allowEmojis = _controller.remoteConfig?.allowEmojis ?? true;
    final isBusy = _controller.isStreaming || _controller.isTyping;
    final hasText = _textController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (allowEmojis)
                IconButton(
                  icon: const Icon(Icons.sentiment_satisfied_alt, color: Color(0xFF64748B)),
                  onPressed: isEnabled ? _showEmojiPicker : null,
                ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  enabled: isEnabled,
                  minLines: 1,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: isEnabled ? 'Ask a question...' : 'Chatbot is currently disabled by admin.',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: (isEnabled && !isBusy && hasText) ? theme.primary : Colors.grey.shade400,
                ),
                onPressed: (isEnabled && !isBusy && hasText)
                    ? () {
                        final text = _textController.text;
                        _textController.clear();
                        setState(() {});
                        _controller.sendMessage(text);
                        _scrollToBottom(true);
                      }
                    : null,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: Text(
                  '${_textController.text.length}/1000',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final emojis = ['👋', '🚀', '🎨', '💳', '🤖', '✨', '👍', '🔥', '❤️', '💡', '💬', '❓'];
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: emojis.length,
          itemBuilder: (context, index) {
            return InkWell(
              onTap: () {
                _textController.text += emojis[index];
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _textController.text.length),
                );
                setState(() {});
                Navigator.of(context).pop();
              },
              child: Center(
                child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageTextContent(NovaChatMessage msg, bool isUser, NovaTheme theme) {
    final textColor = isUser ? theme.userBubbleText : theme.botBubbleText;

    if (isUser) {
      return Text(
        msg.text,
        style: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: textColor,
        ),
      );
    }

    return MarkdownBody(
      data: msg.text,
      selectable: true,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 14, height: 1.4, color: textColor),
        strong: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
        em: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: textColor),
        code: TextStyle(
          fontSize: 13,
          fontFamily: 'monospace',
          backgroundColor: Colors.black.withValues(alpha: 0.06),
          color: theme.primaryText,
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        listBullet: TextStyle(fontSize: 14, color: textColor),
        h1: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        h2: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
        h3: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  void _confirmResetConversation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Start New Conversation?'),
          content: const Text(
            'Your current conversation thread history will be cleared and a new session will begin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _controller.theme.primary),
              onPressed: () {
                Navigator.of(context).pop();
                _controller.resetConversation();
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedMessageBubble extends StatefulWidget {
  final Widget child;
  const _AnimatedMessageBubble({super.key, required this.child});

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class _PulsingAvatarRing extends StatefulWidget {
  final NovaTheme theme;
  final String? profilePicUrl;

  const _PulsingAvatarRing({
    required this.theme,
    this.profilePicUrl,
  });

  @override
  State<_PulsingAvatarRing> createState() => _PulsingAvatarRingState();
}

class _PulsingAvatarRingState extends State<_PulsingAvatarRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget avatarChild;
    if (widget.profilePicUrl != null && widget.profilePicUrl!.trim().isNotEmpty) {
      avatarChild = ClipOval(
        child: Image.network(
          widget.profilePicUrl!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 18),
        ),
      );
    } else {
      avatarChild = const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 18);
    }

    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.theme.primary.withValues(alpha: _opacityAnimation.value),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [widget.theme.gradientFrom, widget.theme.gradientTo]),
              shape: BoxShape.circle,
            ),
            child: avatarChild,
          ),
        ],
      ),
    );
  }
}

class _AnimatedBouncingDots extends StatefulWidget {
  final Color color;
  const _AnimatedBouncingDots({required this.color});

  @override
  State<_AnimatedBouncingDots> createState() => _AnimatedBouncingDotsState();
}

class _AnimatedBouncingDotsState extends State<_AnimatedBouncingDots> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: -4).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[i].value),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
