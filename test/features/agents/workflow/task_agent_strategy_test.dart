import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/suggestion_retraction_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/change_proposal_filter.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

enum _GeneratedMigrationTargetShape { missing, hallucinated, explicit }

class _GeneratedSplitSequenceScenario {
  const _GeneratedSplitSequenceScenario({
    required this.titleSeed,
    required this.itemCount,
    required this.flags,
    required this.targetShape,
  });

  static const _titles = [
    'Write rollout plan',
    'Prepare QA checklist',
    'Draft launch notes',
    'Review metrics',
  ];

  final int titleSeed;
  final int itemCount;
  final int flags;
  final _GeneratedMigrationTargetShape targetShape;

  String get title => _titles[titleSeed % _titles.length];
  bool get createBeforeMigration => flags & 1 == 0;
  bool get duplicateCreate => flags & 2 != 0;
  bool get paddedDuplicateTitle => flags & 4 != 0;

  Map<String, dynamic> get createArgs => {'title': title};

  Map<String, dynamic> get duplicateCreateArgs => {
    'title': paddedDuplicateTitle ? '  $title  ' : title,
  };

  String get rawTargetId => 'llm-target-${titleSeed % 17}';

  Map<String, dynamic> get migrateArgs {
    return {
      if (targetShape != _GeneratedMigrationTargetShape.missing)
        'targetTaskId': rawTargetId,
      'items': [
        for (var index = 0; index < itemCount; index++)
          {'id': 'item-$index', 'title': 'Item $index'},
      ],
    };
  }

  String expectedPlaceholder(String taskId) {
    return ChangeSetBuilder.deterministicPlaceholder(taskId, '$title||');
  }

  List<ChatCompletionMessageToolCall> toolCalls() {
    final create = _toolCall(
      id: 'call-create',
      name: TaskAgentToolNames.createFollowUpTask,
      args: createArgs,
    );
    final duplicate = _toolCall(
      id: 'call-create-duplicate',
      name: TaskAgentToolNames.createFollowUpTask,
      args: duplicateCreateArgs,
    );
    final migrate = _toolCall(
      id: 'call-migrate',
      name: TaskAgentToolNames.migrateChecklistItems,
      args: migrateArgs,
    );

    if (createBeforeMigration) {
      return [create, if (duplicateCreate) duplicate, migrate];
    }
    return [migrate, create, if (duplicateCreate) duplicate];
  }

  @override
  String toString() {
    return '_GeneratedSplitSequenceScenario('
        'title: $title, '
        'itemCount: $itemCount, '
        'createBeforeMigration: $createBeforeMigration, '
        'duplicateCreate: $duplicateCreate, '
        'targetShape: $targetShape)';
  }
}

extension _AnyGeneratedSplitSequenceScenario on glados.Any {
  glados.Generator<_GeneratedMigrationTargetShape> get migrationTargetShape =>
      glados.AnyUtils(this).choose(_GeneratedMigrationTargetShape.values);

  glados.Generator<_GeneratedSplitSequenceScenario> get splitSequenceScenario =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 1000),
        glados.IntAnys(this).intInRange(1, 4),
        glados.IntAnys(this).intInRange(0, 7),
        migrationTargetShape,
        (
          int titleSeed,
          int itemCount,
          int flags,
          _GeneratedMigrationTargetShape targetShape,
        ) => _GeneratedSplitSequenceScenario(
          titleSeed: titleSeed,
          itemCount: itemCount,
          flags: flags,
          targetShape: targetShape,
        ),
      );
}

