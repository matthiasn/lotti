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
      test('should add messages and emit events', () async {
        final events = <ConversationEvent>[];
        manager.events.listen(events.add);

        manager.addUserMessage('Test message');

        // Allow stream to process
        await Future<void>.delayed(Duration.zero);

        expect(manager.messages.length, 1);
        expect(events.whereType<UserMessageEvent>().length, 1);
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
  });
}
