import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/model/ai_chat_message.dart';

enum _GeneratedConversationOperationKind {
  initializeEmpty,
  initializeWithSystem,
  addUser,
  addAssistantContent,
  addAssistantEmpty,
  addAssistantToolCall,
  addAssistantToolCallWithSignature,
  addToolResponse,
  emitThinking,
  emitError,
}

enum _GeneratedConversationTextSlot { first, second, third, fourth }

enum _GeneratedConversationToolSlot { first, second, third }

enum _GeneratedConversationRole {
  system,
  truncationNotice,
  user,
  assistant,
  tool,
}

String _generatedConversationText(_GeneratedConversationTextSlot slot) =>
    'generated conversation text ${slot.name}';

String _generatedConversationToolId(_GeneratedConversationToolSlot slot) =>
    'generated-tool-${slot.name}';

String _generatedConversationSignature(
  _GeneratedConversationToolSlot slot,
  int index,
) => 'generated-signature-${slot.name}-$index';

class _GeneratedConversationOperation {
  const _GeneratedConversationOperation({
    required this.kind,
    required this.textSlot,
    required this.toolSlot,
  });

  final _GeneratedConversationOperationKind kind;
  final _GeneratedConversationTextSlot textSlot;
  final _GeneratedConversationToolSlot toolSlot;

  String get text => _generatedConversationText(textSlot);

  String get toolId => _generatedConversationToolId(toolSlot);

  @override
  String toString() {
    return '_GeneratedConversationOperation('
        'kind: $kind, textSlot: $textSlot, toolSlot: $toolSlot)';
  }
}

class _GeneratedConversationScenario {
  const _GeneratedConversationScenario({
    required this.maxTurns,
    required this.maxHistorySize,
    required this.operations,
  });

  final int maxTurns;
  final int maxHistorySize;
  final List<_GeneratedConversationOperation> operations;

  @override
  String toString() {
    return '_GeneratedConversationScenario('
        'maxTurns: $maxTurns, maxHistorySize: $maxHistorySize, '
        'operations: $operations)';
  }
}

class _GeneratedConversationHistoryScenario {
  const _GeneratedConversationHistoryScenario({
    required this.hasSystemMessage,
    required this.maxHistorySize,
    required this.userMessageCount,
  });

  final bool hasSystemMessage;
  final int maxHistorySize;
  final int userMessageCount;

  int get retainedMessageLimit {
    final minimumRetainedSize = hasSystemMessage ? 3 : 2;
    return maxHistorySize < minimumRetainedSize
        ? minimumRetainedSize
        : maxHistorySize;
  }

  @override
  String toString() {
    return '_GeneratedConversationHistoryScenario('
        'hasSystemMessage: $hasSystemMessage, '
        'maxHistorySize: $maxHistorySize, '
        'userMessageCount: $userMessageCount)';
  }
}

class _GeneratedConversationModel {
  _GeneratedConversationModel({
    required this.maxTurns,
    required this.maxHistorySize,
  });

  final int maxTurns;
  final int maxHistorySize;
  final List<_GeneratedConversationRole> roles = [];
  final Map<String, String> signatures = {};
  int eventCount = 0;

  int get turnCount =>
      roles.where((role) => role == _GeneratedConversationRole.user).length;

  bool get canContinue => turnCount < maxTurns;

  void apply(_GeneratedConversationOperation operation, int index) {
    switch (operation.kind) {
      case _GeneratedConversationOperationKind.initializeEmpty:
        roles.clear();
        signatures.clear();
        eventCount += 1;

      case _GeneratedConversationOperationKind.initializeWithSystem:
        roles
          ..clear()
          ..add(_GeneratedConversationRole.system);
        signatures.clear();
        eventCount += 1;

      case _GeneratedConversationOperationKind.addUser:
        roles.add(_GeneratedConversationRole.user);
        _trimHistoryIfNeeded();
        eventCount += 1;

      case _GeneratedConversationOperationKind.addAssistantContent:
        roles.add(_GeneratedConversationRole.assistant);
        eventCount += 1;

      case _GeneratedConversationOperationKind.addAssistantEmpty:
        roles.add(_GeneratedConversationRole.assistant);

      case _GeneratedConversationOperationKind.addAssistantToolCall:
        roles.add(_GeneratedConversationRole.assistant);
        eventCount += 1;

      case _GeneratedConversationOperationKind
          .addAssistantToolCallWithSignature:
        roles.add(_GeneratedConversationRole.assistant);
        signatures[operation.toolId] = _generatedConversationSignature(
          operation.toolSlot,
          index,
        );
        eventCount += 1;

      case _GeneratedConversationOperationKind.addToolResponse:
        roles.add(_GeneratedConversationRole.tool);
        eventCount += 1;

      case _GeneratedConversationOperationKind.emitThinking:
      case _GeneratedConversationOperationKind.emitError:
        eventCount += 1;
    }
  }

