import 'package:flutter/material.dart';

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
  bool _showScrollBottom = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? NovaChatController(config: Nova.instance.config);
    _controller.addListener(_onControllerUpdate);
    _scrollController.addListener(_onScroll);

    if (_controller.state is NovaChatInitial) {
      _controller.initialize();
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
      _scrollToBottomIfNearEnd();
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
    if (!_scrollController.hasClients) return;
    if (force || !_showScrollBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
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
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22),
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
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Online • Usually replies instantly',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
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
            return _buildMessageBubble(msgs[index], theme);
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
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: isUser ? theme.userBubbleText : theme.botBubbleText,
                    ),
                  ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.gradientFrom, theme.gradientTo]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.botBubbleBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Typing...',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(NovaTheme theme) {
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
              IconButton(
                icon: const Icon(Icons.sentiment_satisfied_alt, color: Color(0xFF64748B)),
                onPressed: _showEmojiPicker,
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  minLines: 1,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Ask a question...',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: (!isBusy && hasText) ? theme.primary : Colors.grey.shade400,
                ),
                onPressed: (!isBusy && hasText)
                    ? () {
                        final text = _textController.text;
                        _textController.clear();
                        setState(() {});
                        _controller.sendMessage(text);
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
