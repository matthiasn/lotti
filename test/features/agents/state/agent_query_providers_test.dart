import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';
import 'agent_providers_test_helpers.dart';

// ── Generators ────────────────────────────────────────────────────────────────

extension _AnyAggregateScenario on glados.Any {
  /// Generates a nullable token count (null meaning "not recorded").
  glados.Generator<int?> get maybeTokenCount =>
      glados.CombinableAny(this).combine2(
        glados.any.bool,
        glados.IntAnys(this).intInRange(0, 5000),
        (bool isNull, int value) => isNull ? null : value,
      );

  /// Generates a short model ID string chosen from a small fixed set so that
  /// records with the same model ID are generated with reasonable frequency.
  glados.Generator<String> get modelId => glados.AnyUtils(this).choose(<String>[
    'models/alpha',
    'models/beta',
    'models/gamma',
  ]);

  /// Generates a [WakeTokenUsageEntity] with a generated model ID and nullable
  /// token fields.
  glados.Generator<WakeTokenUsageEntity> get wakeTokenUsageEntity =>
      glados.CombinableAny(this).combine5(
        glados.any.modelId,
        glados.any.maybeTokenCount,
        glados.any.maybeTokenCount,
        glados.any.maybeTokenCount,
        glados.any.maybeTokenCount,
        (
          String model,
          int? input,
          int? output,
          int? thoughts,
          int? cached,
        ) =>
            AgentDomainEntity.wakeTokenUsage(
                  id: 'id',
                  agentId: 'agent-1',
                  runKey: 'rk-1',
                  threadId: 'thread-1',
                  modelId: model,
                  createdAt: DateTime(2024, 3, 15),
                  vectorClock: null,
                  inputTokens: input,
                  outputTokens: output,
                  thoughtsTokens: thoughts,
                  cachedInputTokens: cached,
                )
                as WakeTokenUsageEntity,
      );

