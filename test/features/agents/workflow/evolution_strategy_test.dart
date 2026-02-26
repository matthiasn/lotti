import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  late EvolutionStrategy strategy;
  late ConversationManager manager;

  setUp(() {
    strategy = EvolutionStrategy();
    manager = ConversationManager(conversationId: 'test-conv')
      ..initialize(systemMessage: 'You are an evolution agent.');
  });

  ChatCompletionMessageToolCall makeToolCall({
    required String name,
    required Map<String, dynamic> args,
    String id = 'call-1',
  }) {
    return ChatCompletionMessageToolCall(
      id: id,
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: name,
        arguments: jsonEncode(args),
      ),
    );
  }

  group('propose_directives', () {
    test('captures proposal and returns wait action', () async {
      final toolCall = makeToolCall(
        name: 'propose_directives',
        args: {
          'directives': 'Be helpful and empathetic.',
          'rationale': 'Added empathy based on user feedback.',
        },
      );

      // Add an assistant message with tool calls so the manager state is valid.
      manager.addAssistantMessage(toolCalls: [toolCall]);

      final action = await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(action, ConversationAction.wait);
      expect(strategy.latestProposal, isNotNull);
      expect(
        strategy.latestProposal!.directives,
        'Be helpful and empathetic.',
      );
      expect(
        strategy.latestProposal!.rationale,
        'Added empathy based on user feedback.',
      );
    });

    test('rejects empty directives', () async {
      final toolCall = makeToolCall(
        name: 'propose_directives',
        args: {'directives': '  ', 'rationale': 'Whatever'},
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);

      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(strategy.latestProposal, isNull);
    });

    test('overwrites previous proposal', () async {
      final call1 = makeToolCall(
        name: 'propose_directives',
        args: {'directives': 'First draft', 'rationale': 'v1'},
      );
      manager.addAssistantMessage(toolCalls: [call1]);
      await strategy.processToolCalls(
        toolCalls: [call1],
        manager: manager,
      );

      expect(strategy.latestProposal!.directives, 'First draft');

      final call2 = makeToolCall(
        id: 'call-2',
        name: 'propose_directives',
        args: {'directives': 'Revised draft', 'rationale': 'v2'},
      );
      manager.addAssistantMessage(toolCalls: [call2]);
      await strategy.processToolCalls(
        toolCalls: [call2],
        manager: manager,
      );

      expect(strategy.latestProposal!.directives, 'Revised draft');
    });

    test('clearProposal removes latest proposal', () async {
      final toolCall = makeToolCall(
        name: 'propose_directives',
        args: {'directives': 'Some text', 'rationale': 'Because'},
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(strategy.latestProposal, isNotNull);

      strategy.clearProposal();

      expect(strategy.latestProposal, isNull);
    });
  });

  group('record_evolution_note', () {
    test('accumulates notes with correct kinds', () async {
      final call1 = makeToolCall(
        name: 'record_evolution_note',
        args: {'kind': 'reflection', 'content': 'Users prefer short reports.'},
      );
      final call2 = makeToolCall(
        id: 'call-2',
        name: 'record_evolution_note',
        args: {'kind': 'hypothesis', 'content': 'Shorter may be better.'},
      );
      manager.addAssistantMessage(toolCalls: [call1, call2]);

      await strategy.processToolCalls(
        toolCalls: [call1, call2],
        manager: manager,
      );

      expect(strategy.pendingNotes, hasLength(2));
      expect(strategy.pendingNotes[0].kind, EvolutionNoteKind.reflection);
      expect(
        strategy.pendingNotes[0].content,
        'Users prefer short reports.',
      );
      expect(strategy.pendingNotes[1].kind, EvolutionNoteKind.hypothesis);
    });

    test('rejects invalid kind', () async {
      final toolCall = makeToolCall(
        name: 'record_evolution_note',
        args: {'kind': 'invalid_kind', 'content': 'Some content'},
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);

      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(strategy.pendingNotes, isEmpty);
    });

    test('rejects empty content', () async {
      final toolCall = makeToolCall(
        name: 'record_evolution_note',
        args: {'kind': 'decision', 'content': '  '},
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);

      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(strategy.pendingNotes, isEmpty);
    });

    test('all EvolutionNoteKind values are accepted', () async {
      for (final kind in EvolutionNoteKind.values) {
        final toolCall = makeToolCall(
          id: 'call-${kind.name}',
          name: 'record_evolution_note',
          args: {'kind': kind.name, 'content': 'Content for ${kind.name}'},
        );
        manager.addAssistantMessage(toolCalls: [toolCall]);
        await strategy.processToolCalls(
          toolCalls: [toolCall],
          manager: manager,
        );
      }

      expect(strategy.pendingNotes, hasLength(EvolutionNoteKind.values.length));
    });
  });

  group('unknown tool', () {
    test('returns wait and does not crash', () async {
      final toolCall = makeToolCall(
        name: 'nonexistent_tool',
        args: {'foo': 'bar'},
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);

      final action = await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(action, ConversationAction.wait);
      expect(strategy.latestProposal, isNull);
      expect(strategy.pendingNotes, isEmpty);
    });
  });

  group('shouldContinue', () {
    test('returns true when manager can continue', () {
      expect(strategy.shouldContinue(manager), isTrue);
    });

    test('returns false when manager has exhausted turns', () {
      final exhausted = ConversationManager(
        conversationId: 'exhausted',
        maxTurns: 1,
      )
        ..initialize()
        // Add one user message to exhaust the single turn.
        ..addUserMessage('Hello');

      expect(strategy.shouldContinue(exhausted), isFalse);
    });
  });

  group('getContinuationPrompt', () {
    test('returns null (user drives conversation)', () {
      expect(strategy.getContinuationPrompt(manager), isNull);
    });
  });

  group('mixed tool calls', () {
    test('handles proposal and notes in same turn', () async {
      final proposalCall = makeToolCall(
        name: 'propose_directives',
        args: {
          'directives': 'New directives',
          'rationale': 'Based on feedback',
        },
      );
      final noteCall = makeToolCall(
        id: 'call-2',
        name: 'record_evolution_note',
        args: {'kind': 'decision', 'content': 'Decided to simplify tone.'},
      );
      manager.addAssistantMessage(toolCalls: [proposalCall, noteCall]);

      final action = await strategy.processToolCalls(
        toolCalls: [proposalCall, noteCall],
        manager: manager,
      );

      expect(action, ConversationAction.wait);
      expect(strategy.latestProposal, isNotNull);
      expect(strategy.pendingNotes, hasLength(1));
    });
  });

  group('malformed arguments', () {
    test('handles invalid JSON gracefully', () async {
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-bad',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_directives',
          arguments: 'not valid json',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);

      final action = await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      // Should not crash; proposal is null due to missing args.
      expect(action, ConversationAction.wait);
      expect(strategy.latestProposal, isNull);
    });
  });
}
