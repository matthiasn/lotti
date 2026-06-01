import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';
import 'package:lotti/features/ai_chat/ui/models/chat_ui_models.dart';

void main() {
  group('ChatSessionUiModel', () {
    group('factory constructors', () {
      test('empty creates model with default values', () {
        final model = ChatSessionUiModel.empty();

        expect(model.id, equals(''));
        expect(model.title, equals('New Chat'));
        expect(model.messages, isEmpty);
        expect(model.isLoading, isFalse);
        expect(model.isStreaming, isFalse);
        expect(model.selectedModelId, isNull);
        expect(model.error, isNull);
        expect(model.streamingMessageId, isNull);
      });

      test('fromDomain creates model from domain ChatSession', () {
        final domainSession = ChatSession(
          id: 'test-id',
          title: 'Test Chat',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: [
            ChatMessage.user('Hello'),
            ChatMessage.assistant('Hi there'),
          ],
        );

        final model = ChatSessionUiModel.fromDomain(domainSession);

        expect(model.id, equals('test-id'));
        expect(model.title, equals('Test Chat'));
        expect(model.messages.length, equals(2));
        expect(model.isLoading, isFalse);
        expect(model.isStreaming, isFalse);
        expect(model.error, isNull);
        expect(model.streamingMessageId, isNull);
        expect(model.selectedModelId, isNull);
      });

      test('fromDomain preserves selectedModelId from metadata', () {
        final domainSession = ChatSession(
          id: 'test-id',
          title: 'Test Chat',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: [],
          metadata: {'selectedModelId': 'gpt-4'},
        );

        final model = ChatSessionUiModel.fromDomain(domainSession);

        expect(model.selectedModelId, equals('gpt-4'));
      });

      test('fromDomain accepts optional presentation parameters', () {
        final domainSession = ChatSession(
          id: 'test-id',
          title: 'Test Chat',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: [],
        );

        final model = ChatSessionUiModel.fromDomain(
          domainSession,
          isLoading: true,
          isStreaming: true,
          error: 'Test error',
          streamingMessageId: 'msg-123',
        );

        expect(model.isLoading, isTrue);
        expect(model.isStreaming, isTrue);
        expect(model.error, equals('Test error'));
        expect(model.streamingMessageId, equals('msg-123'));
      });
    });

    group('copyWith', () {
      test('returns new instance with updated values', () {
        final original = ChatSessionUiModel.empty();

        final updated = original.copyWith(
          id: 'new-id',
          title: 'Updated Title',
          isLoading: true,
          error: 'Error occurred',
        );

        expect(updated.id, equals('new-id'));
        expect(updated.title, equals('Updated Title'));
        expect(updated.isLoading, isTrue);
        expect(updated.error, equals('Error occurred'));
        expect(updated.messages, equals(original.messages));
        expect(updated.isStreaming, equals(original.isStreaming));
      });

      test('maintains original values when not specified', () {
        final original = ChatSessionUiModel.fromDomain(
          ChatSession(
            id: 'original-id',
            title: 'Original Title',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [ChatMessage.user('Hello')],
          ),
          isLoading: true,
        );

        final updated = original.copyWith(error: 'New error');

        expect(updated.id, equals('original-id'));
        expect(updated.title, equals('Original Title'));
        expect(updated.messages.length, equals(1));
        expect(updated.isLoading, isTrue);
        expect(updated.error, equals('New error'));
      });

      test('handles selectedModelId updates correctly', () {
        final original = ChatSessionUiModel.empty();

        // Can set selectedModelId
        final withModel = original.copyWith(selectedModelId: 'gpt-4');
        expect(withModel.selectedModelId, equals('gpt-4'));

        // Can clear selectedModelId
        final cleared = withModel.copyWith(selectedModelId: null);
        expect(cleared.selectedModelId, isNull);

        // Not specifying keeps original value
        final unchanged = withModel.copyWith(title: 'New Title');
        expect(unchanged.selectedModelId, equals('gpt-4'));
      });
    });

    group('toDomain', () {
      test('converts UI model to domain ChatSession', () {
        final messages = [
          ChatMessage.user('Hello'),
          ChatMessage.assistant('Hi there'),
        ];

        final uiModel = ChatSessionUiModel(
          id: 'test-id',
          title: 'Test Chat',
          messages: messages,
          isLoading: false,
          isStreaming: false,
        );

        final domainSession = uiModel.toDomain();

        expect(domainSession.id, equals('test-id'));
        expect(domainSession.title, equals('Test Chat'));
        expect(domainSession.messages, equals(messages));
        expect(domainSession.createdAt, equals(messages.first.timestamp));
        expect(domainSession.lastMessageAt, equals(messages.last.timestamp));
        expect(domainSession.metadata, equals({}));
      });

      test('includes selectedModelId in metadata when present', () {
        const uiModel = ChatSessionUiModel(
          id: 'test-id',
          title: 'Test Chat',
          messages: [],
          isLoading: false,
          isStreaming: false,
          selectedModelId: 'gpt-4',
        );

        final domainSession = uiModel.toDomain();

        expect(domainSession.metadata, isNotNull);
        expect(domainSession.metadata!['selectedModelId'], equals('gpt-4'));
      });

      test('handles empty messages list', () {
        final uiModel = ChatSessionUiModel.empty();
        final domainSession = uiModel.toDomain();

        expect(domainSession.messages, isEmpty);
        // Should use current time for both created and last message timestamps
        expect(domainSession.createdAt, isNotNull);
        expect(domainSession.lastMessageAt, isNotNull);
      });
    });

    group('getter properties', () {
      test('completedMessages filters out streaming messages', () {
        final messages = [
          ChatMessage.user('Hello'),
          ChatMessage.assistant('Response'),
          ChatMessage(
            id: 'streaming',
            content: 'Partial...',
            role: ChatMessageRole.assistant,
            timestamp: DateTime(2024, 3, 15, 10, 30),
            isStreaming: true,
          ),
        ];

        final model = ChatSessionUiModel(
          id: 'test-id',
          title: 'Test',
          messages: messages,
          isLoading: false,
          isStreaming: true,
        );

        expect(model.completedMessages.length, equals(2));
        expect(model.completedMessages.every((m) => !m.isStreaming), isTrue);
      });

      test('streamingMessage returns current streaming message', () {
        final streamingMessage = ChatMessage(
          id: 'streaming',
          content: 'Typing...',
          role: ChatMessageRole.assistant,
          timestamp: DateTime(2024, 3, 15, 10, 30),
          isStreaming: true,
        );

        final model = ChatSessionUiModel(
          id: 'test-id',
          title: 'Test',
          messages: [
            ChatMessage.user('Hello'),
            streamingMessage,
          ],
          isLoading: false,
          isStreaming: true,
        );

        expect(model.streamingMessage, equals(streamingMessage));
      });

      test('streamingMessage returns null when no streaming messages', () {
        final model = ChatSessionUiModel(
          id: 'test-id',
          title: 'Test',
          messages: [ChatMessage.user('Hello')],
          isLoading: false,
          isStreaming: false,
        );

        expect(model.streamingMessage, isNull);
      });

      test('hasMessages returns correct boolean', () {
        final emptyModel = ChatSessionUiModel.empty();
        final modelWithMessages = ChatSessionUiModel(
          id: 'test-id',
          title: 'Test',
          messages: [ChatMessage.user('Hello')],
          isLoading: false,
          isStreaming: false,
        );

        expect(emptyModel.hasMessages, isFalse);
        expect(modelWithMessages.hasMessages, isTrue);
      });

      test('canSendMessage returns correct boolean', () {
        // Model without selectedModelId cannot send messages
        final noModelSelected = ChatSessionUiModel.empty();
        expect(noModelSelected.canSendMessage, isFalse);

        // Model with selectedModelId can send messages
        const readyModel = ChatSessionUiModel(
          id: 'test-id',
          title: 'Test',
          messages: [],
          isLoading: false,
          isStreaming: false,
          selectedModelId: 'test-model',
        );
        expect(readyModel.canSendMessage, isTrue);

        // Model with selectedModelId but loading cannot send messages
        final loadingModel = readyModel.copyWith(isLoading: true);
        expect(loadingModel.canSendMessage, isFalse);

        // Model with selectedModelId but streaming cannot send messages
        final streamingModel = readyModel.copyWith(isStreaming: true);
        expect(streamingModel.canSendMessage, isFalse);

        // Model with selectedModelId but both loading and streaming cannot send messages
        final busyModel = readyModel.copyWith(
          isLoading: true,
          isStreaming: true,
        );
        expect(busyModel.canSendMessage, isFalse);
      });

      test('displayTitle returns title or fallback', () {
        const modelWithTitle = ChatSessionUiModel(
          id: 'test-id',
          title: 'Custom Title',
          messages: [],
          isLoading: false,
          isStreaming: false,
        );

        final emptyModel = ChatSessionUiModel.empty();

        expect(modelWithTitle.displayTitle, equals('Custom Title'));
        expect(emptyModel.displayTitle, equals('New Chat'));
      });

      glados.Glados(
        glados.any.generatedChatSessionUiModel,
        glados.ExploreConfig(numRuns: 160),
      ).test(
        'matches generated derived-state and domain-conversion model',
        (
          scenario,
        ) {
          final model = scenario.model;
          final domain = model.toDomain();

          expect(
            model.completedMessages,
            model.messages.where((message) => !message.isStreaming).toList(),
            reason: '$scenario',
          );
          expect(
            model.streamingMessage,
            scenario.expectedStreamingMessage,
            reason: '$scenario',
          );
          expect(model.hasMessages, model.messages.isNotEmpty);
          expect(model.canSendMessage, scenario.expectedCanSend);
          expect(model.displayTitle, scenario.expectedDisplayTitle);
          expect(domain.id, model.id, reason: '$scenario');
          expect(domain.title, model.title, reason: '$scenario');
          expect(domain.messages, model.messages, reason: '$scenario');
          expect(domain.metadata, scenario.expectedDomainMetadata);

          if (model.messages.isNotEmpty) {
            expect(
              domain.createdAt,
              model.messages.first.timestamp,
              reason: '$scenario',
            );
            expect(
              domain.lastMessageAt,
              model.messages.last.timestamp,
              reason: '$scenario',
            );
          }
        },
        tags: 'glados',
      );
    });
  });

  group('ChatStateUiModel', () {
    group('factory constructors', () {
      test('initial creates model with default values', () {
        final model = ChatStateUiModel.initial();

        expect(model.currentSession?.id ?? '', isEmpty);
        expect(model.recentSessions, isEmpty);
        expect(model.error, isNull);
      });
    });

    group('copyWith', () {
      test('returns new instance with updated values', () {
        final initialSession = ChatSessionUiModel.empty();
        final recentSessions = [
          ChatSessionUiModel.fromDomain(
            ChatSession(
              id: 'recent-1',
              title: 'Recent Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: [],
            ),
          ),
        ];

        final original = ChatStateUiModel(
          currentSession: initialSession,
          recentSessions: [],
        );

        final updated = original.copyWith(
          recentSessions: recentSessions,
          error: 'Test error',
        );

        expect(updated.recentSessions, equals(recentSessions));
        expect(updated.error, equals('Test error'));
        expect(updated.currentSession, equals(original.currentSession));
      });
    });

    group('clearError', () {
      test('returns new instance with error cleared', () {
        final original = ChatStateUiModel(
          currentSession: ChatSessionUiModel.empty(),
          recentSessions: [],
          error: 'Some error',
        );

        final cleared = original.clearError();

        expect(cleared.error, isNull);
        expect(cleared.currentSession, equals(original.currentSession));
        expect(cleared.recentSessions, equals(original.recentSessions));
      });
    });

    group('getter properties', () {
      test('isAnySessionLoading detects loading in current session', () {
        final loadingCurrentSession = ChatSessionUiModel.empty().copyWith(
          isLoading: true,
        );
        final model = ChatStateUiModel(
          currentSession: loadingCurrentSession,
          recentSessions: [],
        );

        expect(model.isAnySessionLoading, isTrue);
      });

      test('isAnySessionLoading detects loading in recent sessions', () {
        final loadingRecentSession = ChatSessionUiModel.empty().copyWith(
          isLoading: true,
        );
        final model = ChatStateUiModel(
          currentSession: ChatSessionUiModel.empty(),
          recentSessions: [loadingRecentSession],
        );

        expect(model.isAnySessionLoading, isTrue);
      });

      test(
        'isAnySessionLoading returns false when no sessions are loading',
        () {
          final model = ChatStateUiModel(
            currentSession: ChatSessionUiModel.empty(),
            recentSessions: [ChatSessionUiModel.empty()],
          );

          expect(model.isAnySessionLoading, isFalse);
        },
      );

      glados.Glados(
        glados.any.generatedChatStateUiModel,
        glados.ExploreConfig(numRuns: 120),
      ).test('matches generated aggregate loading model', (scenario) {
        final model = scenario.model;

        expect(
          model.isAnySessionLoading,
          scenario.expectedIsAnySessionLoading,
          reason: '$scenario',
        );
        expect(model.clearError().error, isNull, reason: '$scenario');
      }, tags: 'glados');
    });
  });
}

