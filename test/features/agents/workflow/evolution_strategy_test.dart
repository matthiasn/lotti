import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/genui/genui_bridge.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:openai_dart/openai_dart.dart';
import 'evolution_strategy_test_helpers.dart';

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
          'general_directive': 'Be helpful and empathetic.',
          'report_directive': '',
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
        strategy.latestProposal!.generalDirective,
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
        args: {
          'general_directive': '  ',
          'report_directive': '',
          'rationale': 'Whatever',
        },
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
        args: {
          'general_directive': 'First draft',
          'report_directive': '',
          'rationale': 'v1',
        },
      );
      manager.addAssistantMessage(toolCalls: [call1]);
      await strategy.processToolCalls(
        toolCalls: [call1],
        manager: manager,
      );

      expect(strategy.latestProposal!.generalDirective, 'First draft');

      final call2 = makeToolCall(
        id: 'call-2',
        name: 'propose_directives',
        args: {
          'general_directive': 'Revised draft',
          'report_directive': '',
          'rationale': 'v2',
        },
      );
      manager.addAssistantMessage(toolCalls: [call2]);
      await strategy.processToolCalls(
        toolCalls: [call2],
        manager: manager,
      );

      expect(strategy.latestProposal!.generalDirective, 'Revised draft');
    });

    test('clearProposal removes latest proposal', () async {
      final toolCall = makeToolCall(
        name: 'propose_directives',
        args: {
          'general_directive': 'Some text',
          'report_directive': '',
          'rationale': 'Because',
        },
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

    // Property: every EvolutionNoteKind is accepted, and the recorded
    // PendingNote round-trips both the kind and the content — stronger than
    // asserting only the count, and it shrinks failures automatically if a
    // new kind is added that the handler does not map.
    glados.Glados(
      glados.AnyUtils(glados.any).choose(EvolutionNoteKind.values),
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'accepts any EvolutionNoteKind and round-trips kind + content',
      (kind) async {
        // Fresh strategy/manager per iteration — Glados re-runs the body many
        // times within one test() and the shared setUp fixtures would
        // accumulate notes across runs.
        final localStrategy = EvolutionStrategy();
        final localManager = ConversationManager(conversationId: 'glados-conv')
          ..initialize(systemMessage: 'You are an evolution agent.');
        final content = 'Content for ${kind.name}';
        final toolCall = makeToolCall(
          id: 'call-${kind.name}',
          name: 'record_evolution_note',
          args: {'kind': kind.name, 'content': content},
        );
        localManager.addAssistantMessage(toolCalls: [toolCall]);

        await localStrategy.processToolCalls(
          toolCalls: [toolCall],
          manager: localManager,
        );

        expect(localStrategy.pendingNotes, hasLength(1), reason: '$kind');
        expect(localStrategy.pendingNotes.single.kind, kind, reason: '$kind');
        expect(
          localStrategy.pendingNotes.single.content,
          content,
          reason: '$kind',
        );
      },
      tags: 'glados',
    );
  });

  group('publish_ritual_recap', () {
    test('captures structured recap content', () async {
      final toolCall = makeToolCall(
        name: 'publish_ritual_recap',
        args: {
          'tldr': 'Short recap for history.',
          'content': '## Session recap\n\nWe tightened the opening prompt.',
        },
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);

      final action = await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(action, ConversationAction.wait);
      expect(strategy.latestRecap, isNotNull);
      expect(strategy.latestRecap!.tldr, 'Short recap for history.');
      expect(
        strategy.latestRecap!.content,
        '## Session recap\n\nWe tightened the opening prompt.',
      );
    });

    test('rejects empty tldr or content', () async {
      final toolCall = makeToolCall(
        name: 'publish_ritual_recap',
        args: {
          'tldr': '  ',
          'content': '',
        },
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);

      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(strategy.latestRecap, isNull);
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
      final exhausted =
          ConversationManager(
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
          'general_directive': 'New directives',
          'report_directive': '',
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
      final bench = buildGenUiBench(conversationId: 'test-auto');
      bridge = bench.bridge;
      strategyWithBridge = bench.strategy;
      bridgeManager = bench.manager;
    });

    test('propose_directives automatically creates a GenUI surface', () async {
      final toolCall = makeToolCall(
        name: 'propose_directives',
        args: {
          'general_directive': 'Be concise and helpful.',
          'report_directive': '',
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

    test(
      'propose_directives with empty directives does not create surface',
      () async {
        final toolCall = makeToolCall(
          name: 'propose_directives',
          args: {
            'general_directive': '  ',
            'report_directive': '',
            'rationale': 'Whatever',
          },
        );
        bridgeManager.addAssistantMessage(toolCalls: [toolCall]);

        await strategyWithBridge.processToolCalls(
          toolCalls: [toolCall],
          manager: bridgeManager,
        );

        expect(strategyWithBridge.latestProposal, isNull);
        expect(bridge.drainPendingSurfaceIds(), isEmpty);
      },
    );
  });
}
