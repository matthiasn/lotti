import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/repository/ai_chat_repository.dart';
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'chat_controller.g.dart';

class ChatState {
  const ChatState({
    required this.messages,
    required this.isLoading,
    this.error,
    this.conversationId,
  });

  factory ChatState.initial() => ChatState(
        messages: [],
        isLoading: false,
        conversationId: const Uuid().v4(),
      );

  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final String? conversationId;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    String? conversationId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      conversationId: conversationId ?? this.conversationId,
    );
  }
}

@riverpod
class ChatController extends _$ChatController {
  String? _currentStreamingMessageId;
  final LoggingService _loggingService = getIt<LoggingService>();

  @override
  ChatState build(String categoryId) {
    return ChatState.initial();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // Add user message
    final userMessage = ChatMessage.user(content);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
    );

    // Create streaming message placeholder
    _currentStreamingMessageId = const Uuid().v4();
    final streamingMessage = ChatMessage(
      id: _currentStreamingMessageId!,
      content: '',
      role: ChatMessageRole.assistant,
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    state = state.copyWith(
      messages: [...state.messages, streamingMessage],
    );

    try {
      await _processMessage(content);
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'ChatController',
        subDomain: 'sendMessage',
        stackTrace: stackTrace,
      );

      state = state.copyWith(
        error: 'Failed to process message: $e',
        isLoading: false,
      );

      // Remove streaming message on error
      if (_currentStreamingMessageId != null) {
        state = state.copyWith(
          messages: state.messages
              .where((m) => m.id != _currentStreamingMessageId)
              .toList(),
        );
        _currentStreamingMessageId = null;
      }
    }
  }

  Future<void> _processMessage(String message) async {
    // Get AI configuration
    final aiConfigRepo = ref.read(aiConfigRepositoryProvider);

    // Get Gemini provider and model
    final providers =
        await aiConfigRepo.getConfigsByType(AiConfigType.inferenceProvider);
    final geminiProvider =
        providers.whereType<AiConfigInferenceProvider>().firstWhere(
              (p) => p.inferenceProviderType == InferenceProviderType.gemini,
              orElse: () => throw Exception('Gemini provider not configured'),
            );

    final models = await aiConfigRepo.getConfigsByType(AiConfigType.model);
    final geminiFlashModel = models.whereType<AiConfigModel>().firstWhere(
          (m) =>
              m.inferenceProviderId == geminiProvider.id &&
              m.providerModelId.contains('flash'),
          orElse: () => throw Exception('Gemini Flash model not found'),
        );

    // Get cloud repository
    final cloudRepo = ref.read(cloudInferenceRepositoryProvider);

    // Use dedicated AI chat repository
    final aiChatRepo = ref.read(aiChatRepositoryProvider);

    // Convert chat messages to OpenAI format for history
    // Include ALL previous messages (both user and assistant) except streaming ones
    final previousMessages = state.messages
        .where((m) => !m.isStreaming)
        .map((m) => m.role == ChatMessageRole.assistant
            ? ChatCompletionMessage.assistant(content: m.content)
            : ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.string(m.content)))
        .toList();

    await aiChatRepo.processMessage(
      message: message,
      previousMessages: previousMessages,
      model: geminiFlashModel,
      provider: geminiProvider,
      cloudRepo: cloudRepo,
      categoryId: categoryId,
      taskSummaryRepo: ref.read(taskSummaryRepositoryProvider),
      onStreamingUpdate: _updateStreamingMessage,
      onComplete: _finalizeStreamingMessage,
      onError: (String error) {
        state = state.copyWith(
          error: error,
          isLoading: false,
        );
        // Remove streaming message on error
        if (_currentStreamingMessageId != null) {
          state = state.copyWith(
            messages: state.messages
                .where((m) => m.id != _currentStreamingMessageId)
                .toList(),
          );
          _currentStreamingMessageId = null;
        }
      },
    );
  }

  void _updateStreamingMessage(String content) {
    if (_currentStreamingMessageId == null) return;

    state = state.copyWith(
      messages: state.messages.map((msg) {
        if (msg.id == _currentStreamingMessageId) {
          return msg.copyWith(content: content);
        }
        return msg;
      }).toList(),
    );
  }

  void _finalizeStreamingMessage(String content) {
    if (_currentStreamingMessageId == null) return;

    state = state.copyWith(
      messages: state.messages.map((msg) {
        if (msg.id == _currentStreamingMessageId) {
          return msg.copyWith(
            content: content,
            isStreaming: false,
          );
        }
        return msg;
      }).toList(),
      isLoading: false,
    );

    _currentStreamingMessageId = null;
  }

  void clearChat() {
    state = ChatState.initial();
  }
}
