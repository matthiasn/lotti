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
      final catalog = buildEvolutionCatalog();
      final processor = SurfaceController(catalogs: [catalog]);
      bridge = GenUiBridge(processor: processor);
      strategyWithBridge = EvolutionStrategy(genUiBridge: bridge);
      bridgeManager = ConversationManager(conversationId: 'test-auto')
        ..initialize(systemMessage: 'You are an evolution agent.');
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

  group('GenUI bridge delegation', () {
    late GenUiBridge bridge;
    late EvolutionStrategy strategyWithBridge;
    late ConversationManager bridgeManager;

    setUp(() {
      final catalog = buildEvolutionCatalog();
      final processor = SurfaceController(catalogs: [catalog]);
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
          'general_directive': 'Be concise.',
          'report_directive': '',
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
        strategyWithBridge.latestProposal!.generalDirective,
        'Be concise.',
      );
    });

    test(
      'without bridge, render_surface falls through to unknown tool',
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
      },
    );
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
        args: {
          'general_directive': 42,
          'report_directive': true,
          'rationale': true,
        },
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

    test('handles non-string values in publish_ritual_recap', () async {
      final toolCall = makeToolCall(
        name: 'publish_ritual_recap',
        args: {'tldr': 123, 'content': true},
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);

      final action = await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(action, ConversationAction.wait);
      expect(strategy.latestRecap, isNull);
    });
  });

  group('propose_soul_directives', () {
    test('captures soul proposal and returns wait action', () async {
      final toolCall = makeToolCall(
        name: 'propose_soul_directives',
        args: {
          'voice_directive': 'Be warm and clear.',
          'tone_bounds': 'Never be sarcastic.',
          'coaching_style': 'Celebrate wins.',
          'anti_sycophancy_policy': 'Push back firmly.',
          'rationale': 'Personality needs refinement.',
        },
      );

      final action = await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(action, ConversationAction.wait);
      expect(strategy.latestSoulProposal, isNotNull);
      expect(
        strategy.latestSoulProposal!.voiceDirective,
        'Be warm and clear.',
      );
      expect(strategy.latestSoulProposal!.toneBounds, 'Never be sarcastic.');
      expect(strategy.latestSoulProposal!.coachingStyle, 'Celebrate wins.');
      expect(
        strategy.latestSoulProposal!.antiSycophancyPolicy,
        'Push back firmly.',
      );
      expect(
        strategy.latestSoulProposal!.rationale,
        'Personality needs refinement.',
      );
    });

    test('rejects when rationale is empty', () async {
      final toolCall = makeToolCall(
        name: 'propose_soul_directives',
        args: {
          'voice_directive': 'Valid voice.',
          'rationale': '  ',
        },
      );

      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(strategy.latestSoulProposal, isNull);
    });

    test('rejects when all directive fields are empty', () async {
      final toolCall = makeToolCall(
        name: 'propose_soul_directives',
        args: {
          'voice_directive': '',
          'tone_bounds': '  ',
          'coaching_style': '',
          'anti_sycophancy_policy': '',
          'rationale': 'Some rationale.',
        },
      );

      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(strategy.latestSoulProposal, isNull);
    });

    test('accepts when only one directive field is non-empty', () async {
      final toolCall = makeToolCall(
        name: 'propose_soul_directives',
        args: {
          'voice_directive': 'Just voice.',
          'rationale': 'Voice-only change.',
        },
      );

      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(strategy.latestSoulProposal, isNotNull);
      expect(strategy.latestSoulProposal!.voiceDirective, 'Just voice.');
    });

    test('stores soul proposal independently from template proposal', () async {
      // First, propose template directives.
      final templateCall = makeToolCall(
        name: 'propose_directives',
        args: {
          'general_directive': 'Skills only.',
          'report_directive': 'Report format.',
          'rationale': 'Skill change.',
        },
      );
      await strategy.processToolCalls(
        toolCalls: [templateCall],
        manager: manager,
      );

      // Then, propose soul directives.
      final soulCall = makeToolCall(
        name: 'propose_soul_directives',
        args: {
          'voice_directive': 'Soul voice.',
          'rationale': 'Soul change.',
        },
        id: 'call-2',
      );
      await strategy.processToolCalls(
        toolCalls: [soulCall],
        manager: manager,
      );

      // Both should coexist.
      expect(strategy.latestProposal, isNotNull);
      expect(strategy.latestSoulProposal, isNotNull);
      expect(strategy.latestProposal!.generalDirective, 'Skills only.');
      expect(strategy.latestSoulProposal!.voiceDirective, 'Soul voice.');
    });

    test('clearSoulProposal clears only soul state', () async {
      final templateCall = makeToolCall(
        name: 'propose_directives',
        args: {
          'general_directive': 'Template stays.',
          'report_directive': '',
          'rationale': 'Template rationale.',
        },
      );
      await strategy.processToolCalls(
        toolCalls: [templateCall],
        manager: manager,
      );

      final soulCall = makeToolCall(
        id: 'call-2',
        name: 'propose_soul_directives',
        args: {
          'voice_directive': 'Voice.',
          'rationale': 'Change.',
        },
      );
      await strategy.processToolCalls(
        toolCalls: [soulCall],
        manager: manager,
      );

      expect(strategy.latestSoulProposal, isNotNull);
      expect(strategy.latestProposal, isNotNull);
      strategy.clearSoulProposal();
      expect(strategy.latestSoulProposal, isNull);
      expect(strategy.latestProposal!.generalDirective, 'Template stays.');
    });

    test('captures cross-template notice', () async {
      final toolCall = makeToolCall(
        name: 'propose_soul_directives',
        args: {
          'voice_directive': 'New voice.',
          'rationale': 'Update.',
          'cross_template_notice':
              'Also affects: Laura Project Analyst, Tom Task Agent',
        },
      );

      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      expect(
        strategy.latestSoulProposal!.crossTemplateNotice,
        contains('Laura Project Analyst'),
      );
    });
  });

  group('auto-surface on propose_soul_directives', () {
    late GenUiBridge bridge;
    late EvolutionStrategy strategyWithBridge;
    late ConversationManager bridgeManager;

    setUp(() {
      final catalog = buildEvolutionCatalog();
      final processor = SurfaceController(catalogs: [catalog]);
      bridge = GenUiBridge(processor: processor);
      strategyWithBridge = EvolutionStrategy(
        genUiBridge: bridge,
        currentVoiceDirective: 'Old voice.',
        currentToneBounds: 'Old bounds.',
        currentCoachingStyle: 'Old coaching.',
        currentAntiSycophancyPolicy: 'Old policy.',
      );
      bridgeManager = ConversationManager(conversationId: 'test-soul-auto')
        ..initialize(systemMessage: 'You are an evolution agent.');
    });

    test('creates a GenUI surface with current values', () async {
      final toolCall = makeToolCall(
        name: 'propose_soul_directives',
        args: {
          'voice_directive': 'Be warm and empathetic.',
          'tone_bounds': 'Stay professional.',
          'coaching_style': 'Celebrate wins.',
          'anti_sycophancy_policy': 'Push back firmly.',
          'rationale': 'Refinement.',
        },
      );
      bridgeManager.addAssistantMessage(toolCalls: [toolCall]);

      await strategyWithBridge.processToolCalls(
        toolCalls: [toolCall],
        manager: bridgeManager,
      );

      expect(strategyWithBridge.latestSoulProposal, isNotNull);
      final surfaceIds = bridge.drainPendingSurfaceIds();
      expect(surfaceIds, hasLength(1));
      expect(surfaceIds.first, startsWith('soul-proposal-'));

      // Verify proposal fields match the tool call args — ensuring the
      // bridge received the correct data (not a fallback rootType).
      final proposal = strategyWithBridge.latestSoulProposal!;
      expect(proposal.voiceDirective, 'Be warm and empathetic.');
      expect(proposal.toneBounds, 'Stay professional.');
      expect(proposal.coachingStyle, 'Celebrate wins.');
      expect(proposal.antiSycophancyPolicy, 'Push back firmly.');
      expect(proposal.rationale, 'Refinement.');
    });

    test('empty directives do not create surface', () async {
      final toolCall = makeToolCall(
        name: 'propose_soul_directives',
        args: {
          'voice_directive': '  ',
          'tone_bounds': '',
          'coaching_style': '',
          'anti_sycophancy_policy': '',
          'rationale': 'Whatever.',
        },
      );
      bridgeManager.addAssistantMessage(toolCalls: [toolCall]);

      await strategyWithBridge.processToolCalls(
        toolCalls: [toolCall],
        manager: bridgeManager,
      );

      expect(strategyWithBridge.latestSoulProposal, isNull);
      expect(bridge.drainPendingSurfaceIds(), isEmpty);
    });

    test('bridge exception does not prevent proposal recording', () async {
      // Create a strategy with a bridge that has no catalog items,
      // causing handleToolCall to fail on unknown rootType processing.
      final emptyProcessor = SurfaceController(catalogs: []);
      final brokenBridge = GenUiBridge(processor: emptyProcessor);
      final strat = EvolutionStrategy(genUiBridge: brokenBridge);
      final mgr = ConversationManager(conversationId: 'test-broken')
        ..initialize();

      final toolCall = makeToolCall(
        name: 'propose_soul_directives',
        args: {
          'voice_directive': 'Some voice.',
          'rationale': 'Change.',
        },
      );
      mgr.addAssistantMessage(toolCalls: [toolCall]);

      await strat.processToolCalls(
        toolCalls: [toolCall],
        manager: mgr,
      );

      // Proposal should still be recorded despite bridge failure.
      expect(strat.latestSoulProposal, isNotNull);
      expect(strat.latestSoulProposal!.voiceDirective, 'Some voice.');
    });
  });
}
