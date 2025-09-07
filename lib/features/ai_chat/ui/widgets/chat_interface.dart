import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_session_controller.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_sessions_controller.dart';
import 'package:lotti/features/ai_chat/ui/providers/chat_model_providers.dart';
import 'package:lotti/features/ai_chat/ui/widgets/thinking_parser.dart';
import 'package:lotti/features/ai_chat/ui/widgets/waveform_bars.dart';

/// Top-level chat UI for the AI Assistant. Renders messages, streaming
/// placeholders, and a collapsible "reasoning" disclosure when hidden
/// thinking content is present. See `thinking_parser.dart` for extraction.
class ChatInterface extends ConsumerStatefulWidget {
  const ChatInterface({
    required this.categoryId,
    this.sessionId,
    super.key,
  });

  final String categoryId;
  final String? sessionId;

  @override
  ConsumerState<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends ConsumerState<ChatInterface> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize session when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSession();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeSession() async {
    final controller =
        ref.read(chatSessionControllerProvider(widget.categoryId).notifier);
    await controller.initializeSession(sessionId: widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final sessionState =
        ref.watch(chatSessionControllerProvider(widget.categoryId));
    final sessionController =
        ref.read(chatSessionControllerProvider(widget.categoryId).notifier);
    final sessionsController =
        ref.read(chatSessionsControllerProvider(widget.categoryId).notifier);

    return Column(
      children: [
        // Header with session management
        _ChatHeader(
          sessionTitle: sessionState.displayTitle,
          canClearChat: sessionState.hasMessages,
          onClearChat: sessionController.clearChat,
          onNewSession: sessionsController.createNewSession,
          categoryId: widget.categoryId,
          selectedModelId: sessionState.selectedModelId,
          isStreaming: sessionState.isStreaming,
          onSelectModel: sessionController.setModel,
        ),

        // Messages area
        Expanded(
          child: _MessagesArea(
            messages: sessionState.messages,
            scrollController: _scrollController,
          ),
        ),

        // Error display
        if (sessionState.error != null)
          _ErrorBanner(
            error: sessionState.error!,
            onRetry: sessionController.retryLastMessage,
            onDismiss: sessionController.clearError,
          ),

        // Input area
        _InputArea(
          controller: _textController,
          scrollController: _scrollController,
          isLoading: sessionState.isLoading,
          canSend: sessionState.canSendMessage,
          onSendMessage: sessionController.sendMessage,
          requiresModelSelection: sessionState.selectedModelId == null,
          categoryId: widget.categoryId,
        ),
      ],
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({
    required this.sessionTitle,
    required this.canClearChat,
    required this.onClearChat,
    required this.onNewSession,
    required this.categoryId,
    required this.selectedModelId,
    required this.isStreaming,
    required this.onSelectModel,
  });

  final String sessionTitle;
  final bool canClearChat;
  final VoidCallback onClearChat;
  final VoidCallback onNewSession;
  final String categoryId;
  final String? selectedModelId;
  final bool isStreaming;
  final ValueChanged<String> onSelectModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibleAsync = ref.watch(
      eligibleChatModelsForCategoryProvider(categoryId),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.psychology_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (sessionTitle.isNotEmpty)
                  Text(
                    sessionTitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Model selector
          eligibleAsync.when(
            data: (models) {
              if (models.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 16),
                      SizedBox(width: 6),
                      Text('No eligible models'),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DropdownButton<String>(
                  value: selectedModelId,
                  hint: const Text('Select model'),
                  onChanged: isStreaming
                      ? null
                      : (v) {
                          if (v != null) onSelectModel(v);
                        },
                  items: [
                    for (final m in models)
                      DropdownMenuItem<String>(
                        value: m.id,
                        child: Text(m.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: onNewSession,
            tooltip: 'New chat',
          ),
          if (canClearChat)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: onClearChat,
              tooltip: 'Clear current chat',
            ),
        ],
      ),
    );
  }
}

class _MessagesArea extends StatelessWidget {
  const _MessagesArea({
    required this.messages,
    required this.scrollController,
  });

  final List<ChatMessage> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return _EmptyState();
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _MessageBubble(
          message: message,
          key: ValueKey(message.id),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 64,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Ask me about your tasks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'I can help analyze your productivity patterns, summarize completed tasks, and provide insights about your work habits.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    super.key,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatMessageRole.user;
    final theme = Theme.of(context);

    // Add asymmetric horizontal margins to differentiate roles visually.
    return Padding(
      padding: EdgeInsets.only(
        bottom: 16,
        left: isUser ? 20 : 0,
        right: isUser ? 0 : 20,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isUser
                          ? const Radius.circular(20)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(20),
                    ),
                  ),
                  child: _MessageContent(
                    message: message,
                    isUser: isUser,
                    theme: theme,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MessageTimestamp(
                      timestamp: message.timestamp,
                      isUser: isUser,
                    ),
                    const SizedBox(width: 8),
                    _CopyMessageButton(message: message),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyMessageButton extends StatelessWidget {
  const _CopyMessageButton({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isAssistant = message.role == ChatMessageRole.assistant;
    return IconButton(
      tooltip: isAssistant ? 'Copy assistant message' : 'Copy message',
      icon: const Icon(Icons.copy, size: 16),
      onPressed: () async {
        // For assistant messages, prefer copying the full raw content without
        // any hidden thinking blocks.
        var text = message.content;
        if (isAssistant) {
          // Strip thinking via shared utility.
          text = ThinkingUtils.stripThinking(text);
        }
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard')),
          );
        }
      },
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  // Thinking stripping handled by ThinkingUtils
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    required this.isUser,
    required this.theme,
  });

  final ChatMessage message;
  final bool isUser;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (message.isStreaming) {
      return _StreamingContent(
        content: message.content,
        isUser: isUser,
        theme: theme,
      );
    }

    if (isUser) {
      // Preserve Markdown formatting for user messages while keeping
      // text selectable. Ensure contrast on the colored bubble by forcing
      // the text color to `onPrimary`.
      return SelectionArea(
        child: DefaultTextStyle.merge(
          style: TextStyle(color: theme.colorScheme.onPrimary),
          child: GptMarkdown(message.content),
        ),
      );
    }

    if (!isUser) {
      // Parse assistant content for hidden thinking blocks and render a
      // collapsible reasoning section similar to popular chat UIs.
      final parsed = parseThinking(message.content);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((parsed.thinking ?? '').isNotEmpty)
            _ThinkingDisclosure(thinking: parsed.thinking!),
          SelectionArea(
            child: GptMarkdown(parsed.visible),
          ),
        ],
      );
    }

    // Unreachable for a boolean, but keeps analyzer satisfied.
    return const SizedBox.shrink();
  }
}

class _StreamingContent extends StatelessWidget {
  const _StreamingContent({
    required this.content,
    required this.isUser,
    required this.theme,
  });

  final String content;
  final bool isUser;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isUser
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Thinking...',
            style: TextStyle(
              color: isUser
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    final parsed = parseThinking(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isUser && (parsed.thinking ?? '').isNotEmpty)
          _ThinkingDisclosure(thinking: parsed.thinking!),
        if (isUser)
          SelectionArea(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: theme.colorScheme.onPrimary),
              child: GptMarkdown(parsed.visible),
            ),
          )
        else if (parsed.visible.isNotEmpty)
          GptMarkdown(parsed.visible),
        const SizedBox(height: 20),
        _TypingIndicator(isUser: isUser),
      ],
    );
  }
}