ChatCompletionMessageToolCall _toolCall({
  required String id,
  required String name,
  required Map<String, dynamic> args,
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

/// Creates a [TaskAgentStrategy] with an attached [ChangeSetBuilder] and
/// optional [ResolveTaskMetadata] for metadata-redundancy tests.
///
/// File-level strategy bench: builds a [TaskAgentStrategy] with fixed stub
/// wiring, parameterized on only the parts individual tests vary.
///
/// Returns both the strategy and the builder so tests can inspect builder
/// state after processing tool calls. Pass [withChangeSetBuilder]: false for
/// tests that exercise the non-deferred wiring (the returned builder is then
/// unused by the strategy).
({TaskAgentStrategy strategy, ChangeSetBuilder builder}) _createStrategy({
  required MockAgentToolExecutor executor,
  required MockAgentSyncService syncService,
  ResolveTaskMetadata? resolveTaskMetadata,
  ChecklistItemStateResolver? checklistItemStateResolver,
  Future<String?> Function(String requestedTaskId)? resolveRelatedTaskDetails,
  Set<String> allowedRelatedTaskIds = const <String>{},
  SuggestionRetractionService? retractionService,
  ExecuteToolHandler? executeToolHandler,
  ChangeSetBuilder? builder,
  bool withChangeSetBuilder = true,
}) {
  const agentId = 'agent-001';
  const taskId = 'task-001';
  const threadId = 'thread-001';
  const runKey = 'run-key-001';

  final csBuilder =
      builder ??
      ChangeSetBuilder(
        agentId: agentId,
        taskId: taskId,
        threadId: threadId,
        runKey: runKey,
        checklistItemStateResolver: checklistItemStateResolver,
      );

  final strategy = TaskAgentStrategy(
    executor: executor,
    syncService: syncService,
    agentId: agentId,
    threadId: threadId,
    runKey: runKey,
    taskId: taskId,
    resolveCategoryId: (_) async => 'cat-001',
    readVectorClock: (_) async => null,
    executeToolHandler:
        executeToolHandler ??
        (toolName, args, manager) async => const ToolExecutionResult(
          success: true,
          output: 'done',
          mutatedEntityId: taskId,
        ),
    changeSetBuilder: withChangeSetBuilder ? csBuilder : null,
    retractionService: retractionService,
    resolveTaskMetadata: resolveTaskMetadata,
    resolveRelatedTaskDetails: resolveRelatedTaskDetails,
    allowedRelatedTaskIds: allowedRelatedTaskIds,
  );

  return (strategy: strategy, builder: csBuilder);
}

void main() {
  late MockAgentSyncService mockSyncService;
  late MockAgentToolExecutor mockExecutor;
  late MockConversationManager mockManager;
  late TaskAgentStrategy strategy;

  const agentId = 'agent-001';
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

    strategy = _createStrategy(
      executor: mockExecutor,
      syncService: mockSyncService,
      withChangeSetBuilder: false,
      executeToolHandler: (toolName, args, manager) async =>
          const ToolExecutionResult(
            success: true,
            output: 'Tool executed successfully',
            mutatedEntityId: taskId,
          ),
    ).strategy;
  });

  group('TaskAgentStrategy', () {
    group('processToolCalls', () {
      test(
        'parses arguments, delegates to executor, feeds results back',
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
        },
      );

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

      // get_related_task_details is handled locally (never reaches the
      // executor); the five scenarios differ only in resolver behaviour,
      // allowlist, requested id, and the expected response.
      Future<String> runRelatedCall({
        required Future<String?> Function(String) resolver,
        required Set<String> allowedIds,
        required String requestedTaskId,
      }) async {
        final relatedStrategy = _createStrategy(
          executor: mockExecutor,
          syncService: mockSyncService,
          withChangeSetBuilder: false,
          resolveRelatedTaskDetails: resolver,
          allowedRelatedTaskIds: allowedIds,
        ).strategy;

        await relatedStrategy.processToolCalls(
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'call-related',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.getRelatedTaskDetails,
                arguments: jsonEncode({'taskId': requestedTaskId}),
              ),
            ),
          ],
          manager: mockManager,
        );

        // The local handler must never reach the deferred-tool executor.
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
        return verify(
              () => mockManager.addToolResponse(
                toolCallId: 'call-related',
                response: captureAny(named: 'response'),
              ),
            ).captured.single
            as String;
      }

      test(
        'handles get_related_task_details locally for allowlisted sibling tasks',
        () async {
          final response = await runRelatedCall(
            resolver: (requestedTaskId) async =>
                '{"task":{"id":"$requestedTaskId"}}',
            allowedIds: const {'task-002'},
            requestedTaskId: 'task-002',
          );
          expect(response, '{"task":{"id":"task-002"}}');
        },
      );

      test('rejects get_related_task_details for the current task', () async {
        final response = await runRelatedCall(
          resolver: (_) async => '{"task":{"id":"unused"}}',
          allowedIds: {taskId},
          requestedTaskId: taskId,
        );
        expect(response, contains('cannot be used for the current task'));
      });

      test('rejects get_related_task_details outside the allowlist', () async {
        final response = await runRelatedCall(
          resolver: (_) async => '{"task":{"id":"unused"}}',
          allowedIds: const {'task-002'},
          requestedTaskId: 'task-999',
        );
        expect(response, contains('not available in the current'));
      });

      test(
        'returns tool error when related-task resolver returns null',
        () async {
          final response = await runRelatedCall(
            resolver: (_) async => null,
            allowedIds: const {'task-002'},
            requestedTaskId: 'task-002',
          );
          expect(response, contains('could not be resolved'));
        },
      );

      test(
        'returns tool error when related-task resolver throws',
        () async {
          final response = await runRelatedCall(
            resolver: (_) async => throw Exception('DB connection lost'),
            allowedIds: const {'task-002'},
            requestedTaskId: 'task-002',
          );
          expect(response, contains('could not be resolved'));
        },
      );

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
            response: any(
              named: 'response',
              that: startsWith(
                'Error: invalid arguments format — expected a JSON object.',
              ),
            ),
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
        verify(
          () => mockSyncService.upsertEntity(any()),
        ).called(greaterThanOrEqualTo(2));
      });

      // JSON-recovery scenarios share one harness: stub the executor, fire a
      // single tool call carrying [rawArguments], then either verify the
      // recovered args reached the executor or that parsing failed cleanly.
      Future<void> runRecovery({
        required String rawArguments,
        required String toolName,
        Map<String, dynamic>? expectedArgs, // null → expect a parse failure
      }) async {
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
          (_) async =>
              const ToolExecutionResult(success: true, output: 'recovery-ok'),
        );

        final action = await strategy.processToolCalls(
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'call-recovery',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: toolName,
                arguments: rawArguments,
              ),
            ),
          ],
          manager: mockManager,
        );

        expect(action, ConversationAction.continueConversation);

        if (expectedArgs != null) {
          // Executor must receive the clean extracted map, not the raw text.
          verify(
            () => mockExecutor.execute(
              toolName: toolName,
              args: expectedArgs,
              targetEntityId: taskId,
              resolveCategoryId: any(named: 'resolveCategoryId'),
              executeHandler: any(named: 'executeHandler'),
              readVectorClock: any(named: 'readVectorClock'),
            ),
          ).called(1);
          verify(
            () => mockManager.addToolResponse(
              toolCallId: 'call-recovery',
              response: 'recovery-ok',
            ),
          ).called(1);
        } else {
          // Parsing failed entirely — the executor is never reached.
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
          verify(
            () => mockManager.addToolResponse(
              toolCallId: 'call-recovery',
              response: any(
                named: 'response',
                that: startsWith(
                  'Error: invalid arguments format — expected a JSON object.',
                ),
              ),
            ),
          ).called(1);
        }
      }

      test(
        'recovers arguments from markdown code-fenced JSON (local model quirk)',
        () => runRecovery(
          // Some local models wrap the JSON in a markdown code fence.
          rawArguments: '```json\n{"priority": "P0"}\n```',
          toolName: 'update_task_priority',
          expectedArgs: {'priority': 'P0'},
        ),
      );

      test(
        'recovers arguments from JSON object embedded in trailing text',
        () => runRecovery(
          // The balanced-brace extractor must isolate the JSON object from
          // trailing explanation text.
          rawArguments:
              '{"status": "IN_PROGRESS"} (setting task to in progress)',
          toolName: 'set_task_status',
          expectedArgs: {'status': 'IN_PROGRESS'},
        ),
      );

      test(
        'recovers via brace extraction when fenced JSON inner content is '
        'invalid',
        () => runRecovery(
          // The fence matches but its inner content is not valid JSON; the
          // valid object trailing the fence is recovered instead.
          rawArguments: '```json\nnot valid json\n```\n{"priority": "P3"}',
          toolName: 'update_task_priority',
          expectedArgs: {'priority': 'P3'},
        ),
      );

      test(
        'returns error when balanced-brace candidate is not valid JSON',
        () => runRecovery(
          // Braces balance but the content between them is not valid JSON,
          // so every recovery attempt fails.
          rawArguments: '{not: valid, json}',
          toolName: 'update_task_priority',
        ),
      );

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
        verify(
          () => mockSyncService.upsertEntity(any()),
        ).called(greaterThanOrEqualTo(1));
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

        final obs = strategy.extractObservations();
        expect(obs.map((o) => o.text).toList(), ['Pattern A', 'Pattern B']);
        // Legacy bare strings default to routine/operational.
        expect(obs[0].priority, ObservationPriority.routine);
        expect(obs[0].category, ObservationCategory.operational);

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
          strategy.extractObservations().map((o) => o.text).toList(),
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

        expect(
          strategy.extractObservations().map((o) => o.text).toList(),
          ['Valid', 'Also valid'],
        );
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

        expect(
          strategy.extractObservations().map((o) => o.text).toList(),
          ['Valid', 'Also valid'],
        );
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
            response: any(
              named: 'response',
              that: startsWith(
                'Error: invalid arguments format — expected a JSON object.',
              ),
            ),
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
            response: 'Error: "observations" must be an array.',
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
                arguments: jsonEncode({
                  'content': '# Report',
                  'oneLiner': 'Implementation done, release next',
                  'tldr': 'Implementation is done and release is next.',
                }),
              ),
            ),
          ],
          manager: mockManager,
        );

        expect(strategy.getContinuationPrompt(mockManager), isNull);
      });
    });

    group('update_report tool', () {
      test('captures report content from tool call', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-report',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({
                'content': '# Task Summary\n\nAll good.',
                'oneLiner': 'Implementation done, release next',
                'tldr': 'Implementation is done and release is next.',
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
        expect(
          strategy.extractReportOneLiner(),
          'Implementation done, release next',
        );
        expect(
          strategy.extractReportTldr(),
          'Implementation is done and release is next.',
        );

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-report',
            response: 'Report updated.',
          ),
        ).called(1);
      });

      test('uses last update_report call when called multiple times', () async {
        for (final (id, content, oneLiner, tldr) in [
          ('call-1', '# First', 'First one-liner', 'First summary'),
          ('call-2', '# Second', 'Second one-liner', 'Second summary'),
        ]) {
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: id,
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'update_report',
                arguments: jsonEncode({
                  'content': content,
                  'oneLiner': oneLiner,
                  'tldr': tldr,
                }),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );
        }

        expect(strategy.extractReportContent(), '# Second');
        expect(strategy.extractReportOneLiner(), 'Second one-liner');
        expect(strategy.extractReportTldr(), 'Second summary');
      });

      test('trims whitespace from report content', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-report',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({
                'content': '  # Report\n\nContent  \n\n',
                'oneLiner': '  Release blocked on docs  ',
                'tldr': '  Release blocked on docs and QA.  ',
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractReportContent(), '# Report\n\nContent');
        expect(strategy.extractReportOneLiner(), 'Release blocked on docs');
        expect(strategy.extractReportTldr(), 'Release blocked on docs and QA.');
      });

      test('returns error for empty content', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-report',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({
                'content': '  ',
                'oneLiner': 'Release blocked on docs',
                'tldr': 'Release blocked on docs and QA.',
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractReportContent(), isEmpty);
        expect(strategy.extractReportOneLiner(), isNull);
        expect(strategy.extractReportTldr(), isNull);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-report',
            response: 'Error: "content" must be a non-empty string.',
          ),
        ).called(1);
      });

      test('returns error for non-string content', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-report',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({
                'content': 42,
                'oneLiner': 'Release blocked on docs',
                'tldr': 'Release blocked on docs and QA.',
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractReportContent(), isEmpty);
        expect(strategy.extractReportOneLiner(), isNull);
        expect(strategy.extractReportTldr(), isNull);
      });

      test('does not delegate to executor', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-report',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({
                'content': '# Report',
                'oneLiner': 'Implementation done, release next',
                'tldr': 'Implementation is done and release is next.',
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

      test('returns empty when update_report never called', () {
        expect(strategy.extractReportContent(), isEmpty);
        expect(strategy.extractReportTldr(), isNull);
        expect(strategy.extractReportOneLiner(), isNull);
      });

      test('captures oneLiner and tldr from update_report tool call', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-report-tldr',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({
                'content': '# Full Report\n\nDetailed analysis.',
                'oneLiner': 'Implementation done, release next',
                'tldr': 'Brief summary of the report.',
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
          '# Full Report\n\nDetailed analysis.',
        );
        expect(
          strategy.extractReportTldr(),
          'Brief summary of the report.',
        );
        expect(
          strategy.extractReportOneLiner(),
          'Implementation done, release next',
        );
      });

      test('returns error when tldr is missing', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-no-tldr',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({
                'content': '# Report',
                'oneLiner': 'Implementation done, release next',
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractReportContent(), isEmpty);
        expect(strategy.extractReportTldr(), isNull);
        expect(strategy.extractReportOneLiner(), isNull);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-no-tldr',
            response: 'Error: "tldr" must be a non-empty string.',
          ),
        ).called(1);
      });

      test('returns error when oneLiner is missing', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-no-one-liner',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_report',
              arguments: jsonEncode({
                'content': '# Report',
                'tldr': 'Implementation is done and release is next.',
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractReportContent(), isEmpty);
        expect(strategy.extractReportTldr(), isNull);
        expect(strategy.extractReportOneLiner(), isNull);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-no-one-liner',
            response: 'Error: "oneLiner" must be a non-empty string.',
          ),
        ).called(1);
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
          () => strategy.extractObservations().add(
            const ObservationRecord(text: 'should fail'),
          ),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('structured observations', () {
      test('parses structured observation items', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-structured',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_observations',
              arguments: jsonEncode({
                'observations': [
                  {
                    'text': 'User requested P0 but I kept P1.',
                    'priority': 'critical',
                    'category': 'grievance',
                  },
                  {
                    'text': 'Routine check completed.',
                  },
                ],
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        final obs = strategy.extractObservations();
        expect(obs, hasLength(2));

        expect(obs[0].text, 'User requested P0 but I kept P1.');
        expect(obs[0].priority, ObservationPriority.critical);
        expect(obs[0].category, ObservationCategory.grievance);

        expect(obs[1].text, 'Routine check completed.');
        expect(obs[1].priority, ObservationPriority.routine);
        expect(obs[1].category, ObservationCategory.operational);
      });

      test('parses excellence category', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-exc',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_observations',
              arguments: jsonEncode({
                'observations': [
                  {
                    'text': 'User praised the report quality.',
                    'priority': 'critical',
                    'category': 'excellence',
                  },
                ],
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        final obs = strategy.extractObservations();
        expect(obs.single.priority, ObservationPriority.critical);
        expect(obs.single.category, ObservationCategory.excellence);
      });

      test('handles snake_case category from tool schema', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-snake',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_observations',
              arguments: jsonEncode({
                'observations': [
                  {
                    'text': 'User suggested a prompt change.',
                    'priority': 'notable',
                    'category': 'template_improvement',
                  },
                ],
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        final obs = strategy.extractObservations();
        expect(obs.single.priority, ObservationPriority.notable);
        expect(obs.single.category, ObservationCategory.templateImprovement);
      });

      test('handles mixed legacy and structured items', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-mixed',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_observations',
              arguments: jsonEncode({
                'observations': [
                  'Legacy bare string',
                  {
                    'text': 'Structured item',
                    'priority': 'critical',
                    'category': 'grievance',
                  },
                ],
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        final obs = strategy.extractObservations();
        expect(obs, hasLength(2));
        expect(obs[0].text, 'Legacy bare string');
        expect(obs[0].priority, ObservationPriority.routine);
        expect(obs[1].text, 'Structured item');
        expect(obs[1].priority, ObservationPriority.critical);
        expect(obs[1].category, ObservationCategory.grievance);
      });

      test('ignores unknown priority/category values gracefully', () async {
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'call-unknown',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_observations',
              arguments: jsonEncode({
                'observations': [
                  {
                    'text': 'Unknown values',
                    'priority': 'super_urgent',
                    'category': 'banana',
                  },
                ],
              }),
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        final obs = strategy.extractObservations();
        expect(obs.single.text, 'Unknown values');
        expect(obs.single.priority, ObservationPriority.routine);
        expect(obs.single.category, ObservationCategory.operational);
      });
    });

    group('deferred tools with changeSetBuilder', () {
      late ChangeSetBuilder csBuilder;
      late TaskAgentStrategy deferredStrategy;

      setUp(() {
        final bench = _createStrategy(
          executor: mockExecutor,
          syncService: mockSyncService,
          executeToolHandler: (toolName, args, manager) async =>
              const ToolExecutionResult(
                success: true,
                output: 'Tool executed successfully',
                mutatedEntityId: taskId,
              ),
        );
        csBuilder = bench.builder;
        deferredStrategy = bench.strategy;
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
            response: any(
              named: 'response',
              that: contains('set_task_title proposal recorded'),
            ),
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
              arguments: jsonEncode({
                'content': '# Report',
                'oneLiner': 'Implementation done, release next',
                'tldr': 'Implementation is done and release is next.',
              }),
            ),
          ),
        ];

        await deferredStrategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(deferredStrategy.extractReportContent(), '# Report');
        expect(
          deferredStrategy.extractReportOneLiner(),
          'Implementation done, release next',
        );
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
              arguments: jsonEncode({
                'content': '# Summary',
                'oneLiner': 'Implementation done, release next',
                'tldr': 'Implementation is done and release is next.',
              }),
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
        expect(
          deferredStrategy.extractReportOneLiner(),
          'Implementation done, release next',
        );

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
          'set_task_language': {'languageCode': 'de'},
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

        expect(csBuilder.items, hasLength(7));
        expect(csBuilder.items[0].humanSummary, 'Set title to "Fix login bug"');
        expect(csBuilder.items[1].humanSummary, 'Set estimate to 60 minutes');
        expect(csBuilder.items[2].humanSummary, 'Set due date to 2024-06-30');
        expect(csBuilder.items[3].humanSummary, 'Set priority to P1');
        expect(csBuilder.items[4].humanSummary, 'Set status to GROOMED');
        expect(csBuilder.items[5].humanSummary, 'Set language to "de"');
        // Labels are now exploded into individual items via batch path.
        expect(
          csBuilder.items[6].humanSummary,
          contains('Assign label:'),
        );
        expect(csBuilder.items[6].toolName, 'assign_task_label');
      });

      test(
        'generates correct human summary for create_time_entry — completed session',
        () async {
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-te',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'create_time_entry',
                arguments: jsonEncode({
                  'startTime': '2026-03-17T14:00:00',
                  'endTime': '2026-03-17T15:30:00',
                  'summary': 'Worked on API integration',
                }),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(csBuilder.items, hasLength(1));
          expect(csBuilder.items.first.toolName, 'create_time_entry');
          expect(
            csBuilder.items.first.humanSummary,
            'Time entry 14:00–15:30: "Worked on API integration"',
          );
        },
      );

      test(
        'generates correct human summary for create_time_entry — running timer',
        () async {
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-timer',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'create_time_entry',
                arguments: jsonEncode({
                  'startTime': '2026-03-17T09:05:00',
                  'summary': 'Starting morning standup',
                }),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(csBuilder.items, hasLength(1));
          expect(
            csBuilder.items.first.humanSummary,
            'Time entry from 09:05: "Starting morning standup"',
          );
        },
      );

      test(
        'uses raw endTime when create_time_entry includes an invalid end timestamp',
        () async {
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-invalid-end',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'create_time_entry',
                arguments: jsonEncode({
                  'startTime': '2026-03-17T14:00:00',
                  'endTime': 'later',
                  'summary': 'Worked on API integration',
                }),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(csBuilder.items, hasLength(1));
          expect(
            csBuilder.items.first.humanSummary,
            'Time entry 14:00–later: "Worked on API integration"',
          );
        },
      );

      test(
        'handles malformed create_time_entry args without crashing',
        () async {
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-malformed-time-entry',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'create_time_entry',
                arguments: jsonEncode({
                  'startTime': 42,
                  'endTime': true,
                  'summary': {'text': 'bad'},
                }),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(csBuilder.items, hasLength(1));
          expect(csBuilder.items.first.humanSummary, 'Time entry ?–?: ""');
        },
      );

      test(
        'generates correct human summary for update_running_timer',
        () async {
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-update-timer',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'update_running_timer',
                arguments: jsonEncode({
                  'timerId': 'timer-123',
                  'summary': '  Refined description of work in progress  ',
                }),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(csBuilder.items, hasLength(1));
          expect(csBuilder.items.first.toolName, 'update_running_timer');
          expect(
            csBuilder.items.first.humanSummary,
            'Update running timer text: '
            '"Refined description of work in progress"',
          );
        },
      );

      test(
        'generates correct human summary for update_time_entry',
        () async {
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-update-time-entry',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'update_time_entry',
                arguments: jsonEncode({
                  'entryId': 'entry-123',
                  'startTime': '2026-03-17T14:15:00',
                  'endTime': '2026-03-17T15:45:00',
                  'summary': '  Refined historical session  ',
                }),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(csBuilder.items, hasLength(1));
          expect(csBuilder.items.first.toolName, 'update_time_entry');
          expect(
            csBuilder.items.first.humanSummary,
            'Update time entry 14:15–15:45: '
            '"Refined historical session"',
          );
        },
      );

      test(
        'generates readable human summary for text-only update_time_entry',
        () async {
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-update-time-entry-text',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'update_time_entry',
                arguments: jsonEncode({
                  'entryId': 'entry-123',
                  'summary': 'Added rollout discussion',
                }),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(csBuilder.items, hasLength(1));
          expect(
            csBuilder.items.first.humanSummary,
            'Revise time entry text: "Added rollout discussion"',
          );
        },
      );

      test(
        'generates time-range-only summary for update_time_entry with no summary',
        () async {
          // When the LLM omits (or blanks out) the summary field, the human
          // summary should describe only the time range rather than crashing or
          // producing an empty string.
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-te-nosummary',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'update_time_entry',
                arguments: jsonEncode({
                  'entryId': 'entry-456',
                  'startTime': '2026-03-17T09:00:00',
                  'endTime': '2026-03-17T10:30:00',
                }),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(csBuilder.items, hasLength(1));
          expect(
            csBuilder.items.first.humanSummary,
            'Update time entry 09:00–10:30',
          );
        },
      );

      test(
        'generates bare label for update_time_entry with no summary and no times',
        () async {
          // Neither summary nor time fields: falls through to the empty-range
          // empty-summary branch and returns the bare label.
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-te-empty',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'update_time_entry',
                arguments: jsonEncode({
                  'entryId': 'entry-789',
                }),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(csBuilder.items, hasLength(1));
          expect(csBuilder.items.first.humanSummary, 'Update time entry');
        },
      );

      test(
        'returns Skipped response when addItem reports a within-wake duplicate',
        () async {
          // Pre-seed the ChangeSetBuilder with the identical item so the first
          // call to processToolCalls triggers the within-wake fingerprint dedup
          // inside ChangeSetBuilder.addItem (not the _usedDeferredTools check
          // which runs at a higher level and blocks repeat *single-use* tools).
          // The strategy must surface the "Already queued" message prefixed with
          // "Skipped:" to the LLM.
          //
          // We use update_task_priority because it is:
          //  - a non-batch deferred tool (routes through _addToChangeSet → addItem)
          //  - single-use (isSingleUse == true)
          // Pre-seeding bypasses the single-use guard and lets addItem's own
          // fingerprint dedup fire on the first processToolCalls call.
          await csBuilder.addItem(
            toolName: 'update_task_priority',
            args: {'priority': 'P2'},
            humanSummary: 'pre-seeded',
          );

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-dedup',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'update_task_priority',
                arguments: jsonEncode({'priority': 'P2'}),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          // Builder still has only the pre-seeded item; the duplicate was not
          // added.
          expect(csBuilder.items, hasLength(1));
          expect(csBuilder.items.first.humanSummary, 'pre-seeded');

          // The strategy forwards the "Already queued" message to the LLM
          // with a "Skipped:" prefix.
          final capturedResponse =
              verify(
                    () => mockManager.addToolResponse(
                      toolCallId: 'call-dedup',
                      response: captureAny(named: 'response'),
                    ),
                  ).captured.single
                  as String;
          expect(capturedResponse, startsWith('Skipped:'));
          expect(capturedResponse, contains('Already queued'));
        },
      );

      test(
        'handles malformed update_running_timer summary without crashing',
        () async {
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-malformed-update',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'update_running_timer',
                arguments: jsonEncode({
                  'timerId': 'timer-123',
                  'summary': 99,
                }),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(csBuilder.items, hasLength(1));
          expect(
            csBuilder.items.first.humanSummary,
            'Update running timer text: ""',
          );
        },
      );

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

        // Malformed labels (not a list) are rejected — no placeholder
        // item is queued to the change set.
        expect(csBuilder.items, isEmpty);
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
          captured.last as String,
          contains('2 malformed item(s) skipped'),
        );
        expect(
          captured.last as String,
          contains('1 item(s) queued'),
        );
      });

      test(
        'suppresses redundant non-batch tool and feeds back to LLM',
        () async {
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async => kTestTaskMetadataSnapshot,
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

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(builder.hasItems, isFalse);
          verify(
            () => mockManager.addToolResponse(
              toolCallId: 'call-redundant',
              response: 'Skipped: estimate is already 120 minutes.',
            ),
          ).called(1);
        },
      );

      test(
        'keeps non-redundant non-batch tool when metadata differs',
        () async {
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async => kTestTaskMetadataSnapshot,
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

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(builder.hasItems, isTrue);
          expect(builder.items.first.toolName, 'update_task_priority');
          verify(
            () => mockManager.addToolResponse(
              toolCallId: 'call-actual',
              response: any(
                named: 'response',
                that: contains('update_task_priority proposal recorded'),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'set_task_title auto-applies when current title is null',
        () async {
          const emptyTitleSnapshot =
              (
                    title: null,
                    status: 'IN PROGRESS',
                    priority: 'P1',
                    estimateMinutes: 120,
                    dueDate: '2026-03-15',
                    languageCode: 'en',
                  )
                  as TaskMetadataSnapshot;
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async => emptyTitleSnapshot,
          );

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
              output: 'Title applied immediately.',
              mutatedEntityId: 'task-001',
            ),
          );

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-initial-title',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskTitle,
                arguments: jsonEncode({'title': 'Buy groceries'}),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(
            builder.hasItems,
            isFalse,
            reason: 'initial title should bypass the change-set builder',
          );
          final executed = verify(
            () => mockExecutor.execute(
              toolName: captureAny(named: 'toolName'),
              args: captureAny(named: 'args'),
              targetEntityId: any(named: 'targetEntityId'),
              resolveCategoryId: any(named: 'resolveCategoryId'),
              executeHandler: any(named: 'executeHandler'),
              readVectorClock: any(named: 'readVectorClock'),
            ),
          ).captured;
          expect(executed[0], TaskAgentToolNames.setTaskTitle);
          expect(executed[1], equals(const {'title': 'Buy groceries'}));
          verify(
            () => mockManager.addToolResponse(
              toolCallId: 'call-initial-title',
              response: 'Title applied immediately.',
            ),
          ).called(1);
        },
      );

      test(
        'set_task_title auto-applies when current title is whitespace-only',
        () async {
          const blankTitleSnapshot =
              (
                    title: '   ',
                    status: 'IN PROGRESS',
                    priority: 'P1',
                    estimateMinutes: 120,
                    dueDate: '2026-03-15',
                    languageCode: 'en',
                  )
                  as TaskMetadataSnapshot;
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async => blankTitleSnapshot,
          );

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
              mutatedEntityId: 'task-001',
            ),
          );

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-blank-title',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskTitle,
                arguments: jsonEncode({'title': 'Write specs'}),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(builder.hasItems, isFalse);
          verify(
            () => mockExecutor.execute(
              toolName: TaskAgentToolNames.setTaskTitle,
              args: any(named: 'args'),
              targetEntityId: any(named: 'targetEntityId'),
              resolveCategoryId: any(named: 'resolveCategoryId'),
              executeHandler: any(named: 'executeHandler'),
              readVectorClock: any(named: 'readVectorClock'),
            ),
          ).called(1);
        },
      );

      test(
        'set_task_title falls back to a proposal when initial auto-apply is '
        'policy denied',
        () async {
          const emptyTitleSnapshot =
              (
                    title: null,
                    status: 'IN PROGRESS',
                    priority: 'P1',
                    estimateMinutes: 120,
                    dueDate: '2026-03-15',
                    languageCode: 'en',
                  )
                  as TaskMetadataSnapshot;
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async => emptyTitleSnapshot,
          );

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
              success: false,
              output: 'Policy denied: Category cat-999 not in allowed set',
              policyDenied: true,
              denialReason: 'Category cat-999 not in allowed set',
            ),
          );

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-policy-denied-title',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskTitle,
                arguments: jsonEncode({'title': 'PR Review for Ibad'}),
              ),
            ),
            ChatCompletionMessageToolCall(
              id: 'call-repeat-title',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskTitle,
                arguments: jsonEncode({'title': 'PR Review for Ibad'}),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          verify(
            () => mockExecutor.execute(
              toolName: TaskAgentToolNames.setTaskTitle,
              args: const {'title': 'PR Review for Ibad'},
              targetEntityId: any(named: 'targetEntityId'),
              resolveCategoryId: any(named: 'resolveCategoryId'),
              executeHandler: any(named: 'executeHandler'),
              readVectorClock: any(named: 'readVectorClock'),
            ),
          ).called(1);

          expect(builder.hasItems, isTrue);
          expect(builder.items, hasLength(1));
          expect(
            builder.items.single.toolName,
            TaskAgentToolNames.setTaskTitle,
          );
          expect(
            builder.items.single.humanSummary,
            'Set title to "PR Review for Ibad"',
          );
          verify(
            () => mockManager.addToolResponse(
              toolCallId: 'call-policy-denied-title',
              response: any(
                named: 'response',
                that: contains('set_task_title proposal recorded'),
              ),
            ),
          ).called(1);
          verify(
            () => mockManager.addToolResponse(
              toolCallId: 'call-repeat-title',
              response: any(
                named: 'response',
                that: contains('already called this session'),
              ),
            ),
          ).called(1);
          final persistedMessages = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured.whereType<AgentMessageEntity>().toList();
          expect(
            persistedMessages.where(
              (message) =>
                  message.kind == AgentMessageKind.toolResult &&
                  message.metadata.toolName ==
                      TaskAgentToolNames.setTaskTitle &&
                  message.metadata.errorMessage == null &&
                  !message.metadata.policyDenied,
            ),
            hasLength(1),
          );
        },
      );

      test(
        'set_task_title policy fallback rechecks metadata before queuing',
        () async {
          var resolveCount = 0;
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async {
              resolveCount += 1;
              return (
                    title: resolveCount == 1 ? null : 'PR Review for Ibad',
                    status: 'IN PROGRESS',
                    priority: 'P1',
                    estimateMinutes: 120,
                    dueDate: '2026-03-15',
                    languageCode: 'en',
                  )
                  as TaskMetadataSnapshot;
            },
          );

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
              success: false,
              output: 'Policy denied: Category cat-999 not in allowed set',
              policyDenied: true,
              denialReason: 'Category cat-999 not in allowed set',
            ),
          );

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-policy-denied-title',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskTitle,
                arguments: jsonEncode({'title': 'PR Review for Ibad'}),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(resolveCount, 2);
          expect(
            builder.hasItems,
            isFalse,
            reason:
                'fresh metadata should suppress a now-redundant fallback '
                'proposal',
          );
          verify(
            () => mockManager.addToolResponse(
              toolCallId: 'call-policy-denied-title',
              response: 'Skipped: title is already "PR Review for Ibad".',
            ),
          ).called(1);
        },
      );

      test(
        'set_task_title stays deferred when an existing title is present',
        () async {
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async => kTestTaskMetadataSnapshot,
          );

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-rename',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskTitle,
                arguments: jsonEncode({'title': 'New name'}),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(builder.hasItems, isTrue);
          expect(
            builder.items.single.toolName,
            TaskAgentToolNames.setTaskTitle,
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
        },
      );

      test(
        'set_task_title cannot auto-apply twice in the same wake',
        () async {
          // Regression guard against the stale-cache double-apply bug:
          // if an LLM emits two back-to-back set_task_title calls (a
          // common failure mode for smaller models), only the first
          // should auto-apply. The second must either (a) observe the
          // freshly-populated title on a forced re-read, or (b) hit the
          // single-use deferred guard — in either case, it must not
          // silently overwrite the title the executor just wrote.
          var autoApplied = 0;
          var currentTitle = '';
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async {
              return (
                    title: currentTitle.isEmpty ? null : currentTitle,
                    status: 'IN PROGRESS',
                    priority: 'P1',
                    estimateMinutes: 120,
                    dueDate: '2026-03-15',
                    languageCode: 'en',
                  )
                  as TaskMetadataSnapshot;
            },
          );

          when(
            () => mockExecutor.execute(
              toolName: any(named: 'toolName'),
              args: any(named: 'args'),
              targetEntityId: any(named: 'targetEntityId'),
              resolveCategoryId: any(named: 'resolveCategoryId'),
              executeHandler: any(named: 'executeHandler'),
              readVectorClock: any(named: 'readVectorClock'),
            ),
          ).thenAnswer((invocation) async {
            autoApplied += 1;
            final args =
                invocation.namedArguments[const Symbol('args')]!
                    as Map<String, dynamic>;
            currentTitle = args['title']! as String;
            return const ToolExecutionResult(
              success: true,
              output: 'applied',
              mutatedEntityId: 'task-001',
            );
          });

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-first',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskTitle,
                arguments: jsonEncode({'title': 'First title'}),
              ),
            ),
            ChatCompletionMessageToolCall(
              id: 'call-second',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskTitle,
                arguments: jsonEncode({'title': 'Second title'}),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(
            autoApplied,
            1,
            reason: 'only the first call must auto-apply',
          );
          expect(
            currentTitle,
            'First title',
            reason:
                'the second call must not silently overwrite the first '
                'via the stale-cache path',
          );
        },
      );

      test(
        'successful auto-apply invalidates the metadata cache primed by an '
        'earlier redundancy check',
        () async {
          // Wake order: (1) a redundancy check on update_task_estimate
          // resolves and caches the snapshot, (2) a set_task_title
          // auto-apply succeeds — which must invalidate that cache —
          // (3) a second update_task_estimate must therefore re-resolve
          // fresh metadata instead of reusing the pre-auto-apply snapshot.
          var resolverCalls = 0;
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async {
              resolverCalls++;
              return (
                title: resolverCalls >= 3 ? 'Cache test' : null,
                status: 'IN PROGRESS',
                priority: 'P1',
                // The estimate changes after the auto-apply: a stale cache
                // would still say 240 and wrongly skip the third call.
                estimateMinutes: resolverCalls >= 3 ? 999 : 240,
                dueDate: '2026-03-15',
                languageCode: 'en',
              );
            },
          );

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
              output: 'Title applied immediately.',
              mutatedEntityId: 'task-001',
            ),
          );

          ChatCompletionMessageToolCall call(
            String id,
            String name,
            Map<String, dynamic> args,
          ) => ChatCompletionMessageToolCall(
            id: id,
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: name,
              arguments: jsonEncode(args),
            ),
          );

          await strategy.processToolCalls(
            toolCalls: [
              // (1) Redundant against the cached 240-minute snapshot.
              call('call-est-1', TaskAgentToolNames.updateTaskEstimate, {
                'minutes': 240,
              }),
              // (2) Auto-applies (title empty) and invalidates the cache.
              call('call-title', TaskAgentToolNames.setTaskTitle, {
                'title': 'Cache test',
              }),
              // (3) Must re-resolve: against the fresh 999-minute snapshot
              // this is NOT redundant and must be queued.
              call('call-est-2', TaskAgentToolNames.updateTaskEstimate, {
                'minutes': 240,
              }),
            ],
            manager: mockManager,
          );

          // Redundancy check + always-fresh auto-apply check + post-
          // invalidation redundancy re-check.
          expect(resolverCalls, 3);

          // First estimate proposal was suppressed as redundant.
          verify(
            () => mockManager.addToolResponse(
              toolCallId: 'call-est-1',
              response: any(named: 'response', that: contains('Skipped')),
            ),
          ).called(1);

          // Third proposal was queued, not skipped against stale metadata.
          expect(builder.items, hasLength(1));
          expect(
            builder.items.single.toolName,
            TaskAgentToolNames.updateTaskEstimate,
          );
          verify(
            () => mockManager.addToolResponse(
              toolCallId: 'call-est-2',
              response: any(
                named: 'response',
                that: isNot(contains('Skipped')),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'set_task_title stays deferred when no resolveTaskMetadata is wired',
        () async {
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            // resolveTaskMetadata intentionally omitted.
          );

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-no-resolver',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskTitle,
                arguments: jsonEncode({'title': 'Something'}),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(
            builder.hasItems,
            isTrue,
            reason: 'without a resolver, fall back to the deferred path',
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
        },
      );

      test(
        'set_task_title stays deferred when resolveTaskMetadata throws',
        () async {
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async => throw Exception('resolver down'),
          );

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-throws',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskTitle,
                arguments: jsonEncode({'title': 'Any'}),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(
            builder.hasItems,
            isTrue,
            reason:
                'resolver failure should not auto-apply; must fall through '
                'to the deferred path',
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
        },
      );

      test(
        'set_task_title stays deferred when resolveTaskMetadata returns null',
        () async {
          // Mirrors the non-Task-entity case where
          // ChangeProposalFilter.resolveTaskMetadata returns null.
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async => null,
          );

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-null-snap',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskTitle,
                arguments: jsonEncode({'title': 'Any'}),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(builder.hasItems, isTrue);
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
        },
      );

      test(
        'set_task_language auto-applies when current language is null',
        () async {
          const emptyLanguageSnapshot =
              (
                    title: 'Buy groceries',
                    status: 'IN PROGRESS',
                    priority: 'P1',
                    estimateMinutes: 120,
                    dueDate: '2026-03-15',
                    languageCode: null,
                  )
                  as TaskMetadataSnapshot;
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async => emptyLanguageSnapshot,
          );

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
              output: 'Language applied immediately.',
              mutatedEntityId: 'task-001',
            ),
          );

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-initial-lang',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskLanguage,
                arguments: jsonEncode({'languageCode': 'en'}),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(
            builder.hasItems,
            isFalse,
            reason: 'initial language should bypass the change-set builder',
          );
          final executed = verify(
            () => mockExecutor.execute(
              toolName: captureAny(named: 'toolName'),
              args: captureAny(named: 'args'),
              targetEntityId: any(named: 'targetEntityId'),
              resolveCategoryId: any(named: 'resolveCategoryId'),
              executeHandler: any(named: 'executeHandler'),
              readVectorClock: any(named: 'readVectorClock'),
            ),
          ).captured;
          expect(executed[0], TaskAgentToolNames.setTaskLanguage);
          expect(executed[1], equals(const {'languageCode': 'en'}));
          verify(
            () => mockManager.addToolResponse(
              toolCallId: 'call-initial-lang',
              response: 'Language applied immediately.',
            ),
          ).called(1);
        },
      );

      test(
        'set_task_language stays deferred when a language is already present',
        () async {
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async => kTestTaskMetadataSnapshot,
          );

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-relang',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskLanguage,
                arguments: jsonEncode({'languageCode': 'de'}),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(builder.hasItems, isTrue);
          expect(
            builder.items.single.toolName,
            TaskAgentToolNames.setTaskLanguage,
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
        },
      );

      test(
        'set_task_language cannot auto-apply twice in the same wake',
        () async {
          // Regression guard mirroring the title double-apply case: two
          // back-to-back set_task_language calls must only auto-apply
          // once, with the second either observing the freshly-populated
          // language on a forced re-read or hitting the single-use
          // deferred guard.
          var autoApplied = 0;
          var currentLanguage = '';
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async {
              return (
                    title: 'Buy groceries',
                    status: 'IN PROGRESS',
                    priority: 'P1',
                    estimateMinutes: 120,
                    dueDate: '2026-03-15',
                    languageCode: currentLanguage.isEmpty
                        ? null
                        : currentLanguage,
                  )
                  as TaskMetadataSnapshot;
            },
          );

          when(
            () => mockExecutor.execute(
              toolName: any(named: 'toolName'),
              args: any(named: 'args'),
              targetEntityId: any(named: 'targetEntityId'),
              resolveCategoryId: any(named: 'resolveCategoryId'),
              executeHandler: any(named: 'executeHandler'),
              readVectorClock: any(named: 'readVectorClock'),
            ),
          ).thenAnswer((invocation) async {
            autoApplied += 1;
            final args =
                invocation.namedArguments[const Symbol('args')]!
                    as Map<String, dynamic>;
            currentLanguage = args['languageCode']! as String;
            return const ToolExecutionResult(
              success: true,
              output: 'applied',
              mutatedEntityId: 'task-001',
            );
          });

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-lang-first',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskLanguage,
                arguments: jsonEncode({'languageCode': 'en'}),
              ),
            ),
            ChatCompletionMessageToolCall(
              id: 'call-lang-second',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskLanguage,
                arguments: jsonEncode({'languageCode': 'de'}),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(
            autoApplied,
            1,
            reason: 'only the first language call must auto-apply',
          );
          expect(
            currentLanguage,
            'en',
            reason:
                'the second call must not silently overwrite the first '
                'via the stale-cache path',
          );
        },
      );

      test(
        'set_task_language stays deferred when resolveTaskMetadata throws',
        () async {
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            resolveTaskMetadata: () async => throw Exception('resolver down'),
          );

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-lang-throws',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.setTaskLanguage,
                arguments: jsonEncode({'languageCode': 'en'}),
              ),
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(builder.hasItems, isTrue);
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
        },
      );

      test('keeps tool when resolver throws (conservative)', () async {
        final (:strategy, :builder) = _createStrategy(
          executor: mockExecutor,
          syncService: mockSyncService,
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

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(builder.hasItems, isTrue);
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-err',
            response: any(
              named: 'response',
              that: contains('update_task_estimate proposal recorded'),
            ),
          ),
        ).called(1);
      });

      test(
        'redundant batch items include redundancy info in response',
        () async {
          final (:strategy, :builder) = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            checklistItemStateResolver: (id) async =>
                (title: 'Buy groceries', isChecked: true, isArchived: null),
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

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(builder.hasItems, isFalse);

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
        },
      );

      test(
        'routes create_follow_up_task to addFollowUpTask and returns '
        'placeholder ID',
        () async {
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-split',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'create_follow_up_task',
                arguments: jsonEncode({'title': 'Design v2'}),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          // Should be routed to addFollowUpTask (has _placeholderTaskId).
          expect(csBuilder.items, hasLength(1));
          expect(
            csBuilder.items.first.toolName,
            'create_follow_up_task',
          );
          expect(
            csBuilder.items.first.args['_placeholderTaskId'],
            isNotNull,
          );
          expect(
            csBuilder.items.first.humanSummary,
            'Create follow-up task: "Design v2"',
          );

          // Response should contain the placeholder ID.
          final captured = verify(
            () => mockManager.addToolResponse(
              toolCallId: 'call-split',
              response: captureAny(named: 'response'),
            ),
          ).captured;
          final response = captured.last as String;
          expect(response, contains('Proposal queued for user review'));
          expect(response, contains('targetTaskId'));
        },
      );

      test(
        'migrate_checklist_items passes targetTaskId as groupId',
        () async {
          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-migrate',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'migrate_checklist_items',
                arguments: jsonEncode({
                  'targetTaskId': 'placeholder-123',
                  'items': [
                    {'id': 'item-1', 'title': 'Buy milk'},
                    {'id': 'item-2', 'title': 'Walk dog'},
                  ],
                }),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(csBuilder.items, hasLength(2));
          // Each exploded item should have the groupId set.
          for (final item in csBuilder.items) {
            expect(item.toolName, 'migrate_checklist_item');
            expect(item.groupId, 'placeholder-123');
            expect(item.args['targetTaskId'], 'placeholder-123');
          }
        },
      );

      test(
        'migrate_checklist_items overrides LLM targetTaskId with real '
        'placeholder from create_follow_up_task',
        () async {
          // First, the LLM calls create_follow_up_task.
          final createCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-create',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'create_follow_up_task',
                arguments: jsonEncode({
                  'title': 'Release Task',
                }),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: createCalls,
            manager: mockManager,
          );

          // The builder should now have a follow-up task with a real
          // placeholder UUID.
          final realPlaceholder = csBuilder.followUpPlaceholderId;
          expect(realPlaceholder, isNotNull);
          expect(realPlaceholder, isNot('hallucinated_id'));

          // Then the LLM calls migrate_checklist_items with a hallucinated
          // targetTaskId that doesn't match the real placeholder.
          final migrateCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-migrate',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'migrate_checklist_items',
                arguments: jsonEncode({
                  'targetTaskId': 'hallucinated_id',
                  'items': [
                    {'id': 'item-1', 'title': 'Do thing'},
                  ],
                }),
              ),
            ),
          ];

          await deferredStrategy.processToolCalls(
            toolCalls: migrateCalls,
            manager: mockManager,
          );

          // The migration item should have the REAL placeholder, not the
          // LLM's hallucinated one.
          final migrateItems = csBuilder.items.where(
            (i) => i.toolName == 'migrate_checklist_item',
          );
          expect(migrateItems, hasLength(1));
          expect(
            migrateItems.first.args['targetTaskId'],
            realPlaceholder,
          );
          expect(migrateItems.first.groupId, realPlaceholder);
        },
      );

      glados.Glados(
        glados.any.splitSequenceScenario,
        glados.ExploreConfig(numRuns: 160),
      ).test(
        'matches generated follow-up and migration sequencing semantics',
        (scenario) async {
          final localExecutor = MockAgentToolExecutor();
          final localSyncService = MockAgentSyncService();
          final localManager = MockConversationManager();
          final (
            strategy: localStrategy,
            builder: localBuilder,
          ) = _createStrategy(
            executor: localExecutor,
            syncService: localSyncService,
          );
          when(
            () => localSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          await localStrategy.processToolCalls(
            toolCalls: scenario.toolCalls(),
            manager: localManager,
          );

          verifyNever(
            () => localExecutor.execute(
              toolName: any(named: 'toolName'),
              args: any(named: 'args'),
              targetEntityId: any(named: 'targetEntityId'),
              resolveCategoryId: any(named: 'resolveCategoryId'),
              executeHandler: any(named: 'executeHandler'),
              readVectorClock: any(named: 'readVectorClock'),
            ),
          );

          final placeholder = scenario.expectedPlaceholder(taskId);
          final createItems = localBuilder.items.where(
            (item) => item.toolName == TaskAgentToolNames.createFollowUpTask,
          );
          expect(createItems, hasLength(1), reason: '$scenario');
          expect(
            createItems.single.args,
            containsPair('_placeholderTaskId', placeholder),
            reason: '$scenario',
          );
          expect(createItems.single.args['title'], scenario.title);

          final migrateItems = localBuilder.items
              .where(
                (item) =>
                    item.toolName == TaskAgentToolNames.migrateChecklistItem,
              )
              .toList(growable: false);
          expect(
            migrateItems,
            hasLength(scenario.itemCount),
            reason: '$scenario',
          );

          final expectedTarget = scenario.createBeforeMigration
              ? placeholder
              : scenario.targetShape == _GeneratedMigrationTargetShape.missing
              ? null
              : scenario.rawTargetId;
          for (final item in migrateItems) {
            expect(item.groupId, expectedTarget, reason: '$scenario');
            if (expectedTarget == null) {
              expect(
                item.args.containsKey('targetTaskId'),
                isFalse,
                reason: '$scenario',
              );
            } else {
              expect(
                item.args['targetTaskId'],
                expectedTarget,
                reason: '$scenario',
              );
            }
          }
        },
        tags: 'glados',
      );
    });

    group('retract_suggestions routing', () {
      test(
        'dispatches to the retraction service without invoking the executor',
        () async {
          final fakeService = _FakeRetractionService(
            responses: (requests) => [
              RetractionResult(
                fingerprint: requests.first.fingerprint,
                outcome: RetractionOutcome.retracted,
                toolName: 'update_task_priority',
                humanSummary: 'Set priority to P1',
              ),
            ],
          );

          final retractionStrategy = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            withChangeSetBuilder: false,
            retractionService: fakeService,
          ).strategy;

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-retract-1',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.retractSuggestions,
                arguments: jsonEncode({
                  'proposals': [
                    {
                      'fingerprint': 'fp-abc',
                      'reason': 'Already P1',
                    },
                  ],
                }),
              ),
            ),
          ];

          await retractionStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          // The retraction service, not the executor, handled the call.
          expect(fakeService.capturedCalls, hasLength(1));
          expect(fakeService.capturedCalls.single.agentId, agentId);
          expect(fakeService.capturedCalls.single.taskId, taskId);
          expect(
            fakeService.capturedCalls.single.requests.single.fingerprint,
            'fp-abc',
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

          // The LLM sees a per-entry outcome report.
          final response =
              verify(
                    () => mockManager.addToolResponse(
                      toolCallId: 'call-retract-1',
                      response: captureAny(named: 'response'),
                    ),
                  ).captured.single
                  as String;
          expect(response, contains('[fp=fp-abc] retracted'));
          expect(response, contains('Set priority to P1'));
        },
      );

      test(
        'stages retractions for end-of-wake application instead of '
        'persisting mid-conversation',
        () async {
          final changeSet = makeTestChangeSet(id: 'cs-stage-1');
          final fakeService = _FakeRetractionService(
            responses: (requests) => [
              RetractionResult(
                fingerprint: requests.first.fingerprint,
                outcome: RetractionOutcome.retracted,
              ),
            ],
            staged: [
              StagedRetraction(
                changeSet: changeSet,
                itemIndex: 0,
                item: changeSet.items.first,
                reason: 'stale',
              ),
            ],
          );

          final retractionStrategy = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            withChangeSetBuilder: false,
            retractionService: fakeService,
          ).strategy;

          await retractionStrategy.processToolCalls(
            toolCalls: [
              ChatCompletionMessageToolCall(
                id: 'call-retract-stage',
                type: ChatCompletionMessageToolCallType.function,
                function: ChatCompletionMessageFunctionCall(
                  name: TaskAgentToolNames.retractSuggestions,
                  arguments: jsonEncode({
                    'proposals': [
                      {'fingerprint': 'fp-stage', 'reason': 'stale'},
                    ],
                  }),
                ),
              ),
            ],
            manager: mockManager,
          );

          // The retraction is staged for the workflow to apply at end-of-wake.
          final staged = retractionStrategy.extractStagedRetractions();
          expect(staged, hasLength(1));
          expect(staged.single.changeSet.id, 'cs-stage-1');
          expect(staged.single.reason, 'stale');
          // It must NOT be persisted during the conversation — otherwise the
          // suggestion list flashes empty until the end-of-wake proposals land.
          expect(fakeService.appliedStaged, isEmpty);
        },
      );

      test(
        'passes already-staged keys to plan so repeat calls stay idempotent',
        () async {
          final changeSet = makeTestChangeSet(id: 'cs-stage-2');
          final fakeService = _FakeRetractionService(
            responses: (requests) => [
              RetractionResult(
                fingerprint: requests.first.fingerprint,
                outcome: RetractionOutcome.retracted,
              ),
            ],
            staged: [
              StagedRetraction(
                changeSet: changeSet,
                itemIndex: 0,
                item: changeSet.items.first,
                reason: 'stale',
              ),
            ],
          );

          final retractionStrategy = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            withChangeSetBuilder: false,
            retractionService: fakeService,
          ).strategy;

          ChatCompletionMessageToolCall retractCall(String id) =>
              ChatCompletionMessageToolCall(
                id: id,
                type: ChatCompletionMessageToolCallType.function,
                function: ChatCompletionMessageFunctionCall(
                  name: TaskAgentToolNames.retractSuggestions,
                  arguments: jsonEncode({
                    'proposals': [
                      {'fingerprint': 'fp-stage', 'reason': 'stale'},
                    ],
                  }),
                ),
              );

          await retractionStrategy.processToolCalls(
            toolCalls: [retractCall('call-1')],
            manager: mockManager,
          );
          await retractionStrategy.processToolCalls(
            toolCalls: [retractCall('call-2')],
            manager: mockManager,
          );

          // First call stages with no prior keys; the second call must pass the
          // key staged by the first so the service can stay idempotent without
          // any persistence between calls.
          expect(fakeService.capturedCalls, hasLength(2));
          expect(fakeService.capturedCalls.first.alreadyStagedKeys, isEmpty);
          expect(
            fakeService.capturedCalls[1].alreadyStagedKeys,
            contains('cs-stage-2:0'),
          );
        },
      );

      test(
        'malformed proposals payload surfaces a non-empty error without '
        'invoking the retraction service',
        () async {
          final fakeService = _FakeRetractionService(
            responses: (_) => const [],
          );
          final retractionStrategy = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            withChangeSetBuilder: false,
            retractionService: fakeService,
          ).strategy;

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-retract-bad',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.retractSuggestions,
                // `proposals` is not an array — should error.
                arguments: jsonEncode({'proposals': 'not-an-array'}),
              ),
            ),
          ];

          await retractionStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(fakeService.capturedCalls, isEmpty);
          final response =
              verify(
                    () => mockManager.addToolResponse(
                      toolCallId: 'call-retract-bad',
                      response: captureAny(named: 'response'),
                    ),
                  ).captured.single
                  as String;
          expect(response, startsWith('Error:'));
        },
      );

      test(
        'drops malformed proposal entries but still retracts the valid ones',
        () async {
          final fakeService = _FakeRetractionService(
            responses: (requests) => [
              for (final r in requests)
                RetractionResult(
                  fingerprint: r.fingerprint,
                  outcome: RetractionOutcome.retracted,
                  humanSummary: 'ok: ${r.fingerprint}',
                ),
            ],
          );
          final retractionStrategy = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            withChangeSetBuilder: false,
            retractionService: fakeService,
          ).strategy;

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-mixed',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.retractSuggestions,
                arguments: jsonEncode({
                  'proposals': [
                    'not-an-object',
                    {'fingerprint': '  ', 'reason': 'empty fp'},
                    {'fingerprint': 'fp-ok', 'reason': '  '},
                    {'fingerprint': 'fp-valid', 'reason': 'Looks stale'},
                  ],
                }),
              ),
            ),
          ];

          await retractionStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(fakeService.capturedCalls, hasLength(1));
          final requests = fakeService.capturedCalls.single.requests;
          expect(requests, hasLength(1));
          expect(requests.single.fingerprint, 'fp-valid');
          expect(requests.single.reason, 'Looks stale');

          final response =
              verify(
                    () => mockManager.addToolResponse(
                      toolCallId: 'call-mixed',
                      response: captureAny(named: 'response'),
                    ),
                  ).captured.single
                  as String;
          expect(response, contains('retracted'));
          expect(response, contains('Skipped malformed entries'));
          expect(response, contains('proposals[0] is not an object'));
          expect(response, contains('fingerprint missing or empty'));
          expect(response, contains('reason missing or empty'));
        },
      );

      test(
        'all entries malformed yields an error response and no service call',
        () async {
          final fakeService = _FakeRetractionService(
            responses: (_) => const [],
          );
          final retractionStrategy = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            withChangeSetBuilder: false,
            retractionService: fakeService,
          ).strategy;

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-all-bad',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.retractSuggestions,
                arguments: jsonEncode({
                  'proposals': [
                    // Non-object elements and malformed objects both fall
                    // through to the same "no valid proposals" error path.
                    'just-a-string',
                    42,
                    ['nested', 'array'],
                    {'fingerprint': null, 'reason': 'x'},
                    {'fingerprint': 'fp', 'reason': ''},
                  ],
                }),
              ),
            ),
          ];

          await retractionStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          expect(fakeService.capturedCalls, isEmpty);
          final response =
              verify(
                    () => mockManager.addToolResponse(
                      toolCallId: 'call-all-bad',
                      response: captureAny(named: 'response'),
                    ),
                  ).captured.single
                  as String;
          expect(response, startsWith('Error: no valid proposals to retract.'));
        },
      );

      test(
        'outcome labels cover retracted, notOpen, and notFound per-entry',
        () async {
          final fakeService = _FakeRetractionService(
            responses: (requests) => const [
              RetractionResult(
                fingerprint: 'fp-retracted',
                outcome: RetractionOutcome.retracted,
                toolName: 'set_task_title',
                humanSummary: 'Rename',
              ),
              RetractionResult(
                fingerprint: 'fp-closed',
                outcome: RetractionOutcome.notOpen,
                toolName: 'update_task_priority',
                humanSummary: 'Already confirmed',
              ),
              RetractionResult(
                fingerprint: 'fp-missing',
                outcome: RetractionOutcome.notFound,
              ),
            ],
          );
          final retractionStrategy = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            withChangeSetBuilder: false,
            retractionService: fakeService,
          ).strategy;

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-labels',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.retractSuggestions,
                arguments: jsonEncode({
                  'proposals': [
                    {'fingerprint': 'fp-retracted', 'reason': 'r'},
                    {'fingerprint': 'fp-closed', 'reason': 'r'},
                    {'fingerprint': 'fp-missing', 'reason': 'r'},
                  ],
                }),
              ),
            ),
          ];

          await retractionStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          final response =
              verify(
                    () => mockManager.addToolResponse(
                      toolCallId: 'call-labels',
                      response: captureAny(named: 'response'),
                    ),
                  ).captured.single
                  as String;
          expect(response, contains('[fp=fp-retracted] retracted'));
          expect(
            response,
            contains('[fp=fp-closed] not_open (already resolved)'),
          );
          expect(response, contains('[fp=fp-missing] not_found'));
          // Items without a humanSummary still report the tool name when
          // available; the not_found line has neither, so only the tool
          // name / humanSummary ones get the suffix.
          expect(response, contains('— "Rename"'));
          expect(response, contains('— "Already confirmed"'));
        },
      );

      test(
        'omitting the retraction service returns a wiring error to the LLM',
        () async {
          // retractionService intentionally omitted.
          final noServiceStrategy = _createStrategy(
            executor: mockExecutor,
            syncService: mockSyncService,
            withChangeSetBuilder: false,
          ).strategy;

          final toolCalls = [
            ChatCompletionMessageToolCall(
              id: 'call-retract-nowire',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: TaskAgentToolNames.retractSuggestions,
                arguments: jsonEncode({
                  'proposals': [
                    {'fingerprint': 'fp-abc', 'reason': 'x'},
                  ],
                }),
              ),
            ),
          ];

          await noServiceStrategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          final response =
              verify(
                    () => mockManager.addToolResponse(
                      toolCallId: 'call-retract-nowire',
                      response: captureAny(named: 'response'),
                    ),
                  ).captured.single
                  as String;
          expect(response, contains('retract_suggestions is not wired up'));
        },
      );
    });

    // -------------------------------------------------------------------------
    // Glados properties for the pure JSON-recovery parser (via the
    // debugParseToolArguments seam) — round-trip, fence-recovery, and
    // balanced-brace invariants for arbitrary generated JSON objects.
    // -------------------------------------------------------------------------
    group('debugParseToolArguments — properties', () {
      glados.Glados(
        glados.any.toolArgsObject,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'round-trips, fence-recovers, and brace-extracts any object',
        (
          obj,
        ) {
          final encoded = jsonEncode(obj);

          // Idempotent direct parse: a valid object returns the same map.
          expect(
            TaskAgentStrategy.debugParseToolArguments(encoded),
            obj,
            reason: 'direct: $encoded',
          );

          // Fence recovery: a markdown-fenced object always round-trips.
          expect(
            TaskAgentStrategy.debugParseToolArguments(
              '```json\n$encoded\n```',
            ),
            obj,
            reason: 'fenced: $encoded',
          );

          // Balanced-brace extraction: the first balanced object in a string
          // with trailing prose is always returned.
          expect(
            TaskAgentStrategy.debugParseToolArguments(
              '$encoded trailing explanation text',
            ),
            obj,
            reason: 'trailing: $encoded',
          );
        },
        tags: 'glados',
      );
    });
  });
}