  void _trimHistoryIfNeeded() {
    if (roles.length <= maxHistorySize) return;

    final hasInitialSystem =
        roles.isNotEmpty && roles.first == _GeneratedConversationRole.system;
    final minimumRetainedSize = hasInitialSystem ? 3 : 2;
    final effectiveMaxSize = maxHistorySize < minimumRetainedSize
        ? minimumRetainedSize
        : maxHistorySize;
    final keepTailCount = effectiveMaxSize - (hasInitialSystem ? 2 : 1);
    final bodyStart = hasInitialSystem ? 1 : 0;
    final bodyRoles = roles
        .skip(bodyStart)
        .where((role) => role != _GeneratedConversationRole.truncationNotice)
        .toList();
    final tailStart = bodyRoles.length > keepTailCount
        ? bodyRoles.length - keepTailCount
        : 0;
    final hadTruncationNotice = roles.contains(
      _GeneratedConversationRole.truncationNotice,
    );

    if (tailStart == 0 && !hadTruncationNotice) return;

    roles
      ..clear()
      ..addAll([
        if (hasInitialSystem) _GeneratedConversationRole.system,
        _GeneratedConversationRole.truncationNotice,
        ...bodyRoles.skip(tailStart),
      ]);
  }
}

extension _AnyGeneratedConversationScenario on glados.Any {
  glados.Generator<_GeneratedConversationOperationKind>
  get conversationOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedConversationOperationKind.values);

  glados.Generator<_GeneratedConversationTextSlot> get conversationTextSlot =>
      glados.AnyUtils(this).choose(_GeneratedConversationTextSlot.values);

  glados.Generator<_GeneratedConversationToolSlot> get conversationToolSlot =>
      glados.AnyUtils(this).choose(_GeneratedConversationToolSlot.values);

  glados.Generator<_GeneratedConversationOperation> get conversationOperation =>
      glados.CombinableAny(this).combine3(
        conversationOperationKind,
        conversationTextSlot,
        conversationToolSlot,
        (
          _GeneratedConversationOperationKind kind,
          _GeneratedConversationTextSlot textSlot,
          _GeneratedConversationToolSlot toolSlot,
        ) => _GeneratedConversationOperation(
          kind: kind,
          textSlot: textSlot,
          toolSlot: toolSlot,
        ),
      );

  glados.Generator<_GeneratedConversationScenario> get conversationScenario =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 8),
        glados.IntAnys(this).intInRange(0, 10),
        glados.ListAnys(this).listWithLengthInRange(
          0,
          45,
          conversationOperation,
        ),
        (
          int maxTurns,
          int maxHistorySize,
          List<_GeneratedConversationOperation> operations,
        ) => _GeneratedConversationScenario(
          maxTurns: maxTurns,
          maxHistorySize: maxHistorySize,
          operations: operations,
        ),
      );

  glados.Generator<_GeneratedConversationHistoryScenario>
  get conversationHistoryScenario => glados.CombinableAny(this).combine3(
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(0, 12),
    glados.IntAnys(this).intInRange(0, 60),
    (
      bool hasSystemMessage,
      int maxHistorySize,
      int userMessageCount,
    ) => _GeneratedConversationHistoryScenario(
      hasSystemMessage: hasSystemMessage,
      maxHistorySize: maxHistorySize,
      userMessageCount: userMessageCount,
    ),
  );
}

AiToolCall _generatedToolCall(String toolId) {
  return AiToolCall(
    id: toolId,
    name: 'generated_function',
    arguments: '{"ok": true}',
  );
}

