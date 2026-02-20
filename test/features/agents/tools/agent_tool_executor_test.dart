import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockAgentRepository mockRepository;
  late AgentToolExecutor executor;

  const agentId = 'agent-001';
  const threadId = 'thread-001';
  const runKey = 'run-key-001';
  const allowedCategoryId = 'cat-001';
  const targetEntityId = 'entity-001';

  setUp(() {
    mockRepository = MockAgentRepository();
    registerFallbackValue(
      AgentDomainEntity.unknown(
        id: 'fallback',
        agentId: 'fallback',
        createdAt: DateTime(2024, 3, 15),
      ),
    );

    when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async => {});

    executor = AgentToolExecutor(
      repository: mockRepository,
      allowedCategoryIds: {allowedCategoryId},
      runKey: runKey,
      agentId: agentId,
      threadId: threadId,
    );
  });

  group('AgentToolExecutor', () {
    group('category enforcement', () {
      test('denies when target entity has no category (null)', () async {
        final result = await executor.execute(
          toolName: 'set_task_title',
          args: {'title': 'New Title'},
          targetEntityId: targetEntityId,
          resolveCategoryId: (_) async => null,
          executeHandler: () async => const ToolExecutionResult(
            success: true,
            output: 'should not be reached',
          ),
          readVectorClock: (_) async => null,
        );

        expect(result.success, isFalse);
        expect(result.policyDenied, isTrue);
        expect(result.denialReason, equals('Target entity has no category'));
        expect(result.output, contains('Policy denied'));
      });

      test('denies when category is not in allowed set', () async {
        final result = await executor.execute(
          toolName: 'set_task_title',
          args: {'title': 'New Title'},
          targetEntityId: targetEntityId,
          resolveCategoryId: (_) async => 'cat-forbidden',
          executeHandler: () async => const ToolExecutionResult(
            success: true,
            output: 'should not be reached',
          ),
          readVectorClock: (_) async => null,
        );

        expect(result.success, isFalse);
        expect(result.policyDenied, isTrue);
        expect(
          result.denialReason,
          equals('Category cat-forbidden not in allowed set'),
        );
      });

      test('records denial in audit log as action message', () async {
        await executor.execute(
          toolName: 'set_task_title',
          args: {'title': 'New Title'},
          targetEntityId: targetEntityId,
          resolveCategoryId: (_) async => null,
          executeHandler: () async => const ToolExecutionResult(
            success: true,
            output: 'unreachable',
          ),
          readVectorClock: (_) async => null,
        );

        // Exactly one upsertEntity call for the denial action message.
        final captured =
            verify(() => mockRepository.upsertEntity(captureAny())).captured;
        expect(captured, hasLength(1));
        final entity = captured.first as AgentDomainEntity;
        final message = entity as AgentMessageEntity;
        expect(message.agentId, equals(agentId));
        expect(message.threadId, equals(threadId));
        expect(message.metadata.policyDenied, isTrue);
        expect(message.metadata.denialReason, isNotNull);
        expect(message.metadata.toolName, equals('set_task_title'));
      });

      test('does not call executeHandler when denied', () async {
        var handlerCalled = false;

        await executor.execute(
          toolName: 'set_task_title',
          args: {'title': 'New Title'},
          targetEntityId: targetEntityId,
          resolveCategoryId: (_) async => 'cat-forbidden',
          executeHandler: () async {
            handlerCalled = true;
            return const ToolExecutionResult(
              success: true,
              output: 'done',
            );
          },
          readVectorClock: (_) async => null,
        );

        expect(handlerCalled, isFalse);
      });

      test('allows when category is in allowed set', () async {
        final result = await executor.execute(
          toolName: 'set_task_title',
          args: {'title': 'New Title'},
          targetEntityId: targetEntityId,
          resolveCategoryId: (_) async => allowedCategoryId,
          executeHandler: () async => const ToolExecutionResult(
            success: true,
            output: 'Title updated',
          ),
          readVectorClock: (_) async => null,
        );

        expect(result.success, isTrue);
        expect(result.policyDenied, isFalse);
        expect(result.output, equals('Title updated'));
      });
    });

    group('action and result message persistence', () {
      test('persists action message before handler and result after', () async {
        await executor.execute(
          toolName: 'set_task_title',
          args: {'title': 'New Title'},
          targetEntityId: targetEntityId,
          resolveCategoryId: (_) async => allowedCategoryId,
          executeHandler: () async => const ToolExecutionResult(
            success: true,
            output: 'done',
          ),
          readVectorClock: (_) async => null,
        );

        // Should have been called exactly twice: action + toolResult.
        final captured =
            verify(() => mockRepository.upsertEntity(captureAny())).captured;
        expect(captured, hasLength(2));

        final actionMessage = captured[0] as AgentMessageEntity;
        final resultMessage = captured[1] as AgentMessageEntity;

        expect(actionMessage.metadata.toolName, equals('set_task_title'));
        expect(actionMessage.metadata.runKey, equals(runKey));
        expect(actionMessage.metadata.operationId, isNotNull);
        expect(actionMessage.metadata.policyDenied, isFalse);

        expect(resultMessage.metadata.toolName, equals('set_task_title'));
        expect(resultMessage.metadata.runKey, equals(runKey));
        expect(resultMessage.metadata.operationId, isNotNull);
        expect(resultMessage.metadata.errorMessage, isNull);
      });

      test('result message contains error when handler returns error',
          () async {
        await executor.execute(
          toolName: 'set_task_title',
          args: {'title': ''},
          targetEntityId: targetEntityId,
          resolveCategoryId: (_) async => allowedCategoryId,
          executeHandler: () async => const ToolExecutionResult(
            success: false,
            output: 'Invalid title',
            errorMessage: 'Title must not be empty',
          ),
          readVectorClock: (_) async => null,
        );

        final captured =
            verify(() => mockRepository.upsertEntity(captureAny())).captured;
        expect(captured, hasLength(2));

        final resultMessage = captured[1] as AgentMessageEntity;
        expect(
          resultMessage.metadata.errorMessage,
          equals('Title must not be empty'),
        );
      });
    });

    group('vector clock capture', () {
      test('captures vector clock for successfully mutated entity', () async {
        const postMutationClock = VectorClock({'host-a': 5});

        await executor.execute(
          toolName: 'set_task_title',
          args: {'title': 'New Title'},
          targetEntityId: targetEntityId,
          resolveCategoryId: (_) async => allowedCategoryId,
          executeHandler: () async => const ToolExecutionResult(
            success: true,
            output: 'done',
            mutatedEntityId: targetEntityId,
          ),
          readVectorClock: (id) async {
            expect(id, equals(targetEntityId));
            return postMutationClock;
          },
        );

        expect(executor.mutatedEntries, contains(targetEntityId));
        expect(
          executor.mutatedEntries[targetEntityId],
          equals(postMutationClock),
        );
      });

      test('does not capture when result has no mutatedEntityId', () async {
        await executor.execute(
          toolName: 'set_task_title',
          args: {'title': 'New Title'},
          targetEntityId: targetEntityId,
          resolveCategoryId: (_) async => allowedCategoryId,
          executeHandler: () async => const ToolExecutionResult(
            success: true,
            output: 'done',
          ),
          readVectorClock: (_) async => const VectorClock({'host-a': 5}),
        );

        expect(executor.mutatedEntries, isEmpty);
      });

      test('does not capture when result is not successful', () async {
        await executor.execute(
          toolName: 'set_task_title',
          args: {'title': 'New Title'},
          targetEntityId: targetEntityId,
          resolveCategoryId: (_) async => allowedCategoryId,
          executeHandler: () async => const ToolExecutionResult(
            success: false,
            output: 'failed',
            mutatedEntityId: targetEntityId,
          ),
          readVectorClock: (_) async => const VectorClock({'host-a': 5}),
        );

        expect(executor.mutatedEntries, isEmpty);
      });

      test('does not capture when readVectorClock returns null', () async {
        await executor.execute(
          toolName: 'set_task_title',
          args: {'title': 'New Title'},
          targetEntityId: targetEntityId,
          resolveCategoryId: (_) async => allowedCategoryId,
          executeHandler: () async => const ToolExecutionResult(
            success: true,
            output: 'done',
            mutatedEntityId: targetEntityId,
          ),
          readVectorClock: (_) async => null,
        );

        expect(executor.mutatedEntries, isEmpty);
      });

      test('mutatedEntries is unmodifiable', () {
        expect(
          () => executor.mutatedEntries['x'] = const VectorClock({'a': 1}),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('accumulates entries across multiple executions', () async {
        const clock1 = VectorClock({'host-a': 1});
        const clock2 = VectorClock({'host-a': 2});

        await executor.execute(
          toolName: 'set_task_title',
          args: {'title': 'First'},
          targetEntityId: 'entity-1',
          resolveCategoryId: (_) async => allowedCategoryId,
          executeHandler: () async => const ToolExecutionResult(
            success: true,
            output: 'done',
            mutatedEntityId: 'entity-1',
          ),
          readVectorClock: (_) async => clock1,
        );

        await executor.execute(
          toolName: 'update_task_priority',
          args: {'priority': 'P1'},
          targetEntityId: 'entity-2',
          resolveCategoryId: (_) async => allowedCategoryId,
          executeHandler: () async => const ToolExecutionResult(
            success: true,
            output: 'done',
            mutatedEntityId: 'entity-2',
          ),
          readVectorClock: (_) async => clock2,
        );

        expect(executor.mutatedEntries, hasLength(2));
        expect(executor.mutatedEntries['entity-1'], equals(clock1));
        expect(executor.mutatedEntries['entity-2'], equals(clock2));
      });
    });

    group('error handling', () {
      test('catches exception from handler and returns error result', () async {
        final result = await executor.execute(
          toolName: 'set_task_title',
          args: {'title': 'New Title'},
          targetEntityId: targetEntityId,
          resolveCategoryId: (_) async => allowedCategoryId,
          executeHandler: () async => throw Exception('DB connection lost'),
          readVectorClock: (_) async => null,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('Error'));
        expect(result.errorMessage, contains('DB connection lost'));
        expect(result.policyDenied, isFalse);
      });

      test('persists error result message when handler throws', () async {
        await executor.execute(
          toolName: 'set_task_title',
          args: {'title': 'New Title'},
          targetEntityId: targetEntityId,
          resolveCategoryId: (_) async => allowedCategoryId,
          executeHandler: () async => throw Exception('Crash'),
          readVectorClock: (_) async => null,
        );

        final captured =
            verify(() => mockRepository.upsertEntity(captureAny())).captured;
        // action + toolResult (with error)
        expect(captured, hasLength(2));

        final resultMessage = captured[1] as AgentMessageEntity;
        expect(
          resultMessage.metadata.errorMessage,
          contains('Crash'),
        );
      });
    });

    group('operation ID determinism', () {
      test(
          'two executions with identical tool/args/target produce same '
          'operationId', () async {
        final operationIds = <String>[];

        when(() => mockRepository.upsertEntity(any())).thenAnswer((inv) async {
          final entity = inv.positionalArguments.first as AgentDomainEntity;
          if (entity is AgentMessageEntity &&
              entity.metadata.operationId != null) {
            operationIds.add(entity.metadata.operationId!);
          }
        });

        final args = {'title': 'Same Title'};

        for (var i = 0; i < 2; i++) {
          await executor.execute(
            toolName: 'set_task_title',
            args: args,
            targetEntityId: targetEntityId,
            resolveCategoryId: (_) async => allowedCategoryId,
            executeHandler: () async => const ToolExecutionResult(
              success: true,
              output: 'done',
            ),
            readVectorClock: (_) async => null,
          );
        }

        // 4 messages total: 2 actions + 2 results, all with same opId.
        expect(operationIds, hasLength(4));
        final uniqueIds = operationIds.toSet();
        expect(
          uniqueIds,
          hasLength(1),
          reason: 'Same tool+args+target should produce same operationId',
        );
      });
    });
  });

  group('ToolExecutionResult', () {
    test('defaults policyDenied to false', () {
      const result = ToolExecutionResult(
        success: true,
        output: 'ok',
      );

      expect(result.policyDenied, isFalse);
      expect(result.denialReason, isNull);
      expect(result.mutatedEntityId, isNull);
      expect(result.mutatedVectorClock, isNull);
      expect(result.errorMessage, isNull);
    });

    test('carries all fields when fully populated', () {
      const vc = VectorClock({'host': 1});
      const result = ToolExecutionResult(
        success: false,
        output: 'denied',
        mutatedEntityId: 'ent-1',
        mutatedVectorClock: vc,
        errorMessage: 'err',
        policyDenied: true,
        denialReason: 'not allowed',
      );

      expect(result.success, isFalse);
      expect(result.output, equals('denied'));
      expect(result.mutatedEntityId, equals('ent-1'));
      expect(result.mutatedVectorClock, equals(vc));
      expect(result.errorMessage, equals('err'));
      expect(result.policyDenied, isTrue);
      expect(result.denialReason, equals('not allowed'));
    });
  });
}
