import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';

class MockConversationManager extends Mock implements ConversationManager {}

class MockAgentToolExecutor extends Mock implements AgentToolExecutor {}

void main() {
  late MockAgentRepository mockRepository;
  late MockAgentToolExecutor mockExecutor;
  late MockConversationManager mockManager;
  late TaskAgentStrategy strategy;

  const agentId = 'agent-001';
  const threadId = 'thread-001';
  const runKey = 'run-key-001';
  const taskId = 'task-001';

  setUp(() {
    mockRepository = MockAgentRepository();
    mockExecutor = MockAgentToolExecutor();
    mockManager = MockConversationManager();

    registerFallbackValue(
      AgentDomainEntity.unknown(
        id: 'fallback',
        agentId: 'fallback',
        createdAt: DateTime(2024, 3, 15),
      ),
    );

    when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async => {});

    strategy = TaskAgentStrategy(
      executor: mockExecutor,
      repository: mockRepository,
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
            response: 'Error: invalid JSON in tool call arguments',
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
        verify(() => mockRepository.upsertEntity(any()))
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
        verify(() => mockRepository.upsertEntity(any()))
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
      test('returns null', () {
        expect(strategy.getContinuationPrompt(mockManager), isNull);
      });
    });

    group('recordFinalResponse and extractReportContent', () {
      test('extracts full markdown content from response', () {
        const response = '# Task Summary\n\nTask is progressing well.\n\n'
            '## Details\n- Item 1\n- Item 2';

        strategy.recordFinalResponse(response);

        final report = strategy.extractReportContent();
        expect(report['markdown'], response);
      });

      test('returns empty markdown when no response recorded', () {
        final report = strategy.extractReportContent();
        expect(report['markdown'], '');
      });

      test('returns empty markdown when null response recorded', () {
        strategy.recordFinalResponse(null);

        final report = strategy.extractReportContent();
        expect(report['markdown'], '');
      });

      test('returns empty markdown when empty response recorded', () {
        strategy.recordFinalResponse('');

        final report = strategy.extractReportContent();
        expect(report['markdown'], '');
      });

      test('uses last response when multiple are recorded', () {
        strategy
          ..recordFinalResponse('# First Report')
          ..recordFinalResponse('# Second Report');

        final report = strategy.extractReportContent();
        expect(report['markdown'], '# Second Report');
      });

      test('trims whitespace from report', () {
        strategy.recordFinalResponse('  # Report\n\nContent  \n\n');

        final report = strategy.extractReportContent();
        expect(report['markdown'], '# Report\n\nContent');
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
  });
}