class _ThinkingDisclosure extends StatefulWidget {
  const _ThinkingDisclosure({required this.thinking});

  final String thinking;

  @override
  State<_ThinkingDisclosure> createState() => _ThinkingDisclosureState();
}

class _ThinkingDisclosureState extends State<_ThinkingDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Reasoning section, ${_expanded ? "expanded" : "collapsed"}',
          button: true,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter): () =>
                  setState(() => _expanded = !_expanded),
              const SingleActivator(LogicalKeyboardKey.space): () =>
                  setState(() => _expanded = !_expanded),
            },
            child: Focus(
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(_expanded ? 'Hide reasoning' : 'Show reasoning',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                    const SizedBox(width: 8),
                    Semantics(
                      label: 'Copy reasoning',
                      child: IconButton(
                        tooltip: 'Copy reasoning',
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: widget.thinking));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reasoning copied')),
                            );
                          }
                        },
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: SelectionArea(
              // Render reasoning using the same markdown widget as the
              // visible response to ensure consistent typography and spacing.
              child: GptMarkdown(widget.thinking),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.isUser});

  final bool isUser;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < 3; i++)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (widget.isUser
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant)
                      .withValues(
                    alpha: (_animationController.value + i * 0.3) % 1.0 > 0.5
                        ? 1.0
                        : 0.3,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MessageTimestamp extends StatelessWidget {
  const _MessageTimestamp({
    required this.timestamp,
    required this.isUser,
  });

  final DateTime timestamp;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeString =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    return Text(
      timeString,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        fontSize: 10,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.error,
    required this.onRetry,
    required this.onDismiss,
  });

  final String error;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onDismiss,
            iconSize: 18,
          ),
        ],
      ),
    );
  }
}