class _GeneratedChatSessionUiModel {
  const _GeneratedChatSessionUiModel({
    required this.idSlot,
    required this.title,
    required this.messages,
    required this.isLoading,
    required this.isStreaming,
    required this.metadataSlot,
    required this.selectedModelSlot,
    required this.errorSlot,
    required this.streamingMessageIdSlot,
  });

  final int idSlot;
  final String title;
  final List<_GeneratedChatMessage> messages;
  final bool isLoading;
  final bool isStreaming;
  final int metadataSlot;
  final int selectedModelSlot;
  final int errorSlot;
  final int streamingMessageIdSlot;

  ChatSessionUiModel get model => ChatSessionUiModel(
    id: 'session-$idSlot',
    title: title,
    messages: messages.map((message) => message.message).toList(),
    isLoading: isLoading,
    isStreaming: isStreaming,
    metadata: metadata,
    selectedModelId: selectedModelId,
    error: _optionalText(errorSlot, 'error'),
    streamingMessageId: _optionalText(streamingMessageIdSlot, 'streaming'),
  );

  Map<String, dynamic>? get metadata => _metadata(metadataSlot);

  String? get selectedModelId => _optionalText(selectedModelSlot, 'model');

  ChatMessage? get expectedStreamingMessage {
    for (final generated in messages) {
      final message = generated.message;
      if (message.isStreaming) {
        return message;
      }
    }
    return null;
  }