/// Generates small JSON-object trees from primitive seeds — strings, ints,
/// bools, nulls, nested objects, and lists, shaped like tool arguments.
extension _AnyToolArgsObject on glados.Any {
  glados.Generator<Object?> get _toolArgsValue =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 6),
        glados.IntAnys(this).intInRange(0, 1000),
        (int kind, int seed) => switch (kind) {
          0 => 'value-$seed',
          1 => seed,
          2 => seed.isEven,
          3 => null,
          4 => <String, dynamic>{'nested-$seed': 'inner-$seed'},
          _ => <dynamic>['item-$seed', seed],
        },
      );

  glados.Generator<Map<String, dynamic>> get toolArgsObject =>
      list(_toolArgsValue).map(
        (values) => <String, dynamic>{
          for (final (i, v) in values.indexed) 'key$i': v,
        },
      );
}

/// Captures every call and returns a scripted response list.
class _FakeRetractionService implements SuggestionRetractionService {
  _FakeRetractionService({required this.responses, this.staged = const []});

  final List<RetractionResult> Function(List<RetractionRequest>) responses;

  /// Staged retractions returned from [plan], so tests can assert the strategy
  /// accumulates them for end-of-wake application instead of persisting now.
  final List<StagedRetraction> staged;

  final capturedCalls = <_CapturedRetract>[];