class _InputArea extends ConsumerStatefulWidget {
  const _InputArea({
    required this.controller,
    required this.scrollController,
    required this.isLoading,
    required this.canSend,
    required this.onSendMessage,
    required this.requiresModelSelection,
    required this.categoryId,
  });

  final TextEditingController controller;
  final ScrollController scrollController;
  final bool isLoading;
  final bool canSend;
  final ValueChanged<String> onSendMessage;
  final bool requiresModelSelection;
  final String categoryId;

  @override
  ConsumerState<_InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends ConsumerState<_InputArea> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final v = widget.controller.text.trim().isNotEmpty;
    if (v != _hasText) {
      setState(() => _hasText = v);
    }
  }

  void _sendMessage([String? text]) {
    final message = text ?? widget.controller.text.trim();
    if (message.isEmpty || !widget.canSend) return;

    widget.onSendMessage(message);
    widget.controller.clear();

    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (widget.scrollController.hasClients) {
        widget.scrollController.animateTo(
          widget.scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recState = ref.watch(chatRecorderControllerProvider);

    // Auto-consume transcript when it arrives
    if (recState.transcript != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final transcript = recState.transcript!.trim();
        if (transcript.isNotEmpty) {
          if (widget.canSend) {
            _sendMessage(transcript);
          } else {
            widget.controller.text = transcript;
          }
        }
        ref.read(chatRecorderControllerProvider.notifier).clearResult();
      });
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: SafeArea(
        child: (recState.status == ChatRecorderStatus.recording)
            ? ChatVoiceControls(
                onCancel: () =>
                    ref.read(chatRecorderControllerProvider.notifier).cancel(),
                onStop: () => ref
                    .read(chatRecorderControllerProvider.notifier)
                    .stopAndTranscribe(),
              )
            : Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: TextField(
                        key: const ValueKey('chat_text_field'),
                        controller: widget.controller,
                        decoration: InputDecoration(
                          hintText: widget.requiresModelSelection
                              ? 'Select a model to start chatting'
                              : 'Ask about your tasks and productivity...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: Theme.of(context).dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: Theme.of(context).dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: widget.canSend ? _sendMessage : null,
                        enabled:
                            recState.status != ChatRecorderStatus.processing &&
                                widget.canSend,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (recState.status != ChatRecorderStatus.recording)
                    IconButton.filled(
                      icon: _buildTrailingIcon(
                        isProcessing:
                            recState.status == ChatRecorderStatus.processing,
                      ),
                      onPressed: _buildTrailingOnPressed(
                        recState: recState,
                      ),
                      tooltip: _buildTrailingTooltip(recState: recState),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildTrailingIcon({required bool isProcessing}) {
    if (isProcessing || widget.isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final hasText = _hasText;
    final recState = ref.read(chatRecorderControllerProvider);
    if (recState.status == ChatRecorderStatus.recording) {
      return const Icon(Icons.stop);
    }
    return hasText ? const Icon(Icons.send) : const Icon(Icons.mic);
  }

  VoidCallback? _buildTrailingOnPressed({required ChatRecorderState recState}) {
    if (recState.status == ChatRecorderStatus.processing || widget.isLoading) {
      return null;
    }
    final hasText = _hasText;
    if (recState.status == ChatRecorderStatus.recording) {
      return () =>
          ref.read(chatRecorderControllerProvider.notifier).stopAndTranscribe();
    }
    if (hasText) {
      return widget.canSend ? _sendMessage : null;
    }
    return () => ref.read(chatRecorderControllerProvider.notifier).start();
  }

  String _buildTrailingTooltip({required ChatRecorderState recState}) {
    if (recState.status == ChatRecorderStatus.processing || widget.isLoading) {
      return 'Processing...';
    }
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (recState.status == ChatRecorderStatus.recording) {
      return 'Stop and transcribe';
    }
    if (hasText) return widget.canSend ? 'Send message' : 'Please wait...';
    return 'Record voice message';
  }
}

class ChatVoiceControls extends ConsumerWidget {
  const ChatVoiceControls({
    required this.onCancel,
    required this.onStop,
    super.key,
  });

  final VoidCallback onCancel;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      },
      child: Focus(
        autofocus: true,
        child: Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: WaveformBars(
                  key: const ValueKey('waveform_bars'),
                  amplitudesNormalized: ref
                      .read(chatRecorderControllerProvider.notifier)
                      .getNormalizedAmplitudeHistory(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.outlined(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel recording (Esc)',
              onPressed: onCancel,
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.stop),
              tooltip: 'Stop and transcribe',
              onPressed: onStop,
            ),
          ],
        ),
      ),
    );
  }
}