  bool get expectedCanSend =>
      !isLoading && !isStreaming && selectedModelId != null;

  String get expectedDisplayTitle => title.isEmpty ? 'New Chat' : title;

  Map<String, dynamic> get expectedDomainMetadata => <String, dynamic>{
    ...?metadata,
    if (selectedModelId != null) 'selectedModelId': selectedModelId,
  };

  @override
  String toString() {
    return '_GeneratedChatSessionUiModel('
        'idSlot: $idSlot, '
        'title: "$title", '
        'messages: $messages, '
        'isLoading: $isLoading, '
        'isStreaming: $isStreaming, '
        'metadataSlot: $metadataSlot, '
        'selectedModelSlot: $selectedModelSlot, '
        'errorSlot: $errorSlot, '
        'streamingMessageIdSlot: $streamingMessageIdSlot)';
  }
}

class _GeneratedChatStateUiModel {
  const _GeneratedChatStateUiModel({
    required this.currentSessionSlot,
    required this.currentSession,
    required this.recentSessions,
    required this.errorSlot,
  });

  final int currentSessionSlot;
  final _GeneratedChatSessionUiModel currentSession;
  final List<_GeneratedChatSessionUiModel> recentSessions;
  final int errorSlot;

  ChatStateUiModel get model => ChatStateUiModel(
    currentSession: currentSessionSlot.isEven ? currentSession.model : null,
    recentSessions: recentSessions
        .map((session) => session.model)
        .toList(growable: false),
    error: _optionalText(errorSlot, 'state-error'),
  );