  /// Records every [applyStaged] call so tests can assert it is NOT invoked
  /// during the conversation (persistence is deferred to the workflow).
  final appliedStaged = <List<StagedRetraction>>[];

  @override
  Future<RetractionPlan> plan({
    required String agentId,
    required String taskId,
    required List<RetractionRequest> requests,
    Set<String> alreadyStagedKeys = const {},
  }) async {
    capturedCalls.add(
      _CapturedRetract(
        agentId: agentId,
        taskId: taskId,
        requests: requests,
        // Snapshot the set: the strategy mutates the same instance after this
        // call returns, so a live reference would reflect later state.
        alreadyStagedKeys: Set<String>.of(alreadyStagedKeys),
      ),
    );
    return RetractionPlan(results: responses(requests), staged: staged);
  }

  @override
  Future<void> applyStaged(
    List<StagedRetraction> staged, {
    Set<String> skipFingerprints = const {},
  }) async {
    appliedStaged.add(staged);
  }
}

class _CapturedRetract {
  const _CapturedRetract({
    required this.agentId,
    required this.taskId,
    required this.requests,
    this.alreadyStagedKeys = const {},
  });
  final String agentId;
  final String taskId;
  final List<RetractionRequest> requests;
  final Set<String> alreadyStagedKeys;
}