  /// Generates a list of [WakeTokenUsageEntity] records (0–10 elements).
  glados.Generator<List<WakeTokenUsageEntity>> get wakeTokenUsageList =>
      glados.ListAnys(this).listWithLengthInRange(
        0,
        10,
        glados.any.wakeTokenUsageEntity,
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Sums all token-fields across a list of records as an aggregate.
int _sumTotalTokens(Iterable<WakeTokenUsageEntity> records) {
  var total = 0;
  for (final r in records) {
    total +=
        (r.inputTokens ?? 0) + (r.outputTokens ?? 0) + (r.thoughtsTokens ?? 0);
  }
  return total;
}

/// Counts records that belong to [modelId].
int _countForModel(
  Iterable<WakeTokenUsageEntity> records,
  String modelId,
) => records.where((r) => r.modelId == modelId).length;

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('aggregateByModel', () {
    // ── Example-based tests ─────────────────────────────────────────────────

    test('returns empty list for empty input', () {
      expect(aggregateByModel(<WakeTokenUsageEntity>[]), isEmpty);
    });

    test('produces a single entry for a single record', () {
      final record =
          AgentDomainEntity.wakeTokenUsage(
                id: 'u-1',
                agentId: 'a-1',
                runKey: 'rk-1',
                threadId: 'th-1',
                modelId: 'models/flash',
                createdAt: DateTime(2024, 3, 15),
                vectorClock: null,
                inputTokens: 100,
                outputTokens: 60,
                thoughtsTokens: 40,
              )
              as WakeTokenUsageEntity;

      final result = aggregateByModel([record]);

      expect(result, hasLength(1));
      expect(result.first.modelId, 'models/flash');
      expect(result.first.inputTokens, 100);
      expect(result.first.outputTokens, 60);
      expect(result.first.thoughtsTokens, 40);
      expect(result.first.wakeCount, 1);
      // totalTokens = inputTokens + outputTokens + thoughtsTokens = 200
      expect(result.first.totalTokens, 200);
    });

    test('accumulates tokens for the same modelId across two records', () {
      WakeTokenUsageEntity makeRecord(int input, int output) =>
          AgentDomainEntity.wakeTokenUsage(
                id: 'u-$input',
                agentId: 'a-1',
                runKey: 'rk-$input',
                threadId: 'th-1',
                modelId: 'models/pro',
                createdAt: DateTime(2024, 3, 15),
                vectorClock: null,
                inputTokens: input,
                outputTokens: output,
                thoughtsTokens: 0,
              )
              as WakeTokenUsageEntity;

      final result = aggregateByModel([
        makeRecord(100, 50),
        makeRecord(200, 75),
      ]);

      expect(result, hasLength(1));
      expect(result.first.modelId, 'models/pro');
      expect(result.first.inputTokens, 300);
      expect(result.first.outputTokens, 125);
      expect(result.first.wakeCount, 2);
      // totalTokens = 300 + 125 + 0 = 425
      expect(result.first.totalTokens, 425);
    });

    test('produces separate entries for two distinct modelIds', () {
      WakeTokenUsageEntity makeRecord(String modelId, int input) =>
          AgentDomainEntity.wakeTokenUsage(
                id: 'u-$modelId',
                agentId: 'a-1',
                runKey: 'rk-$modelId',
                threadId: 'th-1',
                modelId: modelId,
                createdAt: DateTime(2024, 3, 15),
                vectorClock: null,
                inputTokens: input,
                outputTokens: 0,
                thoughtsTokens: 0,
              )
              as WakeTokenUsageEntity;

      final result = aggregateByModel([
        makeRecord('models/alpha', 300),
        makeRecord('models/beta', 100),
      ]);

      expect(result, hasLength(2));
      // Sorted descending by totalTokens → alpha first.
      expect(result.first.modelId, 'models/alpha');
      expect(result.first.totalTokens, 300);
      expect(result.last.modelId, 'models/beta');
      expect(result.last.totalTokens, 100);
    });

    test('null token fields are treated as 0', () {
      final record =
          AgentDomainEntity.wakeTokenUsage(
                id: 'u-null',
                agentId: 'a-1',
                runKey: 'rk-1',
                threadId: 'th-1',
                modelId: 'models/tiny',
                createdAt: DateTime(2024, 3, 15),
                vectorClock: null,
                // All token fields deliberately null.
              )
              as WakeTokenUsageEntity;

      final result = aggregateByModel([record]);

      expect(result, hasLength(1));
      expect(result.first.inputTokens, 0);
      expect(result.first.outputTokens, 0);
      expect(result.first.thoughtsTokens, 0);
      expect(result.first.totalTokens, 0);
      expect(result.first.wakeCount, 1);
    });

    test('result is sorted descending by totalTokens', () {
      WakeTokenUsageEntity makeRecord(String modelId, int tokens) =>
          AgentDomainEntity.wakeTokenUsage(
                id: 'u-$modelId',
                agentId: 'a-1',
                runKey: 'rk-$modelId',
                threadId: 'th-1',
                modelId: modelId,
                createdAt: DateTime(2024, 3, 15),
                vectorClock: null,
                inputTokens: tokens,
                outputTokens: 0,
                thoughtsTokens: 0,
              )
              as WakeTokenUsageEntity;

      final result = aggregateByModel([
        makeRecord('m-low', 50),
        makeRecord('m-high', 500),
        makeRecord('m-mid', 200),
      ]);

      expect(result, hasLength(3));
      expect(result[0].totalTokens, 500);
      expect(result[1].totalTokens, 200);
      expect(result[2].totalTokens, 50);
    });

    test('wakeCount equals the number of records for a modelId', () {
      final records = List.generate(
        5,
        (i) =>
            AgentDomainEntity.wakeTokenUsage(
                  id: 'u-$i',
                  agentId: 'a-1',
                  runKey: 'rk-$i',
                  threadId: 'th-1',
                  modelId: 'models/only',
                  createdAt: DateTime(2024, 3, 15),
                  vectorClock: null,
                  inputTokens: 10,
                )
                as WakeTokenUsageEntity,
      );

      final result = aggregateByModel(records);

      expect(result, hasLength(1));
      expect(result.first.wakeCount, 5);
    });

    // ── Property tests ──────────────────────────────────────────────────────

    glados.Glados(
      glados.any.wakeTokenUsageList,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'total tokens across all summaries equals total tokens in records',
      (records) {
        final result = aggregateByModel(records);
        final sumBefore = _sumTotalTokens(records);
        final sumAfter = result.fold<int>(0, (s, r) => s + r.totalTokens);
        expect(
          sumAfter,
          sumBefore,
          reason:
              'aggregated total differs from record total; records=$records',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.wakeTokenUsageList,
      glados.ExploreConfig(numRuns: 120),
    ).test('result is sorted descending by totalTokens', (records) {
      final result = aggregateByModel(records);
      for (var i = 0; i < result.length - 1; i++) {
        expect(
          result[i].totalTokens,
          greaterThanOrEqualTo(result[i + 1].totalTokens),
          reason:
              'result[$i].totalTokens=${result[i].totalTokens} < '
              'result[${i + 1}].totalTokens=${result[i + 1].totalTokens}',
        );
      }
    }, tags: 'glados');

    glados.Glados(
      glados.any.wakeTokenUsageList,
      glados.ExploreConfig(numRuns: 120),
    ).test('output contains at most one entry per modelId', (records) {
      final result = aggregateByModel(records);
      final modelIds = result.map((r) => r.modelId).toList();
      final uniqueModelIds = modelIds.toSet();
      expect(
        modelIds.length,
        uniqueModelIds.length,
        reason: 'Duplicate modelId entries in result; modelIds=$modelIds',
      );
    }, tags: 'glados');

    glados.Glados(
      glados.any.wakeTokenUsageList,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'wakeCount for each modelId equals record count for that model',
      (records) {
        final result = aggregateByModel(records);
        for (final summary in result) {
          final expected = _countForModel(records, summary.modelId);
          expect(
            summary.wakeCount,
            expected,
            reason:
                'modelId=${summary.modelId}: '
                'wakeCount=${summary.wakeCount} != expected=$expected',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.wakeTokenUsageList,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'output length does not exceed the number of distinct modelIds',
      (records) {
        final result = aggregateByModel(records);
        final distinctModels = records.map((r) => r.modelId).toSet().length;
        expect(
          result.length,
          lessThanOrEqualTo(distinctModels),
          reason: 'output has more entries than distinct models',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.wakeTokenUsageList,
      glados.ExploreConfig(numRuns: 120),
    ).test('every AgentTokenUsageSummary has non-negative token fields', (
      records,
    ) {
      final result = aggregateByModel(records);
      for (final summary in result) {
        expect(
          summary.inputTokens,
          greaterThanOrEqualTo(0),
          reason: 'modelId=${summary.modelId} has negative inputTokens',
        );
        expect(
          summary.outputTokens,
          greaterThanOrEqualTo(0),
          reason: 'modelId=${summary.modelId} has negative outputTokens',
        );
        expect(
          summary.thoughtsTokens,
          greaterThanOrEqualTo(0),
          reason: 'modelId=${summary.modelId} has negative thoughtsTokens',
        );
        expect(
          summary.wakeCount,
          greaterThanOrEqualTo(0),
          reason: 'modelId=${summary.modelId} has negative wakeCount',
        );
      }
    }, tags: 'glados');
  });

  // ── Provider wiring tests moved from agent_providers_test.dart so this
  // file is the single mirror of its source (one-test-file-per-source). ──
  group('provider wiring', () {
    late MockAgentService mockService;
    late MockAgentRepository mockRepository;
    late MockAiConfigRepository mockAiConfigRepo;

    setUpAll(() {
      registerAllFallbackValues();
      registerFallbackValue(const Stream<Set<String>>.empty());
    });

    setUp(() {
      mockService = MockAgentService();
      mockRepository = MockAgentRepository();
      mockAiConfigRepo = MockAiConfigRepository();
    });

    /// Helper to create a [ProviderContainer] with common mocks overridden.
    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    group('agentRecentMessagesProvider', () {
      test('returns messages in DB order (newest-first)', () async {
        // The DB query sorts by created_at DESC, so the mock returns
        // them in that order already.
        final msg2 = makeTestMessage(
          id: 'msg-2',
          createdAt: DateTime(2024, 3, 15, 12),
        );
        final msg3 = makeTestMessage(
          id: 'msg-3',
          createdAt: DateTime(2024, 3, 15, 11),
        );
        final msg1 = makeTestMessage(
          id: 'msg-1',
          createdAt: DateTime(2024, 3, 15, 10),
        );

        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 50,
          ),
        ).thenAnswer((_) async => [msg2, msg3, msg1]);

        final container = createContainer();
        final result = await container.read(
          agentRecentMessagesProvider(kTestAgentId).future,
        );

        expect(result, hasLength(3));
        expect((result[0] as AgentMessageEntity).id, 'msg-2');
        expect((result[1] as AgentMessageEntity).id, 'msg-3');
        expect((result[2] as AgentMessageEntity).id, 'msg-1');
      });

      test('passes limit=50 to repository', () async {
        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 50,
          ),
        ).thenAnswer((_) async => []);

        final container = createContainer();
        await container.read(agentRecentMessagesProvider(kTestAgentId).future);

        verify(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 50,
          ),
        ).called(1);
      });

      test('returns empty list when no messages exist', () async {
        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 50,
          ),
        ).thenAnswer((_) async => []);

        final container = createContainer();
        final result = await container.read(
          agentRecentMessagesProvider(kTestAgentId).future,
        );

        expect(result, isEmpty);
      });

      test('filters out non-AgentMessageEntity types', () async {
        final msg = makeTestMessage(id: 'msg-1');
        final report = makeTestReport(id: 'report-1');
        final state = makeTestState(id: 'state-1');

        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 50,
          ),
        ).thenAnswer((_) async => [msg, report, state]);

        final container = createContainer();
        final result = await container.read(
          agentRecentMessagesProvider(kTestAgentId).future,
        );

        expect(result, hasLength(1));
        expect((result[0] as AgentMessageEntity).id, 'msg-1');
      });
    });

    group('agentMessagePayloadTextProvider', () {
      test('returns text from payload content', () async {
        const payloadId = 'payload-1';
        final payloadEntity = AgentDomainEntity.agentMessagePayload(
          id: payloadId,
          agentId: kTestAgentId,
          createdAt: DateTime(2024, 3, 15),
          vectorClock: null,
          content: const {'text': 'hello world'},
        );

        when(
          () => mockRepository.getEntity(payloadId),
        ).thenAnswer((_) async => payloadEntity);

        final container = createContainer();
        final result = await container.read(
          agentMessagePayloadTextProvider(payloadId).future,
        );

        expect(result, 'hello world');
        verify(() => mockRepository.getEntity(payloadId)).called(1);
      });

      test('reconstructs a v2 prompt record from the event log', () async {
        const payloadId = 'payload-v2';
        const tailContent = {'entryType': 'text', 'text': 'captured note'};
        final tailDigest = ContentDigest.of(tailContent);
        final link = makeTestMessagePayloadLink(
          id: 'pl-1',
          createdAt: DateTime(2024, 3, 10),
          toId: tailDigest,
          contentEntryId: 'e1',
          sourceCreatedAt: DateTime(2024, 3, 9),
        );
        final payloadEntity = AgentDomainEntity.agentMessagePayload(
          id: payloadId,
          agentId: kTestAgentId,
          createdAt: DateTime(2024, 3, 15),
          vectorClock: null,
          content: <String, Object?>{
            'promptFormat': 'v2',
            'head': 'HEAD\n## Task Log\n',
            'tail': '\n\nTAIL',
            'log': <String, Object?>{
              'until': <String, Object?>{
                'at': link.createdAt.toIso8601String(),
                'sourceAt': DateTime(2024, 3, 9).toIso8601String(),
                'key': 'e1|pl-1',
              },
            },
          },
        );

        when(
          () => mockRepository.getEntity(payloadId),
        ).thenAnswer((_) async => payloadEntity);
        when(
          () => mockRepository.getMessagesByKind(kTestAgentId, any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockRepository.getLinksFrom(
            kTestAgentId,
            type: any(named: 'type'),
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockRepository.getLinksFrom(kTestAgentId),
        ).thenAnswer((_) async => [link]);
        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: any(named: 'type'),
          ),
        ).thenAnswer((_) async => []);
        when(() => mockRepository.getEntity(tailDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: tailDigest,
            agentId: 'shared-input-content',
            createdAt: DateTime(2024, 3, 10),
            vectorClock: null,
            content: tailContent,
          ),
        );

        // The reconstructor reads through the sync service's repository.
        final outbox = MockOutboxService();
        when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
        final vc = MockVectorClockService();
        final container = ProviderContainer(
          overrides: [
            agentServiceProvider.overrideWithValue(mockService),
            agentRepositoryProvider.overrideWithValue(mockRepository),
            aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
            agentSyncServiceProvider.overrideWithValue(
              AgentSyncService(
                repository: mockRepository,
                outboxService: outbox,
                vectorClockService: vc,
              ),
            ),
            domainLoggerProvider.overrideWithValue(
              DomainLogger(loggingService: LoggingService()),
            ),
          ],
        );
        addTearDown(container.dispose);
        final result = await container.read(
          agentMessagePayloadTextProvider(payloadId).future,
        );

        // head + re-derived log + tail.
        expect(result, startsWith('HEAD\n## Task Log\n### Recent entries'));
        expect(result, contains('(id: e1, text) captured note'));
        expect(result, endsWith('\n\nTAIL'));
      });

      test('returns null when entity is not found', () async {
        const payloadId = 'nonexistent';

        when(
          () => mockRepository.getEntity(payloadId),
        ).thenAnswer((_) async => null);

        final container = createContainer();
        final result = await container.read(
          agentMessagePayloadTextProvider(payloadId).future,
        );

        expect(result, isNull);
      });

      test('returns null when entity is not a payload type', () async {
        const payloadId = 'not-a-payload';
        final identity = makeTestIdentity(id: payloadId);

        when(
          () => mockRepository.getEntity(payloadId),
        ).thenAnswer((_) async => identity);

        final container = createContainer();
        final result = await container.read(
          agentMessagePayloadTextProvider(payloadId).future,
        );

        expect(result, isNull);
      });

      test('returns null when payload text is empty', () async {
        const payloadId = 'payload-empty';
        final payloadEntity = AgentDomainEntity.agentMessagePayload(
          id: payloadId,
          agentId: kTestAgentId,
          createdAt: DateTime(2024, 3, 15),
          vectorClock: null,
          content: const {'text': ''},
        );

        when(
          () => mockRepository.getEntity(payloadId),
        ).thenAnswer((_) async => payloadEntity);

        final container = createContainer();
        final result = await container.read(
          agentMessagePayloadTextProvider(payloadId).future,
        );

        expect(result, isNull);
      });

      test('returns null when payload has no text key', () async {
        const payloadId = 'payload-no-text';
        final payloadEntity = AgentDomainEntity.agentMessagePayload(
          id: payloadId,
          agentId: kTestAgentId,
          createdAt: DateTime(2024, 3, 15),
          vectorClock: null,
          content: const {'other': 'data'},
        );

        when(
          () => mockRepository.getEntity(payloadId),
        ).thenAnswer((_) async => payloadEntity);

        final container = createContainer();
        final result = await container.read(
          agentMessagePayloadTextProvider(payloadId).future,
        );

        expect(result, isNull);
      });

      test('returns null when payload text is not a String', () async {
        const payloadId = 'payload-int-text';
        final payloadEntity = AgentDomainEntity.agentMessagePayload(
          id: payloadId,
          agentId: kTestAgentId,
          createdAt: DateTime(2024, 3, 15),
          vectorClock: null,
          content: const {'text': 42},
        );

        when(
          () => mockRepository.getEntity(payloadId),
        ).thenAnswer((_) async => payloadEntity);

        final container = createContainer();
        final result = await container.read(
          agentMessagePayloadTextProvider(payloadId).future,
        );

        expect(result, isNull);
      });
    });

    group('agentMessagesByThreadProvider', () {
      test('groups messages by threadId', () async {
        final msg1 = makeTestMessage(
          id: 'msg-1',
          threadId: 'thread-a',
          createdAt: DateTime(2024, 3, 15, 10),
        );
        final msg2 = makeTestMessage(
          id: 'msg-2',
          threadId: 'thread-b',
          createdAt: DateTime(2024, 3, 15, 11),
        );
        final msg3 = makeTestMessage(
          id: 'msg-3',
          threadId: 'thread-a',
          createdAt: DateTime(2024, 3, 15, 12),
        );

        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 200,
          ),
        ).thenAnswer((_) async => [msg1, msg2, msg3]);

        final container = createContainer();
        final result = await container.read(
          agentMessagesByThreadProvider(kTestAgentId).future,
        );

        expect(result, hasLength(2));
        expect(result['thread-a'], hasLength(2));
        expect(result['thread-b'], hasLength(1));
      });

      test('sorts messages within each thread chronologically', () async {
        final msg1 = makeTestMessage(
          id: 'msg-1',
          threadId: 'thread-a',
          createdAt: DateTime(2024, 3, 15, 12),
        );
        final msg2 = makeTestMessage(
          id: 'msg-2',
          threadId: 'thread-a',
          createdAt: DateTime(2024, 3, 15, 10),
        );
        final msg3 = makeTestMessage(
          id: 'msg-3',
          threadId: 'thread-a',
          createdAt: DateTime(2024, 3, 15, 11),
        );

        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 200,
          ),
        ).thenAnswer((_) async => [msg1, msg2, msg3]);

        final container = createContainer();
        final result = await container.read(
          agentMessagesByThreadProvider(kTestAgentId).future,
        );

        final thread = result['thread-a']!;
        expect((thread[0] as AgentMessageEntity).id, 'msg-2');
        expect((thread[1] as AgentMessageEntity).id, 'msg-3');
        expect((thread[2] as AgentMessageEntity).id, 'msg-1');
      });

      test('breaks the shared wake timestamp by conversation order: system '
          'prompt first, bookkeeping last', () async {
        // A wake persists several rows with ONE shared timestamp (causality).
        // Without a conversation-order tiebreak the wake-completed milestone
        // (kind system, no content) rendered above the agent's output, looking
        // like a late-arriving system prompt.
        final wakeAt = DateTime(2024, 3, 15, 10);
        final milestone = makeTestMessage(
          id: 'msg-milestone',
          threadId: 'thread-a',
          kind: AgentMessageKind.system,
          createdAt: wakeAt,
          metadata: const AgentMessageMetadata(
            milestone: AgentMilestone.wakeCompleted,
          ),
        );
        final observation = makeTestMessage(
          id: 'msg-observation',
          threadId: 'thread-a',
          kind: AgentMessageKind.observation,
          createdAt: wakeAt,
        );
        final user = makeTestMessage(
          id: 'msg-user',
          threadId: 'thread-a',
          kind: AgentMessageKind.user,
          createdAt: wakeAt,
        );
        final systemPrompt = makeTestMessage(
          id: 'msg-prompt',
          threadId: 'thread-a',
          kind: AgentMessageKind.system,
          createdAt: wakeAt,
          contentEntryId: 'sha256-v1:prompt',
        );
        // A later-timestamped action must still sort strictly after.
        final action = makeTestMessage(
          id: 'msg-action',
          threadId: 'thread-a',
          kind: AgentMessageKind.action,
          createdAt: wakeAt.add(const Duration(seconds: 5)),
        );

        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 200,
          ),
        ).thenAnswer(
          (_) async => [milestone, observation, user, systemPrompt, action],
        );

        final container = createContainer();
        final result = await container.read(
          agentMessagesByThreadProvider(kTestAgentId).future,
        );

        expect(
          [
            for (final m in result['thread-a']!) (m as AgentMessageEntity).id,
          ],
          [
            'msg-prompt',
            'msg-user',
            'msg-observation',
            'msg-milestone',
            'msg-action',
          ],
        );
      });

      test('breaks same-time same-kind ties deterministically by id', () async {
        final wakeAt = DateTime(2024, 3, 15, 10);
        final obsB = makeTestMessage(
          id: 'obs-b',
          threadId: 'thread-a',
          kind: AgentMessageKind.observation,
          createdAt: wakeAt,
        );
        final obsA = makeTestMessage(
          id: 'obs-a',
          threadId: 'thread-a',
          kind: AgentMessageKind.observation,
          createdAt: wakeAt,
        );

        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 200,
          ),
        ).thenAnswer((_) async => [obsB, obsA]);

        final container = createContainer();
        final result = await container.read(
          agentMessagesByThreadProvider(kTestAgentId).future,
        );

        expect(
          [for (final m in result['thread-a']!) (m as AgentMessageEntity).id],
          ['obs-a', 'obs-b'],
        );
      });

      test('returns empty map when no messages exist', () async {
        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 200,
          ),
        ).thenAnswer((_) async => []);

        final container = createContainer();
        final result = await container.read(
          agentMessagesByThreadProvider(kTestAgentId).future,
        );

        expect(result, isEmpty);
      });

      test('filters out non-AgentMessageEntity types', () async {
        final msg = makeTestMessage(id: 'msg-1', threadId: 'thread-a');
        final report = makeTestReport(id: 'report-1');

        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 200,
          ),
        ).thenAnswer((_) async => [msg, report]);

        final container = createContainer();
        final result = await container.read(
          agentMessagesByThreadProvider(kTestAgentId).future,
        );

        expect(result, hasLength(1));
        expect(result['thread-a'], hasLength(1));
      });

      test('passes limit=200 to repository', () async {
        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 200,
          ),
        ).thenAnswer((_) async => []);

        final container = createContainer();
        await container.read(
          agentMessagesByThreadProvider(kTestAgentId).future,
        );

        verify(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 200,
          ),
        ).called(1);
      });

      test('sorts threads most-recent-first by latest message', () async {
        // thread-a: latest message at 10:00
        // thread-b: latest message at 14:00
        // thread-c: latest message at 12:00
        final messages = [
          makeTestMessage(
            id: 'a1',
            threadId: 'thread-a',
            createdAt: DateTime(2024, 3, 15, 10),
          ),
          makeTestMessage(
            id: 'b1',
            threadId: 'thread-b',
            createdAt: DateTime(2024, 3, 15, 14),
          ),
          makeTestMessage(
            id: 'c1',
            threadId: 'thread-c',
            createdAt: DateTime(2024, 3, 15, 12),
          ),
        ];

        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 200,
          ),
        ).thenAnswer((_) async => messages);

        final container = createContainer();
        final result = await container.read(
          agentMessagesByThreadProvider(kTestAgentId).future,
        );

        final threadIds = result.keys.toList();
        expect(threadIds, ['thread-b', 'thread-c', 'thread-a']);
      });
    });

    group('agentObservationMessagesProvider', () {
      test('returns only observation messages', () async {
        final obs = makeTestMessage(
          id: 'obs-1',
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2024, 3, 15, 10),
        );
        final thought = makeTestMessage(
          id: 'thought-1',
          createdAt: DateTime(2024, 3, 15, 11),
        );
        final action = makeTestMessage(
          id: 'action-1',
          kind: AgentMessageKind.action,
          createdAt: DateTime(2024, 3, 15, 12),
        );
        final obs2 = makeTestMessage(
          id: 'obs-2',
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2024, 3, 15, 13),
        );

        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 200,
          ),
        ).thenAnswer((_) async => [obs, thought, action, obs2]);

        final container = createContainer();
        final result = await container.read(
          agentObservationMessagesProvider(kTestAgentId).future,
        );

        expect(result, hasLength(2));
        expect((result[0] as AgentMessageEntity).id, 'obs-1');
        expect((result[1] as AgentMessageEntity).id, 'obs-2');
      });

      test('returns empty list when no observations exist', () async {
        final thought = makeTestMessage(
          id: 'thought-1',
          createdAt: DateTime(2024, 3, 15, 10),
        );

        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 200,
          ),
        ).thenAnswer((_) async => [thought]);

        final container = createContainer();
        final result = await container.read(
          agentObservationMessagesProvider(kTestAgentId).future,
        );

        expect(result, isEmpty);
      });

      test('returns empty list when no messages exist at all', () async {
        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 200,
          ),
        ).thenAnswer((_) async => []);

        final container = createContainer();
        final result = await container.read(
          agentObservationMessagesProvider(kTestAgentId).future,
        );

        expect(result, isEmpty);
      });

      test('filters out non-AgentMessageEntity types', () async {
        final obs = makeTestMessage(
          id: 'obs-1',
          kind: AgentMessageKind.observation,
        );
        final report = makeTestReport(id: 'report-1');

        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: 200,
          ),
        ).thenAnswer((_) async => [obs, report]);

        final container = createContainer();
        final result = await container.read(
          agentObservationMessagesProvider(kTestAgentId).future,
        );

        expect(result, hasLength(1));
        expect((result[0] as AgentMessageEntity).id, 'obs-1');
      });
    });

    group('agentReportHistoryProvider', () {
      test('returns report entities ordered most-recent-first', () async {
        final report1 = makeTestReport(
          id: 'report-1',
          content: 'First report',
        );
        final report2 = makeTestReport(
          id: 'report-2',
          content: 'Second report',
        );

        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentReport',
            limit: 50,
          ),
        ).thenAnswer((_) async => [report2, report1]);

        final container = createContainer();
        final result = await container.read(
          agentReportHistoryProvider(kTestAgentId).future,
        );

        expect(result, hasLength(2));
        expect((result[0] as AgentReportEntity).id, 'report-2');
        expect((result[1] as AgentReportEntity).id, 'report-1');
      });

      test('returns empty list when no reports exist', () async {
        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentReport',
            limit: 50,
          ),
        ).thenAnswer((_) async => []);

        final container = createContainer();
        final result = await container.read(
          agentReportHistoryProvider(kTestAgentId).future,
        );

        expect(result, isEmpty);
      });

      test('filters out non-AgentReportEntity types', () async {
        final report = makeTestReport(id: 'report-1');
        final msg = makeTestMessage(id: 'msg-1', threadId: 'thread-a');

        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentReport',
            limit: 50,
          ),
        ).thenAnswer((_) async => [report, msg]);

        final container = createContainer();
        final result = await container.read(
          agentReportHistoryProvider(kTestAgentId).future,
        );

        expect(result, hasLength(1));
        expect((result[0] as AgentReportEntity).id, 'report-1');
      });

      test('passes limit=50 and type=agentReport to repository', () async {
        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentReport',
            limit: 50,
          ),
        ).thenAnswer((_) async => []);

        final container = createContainer();
        await container.read(agentReportHistoryProvider(kTestAgentId).future);

        verify(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentReport',
            limit: 50,
          ),
        ).called(1);
      });
    });

    group('agentIsRunningProvider', () {
      test('yields initial false when agent is not running', () async {
        final runner = WakeRunner();
        addTearDown(runner.dispose);

        final container = ProviderContainer(
          overrides: [
            wakeRunnerProvider.overrideWithValue(runner),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(
          agentIsRunningProvider(kTestAgentId),
          (_, _) {},
        );
        addTearDown(sub.close);

        // Let the stream provider initialize.
        await pumpEventQueue();

        final value = container.read(agentIsRunningProvider(kTestAgentId));
        expect(value.value, isFalse);
      });

      test('yields true after agent acquires lock', () async {
        final runner = WakeRunner();
        addTearDown(runner.dispose);

        final container = ProviderContainer(
          overrides: [
            wakeRunnerProvider.overrideWithValue(runner),
          ],
        );
        addTearDown(container.dispose);

        final values = <bool>[];
        final sub = container.listen(
          agentIsRunningProvider(kTestAgentId),
          (_, next) {
            if (next.hasValue) values.add(next.value!);
          },
        );
        addTearDown(sub.close);

        await pumpEventQueue();

        await runner.tryAcquire(kTestAgentId);
        await pumpEventQueue();

        final value = container.read(agentIsRunningProvider(kTestAgentId));
        expect(value.value, isTrue);
      });

      test('yields false again after agent is released', () async {
        final runner = WakeRunner();
        addTearDown(runner.dispose);

        final container = ProviderContainer(
          overrides: [
            wakeRunnerProvider.overrideWithValue(runner),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(
          agentIsRunningProvider(kTestAgentId),
          (_, _) {},
        );
        addTearDown(sub.close);

        await pumpEventQueue();

        await runner.tryAcquire(kTestAgentId);
        await pumpEventQueue();
        expect(
          container.read(agentIsRunningProvider(kTestAgentId)).value,
          isTrue,
        );

        runner.release(kTestAgentId);
        await pumpEventQueue();
        expect(
          container.read(agentIsRunningProvider(kTestAgentId)).value,
          isFalse,
        );
      });

      test('yields initial true when agent is already running', () async {
        final runner = WakeRunner();
        addTearDown(runner.dispose);

        // Acquire lock before creating the provider.
        await runner.tryAcquire(kTestAgentId);

        final container = ProviderContainer(
          overrides: [
            wakeRunnerProvider.overrideWithValue(runner),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(
          agentIsRunningProvider(kTestAgentId),
          (_, _) {},
        );
        addTearDown(sub.close);

        await pumpEventQueue();

        final value = container.read(agentIsRunningProvider(kTestAgentId));
        expect(value.value, isTrue);

        runner.release(kTestAgentId);
      });
    });

    group('agentUpdateStreamProvider', () {
      test(
        'emits when UpdateNotifications fires with matching agent ID',
        () async {
          final setup = await setUpUpdateStreamTest();

          final values = <AsyncValue<Set<String>>>[];
          final sub = setup.container.listen(
            agentUpdateStreamProvider(kTestAgentId),
            (_, next) => values.add(next),
          );
          addTearDown(sub.close);

          await pumpEventQueue();

          // Fire notification with matching agent ID.
          setup.controller.add({kTestAgentId, 'other-id'});
          await pumpEventQueue();

          expect(values, isNotEmpty);
        },
      );

      test('does NOT emit for unrelated agent IDs', () async {
        final setup = await setUpUpdateStreamTest();

        final values = <AsyncValue<Set<String>>>[];
        final sub = setup.container.listen(
          agentUpdateStreamProvider(kTestAgentId),
          (_, next) => values.add(next),
        );
        addTearDown(sub.close);

        await pumpEventQueue();
        values.clear();

        // Fire notification with a DIFFERENT agent ID.
        setup.controller.add({'different-agent-id'});
        await pumpEventQueue();

        expect(values, isEmpty);
      });

      test('multiple emissions each trigger a new notification', () async {
        final setup = await setUpUpdateStreamTest();

        final values = <AsyncValue<Set<String>>>[];
        final sub = setup.container.listen(
          agentUpdateStreamProvider(kTestAgentId),
          (_, next) => values.add(next),
        );
        addTearDown(sub.close);

        await pumpEventQueue();
        values.clear();

        // Fire three successive notifications — each must produce a
        // distinct AsyncData because we pass through Set<String> (identity
        // distinct) rather than void (which Riverpod would deduplicate).
        setup.controller.add({kTestAgentId});
        await pumpEventQueue();
        setup.controller.add({kTestAgentId});
        await pumpEventQueue();
        setup.controller.add({kTestAgentId});
        await pumpEventQueue();

        expect(values, hasLength(3));
      });
    });

    group('allAgentInstancesProvider', () {
      test('delegates to listAgents and casts result', () async {
        final agents = [makeTestIdentity(id: 'a1', agentId: 'a1')];
        when(() => mockService.listAgents()).thenAnswer((_) async => agents);

        final container = createContainer();
        final result = await container.read(allAgentInstancesProvider.future);

        expect(result, hasLength(1));
        expect((result[0] as AgentIdentityEntity).id, 'a1');
        verify(() => mockService.listAgents()).called(1);
      });

      test('returns empty list when no agents exist', () async {
        when(() => mockService.listAgents()).thenAnswer((_) async => []);

        final container = createContainer();
        final result = await container.read(allAgentInstancesProvider.future);

        expect(result, isEmpty);
      });
    });

    group('modelIdForThreadProvider', () {
      /// Stub common defaults so tests only need to override what they vary.
      void stubDefaults() {
        when(
          () => mockRepository.getTokenUsageForAgent(
            any(),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => <WakeTokenUsageEntity>[]);
        when(
          () => mockRepository.getWakeRunByThreadId(any(), any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockRepository.getEntity(kTestAgentId),
        ).thenAnswer((_) async => null);
      }

      test('tier 1: returns model ID from token usage record', () async {
        when(
          () => mockRepository.getTokenUsageForAgent(
            any(),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            WakeTokenUsageEntity(
              id: 'usage-1',
              agentId: kTestAgentId,
              runKey: 'run-1',
              threadId: 'thread-abc',
              modelId: 'qwen3:8b',
              createdAt: DateTime(2024, 3, 15),
              vectorClock: null,
            ),
          ],
        );

        final container = createContainer();
        final result = await container.read(
          modelIdForThreadProvider(kTestAgentId, 'thread-abc').future,
        );

        expect(result, 'qwen3:8b');
      });

      test('tier 2: returns resolvedModelId from wake run', () async {
        stubDefaults();

        final wakeRun = makeTestWakeRun(
          threadId: 'thread-abc',
          resolvedModelId: 'qwen3.5:9b',
          templateVersionId: 'ver-1',
        );
        when(
          () => mockRepository.getWakeRunByThreadId(kTestAgentId, 'thread-abc'),
        ).thenAnswer((_) async => wakeRun);
        when(
          () => mockRepository.getEntity('ver-1'),
        ).thenAnswer(
          (_) async => makeTestTemplateVersion(
            id: 'ver-1',
            modelId: 'models/gemini-3-pro',
          ),
        );

        final container = createContainer();
        final result = await container.read(
          modelIdForThreadProvider(kTestAgentId, 'thread-abc').future,
        );

        expect(result, 'qwen3.5:9b');
      });

      test('tier 3: falls back to wake-run template version profile', () async {
        stubDefaults();

        final wakeRun = makeTestWakeRun(
          threadId: 'thread-abc',
          templateVersionId: 'ver-1',
        );
        when(
          () => mockRepository.getWakeRunByThreadId(kTestAgentId, 'thread-abc'),
        ).thenAnswer((_) async => wakeRun);

        final version = makeTestTemplateVersion(
          id: 'ver-1',
          profileId: 'profile-1',
        );
        when(
          () => mockRepository.getEntity('ver-1'),
        ).thenAnswer((_) async => version);
        when(
          () => mockAiConfigRepo.getConfigById('profile-1'),
        ).thenAnswer(
          (_) async => AiConfig.inferenceProfile(
            id: 'profile-1',
            name: 'Local Ollama',
            thinkingModelId: 'qwen3.5:9b',
            createdAt: DateTime(2024, 3, 15),
          ),
        );

        final container = createContainer();
        final result = await container.read(
          modelIdForThreadProvider(kTestAgentId, 'thread-abc').future,
        );

        expect(result, 'qwen3.5:9b');
      });

      test('tier 3: falls back to wake-run template version modelId', () async {
        stubDefaults();

        final wakeRun = makeTestWakeRun(
          threadId: 'thread-abc',
          templateVersionId: 'ver-1',
        );
        when(
          () => mockRepository.getWakeRunByThreadId(kTestAgentId, 'thread-abc'),
        ).thenAnswer((_) async => wakeRun);

        final version = makeTestTemplateVersion(
          id: 'ver-1',
          modelId: 'models/gemini-3-pro',
        );
        when(
          () => mockRepository.getEntity('ver-1'),
        ).thenAnswer((_) async => version);

        final container = createContainer();
        final result = await container.read(
          modelIdForThreadProvider(kTestAgentId, 'thread-abc').future,
        );

        expect(result, 'models/gemini-3-pro');
      });

      test('tier 4: falls back to live agent config profile', () async {
        stubDefaults();

        final agent = makeTestIdentity(
          config: const AgentConfig(profileId: 'profile-1'),
        );
        when(
          () => mockRepository.getEntity(kTestAgentId),
        ).thenAnswer((_) async => agent);
        when(
          () => mockAiConfigRepo.getConfigById('profile-1'),
        ).thenAnswer(
          (_) async => AiConfig.inferenceProfile(
            id: 'profile-1',
            name: 'Local Ollama',
            thinkingModelId: 'qwen3.5:9b',
            createdAt: DateTime(2024, 3, 15),
          ),
        );

        final container = createContainer();
        final result = await container.read(
          modelIdForThreadProvider(kTestAgentId, 'thread-abc').future,
        );

        expect(result, 'qwen3.5:9b');
      });

      test('tier 4: falls back to live agent config modelId', () async {
        stubDefaults();

        final agent = makeTestIdentity(
          config: const AgentConfig(modelId: 'models/gemini-3-pro'),
        );
        when(
          () => mockRepository.getEntity(kTestAgentId),
        ).thenAnswer((_) async => agent);

        final container = createContainer();
        final result = await container.read(
          modelIdForThreadProvider(kTestAgentId, 'thread-abc').future,
        );

        expect(result, 'models/gemini-3-pro');
      });

      test('returns null when nothing resolves', () async {
        stubDefaults();

        final container = createContainer();
        final result = await container.read(
          modelIdForThreadProvider(kTestAgentId, 'missing').future,
        );

        expect(result, isNull);
      });
    });

    group('agentTokenUsageSummariesProvider', () {
      const agentId = kTestAgentId;

      test('returns empty list when no records', () async {
        final container = createAgentTokenContainer(
          agentId: agentId,
          records: [],
        );
        final result = await container.read(
          agentTokenUsageSummariesProvider(agentId).future,
        );
        expect(result, isEmpty);
      });

      test('aggregates records by model', () async {
        final now = DateTime(2025, 6, 15);
        final container = createAgentTokenContainer(
          agentId: agentId,
          records: [
            WakeTokenUsageEntity(
              id: 'u1',
              agentId: agentId,
              runKey: 'run-1',
              threadId: 't1',
              modelId: 'gemini-2.5-pro',
              createdAt: now,
              vectorClock: null,
              inputTokens: 100,
              outputTokens: 50,
              thoughtsTokens: 20,
              cachedInputTokens: 10,
            ),
            WakeTokenUsageEntity(
              id: 'u2',
              agentId: agentId,
              runKey: 'run-2',
              threadId: 't1',
              modelId: 'gemini-2.5-pro',
              createdAt: now,
              vectorClock: null,
              inputTokens: 200,
              outputTokens: 80,
              thoughtsTokens: 30,
              cachedInputTokens: 5,
            ),
            WakeTokenUsageEntity(
              id: 'u3',
              agentId: agentId,
              runKey: 'run-3',
              threadId: 't2',
              modelId: 'claude-sonnet',
              createdAt: now,
              vectorClock: null,
              inputTokens: 500,
              outputTokens: 100,
            ),
          ],
        );

        final result = await container.read(
          agentTokenUsageSummariesProvider(agentId).future,
        );

        expect(result, hasLength(2));

        // Sorted by totalTokens descending: claude-sonnet (600) > gemini (480)
        expect(result[0].modelId, 'claude-sonnet');
        expect(result[0].inputTokens, 500);
        expect(result[0].outputTokens, 100);
        expect(result[0].wakeCount, 1);

        expect(result[1].modelId, 'gemini-2.5-pro');
        expect(result[1].inputTokens, 300);
        expect(result[1].outputTokens, 130);
        expect(result[1].thoughtsTokens, 50);
        expect(result[1].cachedInputTokens, 15);
        expect(result[1].wakeCount, 2);
      });

      test('handles null token fields gracefully', () async {
        final now = DateTime(2025, 6, 15);
        final container = createAgentTokenContainer(
          agentId: agentId,
          records: [
            WakeTokenUsageEntity(
              id: 'u1',
              agentId: agentId,
              runKey: 'run-1',
              threadId: 't1',
              modelId: 'model-a',
              createdAt: now,
              vectorClock: null,
              // All token fields null
            ),
          ],
        );

        final result = await container.read(
          agentTokenUsageSummariesProvider(agentId).future,
        );

        expect(result, hasLength(1));
        expect(result[0].inputTokens, 0);
        expect(result[0].outputTokens, 0);
        expect(result[0].thoughtsTokens, 0);
        expect(result[0].cachedInputTokens, 0);
        expect(result[0].wakeCount, 1);
      });
    });

    group('tokenUsageForThreadProvider', () {
      const agentId = kTestAgentId;

      test('returns null when no records match threadId', () async {
        final now = DateTime(2025, 6, 15);
        final container = createAgentTokenContainer(
          agentId: agentId,
          records: [
            WakeTokenUsageEntity(
              id: 'u1',
              agentId: agentId,
              runKey: 'run-1',
              threadId: 'other-thread',
              modelId: 'gemini-2.5-pro',
              createdAt: now,
              vectorClock: null,
              inputTokens: 100,
              outputTokens: 50,
            ),
          ],
        );
        final result = await container.read(
          tokenUsageForThreadProvider(agentId, 'my-thread').future,
        );
        expect(result, isNull);
      });

      test('returns null when no records at all', () async {
        final container = createAgentTokenContainer(
          agentId: agentId,
          records: [],
        );
        final result = await container.read(
          tokenUsageForThreadProvider(agentId, 'my-thread').future,
        );
        expect(result, isNull);
      });

      test('aggregates records for matching threadId', () async {
        final now = DateTime(2025, 6, 15);
        final container = createAgentTokenContainer(
          agentId: agentId,
          records: [
            WakeTokenUsageEntity(
              id: 'u1',
              agentId: agentId,
              runKey: 'run-1',
              threadId: 'target-thread',
              modelId: 'gemini-2.5-pro',
              createdAt: now,
              vectorClock: null,
              inputTokens: 100,
              outputTokens: 50,
              thoughtsTokens: 20,
              cachedInputTokens: 10,
            ),
            WakeTokenUsageEntity(
              id: 'u2',
              agentId: agentId,
              runKey: 'run-2',
              threadId: 'target-thread',
              modelId: 'gemini-2.5-pro',
              createdAt: now,
              vectorClock: null,
              inputTokens: 200,
              outputTokens: 80,
              thoughtsTokens: 30,
              cachedInputTokens: 5,
            ),
            // Different thread — should be excluded
            WakeTokenUsageEntity(
              id: 'u3',
              agentId: agentId,
              runKey: 'run-3',
              threadId: 'other-thread',
              modelId: 'claude-sonnet',
              createdAt: now,
              vectorClock: null,
              inputTokens: 999,
              outputTokens: 999,
            ),
          ],
        );

        final result = await container.read(
          tokenUsageForThreadProvider(agentId, 'target-thread').future,
        );

        expect(result, isNotNull);
        expect(result!.modelId, 'gemini-2.5-pro');
        expect(result.inputTokens, 300);
        expect(result.outputTokens, 130);
        expect(result.thoughtsTokens, 50);
        expect(result.cachedInputTokens, 15);
        expect(result.wakeCount, 2);
        expect(result.totalTokens, 480);
      });

      test('handles null token fields gracefully', () async {
        final now = DateTime(2025, 6, 15);
        final container = createAgentTokenContainer(
          agentId: agentId,
          records: [
            WakeTokenUsageEntity(
              id: 'u1',
              agentId: agentId,
              runKey: 'run-1',
              threadId: 'null-thread',
              modelId: 'model-a',
              createdAt: now,
              vectorClock: null,
              // All token fields null
            ),
          ],
        );

        final result = await container.read(
          tokenUsageForThreadProvider(agentId, 'null-thread').future,
        );

        expect(result, isNotNull);
        expect(result!.inputTokens, 0);
        expect(result.outputTokens, 0);
        expect(result.thoughtsTokens, 0);
        expect(result.cachedInputTokens, 0);
        expect(result.wakeCount, 1);
      });
    });
  });
}