  bool get expectedIsAnySessionLoading =>
      (currentSessionSlot.isEven && currentSession.isLoading) ||
      recentSessions.any((session) => session.isLoading);

  @override
  String toString() {
    return '_GeneratedChatStateUiModel('
        'currentSessionSlot: $currentSessionSlot, '
        'currentSession: $currentSession, '
        'recentSessions: $recentSessions, '
        'errorSlot: $errorSlot)';
  }
}

class _GeneratedChatMessage {
  const _GeneratedChatMessage({
    required this.idSlot,
    required this.content,
    required this.role,
    required this.timestampSlot,
    required this.isStreaming,
  });

  final int idSlot;
  final String content;
  final ChatMessageRole role;
  final int timestampSlot;
  final bool isStreaming;

  ChatMessage get message => ChatMessage(
    id: 'message-$idSlot',
    content: content,
    role: role,
    timestamp: _date(timestampSlot),
    isStreaming: isStreaming,
  );

  @override
  String toString() {
    return '_GeneratedChatMessage('
        'idSlot: $idSlot, '
        'content: "$content", '
        'role: $role, '
        'timestampSlot: $timestampSlot, '
        'isStreaming: $isStreaming)';
  }
}

extension _AnyChatUiModels on glados.Any {
  glados.Generator<String> get _chatText => glados.AnyUtils(this).choose(const [
    '',
    'Chat',
    'Text with "quotes"',
    r'Text with \ slash',
    'Line\nbreak',
  ]);

