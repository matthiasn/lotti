import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';

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
}
