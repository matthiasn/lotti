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
      test('stores content for later extraction', () {
        final jsonResponse = jsonEncode({
          'report': {
            'title': 'Task Summary',
            'status': 'in_progress',
          },
          'observations': ['Note 1'],
        });

        strategy.recordFinalResponse(jsonResponse);

        final report = strategy.extractReportContent();
        expect(report['title'], 'Task Summary');
        expect(report['status'], 'in_progress');
      });

      test('does not store null content', () {
        strategy.recordFinalResponse(null);

        final report = strategy.extractReportContent();
        expect(report['error'], 'No assistant response received');
      });

      test('does not store empty content', () {
        strategy.recordFinalResponse('');

        final report = strategy.extractReportContent();
        expect(report['error'], 'No assistant response received');
      });

      test('parses JSON with report key', () {
        final jsonResponse = jsonEncode({
          'report': {
            'title': 'My Task',
            'tldr': 'In progress',
            'status': 'in_progress',
          },
          'observations': <String>[],
        });

        strategy.recordFinalResponse(jsonResponse);
        final report = strategy.extractReportContent();

        expect(report['title'], 'My Task');
        expect(report['tldr'], 'In progress');
        expect(report['status'], 'in_progress');
      });

      test('handles JSON without report wrapper', () {
        final jsonResponse = jsonEncode({
          'title': 'Direct report',
          'status': 'completed',
        });

        strategy.recordFinalResponse(jsonResponse);
        final report = strategy.extractReportContent();

        expect(report['title'], 'Direct report');
        expect(report['status'], 'completed');
      });

      test('handles raw text fallback when JSON parsing fails', () {
        strategy.recordFinalResponse('This is raw text, not JSON');

        final report = strategy.extractReportContent();
        expect(report['rawText'], 'This is raw text, not JSON');
      });

      test('uses last response when multiple are recorded', () {
        strategy
          ..recordFinalResponse(jsonEncode({
            'report': {'title': 'First'}
          }))
          ..recordFinalResponse(jsonEncode({
            'report': {'title': 'Second'}
          }));

        final report = strategy.extractReportContent();
        expect(report['title'], 'Second');
      });
    });

    group('extractObservations', () {
      test('parses observations array from JSON', () {
        final jsonResponse = jsonEncode({
          'report': {'title': 'Test'},
          'observations': [
            'Observation 1',
            'Observation 2',
            'Observation 3',
          ],
        });

        strategy.recordFinalResponse(jsonResponse);
        final observations = strategy.extractObservations();

        expect(observations, hasLength(3));
        expect(observations[0], 'Observation 1');
        expect(observations[1], 'Observation 2');
        expect(observations[2], 'Observation 3');
      });

      test('filters non-string values from observations', () {
        final jsonResponse = jsonEncode({
          'report': {'title': 'Test'},
          'observations': ['Valid', 42, null, 'Also valid'],
        });

        strategy.recordFinalResponse(jsonResponse);
        final observations = strategy.extractObservations();

        expect(observations, ['Valid', 'Also valid']);
      });

      test('handles non-array observations value gracefully', () {
        final jsonResponse = jsonEncode({
          'report': {'title': 'Test'},
          'observations': 'not an array',
        });

        strategy.recordFinalResponse(jsonResponse);
        final observations = strategy.extractObservations();

        expect(observations, isEmpty);
      });

      test('returns empty list when no observations key', () {
        final jsonResponse = jsonEncode({
          'report': {'title': 'Test'},
        });

        strategy.recordFinalResponse(jsonResponse);
        final observations = strategy.extractObservations();

        expect(observations, isEmpty);
      });

      test('returns empty list when no responses recorded', () {
        final observations = strategy.extractObservations();
        expect(observations, isEmpty);
      });

      test('returns empty list when response is not valid JSON', () {
        strategy.recordFinalResponse('plain text response');

        final observations = strategy.extractObservations();
        expect(observations, isEmpty);
      });
    });
  });
}
