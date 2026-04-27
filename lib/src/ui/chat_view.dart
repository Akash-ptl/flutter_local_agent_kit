import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_local_agent_kit/src/core/models.dart';
import 'package:flutter_local_agent_kit/src/utils/voice_service.dart';

/// A high-performance, markdown-capable chat interface for AI agents.
class AgentChatView extends StatefulWidget {
  /// The callback invoked when a user sends a message.
  /// Should return a stream of response tokens.
  final Stream<String> Function(
    String query, {
    List<int>? imageBytes,
    void Function(List<RetrievalResult>)? onCitations,
  }) onMessage;

  /// Optional welcome message displayed when the chat starts.
  final String? welcomeMessage;

  /// Optional list of suggestion chips to show when starting a conversation.
  final List<String>? suggestions;

  /// The title displayed in the AppBar.
  final String title;

  /// Primary color for user messages and UI elements.
  final Color? accentColor;

  /// Optional initial history to display when the view loads.
  final List<AgentChatMessage>? initialHistory;

  /// Optional callback invoked whenever the message history changes.
  /// Useful for auto-saving sessions.
  final void Function(List<AgentChatMessage> history)? onHistoryChanged;

  /// Creates an [AgentChatView].
  ///
  /// The widget renders a simple chat transcript and streams assistant output
  /// from [onMessage] directly into the last assistant bubble.
  const AgentChatView({
    super.key,
    required this.onMessage,
    this.welcomeMessage,
    this.suggestions,
    this.title = 'AI Assistant',
    this.accentColor,
    this.initialHistory,
    this.onHistoryChanged,
  });

  @override

  /// Creates the mutable state backing the chat transcript and input controls.
  State<AgentChatView> createState() => _AgentChatViewState();
}

