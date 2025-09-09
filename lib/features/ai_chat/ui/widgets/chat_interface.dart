import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_session_controller.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_sessions_controller.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/chat_header.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/error_banner.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/input_area.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/messages_area.dart';

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
        ChatHeader(
          sessionTitle: sessionState.displayTitle,
          canClearChat: sessionState.hasMessages,
          onClearChat: sessionController.clearChat,
          onNewSession: sessionsController.createNewSession,
          categoryId: widget.categoryId,
          selectedModelId: sessionState.selectedModelId,
          isStreaming: sessionState.isStreaming,
          onSelectModel: sessionController.setModel,
        ),
        Expanded(
          child: ShaderMask(
            shaderCallback: (Rect rect) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x03000000),
                  Color(0x00000000),
                  Color(0x06000000),
                ],
                stops: [0.0, 0.6, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.srcOver,
            child: MessagesArea(
              messages: sessionState.messages,
              scrollController: _scrollController,
              showTypingIndicator: sessionState.isStreaming,
            ),
          ),
        ),
        if (sessionState.error != null)
          ErrorBanner(
            error: sessionState.error!,
            onRetry: sessionController.retryLastMessage,
            onDismiss: sessionController.clearError,
          ),
        InputArea(
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
