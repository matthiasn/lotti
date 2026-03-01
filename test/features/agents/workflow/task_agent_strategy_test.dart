import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockAgentSyncService mockSyncService;
  late MockAgentToolExecutor mockExecutor;
  late MockConversationManager mockManager;
  late TaskAgentStrategy strategy;

  const agentId = 'agent-001';
  const threadId = 'thread-001';
  const runKey = 'run-key-001';
  const taskId = 'task-001';

  setUp(() {
    mockSyncService = MockAgentSyncService();
    mockExecutor = MockAgentToolExecutor();
    mockManager = MockConversationManager();

    registerFallbackValue(
      AgentDomainEntity.unknown(
        id: 'fallback',
        agentId: 'fallback',
        createdAt: DateTime(2024, 3, 15),
      ),
    );

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async => {});

    strategy = TaskAgentStrategy(
      executor: mockExecutor,
      syncService: mockSyncService,
      agentId: agentId,
      threadId: threadId,
      runKey: runKey,
      taskId: taskId,
      resolveCategoryId: (_) async => 'cat-001',
      readVectorClock: (_) async => null,
      executeToolHandler: (toolName, args, manager) async =>
          const ToolExecutionResult(
        success: true,
        output: 'Tool executed successfully',
        mutatedEntityId: taskId,
      ),
    );
  });

  group('TaskAgentStrategy', () {
    group('processToolCalls', () {
      test('parses arguments, delegates to executor, feeds results back',
          () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'set_task_title',
              arguments: jsonEncode({'title': 'New Title'}),
            ),
          ),
        ];

        when(
          () => mockExecutor.execute(
            toolName: any(named: 'toolName'),
            args: any(named: 'args'),
            targetEntityId: any(named: 'targetEntityId'),
            resolveCategoryId: any(named: 'resolveCategoryId'),
            executeHandler: any(named: 'executeHandler'),
            readVectorClock: any(named: 'readVectorClock'),
          ),
        ).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: true,
            output: 'Title updated',
            mutatedEntityId: taskId,
          ),
        );

        final action = await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(action, ConversationAction.continueConversation);

        verify(
          () => mockExecutor.execute(
            toolName: 'set_task_title',
            args: {'title': 'New Title'},
            targetEntityId: taskId,
            resolveCategoryId: any(named: 'resolveCategoryId'),
            executeHandler: any(named: 'executeHandler'),
            readVectorClock: any(named: 'readVectorClock'),
          ),
        ).called(1);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-1',
            response: 'Title updated',
          ),
        ).called(1);
      });

      test('processes multiple tool calls sequentially', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'set_task_title',
              arguments: jsonEncode({'title': 'Title'}),
            ),
          ),
          ChatCompletionMessageToolCall(
            id: 'call-2',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_task_priority',
              arguments: jsonEncode({'priority': 'P1'}),
            ),
          ),
        ];

        when(
          () => mockExecutor.execute(
            toolName: any(named: 'toolName'),
            args: any(named: 'args'),
            targetEntityId: any(named: 'targetEntityId'),
            resolveCategoryId: any(named: 'resolveCategoryId'),
            executeHandler: any(named: 'executeHandler'),
            readVectorClock: any(named: 'readVectorClock'),
          ),
        ).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: true,
            output: 'done',
          ),
        );

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        verify(
          () => mockExecutor.execute(
            toolName: any(named: 'toolName'),
            args: any(named: 'args'),
            targetEntityId: taskId,
            resolveCategoryId: any(named: 'resolveCategoryId'),
            executeHandler: any(named: 'executeHandler'),
            readVectorClock: any(named: 'readVectorClock'),
          ),
        ).called(2);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: 'done',
          ),
        ).called(2);
      });

      test('records error and continues on invalid JSON arguments', () async {
        final toolCalls = [
          const ChatCompletionMessageToolCall(
            id: 'call-bad',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'set_task_title',
              arguments: '{invalid json!!!',
            ),
          ),
          ChatCompletionMessageToolCall(
            id: 'call-good',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_task_priority',
              arguments: jsonEncode({'priority': 'P2'}),
            ),
          ),
        ];

        when(
          () => mockExecutor.execute(
            toolName: any(named: 'toolName'),
            args: any(named: 'args'),
            targetEntityId: any(named: 'targetEntityId'),
            resolveCategoryId: any(named: 'resolveCategoryId'),
            executeHandler: any(named: 'executeHandler'),
            readVectorClock: any(named: 'readVectorClock'),
          ),
        ).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: true,
            output: 'done',
          ),
        );

        final action = await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(action, ConversationAction.continueConversation);

        // The bad call should get an error response
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-bad',
            response:
                'Error: invalid arguments format — expected a JSON object.',
          ),
        ).called(1);

        // The good call should still be executed
        verify(
          () => mockExecutor.execute(
            toolName: 'update_task_priority',
            args: {'priority': 'P2'},
            targetEntityId: taskId,
            resolveCategoryId: any(named: 'resolveCategoryId'),
            executeHandler: any(named: 'executeHandler'),
            readVectorClock: any(named: 'readVectorClock'),
          ),
        ).called(1);

        // Persists a tool result message for the error
        verify(() => mockSyncService.upsertEntity(any()))
            .called(greaterThanOrEqualTo(2));
      });

      test('persists assistant message before processing tool calls', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'set_task_title',
              arguments: jsonEncode({'title': 'T'}),
            ),
          ),
        ];

        when(
          () => mockExecutor.execute(
            toolName: any(named: 'toolName'),
            args: any(named: 'args'),
            targetEntityId: any(named: 'targetEntityId'),
            resolveCategoryId: any(named: 'resolveCategoryId'),
            executeHandler: any(named: 'executeHandler'),
            readVectorClock: any(named: 'readVectorClock'),
          ),
        ).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: true,
            output: 'ok',
          ),
        );

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        // At least one upsertEntity call for the assistant message
        verify(() => mockSyncService.upsertEntity(any()))
            .called(greaterThanOrEqualTo(1));
      });
    });

    group('record_observations tool', () {
      test('accumulates observations from tool call', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-obs',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_observations',
              arguments: jsonEncode({
                'observations': ['Pattern A', 'Pattern B'],
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractObservations(), ['Pattern A', 'Pattern B']);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-obs',
            response: 'Recorded 2 observation(s).',
          ),
        ).called(1);
      });

      test('accumulates across multiple tool calls', () async {
        final firstBatch = [
          ChatCompletionMessageToolCall(
            id: 'call-1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_observations',
              arguments: jsonEncode({
                'observations': ['Note 1'],
              }),
            ),
          ),
        ];

        final secondBatch = [
          ChatCompletionMessageToolCall(
            id: 'call-2',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_observations',
              arguments: jsonEncode({
                'observations': ['Note 2', 'Note 3'],
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: firstBatch,
          manager: mockManager,
        );
        await strategy.processToolCalls(
          toolCalls: secondBatch,
          manager: mockManager,
        );

        expect(
          strategy.extractObservations(),
          ['Note 1', 'Note 2', 'Note 3'],
        );
      });

      test('filters empty strings from observations', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-obs',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_observations',
              arguments: jsonEncode({
                'observations': ['Valid', '', '  ', 'Also valid'],
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractObservations(), ['Valid', 'Also valid']);
      });

      test('filters non-string values from observations', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-obs',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_observations',
              arguments: jsonEncode({
                'observations': ['Valid', 42, null, 'Also valid'],
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractObservations(), ['Valid', 'Also valid']);
      });

      test('records zero observations from empty array', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-obs',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_observations',
              arguments: jsonEncode({
                'observations': <String>[],
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractObservations(), isEmpty);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-obs',
            response: 'Recorded 0 observation(s).',
          ),
        ).called(1);
      });

      test('handles null JSON arguments gracefully', () async {
        // When the LLM sends literal 'null' as arguments, jsonDecode returns
        // null which is not a Map — caught at the parsing stage.
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-null-args',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_observations',
              arguments: jsonEncode(null),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        // null is not a Map<String, dynamic> → invalid format error.
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-null-args',
            response:
                'Error: invalid arguments format — expected a JSON object.',
          ),
        ).called(1);
      });

      test('returns error when observations is not an array', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-obs',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_observations',
              arguments: jsonEncode({
                'observations': 'not an array',
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractObservations(), isEmpty);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-obs',
            response: 'Error: "observations" must be an array of strings.',
          ),
        ).called(1);
      });

      test('does not delegate to executor', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-obs',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_observations',
              arguments: jsonEncode({
                'observations': ['Note'],
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        verifyNever(
          () => mockExecutor.execute(
            toolName: any(named: 'toolName'),
            args: any(named: 'args'),
            targetEntityId: any(named: 'targetEntityId'),
            resolveCategoryId: any(named: 'resolveCategoryId'),
            executeHandler: any(named: 'executeHandler'),
            readVectorClock: any(named: 'readVectorClock'),
          ),
        );
      });
    });

    group('shouldContinue', () {
      test('delegates to manager.canContinue()', () {
        when(mockManager.canContinue).thenReturn(true);
        expect(strategy.shouldContinue(mockManager), isTrue);

        when(mockManager.canContinue).thenReturn(false);
        expect(strategy.shouldContinue(mockManager), isFalse);
      });
    });

    group('getContinuationPrompt', () {
      test('returns continuation prompt when no report submitted', () {
        expect(strategy.getContinuationPrompt(mockManager), isNotNull);
        expect(
          strategy.getContinuationPrompt(mockManager),
          contains('update_report'),
        );
      });

      test('returns null after report is submitted', () async {
        await strategy.processToolCalls(
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'call-report',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'update_report',
                arguments: jsonEncode({'markdown': '# Report'}),
              ),
            ),
          ],
          manager: mockManager,
        );

        expect(strategy.getContinuationPrompt(mockManager), isNull);
      });
    });

    group('update_report tool', () {
      test('captures report markdown from tool call', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-report',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({
                'markdown': '# Task Summary\n\nAll good.',
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(
          strategy.extractReportContent(),
          '# Task Summary\n\nAll good.',
        );

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-report',
            response: 'Report updated.',
          ),
        ).called(1);
      });

      test('uses last update_report call when called multiple times', () async {
        for (final (id, markdown) in [
          ('call-1', '# First'),
          ('call-2', '# Second'),
        ]) {
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: id,
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'update_report',
                arguments: jsonEncode({'markdown': markdown}),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );
        }

        expect(strategy.extractReportContent(), '# Second');
      });

      test('trims whitespace from report markdown', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-report',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({
                'markdown': '  # Report\n\nContent  \n\n',
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractReportContent(), '# Report\n\nContent');
      });

      test('returns error for empty markdown', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-report',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({'markdown': '  '}),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractReportContent(), isEmpty);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-report',
            response: 'Error: "markdown" must be a non-empty string.',
          ),
        ).called(1);
      });

      test('returns error for non-string markdown', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-report',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({'markdown': 42}),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractReportContent(), isEmpty);
      });

      test('does not delegate to executor', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-report',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({'markdown': '# Report'}),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        verifyNever(
          () => mockExecutor.execute(
            toolName: any(named: 'toolName'),
            args: any(named: 'args'),
            targetEntityId: any(named: 'targetEntityId'),
            resolveCategoryId: any(named: 'resolveCategoryId'),
            executeHandler: any(named: 'executeHandler'),
            readVectorClock: any(named: 'readVectorClock'),
          ),
        );
      });

      test('returns empty when update_report never called', () {
        expect(strategy.extractReportContent(), isEmpty);
      });
    });

    group('recordFinalResponse and finalResponse', () {
      test('captures final response for thought persistence', () {
        strategy.recordFinalResponse('Some thinking content');
        expect(strategy.finalResponse, 'Some thinking content');
      });

      test('returns null when no response recorded', () {
        expect(strategy.finalResponse, isNull);
      });

      test('returns null when null response recorded', () {
        strategy.recordFinalResponse(null);
        expect(strategy.finalResponse, isNull);
      });

      test('returns null when empty response recorded', () {
        strategy.recordFinalResponse('');
        expect(strategy.finalResponse, isNull);
      });

      test('uses last response when multiple are recorded', () {
        strategy
          ..recordFinalResponse('First thought')
          ..recordFinalResponse('Second thought');
        expect(strategy.finalResponse, 'Second thought');
      });

      test('does not affect report content', () {
        strategy.recordFinalResponse('<think>reasoning</think># Report');
        expect(strategy.extractReportContent(), isEmpty);
      });
    });

    group('extractObservations', () {
      test('returns empty list when no observations recorded', () {
        expect(strategy.extractObservations(), isEmpty);
      });

      test('returns unmodifiable list', () {
        expect(
          () => strategy.extractObservations().add('should fail'),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('deferred tools with changeSetBuilder', () {
      late ChangeSetBuilder csBuilder;
      late TaskAgentStrategy deferredStrategy;

      setUp(() {
        csBuilder = ChangeSetBuilder(
          agentId: agentId,
          taskId: taskId,
          threadId: threadId,
          runKey: runKey,
        );

        deferredStrategy = TaskAgentStrategy(
          executor: mockExecutor,
          syncService: mockSyncService,
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          taskId: taskId,
          resolveCategoryId: (_) async => 'cat-001',
          readVectorClock: (_) async => null,
          executeToolHandler: (toolName, args, manager) async =>
              const ToolExecutionResult(
            success: true,
            output: 'Tool executed successfully',
            mutatedEntityId: taskId,
          ),
          changeSetBuilder: csBuilder,
        );
      });

      test('routes deferred tools to change set builder', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'set_task_title',
              arguments: jsonEncode({'title': 'New Title'}),
            ),
          ),
        ];

        await deferredStrategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        // Should NOT delegate to executor.
        verifyNever(
          () => mockExecutor.execute(
            toolName: any(named: 'toolName'),
            args: any(named: 'args'),
            targetEntityId: any(named: 'targetEntityId'),
            resolveCategoryId: any(named: 'resolveCategoryId'),
            executeHandler: any(named: 'executeHandler'),
            readVectorClock: any(named: 'readVectorClock'),
          ),
        );

        // Should respond with queued message.
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-1',
            response: 'Proposal queued for user review.',
          ),
        ).called(1);

        // Item should be in the builder.
        expect(csBuilder.hasItems, isTrue);
        expect(csBuilder.items, hasLength(1));
        expect(csBuilder.items.first.toolName, 'set_task_title');
        expect(csBuilder.items.first.humanSummary, contains('New Title'));
      });

      test('still executes immediate tools (update_report)', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-report',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({'markdown': '# Report'}),
            ),
          ),
        ];

        await deferredStrategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(deferredStrategy.extractReportContent(), '# Report');
        expect(csBuilder.hasItems, isFalse);
      });

      test('explodes batch checklist tools into individual items', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-batch',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'add_multiple_checklist_items',
              arguments: jsonEncode({
                'items': [
                  {'title': 'Design mockup'},
                  {'title': 'Implement API'},
                  {'title': 'Write tests'},
                ],
              }),
            ),
          ),
        ];

        await deferredStrategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(csBuilder.items, hasLength(3));
        expect(csBuilder.items[0].toolName, 'add_checklist_item');
        expect(csBuilder.items[0].humanSummary, 'Add: "Design mockup"');
        expect(csBuilder.items[1].humanSummary, 'Add: "Implement API"');
        expect(csBuilder.items[2].humanSummary, 'Add: "Write tests"');
      });

      test('mixes deferred and immediate tools in one call', () async {
        when(
          () => mockExecutor.execute(
            toolName: any(named: 'toolName'),
            args: any(named: 'args'),
            targetEntityId: any(named: 'targetEntityId'),
            resolveCategoryId: any(named: 'resolveCategoryId'),
            executeHandler: any(named: 'executeHandler'),
            readVectorClock: any(named: 'readVectorClock'),
          ),
        ).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: true,
            output: 'done',
          ),
        );

        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-deferred',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_task_estimate',
              arguments: jsonEncode({'minutes': 120}),
            ),
          ),
          ChatCompletionMessageToolCall(
            id: 'call-report',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({'markdown': '# Summary'}),
            ),
          ),
        ];

        await deferredStrategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        // Deferred tool should be in builder, not executed.
        expect(csBuilder.items, hasLength(1));
        expect(csBuilder.items.first.toolName, 'update_task_estimate');

        // Report should be handled immediately.
        expect(deferredStrategy.extractReportContent(), '# Summary');

        // Executor should NOT have been called (only deferred + immediate).
        verifyNever(
          () => mockExecutor.execute(
            toolName: any(named: 'toolName'),
            args: any(named: 'args'),
            targetEntityId: any(named: 'targetEntityId'),
            resolveCategoryId: any(named: 'resolveCategoryId'),
            executeHandler: any(named: 'executeHandler'),
            readVectorClock: any(named: 'readVectorClock'),
          ),
        );
      });

      test('generates meaningful human summaries for each tool type', () async {
        final deferredToolCalls = <String, Map<String, dynamic>>{
          'set_task_title': {'title': 'Fix login bug'},
          'update_task_estimate': {'minutes': 60},
          'update_task_due_date': {'dueDate': '2024-06-30'},
          'update_task_priority': {'priority': 'P1'},
          'set_task_status': {'status': 'GROOMED'},
          'assign_task_labels': {
            'labels': [
              {'id': 'l1', 'confidence': 'high'},
            ],
          },
        };

        for (final entry in deferredToolCalls.entries) {
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-${entry.key}',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: entry.key,
                arguments: jsonEncode(entry.value),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );
        }

        expect(csBuilder.items, hasLength(6));
        expect(csBuilder.items[0].humanSummary, 'Set title to "Fix login bug"');
        expect(csBuilder.items[1].humanSummary, 'Set estimate to 60 minutes');
        expect(csBuilder.items[2].humanSummary, 'Set due date to 2024-06-30');
        expect(csBuilder.items[3].humanSummary, 'Set priority to P1');
        expect(csBuilder.items[4].humanSummary, 'Set status to GROOMED');
        expect(csBuilder.items[5].humanSummary, 'Assign 1 label(s)');
      });

      test('handles malformed labels arg without crashing', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-bad-labels',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'assign_task_labels',
              arguments: jsonEncode({'labels': 'not-a-list'}),
            ),
          ),
        ];

        await deferredStrategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(csBuilder.items, hasLength(1));
        expect(csBuilder.items.first.humanSummary, 'Assign 0 label(s)');
      });

      test('warns LLM when batch items contain non-map elements', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-mixed',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'add_multiple_checklist_items',
              arguments: jsonEncode({
                'items': [
                  {'title': 'Valid item'},
                  'not-a-map',
                  42,
                ],
              }),
            ),
          ),
        ];

        await deferredStrategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        // Only the valid map item should be in the builder.
        expect(csBuilder.items, hasLength(1));
        expect(csBuilder.items.first.humanSummary, 'Add: "Valid item"');

        // LLM should be warned about skipped items.
        final captured = verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-mixed',
            response: captureAny(named: 'response'),
          ),
        ).captured;
        expect(
            captured.last as String, contains('2 malformed item(s) skipped'));
        expect(
          captured.last as String,
          contains('1 item(s) queued'),
        );
      });

      test('suppresses redundant non-batch tool and feeds back to LLM',
          () async {
        final csBuilderWithResolver = ChangeSetBuilder(
          agentId: agentId,
          taskId: taskId,
          threadId: threadId,
          runKey: runKey,
        );

        final strategyWithMetadata = TaskAgentStrategy(
          executor: mockExecutor,
          syncService: mockSyncService,
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          taskId: taskId,
          resolveCategoryId: (_) async => 'cat-001',
          readVectorClock: (_) async => null,
          executeToolHandler: (toolName, args, manager) async =>
              const ToolExecutionResult(
            success: true,
            output: 'done',
            mutatedEntityId: taskId,
          ),
          changeSetBuilder: csBuilderWithResolver,
          resolveTaskMetadata: () async => (
            title: 'Fix login bug',
            status: 'IN PROGRESS',
            priority: 'P1',
            estimateMinutes: 120,
            dueDate: '2026-03-15',
          ),
        );

        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-redundant',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_task_estimate',
              arguments: jsonEncode({'minutes': 120}),
            ),
          ),
        ];

        await strategyWithMetadata.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        // Should NOT be added to the builder.
        expect(csBuilderWithResolver.hasItems, isFalse);

        // LLM should get a skip message.
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-redundant',
            response: 'Skipped: estimate is already 120 minutes.',
          ),
        ).called(1);
      });

      test('keeps non-redundant non-batch tool when metadata differs',
          () async {
        final csBuilderWithResolver = ChangeSetBuilder(
          agentId: agentId,
          taskId: taskId,
          threadId: threadId,
          runKey: runKey,
        );

        final strategyWithMetadata = TaskAgentStrategy(
          executor: mockExecutor,
          syncService: mockSyncService,
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          taskId: taskId,
          resolveCategoryId: (_) async => 'cat-001',
          readVectorClock: (_) async => null,
          executeToolHandler: (toolName, args, manager) async =>
              const ToolExecutionResult(
            success: true,
            output: 'done',
            mutatedEntityId: taskId,
          ),
          changeSetBuilder: csBuilderWithResolver,
          resolveTaskMetadata: () async => (
            title: 'Fix login bug',
            status: 'IN PROGRESS',
            priority: 'P1',
            estimateMinutes: 120,
            dueDate: '2026-03-15',
          ),
        );

        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-actual',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_task_priority',
              arguments: jsonEncode({'priority': 'P0'}),
            ),
          ),
        ];

        await strategyWithMetadata.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        // Should be added to the builder.
        expect(csBuilderWithResolver.hasItems, isTrue);
        expect(
            csBuilderWithResolver.items.first.toolName, 'update_task_priority');

        // LLM should get a queued message.
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-actual',
            response: 'Proposal queued for user review.',
          ),
        ).called(1);
      });

      test('keeps tool when resolver throws (conservative)', () async {
        final csBuilderWithResolver = ChangeSetBuilder(
          agentId: agentId,
          taskId: taskId,
          threadId: threadId,
          runKey: runKey,
        );

        final strategyWithResolver = TaskAgentStrategy(
          executor: mockExecutor,
          syncService: mockSyncService,
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          taskId: taskId,
          resolveCategoryId: (_) async => 'cat-001',
          readVectorClock: (_) async => null,
          executeToolHandler: (toolName, args, manager) async =>
              const ToolExecutionResult(
            success: true,
            output: 'done',
            mutatedEntityId: taskId,
          ),
          changeSetBuilder: csBuilderWithResolver,
          resolveTaskMetadata: () async => throw Exception('DB error'),
        );

        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-err',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_task_estimate',
              arguments: jsonEncode({'minutes': 120}),
            ),
          ),
        ];

        await strategyWithResolver.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        // Conservative: should still be added.
        expect(csBuilderWithResolver.hasItems, isTrue);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-err',
            response: 'Proposal queued for user review.',
          ),
        ).called(1);
      });

      test('redundant batch items include redundancy info in response',
          () async {
        final csBuilderWithResolver = ChangeSetBuilder(
          agentId: agentId,
          taskId: taskId,
          threadId: threadId,
          runKey: runKey,
          checklistItemStateResolver: (id) async =>
              (title: 'Buy groceries', isChecked: true),
        );

        final strategyWithResolver = TaskAgentStrategy(
          executor: mockExecutor,
          syncService: mockSyncService,
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          taskId: taskId,
          resolveCategoryId: (_) async => 'cat-001',
          readVectorClock: (_) async => null,
          executeToolHandler: (toolName, args, manager) async =>
              const ToolExecutionResult(
            success: true,
            output: 'done',
            mutatedEntityId: taskId,
          ),
          changeSetBuilder: csBuilderWithResolver,
        );

        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-batch-redundant',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_checklist_items',
              arguments: jsonEncode({
                'items': [
                  {'id': 'item-1', 'isChecked': true},
                ],
              }),
            ),
          ),
        ];

        await strategyWithResolver.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        // Builder should have no items (all redundant).
        expect(csBuilderWithResolver.hasItems, isFalse);

        // LLM should see the redundancy feedback.
        final captured = verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-batch-redundant',
            response: captureAny(named: 'response'),
          ),
        ).captured;
        expect(
          captured.last as String,
          contains('Skipped 1 redundant update(s)'),
        );
        expect(
          captured.last as String,
          contains('"Buy groceries" is already checked'),
        );
      });
    });
  });
}
