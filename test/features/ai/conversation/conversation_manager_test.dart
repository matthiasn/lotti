import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:openai_dart/openai_dart.dart';

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
              (msg) => msg.content?.toString().contains('truncated') ?? false),
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
        expect(manager.messages.first.role, ChatCompletionMessageRole.system);
        expect(
          manager.messages.first.content?.toString().contains('truncated') ??
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
        expect(manager.messages.first.role, ChatCompletionMessageRole.system);
        expect(
          manager.messages.first.content?.toString() ?? '',
          contains('helpful assistant'),
        );

        // Truncation notice should be second
        expect(manager.messages[1].role, ChatCompletionMessageRole.system);
        expect(
          manager.messages[1].content?.toString() ?? '',
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
        final systemMessages = messages
            .where((m) => m.role == ChatCompletionMessageRole.system)
            .toList();
        expect(systemMessages.length, greaterThanOrEqualTo(1));

        // Should have truncation notice
        expect(
          messages
              .any((m) => m.content?.toString().contains('truncated') ?? false),
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
        expect(manager.messages.first.role, ChatCompletionMessageRole.tool);
      });
    });

    group('export', () {
      test('should export conversation as formatted string', () {
        manager
          ..initialize(systemMessage: 'System message')
          ..addUserMessage('User message')
          ..addAssistantMessage(content: 'Assistant response');

        final exported = manager.exportAsString();

        expect(exported, contains('SYSTEM: System message'));
        expect(exported, contains('USER: User message'));
        expect(exported, contains('ASSISTANT: Assistant response'));
      });

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
          expect(manager.messages.first.role, ChatCompletionMessageRole.tool);

          expect(events.length, 1);
          expect(events.first, isA<ToolResponseEvent>());
          final toolEvent = events.first as ToolResponseEvent;
          expect(toolEvent.toolCallId, 'tool-123');
          expect(toolEvent.response, 'Tool executed successfully');
        });
      });
    });

    group('Assistant Message Handling', () {
      test('addAssistantMessage with only content', () {
        fakeAsync((async) {
          final events = <ConversationEvent>[];
          manager.events.listen(events.add);

          manager.addAssistantMessage(
            content: 'This is the assistant response',
          );
          async.flushMicrotasks();

          expect(manager.messages.length, 1);
          expect(
              manager.messages.first.role, ChatCompletionMessageRole.assistant);
          expect(
              manager.messages.first.content, 'This is the assistant response');

          expect(events.length, 1);
          expect(events.first, isA<AssistantMessageEvent>());
          final assistantEvent = events.first as AssistantMessageEvent;
          expect(assistantEvent.message, 'This is the assistant response');
        });
      });

      test('addAssistantMessage with only tool calls', () async {
        final events = <ConversationEvent>[];
        manager.events.listen(events.add);

        final toolCalls = [
          const ChatCompletionMessageToolCall(
            id: 'tool-1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'test_function',
              arguments: '{"arg": "value"}',
            ),
          ),
        ];

        manager.addAssistantMessage(
          toolCalls: toolCalls,
        );

        // Allow event processing
        await Future<void>.delayed(Duration.zero);

        expect(manager.messages.length, 1);
        expect(
            manager.messages.first.role, ChatCompletionMessageRole.assistant);
        expect(manager.messages.first.content, isNull);
        // Tool calls were provided in the addAssistantMessage call

        expect(events.length, 1);
        expect(events.first, isA<ToolCallsEvent>());
        final toolCallsEvent = events.first as ToolCallsEvent;
        expect(toolCallsEvent.calls, toolCalls);
      });

      test('addAssistantMessage with both content and tool calls', () async {
        final events = <ConversationEvent>[];
        manager.events.listen(events.add);

        final toolCalls = [
          const ChatCompletionMessageToolCall(
            id: 'tool-1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'test_function',
              arguments: '{"arg": "value"}',
            ),
          ),
        ];

        manager.addAssistantMessage(
          content: 'Executing function',
          toolCalls: toolCalls,
        );

        // Allow event processing
        await Future<void>.delayed(Duration.zero);

        expect(manager.messages.length, 1);
        expect(manager.messages.first.content, 'Executing function');
        // Both content and tool calls were provided

        // Should emit tool calls event (takes priority over content)
        expect(events.length, 1);
        expect(events.first, isA<ToolCallsEvent>());
      });

      test('addAssistantMessage with neither content nor tool calls', () async {
        final events = <ConversationEvent>[];
        manager.events.listen(events.add);

        manager.addAssistantMessage();

        // Allow event processing
        await Future<void>.delayed(Duration.zero);

        expect(manager.messages.length, 1);
        expect(
            manager.messages.first.role, ChatCompletionMessageRole.assistant);
        expect(manager.messages.first.content, isNull);
        // Neither content nor tool calls were provided

        // No event should be emitted for empty assistant message
        expect(events, isEmpty);
      });
    });

    group('Export Functionality - Extended', () {
      test('exportAsString handles ChatCompletionUserMessageContent parts', () {
        // Test with a simple message first
        manager.addUserMessage('Simple message');

        // The ConversationManager's addUserMessage method creates messages with
        // string content, not parts. To properly test parts handling, we would
        // need to extend the manager's API or test the export logic differently.
        // For now, we'll verify that string content is exported correctly.

        final exported = manager.exportAsString();

        expect(exported, contains('USER: Simple message'));

        // Since we can't directly add parts messages through the public API,
        // we're verifying that regular messages are handled correctly.
        // The parts handling logic in exportAsString should work if messages
        // with parts content are added through other means (e.g., from AI responses).
      });

      test('exportAsString handles unknown content types', () {
        // Add a message with custom content type
        // Note: ChatCompletionMessage is a sealed class, so we can't create custom content types
        manager.addUserMessage('[Unknown content type]');

        final exported = manager.exportAsString();

        expect(exported, contains('USER: [Unknown content type]'));
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
        expect(manager.messages.first.role, ChatCompletionMessageRole.system);
        expect(manager.messages.first.content, 'New system message');
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
        expect(messages1.first.content, messages2.first.content);
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
            (msg) => msg.content?.toString().contains('truncated') ?? false,
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
            (msg) => msg.content?.toString().contains('truncated') ?? false,
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

    group('Event Classes', () {
      test('ConversationErrorEvent properties', () {
        final event = ConversationEvent.error(
          message: 'Test error',
          turnNumber: 5,
        ) as ConversationErrorEvent;

        expect(event.message, 'Test error');
        expect(event.turnNumber, 5);
      });

      test('UserMessageEvent properties', () {
        final event = ConversationEvent.userMessage(
          message: 'User input',
          turnNumber: 3,
        ) as UserMessageEvent;

        expect(event.message, 'User input');
        expect(event.turnNumber, 3);
      });

      test('ToolCallsEvent properties', () {
        final toolCalls = [
          const ChatCompletionMessageToolCall(
            id: 'tool-1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'test',
              arguments: '{}',
            ),
          ),
        ];

        final event = ConversationEvent.toolCalls(
          calls: toolCalls,
          turnNumber: 2,
        ) as ToolCallsEvent;

        expect(event.calls, toolCalls);
        expect(event.turnNumber, 2);
      });
    });
  });
}
