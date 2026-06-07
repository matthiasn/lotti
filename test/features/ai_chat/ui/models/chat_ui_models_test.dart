import 'package:clock/clock.dart';
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
        // With no selectedModelId and no source metadata, toDomain must not
        // inject a model key. Assert the absence of that key rather than exact
        // map equality so an unrelated future metadata key would not break it.
        expect(
          domainSession.metadata,
          isNot(contains('selectedModelId')),
        );
      });

      test('a single message anchors both createdAt and lastMessageAt', () {
        final message = ChatMessage.user('Only one');
        final uiModel = ChatSessionUiModel(
          id: 'single-id',
          title: 'Single',
          messages: [message],
          isLoading: false,
          isStreaming: false,
        );

        final domainSession = uiModel.toDomain();

        // first == last: both timestamps collapse onto the lone message.
        expect(domainSession.createdAt, message.timestamp);
        expect(domainSession.lastMessageAt, message.timestamp);
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
        final pinned = DateTime(2026, 3, 1, 9, 30);
        final uiModel = ChatSessionUiModel.empty();
        final domainSession = withClock(
          Clock.fixed(pinned),
          uiModel.toDomain,
        );

        expect(domainSession.messages, isEmpty);
        // Both timestamps come from the (pinned) wall clock.
        expect(domainSession.createdAt, pinned);
        expect(domainSession.lastMessageAt, pinned);
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

      test('streamingMessage returns the first when several are streaming', () {
        final firstStreaming = ChatMessage(
          id: 'streaming-1',
          content: 'First...',
          role: ChatMessageRole.assistant,
          timestamp: DateTime(2024, 3, 15, 10, 30),
          isStreaming: true,
        );
        final secondStreaming = ChatMessage(
          id: 'streaming-2',
          content: 'Second...',
          role: ChatMessageRole.assistant,
          timestamp: DateTime(2024, 3, 15, 10, 31),
          isStreaming: true,
        );

        final model = ChatSessionUiModel(
          id: 'test-id',
          title: 'Test',
          messages: [
            ChatMessage.user('Hello'),
            firstStreaming,
            secondStreaming,
          ],
          isLoading: false,
          isStreaming: true,
        );

        // firstOrNull resolves multi-streaming ambiguity to document order:
        // the earliest streaming message wins, not the latest.
        expect(model.streamingMessage, equals(firstStreaming));
        expect(model.streamingMessage, isNot(equals(secondStreaming)));
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

      test('canSendMessage covers the full flag matrix', () {
        // (hasModel, isLoading, isStreaming) → canSend. Only the fully idle
        // configured state may send.
        const cases = <(bool, bool, bool, bool)>[
          (false, false, false, false),
          (true, false, false, true),
          (true, true, false, false),
          (true, false, true, false),
          (true, true, true, false),
        ];

        for (final (hasModel, isLoading, isStreaming, canSend) in cases) {
          final model = ChatSessionUiModel(
            id: 'test-id',
            title: 'Test',
            messages: const [],
            isLoading: isLoading,
            isStreaming: isStreaming,
            selectedModelId: hasModel ? 'test-model' : null,
          );
          expect(
            model.canSendMessage,
            canSend,
            reason:
                'hasModel=$hasModel loading=$isLoading '
                'streaming=$isStreaming',
          );
        }
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

      glados.Glados<String>(
        glados.any.chatTitle,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'displayTitle: empty falls back to "New Chat", else identity',
        (
          title,
        ) {
          final model = ChatSessionUiModel(
            id: 'id',
            title: title,
            messages: const [],
            isLoading: false,
            isStreaming: false,
          );

          if (title.isEmpty) {
            expect(model.displayTitle, 'New Chat', reason: 'title="$title"');
          } else {
            expect(model.displayTitle, title, reason: 'title="$title"');
          }
        },
        tags: 'glados',
      );

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
    group('copyWith sentinel properties', () {
      test('no-argument copyWith preserves every field, incl. nullables', () {
        // The Object() sentinel must pass nullable fields through untouched
        // for any combination of set/unset nullable values.
        for (final modelId in <String?>[null, 'model-x']) {
          for (final error in <String?>[null, 'boom']) {
            for (final streamingId in <String?>[null, 'msg-1']) {
              final original = ChatSessionUiModel(
                id: 'id-1',
                title: 'Title',
                messages: [ChatMessage.user('hello')],
                isLoading: true,
                isStreaming: true,
                selectedModelId: modelId,
                error: error,
                streamingMessageId: streamingId,
              );
              final copy = original.copyWith();
              final reason =
                  'modelId=$modelId error=$error streamingId=$streamingId';

              expect(copy.id, original.id, reason: reason);
              expect(copy.title, original.title, reason: reason);
              expect(copy.messages, original.messages, reason: reason);
              expect(copy.isLoading, original.isLoading, reason: reason);
              expect(copy.isStreaming, original.isStreaming, reason: reason);
              expect(
                copy.selectedModelId,
                original.selectedModelId,
                reason: reason,
              );
              expect(copy.error, original.error, reason: reason);
              expect(
                copy.streamingMessageId,
                original.streamingMessageId,
                reason: reason,
              );
            }
          }
        }
      });

      test('ChatStateUiModel.copyWith(error: null) clears the error', () {
        const withError = ChatStateUiModel(
          recentSessions: [],
          error: 'something failed',
        );

        final cleared = withError.copyWith(error: null);

        // Explicit null beats the sentinel: the error is gone.
        expect(cleared.error, isNull);
        expect(cleared.recentSessions, withError.recentSessions);
      });

      test('fromDomain ignores a non-String selectedModelId in metadata', () {
        final session = ChatSession(
          id: 's-1',
          title: 'Session',
          createdAt: DateTime(2026),
          lastMessageAt: DateTime(2026),
          messages: const [],
          metadata: const {'selectedModelId': 42},
        );

        final uiModel = ChatSessionUiModel.fromDomain(session);

        // The type guard coerces the malformed value to null rather than
        // crashing on the cast.
        expect(uiModel.selectedModelId, isNull);
      });
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

  _GeneratedChatMessage withStreaming({required bool isStreaming}) =>
      _GeneratedChatMessage(
        idSlot: idSlot,
        content: content,
        role: role,
        timestampSlot: timestampSlot,
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
  /// Titles for the displayTitle invariant: letterOrDigits can be empty (it is
  /// built from `list(...)`), so both the fallback and identity branches are
  /// exercised.
  glados.Generator<String> get chatTitle =>
      glados.StringAnys(this).letterOrDigits;

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

  glados.Generator<List<_GeneratedChatMessage>>
  get _chatMessagesWithAtMostOneStreaming =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(this).listWithLengthInRange(0, 5, _chatMessage),
        glados.IntAnys(this).intInRange(0, 6),
        (
          List<_GeneratedChatMessage> messages,
          int streamingIndexSlot,
        ) {
          final streamingIndex = streamingIndexSlot < messages.length
              ? streamingIndexSlot
              : null;

          return [
            for (final (index, message) in messages.indexed)
              message.withStreaming(isStreaming: index == streamingIndex),
          ];
        },
      );

  glados.Generator<_GeneratedChatSessionUiModel>
  get generatedChatSessionUiModel => glados.CombinableAny(this).combine9(
    glados.IntAnys(this).intInRange(0, 80),
    _chatText,
    _chatMessagesWithAtMostOneStreaming,
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