List<_GeneratedConversationRole> _conversationRoles(
  List<AiChatMessage> messages,
) {
  return messages.map((message) {
    if (_isGeneratedTruncationNotice(message)) {
      return _GeneratedConversationRole.truncationNotice;
    }

    return switch (message) {
      AiSystemMessage() => _GeneratedConversationRole.system,
      AiUserMessage() => _GeneratedConversationRole.user,
      AiAssistantMessage() => _GeneratedConversationRole.assistant,
      AiToolResultMessage() => _GeneratedConversationRole.tool,
    };
  }).toList();
}

bool _isGeneratedTruncationNotice(AiChatMessage message) {
  return message is AiSystemMessage &&
      message.content.contains('Previous messages truncated');
}

String? _systemOrAssistantContent(AiChatMessage message) {
  if (message is AiSystemMessage) return message.content;
  if (message is AiAssistantMessage) return message.content;
  if (message is AiToolResultMessage) return message.content;
  if (message is AiUserMessage) {
    final content = message.content;
    if (content is AiUserTextContent) return content.text;
  }
  return null;
}

void main() {
  group('ConversationManager', () {
    late ConversationManager manager;

    setUp(() {
      manager = ConversationManager(
        conversationId: 'test-conversation',
        maxHistorySize: 50,
      );
    });

    group('_trimHistoryIfNeeded', () {
      test('should not trim when history is below max size', () {
        // Add messages below the max size
        for (var i = 0; i < 20; i++) {
          manager.addUserMessage('Message $i');
        }

        expect(manager.messages.length, 20);
        expect(
          manager.messages.any(
            (msg) =>
                _systemOrAssistantContent(msg)?.contains('truncated') ?? false,
          ),
          false,
        );
      });

      test('should trim history when exceeding max size', () {
        // Add more messages than max size (50)
        for (var i = 0; i < 60; i++) {
          manager.addUserMessage('Message $i');
        }

        // Should have trimmed to at or below max size
        expect(manager.messages.length, lessThanOrEqualTo(50));

        // Should have truncation notice as the first message
        expect(manager.messages.first.role, AiMessageRole.system);
        expect(
          _systemOrAssistantContent(manager.messages.first)?.contains(
                'truncated',
              ) ??
              false,
          true,
        );
      });

      test('should preserve system message when trimming', () {
        // Initialize with system message
        manager.initialize(systemMessage: 'You are a helpful assistant');

        // Add many user messages
        for (var i = 0; i < 60; i++) {
          manager.addUserMessage('Message $i');
        }

        // System message should still be first
        expect(manager.messages.first.role, AiMessageRole.system);
        expect(
          _systemOrAssistantContent(manager.messages.first) ?? '',
          contains('helpful assistant'),
        );

        // Truncation notice should be second
        expect(manager.messages[1].role, AiMessageRole.system);
        expect(
          _systemOrAssistantContent(manager.messages[1]) ?? '',
          contains('truncated'),
        );
      });

      test('should handle edge case where trim count exceeds list length', () {
        // Add exactly max size messages
        for (var i = 0; i < 50; i++) {
          manager.addUserMessage('Message $i');
        }

        // Add one more to trigger trim
        manager.addUserMessage('Message 50');

        // Should not throw and should have valid message count
        expect(manager.messages.length, lessThanOrEqualTo(50));
      });

      test('should correctly calculate trim indices with system message', () {
        // Initialize with system message
        manager.initialize(systemMessage: 'System prompt');

        // Fill to max
        for (var i = 0; i < 55; i++) {
          manager.addUserMessage('Message $i');
        }

        final messages = manager.messages;

        // Should have system messages
        final systemMessages = messages.whereType<AiSystemMessage>().toList();
        expect(systemMessages.length, greaterThanOrEqualTo(1));

        // Should have truncation notice
        expect(
          messages.any(
            (m) => _systemOrAssistantContent(m)?.contains('truncated') ?? false,
          ),
          true,
        );

        // Should have reasonable number of messages
        expect(messages.length, greaterThan(10));
        expect(messages.length, lessThanOrEqualTo(50));
      });
    });

    group('addUserMessage', () {
      test('should add messages and emit events', () {
        fakeAsync((async) {
          final events = <ConversationEvent>[];
          manager.events.listen(events.add);

          manager.addUserMessage('Test message');
          async.flushMicrotasks();

          expect(manager.messages.length, 1);
          expect(events.whereType<UserMessageEvent>().length, 1);
        });
      });

      test('should add tool responses correctly', () {
        const toolCallId = 'tool-123';

        manager.addToolResponse(
          toolCallId: toolCallId,
          response: 'Tool executed successfully',
        );

        expect(manager.messages.length, 1);
        expect(manager.messages.first.role, AiMessageRole.tool);
      });
    });

    group('export', () {
      test('should handle max turns', () {
        // Test that we can check if conversation can continue
        for (var i = 0; i < 10; i++) {
          manager.addUserMessage('Message $i');
        }

        expect(manager.messages.length, 10);
        expect(manager.canContinue(), true); // Default max turns is 20
      });
    });

    group('Event Emission', () {
      test('emitThinking should emit thinking event', () {
        fakeAsync((async) {
          final events = <ConversationEvent>[];
          manager.events.listen(events.add);

          manager.emitThinking();
          async.flushMicrotasks();

          expect(events.length, 1);
          expect(events.first, isA<ThinkingEvent>());
          expect((events.first as ThinkingEvent).turnNumber, 0);
        });
      });

      test('emitError should emit error event', () {
        fakeAsync((async) {
          final events = <ConversationEvent>[];
          manager.events.listen(events.add);

          manager.emitError('Test error message');
          async.flushMicrotasks();

          expect(events.length, 1);
          expect(events.first, isA<ConversationErrorEvent>());
          final errorEvent = events.first as ConversationErrorEvent;
          expect(errorEvent.message, 'Test error message');
          expect(errorEvent.turnNumber, 0);
        });
      });

      test('should not emit events after dispose', () {
        fakeAsync((async) {
          final events = <ConversationEvent>[];
          manager.events.listen(events.add);

          // Dispose the manager
          manager
            ..dispose()
            ..emitError('Should not be emitted')
            ..emitThinking()
            ..addUserMessage('Should not be emitted');

          async.flushMicrotasks();
          expect(events, isEmpty);
        });
      });
    });

    group('Tool Response Handling', () {
      test('addToolResponse should emit tool response event', () {
        fakeAsync((async) {
          final events = <ConversationEvent>[];
          manager.events.listen(events.add);

          manager.addToolResponse(
            toolCallId: 'tool-123',
            response: 'Tool executed successfully',
          );
          async.flushMicrotasks();

          expect(manager.messages.length, 1);
          expect(manager.messages.first.role, AiMessageRole.tool);

          expect(events.length, 1);
          expect(events.first, isA<ToolResponseEvent>());
          final toolEvent = events.first as ToolResponseEvent;
          expect(toolEvent.toolCallId, 'tool-123');
          expect(toolEvent.response, 'Tool executed successfully');
        });
      });
    });

    group('Assistant Message Handling', () {
      const sampleToolCalls = [
        AiToolCall(
          id: 'tool-1',
          name: 'test_function',
          arguments: '{"arg": "value"}',
        ),
      ];

      test('emits the right event per content/toolCalls combination', () {
        // (description, content, toolCalls, expected event type or null).
        // Tool calls take priority over content; an empty assistant message
        // emits nothing.
        final cases =
            <
              (
                String,
                String?,
                List<AiToolCall>?,
                Type?,
              )
            >[
              (
                'content only',
                'This is the assistant response',
                null,
                AssistantMessageEvent,
              ),
              ('tool calls only', null, sampleToolCalls, ToolCallsEvent),
              (
                'content and tool calls',
                'Executing function',
                sampleToolCalls,
                ToolCallsEvent,
              ),
              ('neither content nor tool calls', null, null, null),
            ];

        for (final (description, content, toolCalls, expectedEvent) in cases) {
          fakeAsync((async) {
            final caseManager = ConversationManager(
              conversationId: 'assistant-$description',
              maxHistorySize: 50,
            );
            addTearDown(caseManager.dispose);
            final events = <ConversationEvent>[];
            caseManager.events.listen(events.add);

            caseManager.addAssistantMessage(
              content: content,
              toolCalls: toolCalls,
            );
            async.flushMicrotasks();

            expect(caseManager.messages.length, 1, reason: description);
            expect(
              caseManager.messages.first.role,
              AiMessageRole.assistant,
              reason: description,
            );
            expect(
              _systemOrAssistantContent(caseManager.messages.first),
              content,
              reason: description,
            );

            if (expectedEvent == null) {
              expect(events, isEmpty, reason: description);
            } else {
              expect(events.length, 1, reason: description);
              expect(
                events.first.runtimeType,
                expectedEvent,
                reason: description,
              );
              if (events.first case final AssistantMessageEvent event) {
                expect(event.message, content, reason: description);
              }
              if (events.first case final ToolCallsEvent event) {
                expect(event.calls, toolCalls, reason: description);
              }
            }
          });
        }
      });
    });

    group('Initialization - Extended', () {
      test('initialize clears existing messages', () {
        // Add some messages
        manager
          ..addUserMessage('Message 1')
          ..addUserMessage('Message 2');
        expect(manager.messages.length, 2);

        // Initialize with system message
        manager.initialize(systemMessage: 'New system message');

        // Should have only the system message
        expect(manager.messages.length, 1);
        expect(manager.messages.first.role, AiMessageRole.system);
        expect(
          _systemOrAssistantContent(manager.messages.first),
          'New system message',
        );
      });

      test('initialize without system message', () {
        // Add some messages
        manager.addUserMessage('Message 1');
        expect(manager.messages.length, 1);

        // Initialize without system message
        manager.initialize();

        // Should have no messages
        expect(manager.messages, isEmpty);
      });

      test('initialize emits initialization event', () {
        fakeAsync((async) {
          final events = <ConversationEvent>[];
          manager.events.listen(events.add);

          manager.initialize(systemMessage: 'Test system');

          // Deterministically allow event processing
          async.flushMicrotasks();

          expect(events.length, 1);
          expect(events.first, isA<ConversationInitializedEvent>());
          final initEvent = events.first as ConversationInitializedEvent;
          expect(initEvent.conversationId, 'test-conversation');
          expect(initEvent.systemMessage, 'Test system');
        });
      });
    });

    group('Turn Management', () {
      test('turnCount counts only user messages', () {
        manager.initialize(systemMessage: 'System');
        expect(manager.turnCount, 0);

        manager.addUserMessage('User 1');
        expect(manager.turnCount, 1);

        manager.addAssistantMessage(content: 'Assistant 1');
        expect(manager.turnCount, 1);

        manager.addUserMessage('User 2');
        expect(manager.turnCount, 2);

        manager.addToolResponse(toolCallId: 'tool-1', response: 'Tool');
        expect(manager.turnCount, 2);
      });

      test('canContinue respects maxTurns', () {
        final limitedManager = ConversationManager(
          conversationId: 'limited',
          maxTurns: 3,
        );

        expect(limitedManager.canContinue(), true);

        // Add 3 user messages
        for (var i = 0; i < 3; i++) {
          limitedManager.addUserMessage('Message $i');
          if (i < 2) {
            expect(limitedManager.canContinue(), true);
          }
        }

        expect(limitedManager.canContinue(), false);
      });
    });

    group('getMessagesForRequest', () {
      test('returns copy of messages', () {
        manager.addUserMessage('Test message');

        final messages1 = manager.getMessagesForRequest();
        final messages2 = manager.getMessagesForRequest();

        // Should be different instances
        expect(identical(messages1, messages2), false);

        // But contain the same data
        expect(messages1.length, messages2.length);
        expect(
          _systemOrAssistantContent(messages1.first),
          _systemOrAssistantContent(messages2.first),
        );
      });
    });

    group('Edge Cases', () {
      test('handles trimming with exactly max size', () {
        // Add exactly 50 messages
        for (var i = 0; i < 50; i++) {
          manager.addUserMessage('Message $i');
        }

        expect(manager.messages.length, 50);
        // No truncation message
        expect(
          manager.messages.any(
            (msg) =>
                _systemOrAssistantContent(msg)?.contains('truncated') ?? false,
          ),
          false,
        );
      });

      test('handles trimming when trimmed result would still exceed max', () {
        // Create manager with small max size
        final smallManager = ConversationManager(
          conversationId: 'small',
          maxHistorySize: 5,
        );

        // Add many messages
        for (var i = 0; i < 20; i++) {
          smallManager.addUserMessage('Message $i');
        }

        // Should be at or below max size
        expect(smallManager.messages.length, lessThanOrEqualTo(5));

        // Should have truncation notice
        expect(
          smallManager.messages.any(
            (msg) =>
                _systemOrAssistantContent(msg)?.contains('truncated') ?? false,
          ),
          true,
        );
      });
    });

    group('ConversationStrategy', () {
      test('ConversationAction enum values', () {
        expect(ConversationAction.values.length, 3);
        expect(ConversationAction.continueConversation.index, 0);
        expect(ConversationAction.complete.index, 1);
        expect(ConversationAction.wait.index, 2);
      });
    });

    group('Thought Signatures', () {
      test('stores thought signatures when adding assistant message', () {
        final toolCalls = [
          const AiToolCall(
            id: 'tool-1',
            name: 'test_function',
            arguments: '{"arg": "value"}',
          ),
        ];

        manager.addAssistantMessage(
          toolCalls: toolCalls,
          signatures: {'tool-1': 'signature-abc123'},
        );

        expect(manager.thoughtSignatures, {'tool-1': 'signature-abc123'});
      });

      test('accumulates signatures across multiple messages', () {
        final toolCalls1 = [
          const AiToolCall(
            id: 'tool-1',
            name: 'func1',
            arguments: '{}',
          ),
        ];

        final toolCalls2 = [
          const AiToolCall(
            id: 'tool-2',
            name: 'func2',
            arguments: '{}',
          ),
        ];

        manager
          ..addAssistantMessage(
            toolCalls: toolCalls1,
            signatures: {'tool-1': 'sig-1'},
          )
          ..addToolResponse(toolCallId: 'tool-1', response: 'Result 1')
          ..addAssistantMessage(
            toolCalls: toolCalls2,
            signatures: {'tool-2': 'sig-2'},
          );

        expect(manager.thoughtSignatures, {
          'tool-1': 'sig-1',
          'tool-2': 'sig-2',
        });
      });

      test('thoughtSignatures returns unmodifiable map', () {
        manager.addAssistantMessage(
          signatures: {'tool-1': 'sig-1'},
        );

        final signatures = manager.thoughtSignatures;
        expect(
          () => signatures['tool-2'] = 'sig-2',
          throwsUnsupportedError,
        );
      });

      test('does not store signatures when null', () {
        final toolCalls = [
          const AiToolCall(
            id: 'tool-1',
            name: 'test_function',
            arguments: '{}',
          ),
        ];

        manager.addAssistantMessage(toolCalls: toolCalls);

        expect(manager.thoughtSignatures, isEmpty);
      });
    });

    group('Generated lifecycle sequences', () {
      glados.Glados(
        glados.any.conversationScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test('match generated message, event, and signature semantics', (
        scenario,
      ) {
        fakeAsync((async) {
          final generatedManager = ConversationManager(
            conversationId: 'generated-conversation',
            maxTurns: scenario.maxTurns,
            maxHistorySize: scenario.maxHistorySize,
          );
          final model = _GeneratedConversationModel(
            maxTurns: scenario.maxTurns,
            maxHistorySize: scenario.maxHistorySize,
          );
          final events = <ConversationEvent>[];
          generatedManager.events.listen(events.add);

          for (final (index, operation) in scenario.operations.indexed) {
            switch (operation.kind) {
              case _GeneratedConversationOperationKind.initializeEmpty:
                generatedManager.initialize();

              case _GeneratedConversationOperationKind.initializeWithSystem:
                generatedManager.initialize(systemMessage: operation.text);

              case _GeneratedConversationOperationKind.addUser:
                generatedManager.addUserMessage(operation.text);

              case _GeneratedConversationOperationKind.addAssistantContent:
                generatedManager.addAssistantMessage(content: operation.text);

              case _GeneratedConversationOperationKind.addAssistantEmpty:
                generatedManager.addAssistantMessage();

              case _GeneratedConversationOperationKind.addAssistantToolCall:
                generatedManager.addAssistantMessage(
                  toolCalls: [_generatedToolCall(operation.toolId)],
                );

              case _GeneratedConversationOperationKind
                  .addAssistantToolCallWithSignature:
                generatedManager.addAssistantMessage(
                  toolCalls: [_generatedToolCall(operation.toolId)],
                  signatures: {
                    operation.toolId: _generatedConversationSignature(
                      operation.toolSlot,
                      index,
                    ),
                  },
                );

              case _GeneratedConversationOperationKind.addToolResponse:
                generatedManager.addToolResponse(
                  toolCallId: operation.toolId,
                  response: operation.text,
                );

              case _GeneratedConversationOperationKind.emitThinking:
                generatedManager.emitThinking();

              case _GeneratedConversationOperationKind.emitError:
                generatedManager.emitError(operation.text);
            }
            model.apply(operation, index);
          }

          async.flushMicrotasks();

          expect(
            _conversationRoles(generatedManager.messages),
            model.roles,
            reason: '$scenario',
          );
          expect(
            generatedManager.thoughtSignatures,
            model.signatures,
            reason: '$scenario',
          );
          expect(generatedManager.turnCount, model.turnCount);
          expect(generatedManager.canContinue(), model.canContinue);
          expect(events.length, model.eventCount, reason: '$scenario');

          generatedManager.dispose();
        });
      }, tags: 'glados');

      glados.Glados(
        glados.any.conversationHistoryScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test(
        'preserve latest generated history with one truncation notice',
        (
          scenario,
        ) {
          final generatedManager = ConversationManager(
            conversationId: 'generated-history',
            maxHistorySize: scenario.maxHistorySize,
          );

          if (scenario.hasSystemMessage) {
            generatedManager.initialize(systemMessage: 'generated system');
          }
          for (var i = 0; i < scenario.userMessageCount; i++) {
            generatedManager.addUserMessage('generated user $i');
          }

          final messages = generatedManager.messages;
          final truncationNoticeCount = messages
              .where(_isGeneratedTruncationNotice)
              .length;
          final retainedUserMessages = messages
              .whereType<AiUserMessage>()
              .toList();

          expect(
            truncationNoticeCount,
            lessThanOrEqualTo(1),
            reason: '$scenario',
          );
          expect(
            messages.length,
            lessThanOrEqualTo(scenario.retainedMessageLimit),
            reason: '$scenario',
          );
          expect(
            generatedManager.turnCount,
            retainedUserMessages.length,
            reason: '$scenario',
          );

          if (scenario.hasSystemMessage) {
            expect(
              _systemOrAssistantContent(messages.first),
              'generated system',
            );
          } else {
            expect(
              messages
                  .where(
                    (message) =>
                        message is AiSystemMessage &&
                        !_isGeneratedTruncationNotice(message),
                  )
                  .toList(),
              isEmpty,
              reason: '$scenario',
            );
          }

          if (scenario.userMessageCount > 0) {
            expect(
              _systemOrAssistantContent(messages.last),
              contains('generated user ${scenario.userMessageCount - 1}'),
              reason: '$scenario',
            );
          }

          if (truncationNoticeCount == 1) {
            final noticeIndex = scenario.hasSystemMessage ? 1 : 0;
            expect(
              _isGeneratedTruncationNotice(messages[noticeIndex]),
              true,
              reason: '$scenario',
            );
            expect(retainedUserMessages, isNotEmpty, reason: '$scenario');
          }

          generatedManager.dispose();
        },
        tags: 'glados',
      );
    });

    group('Event Classes', () {
      test('ConversationErrorEvent properties', () {
        final event =
            ConversationEvent.error(
                  message: 'Test error',
                  turnNumber: 5,
                )
                as ConversationErrorEvent;

        expect(event.message, 'Test error');
        expect(event.turnNumber, 5);
      });

      test('UserMessageEvent properties', () {
        final event =
            ConversationEvent.userMessage(
                  message: 'User input',
                  turnNumber: 3,
                )
                as UserMessageEvent;

        expect(event.message, 'User input');
        expect(event.turnNumber, 3);
      });

      test('ToolCallsEvent properties', () {
        final toolCalls = [
          const AiToolCall(
            id: 'tool-1',
            name: 'test',
            arguments: '{}',
          ),
        ];

        final event =
            ConversationEvent.toolCalls(
                  calls: toolCalls,
                  turnNumber: 2,
                )
                as ToolCallsEvent;

        expect(event.calls, toolCalls);
        expect(event.turnNumber, 2);
      });
    });
  });
}
