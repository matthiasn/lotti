import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:lotti/features/agents/genui/genui_bridge.dart';
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

  group('removeFirstNote', () {
    test('returns and removes the first note', () async {
      final toolCall = makeToolCall(
        name: 'record_evolution_note',
        args: {'kind': 'reflection', 'content': 'First note'},
      );
      final toolCall2 = makeToolCall(
        id: 'call-2',
        name: 'record_evolution_note',
        args: {'kind': 'decision', 'content': 'Second note'},
      );
      manager.addAssistantMessage(toolCalls: [toolCall, toolCall2]);
      await strategy.processToolCalls(
        toolCalls: [toolCall, toolCall2],
        manager: manager,
      );

      expect(strategy.pendingNotes, hasLength(2));

      final first = strategy.removeFirstNote();
      expect(first, isNotNull);
      expect(first!.content, 'First note');
      expect(strategy.pendingNotes, hasLength(1));

      final second = strategy.removeFirstNote();
      expect(second, isNotNull);
      expect(second!.content, 'Second note');
      expect(strategy.pendingNotes, isEmpty);
    });

    test('returns null when no notes pending', () {
      expect(strategy.removeFirstNote(), isNull);
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

  group('auto-surface on propose_directives', () {
    late GenUiBridge bridge;
    late EvolutionStrategy strategyWithBridge;
    late ConversationManager bridgeManager;

    setUp(() {
      final catalog = buildEvolutionCatalog();
      final processor = A2uiMessageProcessor(catalogs: [catalog]);
      bridge = GenUiBridge(processor: processor);
      strategyWithBridge = EvolutionStrategy(genUiBridge: bridge);
      bridgeManager = ConversationManager(conversationId: 'test-auto')
        ..initialize(systemMessage: 'You are an evolution agent.');
    });

    test('propose_directives automatically creates a GenUI surface', () async {
      final toolCall = makeToolCall(
        name: 'propose_directives',
        args: {
          'directives': 'Be concise and helpful.',
          'rationale': 'User feedback suggested brevity.',
        },
      );
      bridgeManager.addAssistantMessage(toolCalls: [toolCall]);

      await strategyWithBridge.processToolCalls(
        toolCalls: [toolCall],
        manager: bridgeManager,
      );

      expect(strategyWithBridge.latestProposal, isNotNull);
      final surfaceIds = bridge.drainPendingSurfaceIds();
      expect(surfaceIds, hasLength(1));
      expect(surfaceIds.first, startsWith('proposal-'));
    });

    test('propose_directives with empty directives does not create surface',
        () async {
      final toolCall = makeToolCall(
        name: 'propose_directives',
        args: {'directives': '  ', 'rationale': 'Whatever'},
      );
      bridgeManager.addAssistantMessage(toolCalls: [toolCall]);

      await strategyWithBridge.processToolCalls(
        toolCalls: [toolCall],
        manager: bridgeManager,
      );

      expect(strategyWithBridge.latestProposal, isNull);
      expect(bridge.drainPendingSurfaceIds(), isEmpty);
    });
  });

  group('GenUI bridge delegation', () {
    late GenUiBridge bridge;
    late EvolutionStrategy strategyWithBridge;
    late ConversationManager bridgeManager;

    setUp(() {
      final catalog = buildEvolutionCatalog();
      final processor = A2uiMessageProcessor(catalogs: [catalog]);
      bridge = GenUiBridge(processor: processor);
      strategyWithBridge = EvolutionStrategy(genUiBridge: bridge);
      bridgeManager = ConversationManager(conversationId: 'test-bridge')
        ..initialize(systemMessage: 'You are an evolution agent.');
    });

    test('delegates render_surface to GenUiBridge', () async {
      final toolCall = makeToolCall(
        name: 'render_surface',
        args: {
          'surfaceId': 'surf-1',
          'rootType': 'MetricsSummary',
          'data': {
            'totalWakes': 5,
            'successRate': 0.9,
            'failureCount': 1,
          },
        },
      );
      bridgeManager.addAssistantMessage(toolCalls: [toolCall]);

      final action = await strategyWithBridge.processToolCalls(
        toolCalls: [toolCall],
        manager: bridgeManager,
      );

      expect(action, ConversationAction.wait);
      expect(bridge.drainPendingSurfaceIds(), ['surf-1']);
      // Should not affect proposal or notes.
      expect(strategyWithBridge.latestProposal, isNull);
      expect(strategyWithBridge.pendingNotes, isEmpty);
    });

    test('processes render_surface alongside other tools', () async {
      final surfaceCall = makeToolCall(
        name: 'render_surface',
        args: {
          'surfaceId': 'surf-2',
          'rootType': 'EvolutionNoteConfirmation',
          'data': {'kind': 'reflection', 'content': 'Noted.'},
        },
      );
      final proposalCall = makeToolCall(
        id: 'call-2',
        name: 'propose_directives',
        args: {
          'directives': 'Be concise.',
          'rationale': 'Users prefer short answers.',
        },
      );
      bridgeManager.addAssistantMessage(
        toolCalls: [surfaceCall, proposalCall],
      );

      await strategyWithBridge.processToolCalls(
        toolCalls: [surfaceCall, proposalCall],
        manager: bridgeManager,
      );

      // 2 surfaces: one explicit render_surface + one auto from
      // propose_directives.
      final surfaceIds = bridge.drainPendingSurfaceIds();
      expect(surfaceIds, hasLength(2));
      expect(surfaceIds.first, 'surf-2');
      expect(surfaceIds.last, startsWith('proposal-'));
      expect(strategyWithBridge.latestProposal, isNotNull);
      expect(
        strategyWithBridge.latestProposal!.directives,
        'Be concise.',
      );
    });

    test('without bridge, render_surface falls through to unknown tool',
        () async {
      // Strategy without bridge.
      final noBridgeStrategy = EvolutionStrategy();
      final toolCall = makeToolCall(
        name: 'render_surface',
        args: {
          'surfaceId': 'x',
          'rootType': 'MetricsSummary',
          'data': <String, dynamic>{},
        },
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);

      final action = await noBridgeStrategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(action, ConversationAction.wait);
      // No crash, treated as unknown tool.
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

    test('handles non-string argument values gracefully', () async {
      // Simulate the LLM emitting an integer instead of a string for
      // "directives". The defensive _readStringArg helper should treat
      // non-string values as empty rather than throwing a TypeError.
      final toolCall = makeToolCall(
        name: 'propose_directives',
        args: {'directives': 42, 'rationale': true},
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);

      final action = await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(action, ConversationAction.wait);
      // Empty directives should be rejected, not crash.
      expect(strategy.latestProposal, isNull);
    });

    test('handles non-string kind in record_evolution_note', () async {
      final toolCall = makeToolCall(
        name: 'record_evolution_note',
        args: {'kind': 123, 'content': 'Some content'},
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);

      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      // Invalid kind (non-string) should be rejected.
      expect(strategy.pendingNotes, isEmpty);
    });
  });
}
