import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_local_agent_kit/src/core/models.dart';

/// A high-performance, markdown-capable chat interface for AI agents.
class AgentChatView extends StatefulWidget {
  /// The callback invoked when a user sends a message. 
  /// Should return a stream of response tokens.
  final Stream<String> Function(String query) onMessage;
  
  /// Optional welcome message displayed when the chat starts.
  final String? welcomeMessage;

  /// Optional list of suggestion chips to show when starting a conversation.
  final List<String>? suggestions;

  /// The title displayed in the AppBar.
  final String title;
  
  /// Primary color for user messages and UI elements.
  final Color? accentColor;

  /// Creates an [AgentChatView].
  const AgentChatView({
    super.key,
    required this.onMessage,
    this.welcomeMessage,
    this.suggestions,
    this.title = 'AI Assistant',
    this.accentColor,
  });


  @override
  State<AgentChatView> createState() => _AgentChatViewState();
}

class _AgentChatViewState extends State<AgentChatView> {
  final TextEditingController _controller = TextEditingController();
  final List<AgentChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isProcessing = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    if (widget.welcomeMessage != null) {
      _messages.add(AgentChatMessage.assistant(widget.welcomeMessage!));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isProcessing.value) return;

    setState(() {
      _messages.add(AgentChatMessage.user(text));
      _controller.clear();
      _isProcessing.value = true;
    });
    _scrollToBottom();

    String responseBuffer = "";
    final assistantMessageId = DateTime.now().millisecondsSinceEpoch.toString();
    
    setState(() {
      _messages.add(AgentChatMessage.assistant("", id: assistantMessageId));
    });

    try {
      await for (final token in widget.onMessage(text)) {
        responseBuffer += token;
        final index = _messages.indexWhere((m) => m.id == assistantMessageId);
        if (index != -1) {
          setState(() {
            _messages[index] = AgentChatMessage.assistant(
              responseBuffer,
              id: assistantMessageId,
            );
          });
        }
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        _isProcessing.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.accentColor ?? theme.colorScheme.primary;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isUser = message.role == MessageRole.user;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isUser) _buildAvatar(Icons.smart_toy_rounded, accent),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? accent : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isUser ? const Radius.circular(0) : null,
                            bottomLeft: !isUser ? const Radius.circular(0) : null,
                          ),
                        ),
                        child: MarkdownBody(
                          data: message.content,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                            p: theme.textTheme.bodyMedium?.copyWith(
                              color: isUser ? Colors.white : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isUser) _buildAvatar(Icons.person_rounded, Colors.grey),
                  ],
                ),
              );
            },
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _isProcessing,
          builder: (context, processing, _) {
            if (processing && _messages.isNotEmpty && _messages.last.content.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: LinearProgressIndicator(minHeight: 2),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        if (widget.suggestions != null)
          _buildSuggestions(theme, accent),

        _buildInputArea(theme, accent),
      ],
    );
  }

  Widget _buildSuggestions(ThemeData theme, Color accent) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.suggestions!.length,
        itemBuilder: (context, index) {
          final suggestion = widget.suggestions![index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(suggestion, style: const TextStyle(fontSize: 12)),
              onPressed: () {
                _controller.text = suggestion;
                _sendMessage();
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(IconData icon, Color color) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildInputArea(ThemeData theme, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.cardColor),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onSubmitted: (value) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _isProcessing.dispose();
    super.dispose();
  }
}