  glados.Generator<ChatMessageRole> get _chatRole =>
      glados.AnyUtils(this).choose(ChatMessageRole.values);

  glados.Generator<_GeneratedChatMessage> get _chatMessage =>
      glados.CombinableAny(this).combine5(
        glados.IntAnys(this).intInRange(0, 80),
        _chatText,
        _chatRole,
        glados.IntAnys(this).intInRange(0, 240),
        this.bool,
        (
          int idSlot,
          String content,
          ChatMessageRole role,
          int timestampSlot,
          bool isStreaming,
        ) => _GeneratedChatMessage(
          idSlot: idSlot,
          content: content,
          role: role,
          timestampSlot: timestampSlot,
          isStreaming: isStreaming,
        ),
      );

  glados.Generator<_GeneratedChatSessionUiModel>
  get generatedChatSessionUiModel => glados.CombinableAny(this).combine9(
    glados.IntAnys(this).intInRange(0, 80),
    _chatText,
    glados.ListAnys(this).listWithLengthInRange(0, 5, _chatMessage),
    this.bool,
    this.bool,
    glados.IntAnys(this).intInRange(0, 20),
    glados.IntAnys(this).intInRange(0, 20),
    glados.IntAnys(this).intInRange(0, 20),
    glados.IntAnys(this).intInRange(0, 20),
    (
      int idSlot,
      String title,
      List<_GeneratedChatMessage> messages,
      bool isLoading,
      bool isStreaming,
      int metadataSlot,
      int selectedModelSlot,
      int errorSlot,
      int streamingMessageIdSlot,
    ) => _GeneratedChatSessionUiModel(
      idSlot: idSlot,
      title: title,
      messages: messages,
      isLoading: isLoading,
      isStreaming: isStreaming,
      metadataSlot: metadataSlot,
      selectedModelSlot: selectedModelSlot,
      errorSlot: errorSlot,
      streamingMessageIdSlot: streamingMessageIdSlot,
    ),
  );

  glados.Generator<_GeneratedChatStateUiModel> get generatedChatStateUiModel =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 20),
        generatedChatSessionUiModel,
        glados.ListAnys(this).listWithLengthInRange(
          0,
          4,
          generatedChatSessionUiModel,
        ),
        glados.IntAnys(this).intInRange(0, 20),
        (
          int currentSessionSlot,
          _GeneratedChatSessionUiModel currentSession,
          List<_GeneratedChatSessionUiModel> recentSessions,
          int errorSlot,
        ) => _GeneratedChatStateUiModel(
          currentSessionSlot: currentSessionSlot,
          currentSession: currentSession,
          recentSessions: recentSessions,
          errorSlot: errorSlot,
        ),
      );
}

DateTime _date(int slot) {
  return DateTime.utc(
    2024 + (slot % 4),
    (slot % 12) + 1,
    (slot % 28) + 1,
    slot % 24,
    slot % 60,
  );
}

String? _optionalText(int slot, String prefix) {
  return switch (slot % 4) {
    0 => null,
    1 => '$prefix-$slot',
    2 => '$prefix "$slot"',
    _ => '$prefix \\ $slot',
  };
}

Map<String, dynamic>? _metadata(int slot) {
  return switch (slot % 4) {
    0 => null,
    1 => <String, dynamic>{'source': 'generated-$slot'},
    2 => <String, dynamic>{'selectedModelId': 'domain-model-$slot'},
    _ => <String, dynamic>{
      'nested': <String, dynamic>{'slot': slot},
      'tags': <String>['chat', 'ui'],
    },
  };
}