class _AgentChatViewState extends State<AgentChatView> {
  final TextEditingController _controller = TextEditingController();
  final List<AgentChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isProcessing = ValueNotifier(false);
  final ValueNotifier<String> _streamingContent = ValueNotifier("");
  String? _activeAssistantId;
  Uint8List? _selectedImageBytes;
  final ImagePicker _picker = ImagePicker();
  final VoiceService _voice = VoiceService();
  final ValueNotifier<bool> _isListening = ValueNotifier(false);
  final ValueNotifier<List<RetrievalResult>> _streamingCitations = ValueNotifier([]);
  final ValueNotifier<double> _scrollPos = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollPos.value = _scrollController.offset;
      }
    });
    if (widget.initialHistory != null) {
      _messages.addAll(widget.initialHistory!);
    } else if (widget.welcomeMessage != null) {
      _messages.add(AgentChatMessage.assistant(widget.welcomeMessage!));
    }
    _voice.initialize();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
      });
    }
  }

  Future<void> _toggleListening() async {
    try {
      await _voice.listen(
        onResult: (text) {
          _controller.text = text;
        },
        onListeningChange: (listening) {
          _isListening.value = listening;
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice Error: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _selectedImageBytes == null) || _isProcessing.value) return;

    final imageToSend = _selectedImageBytes;

    setState(() {
      _messages.add(AgentChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: text,
        role: MessageRole.user,
        timestamp: DateTime.now(),
        imageBytes: imageToSend,
      ));
      _controller.clear();
      _selectedImageBytes = null;
      _isProcessing.value = true;
    });
    _scrollToBottom();

    final assistantMessageId = DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      _messages.add(AgentChatMessage.assistant("", id: assistantMessageId));
    });

    _streamingContent.value = "";
    _streamingCitations.value = [];
    _activeAssistantId = assistantMessageId;

    try {
      List<RetrievalResult> citations = [];
      await for (final token in widget.onMessage(
        text,
        imageBytes: imageToSend,
        onCitations: (results) {
          citations = results;
          _streamingCitations.value = results;
        },
      )) {
        _streamingContent.value += token;
        _scrollToBottom();
      }

      final finalContent = _streamingContent.value;
      final index = _messages.indexWhere((m) => m.id == assistantMessageId);
      if (index != -1) {
        setState(() {
          _messages[index] = AgentChatMessage.assistant(
            finalContent,
            id: assistantMessageId,
            metadata: citations.isNotEmpty
                ? {
                    'citations': citations.map((c) => c.toJson()).toList(),
                  }
                : null,
          );
          _streamingContent.value = "";
          _activeAssistantId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        final index = _messages.indexWhere((m) => m.id == assistantMessageId);
        if (index != -1) {
          setState(() {
            _messages[index] = AgentChatMessage.assistant(
              'Sorry, something went wrong while generating a response.\n\nError: $e',
              id: assistantMessageId,
            );
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    } finally {
      if (mounted) {
        _isProcessing.value = false;
        _activeAssistantId = null;
      }
      widget.onHistoryChanged?.call(List.from(_messages));
    }
  }

  MarkdownStyleSheet _markdownStyle(ThemeData theme, bool isUser) {
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(
        color: isUser ? Colors.white : theme.colorScheme.onSurfaceVariant,
      ),
      code: theme.textTheme.bodySmall?.copyWith(
        backgroundColor: Colors.transparent,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.accentColor ?? theme.colorScheme.primary;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.enter):
            const _SendIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
            const _SendIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
            const _ClearIntent(),
      },
      child: Actions(
        actions: {
          _SendIntent: CallbackAction<_SendIntent>(
            onInvoke: (_) => _sendMessage(),
          ),
          _ClearIntent: CallbackAction<_ClearIntent>(
            onInvoke: (_) {
              setState(() => _messages.clear());
              return null;
            },
          ),
        },
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    cacheExtent: 500, // Pre-render bubbles for smooth scrolling
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message.role == MessageRole.user;

                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width *
                            (MediaQuery.of(context).size.width > 800
                                ? 0.6
                                : 0.85),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser)
                              _buildAvatar(Icons.smart_toy_rounded, accent),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? accent
                                      : theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                  borderRadius:
                                      BorderRadius.circular(16).copyWith(
                                    bottomRight: isUser
                                        ? const Radius.circular(0)
                                        : null,
                                    bottomLeft: !isUser
                                        ? const Radius.circular(0)
                                        : null,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (message.imageBytes != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.memory(
                                                Uint8List.fromList(
                                                    message.imageBytes!),
                                                height: 200,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        _activeAssistantId == message.id
                                            ? ValueListenableBuilder<String>(
                                                valueListenable:
                                                    _streamingContent,
                                                builder: (context, content, _) {
                                                  return MarkdownBody(
                                                    data: content.isEmpty
                                                        ? "..."
                                                        : content,
                                                    selectable: true,
                                                    builders: {
                                                      'code': CodeBlockBuilder(
                                                          context),
                                                    },
                                                    styleSheet: _markdownStyle(
                                                        theme, isUser),
                                                  );
                                                },
                                              )
                                            : MarkdownBody(
                                                data: message.content,
                                                selectable: true,
                                                builders: {
                                                  'code': CodeBlockBuilder(
                                                      context),
                                                },
                                                styleSheet: _markdownStyle(
                                                    theme, isUser),
                                              ),
                                        _activeAssistantId == message.id
                                            ? ValueListenableBuilder<
                                                List<RetrievalResult>>(
                                                valueListenable:
                                                    _streamingCitations,
                                                builder: (context, cits, _) {
                                                  if (cits.isEmpty) {
                                                    return const SizedBox
                                                        .shrink();
                                                  }
                                                  return _buildCitations(
                                                      cits, theme, accent);
                                                },
                                              )
                                            : (message.metadata?['citations'] !=
                                                    null
                                                ? _buildCitations(
                                                    message.metadata![
                                                        'citations'],
                                                    theme,
                                                    accent)
                                                : const SizedBox.shrink()),
                                      ],
                                    ),
                                    if (!isUser &&
                                        _activeAssistantId != message.id)
                                      Positioned(
                                        right: -8,
                                        top: -8,
                                        child: IconButton(
                                          icon: Icon(Icons.volume_up_rounded,
                                              size: 16,
                                              color: theme
                                                  .colorScheme.onSurfaceVariant
                                                  .withValues(alpha: 0.5)),
                                          onPressed: () =>
                                              _voice.speak(message.content),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isUser)
                              _buildAvatar(Icons.person_rounded, Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 16,
                    right: 16,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _scrollPos,
                      builder: (context, pos, _) {
                        if (!_scrollController.hasClients ||
                            !_scrollController.position.hasContentDimensions ||
                            _scrollController.position.maxScrollExtent - pos <
                                400) {
                          return const SizedBox.shrink();
                        }
                        return FloatingActionButton.small(
                          heroTag: 'chat_scroll_btn',
                          onPressed: () => _scrollToBottom(),
                          backgroundColor: accent.withValues(alpha: 0.9),
                          child: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Colors.white),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isProcessing,
              builder: (context, processing, _) {
                if (processing &&
                    _messages.isNotEmpty &&
                    _messages.last.content.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            if (widget.suggestions != null) _buildSuggestions(theme, accent),
            if (_selectedImageBytes != null) _buildImagePreview(theme),
            _buildInputArea(theme, accent),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 100,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_selectedImageBytes!),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() => _selectedImageBytes = null),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: theme.colorScheme.error,
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCitations(dynamic citations, ThemeData theme, Color accent) {
    if (citations is! List) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          Row(
            children: [
              Icon(Icons.auto_stories_rounded, size: 14, color: accent),
              const SizedBox(width: 6),
              Text(
                'Sources',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: citations.map((c) {
              final source = c['source'];
              final title = source is Map ? source['title'] ?? 'Source' : 'Source';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.1)),
                ),
                child: Text(
                  title as String,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
            IconButton(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<bool>(
              valueListenable: _isListening,
              builder: (context, isListening, _) {
                return IconButton(
                  onPressed: _toggleListening,
                  icon: Icon(
                    isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: isListening ? Colors.red : null,
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30)),
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
    _streamingContent.dispose();
    _isListening.dispose();
    _streamingCitations.dispose();
    _voice.dispose();
    super.dispose();
  }
}

/// Custom builder for code blocks to add a copy button.
class CodeBlockBuilder extends MarkdownElementBuilder {
  /// The [BuildContext] used for accessing themes and showing snackbars.
  final BuildContext context;

  /// Creates a [CodeBlockBuilder].
  CodeBlockBuilder(this.context);

  /// Builds the code block widget with a custom layout and copy button.
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final textContent = element.textContent;
    final isCodeBlock = element.tag == 'pre' ||
        (element.tag == 'code' && textContent.contains('\n'));

    if (!isCodeBlock) return null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Code',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: textContent));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1)),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              textContent,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendIntent extends Intent {
  const _SendIntent();
}

class _ClearIntent extends Intent {
  const _ClearIntent();
}
