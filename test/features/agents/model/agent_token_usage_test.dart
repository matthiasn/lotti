import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';

enum _GeneratedTokenLifecycle { created, active, dormant, destroyed }

AgentLifecycle _generatedTokenLifecycle(_GeneratedTokenLifecycle lifecycle) {
  return switch (lifecycle) {
    _GeneratedTokenLifecycle.created => AgentLifecycle.created,
    _GeneratedTokenLifecycle.active => AgentLifecycle.active,
    _GeneratedTokenLifecycle.dormant => AgentLifecycle.dormant,
    _GeneratedTokenLifecycle.destroyed => AgentLifecycle.destroyed,
  };
}

class _GeneratedTokenSummary {
  const _GeneratedTokenSummary({
    required this.modelSlot,
    required this.inputTokens,
    required this.outputTokens,
    required this.thoughtsTokens,
    required this.cachedInputTokens,
    required this.wakeCount,
  });

  final int modelSlot;
  final int inputTokens;
  final int outputTokens;
  final int thoughtsTokens;
  final int cachedInputTokens;
  final int wakeCount;

  String get modelId => 'generated-model-$modelSlot';

  int get expectedTotalTokens => inputTokens + outputTokens + thoughtsTokens;

  AgentTokenUsageSummary get summary => AgentTokenUsageSummary(
    modelId: modelId,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    thoughtsTokens: thoughtsTokens,
    cachedInputTokens: cachedInputTokens,
    wakeCount: wakeCount,
  );

  @override
  String toString() {
    return '_GeneratedTokenSummary('
        'modelSlot: $modelSlot, inputTokens: $inputTokens, '
        'outputTokens: $outputTokens, thoughtsTokens: $thoughtsTokens, '
        'cachedInputTokens: $cachedInputTokens, wakeCount: $wakeCount)';
  }
}

class _GeneratedInstanceBreakdown {
  const _GeneratedInstanceBreakdown({
    required this.lifecycle,
    required this.summaries,
  });

  final _GeneratedTokenLifecycle lifecycle;
  final List<_GeneratedTokenSummary> summaries;

  int get expectedTotalTokens => summaries.fold<int>(
    0,
    (sum, summary) => sum + summary.expectedTotalTokens,
  );

  InstanceTokenBreakdown get breakdown => InstanceTokenBreakdown(
    agentId: 'generated-agent',
    displayName: 'Generated Agent',
    lifecycle: _generatedTokenLifecycle(lifecycle),
    summaries: summaries.map((summary) => summary.summary).toList(),
  );

  @override
  String toString() {
    return '_GeneratedInstanceBreakdown('
        'lifecycle: $lifecycle, summaries: $summaries)';
  }
}

extension _AnyGeneratedAgentTokenUsage on glados.Any {
  glados.Generator<_GeneratedTokenLifecycle> get tokenLifecycle =>
      glados.AnyUtils(this).choose(_GeneratedTokenLifecycle.values);

  glados.Generator<_GeneratedTokenSummary> get tokenSummary =>
      glados.CombinableAny(this).combine6(
        glados.IntAnys(this).intInRange(0, 8),
        glados.IntAnys(this).intInRange(0, 50000),
        glados.IntAnys(this).intInRange(0, 50000),
        glados.IntAnys(this).intInRange(0, 50000),
        glados.IntAnys(this).intInRange(0, 50000),
        glados.IntAnys(this).intInRange(0, 1000),
        (
          int modelSlot,
          int inputTokens,
          int outputTokens,
          int thoughtsTokens,
          int cachedInputTokens,
          int wakeCount,
        ) => _GeneratedTokenSummary(
          modelSlot: modelSlot,
          inputTokens: inputTokens,
          outputTokens: outputTokens,
          thoughtsTokens: thoughtsTokens,
          cachedInputTokens: cachedInputTokens,
          wakeCount: wakeCount,
        ),
      );

  glados.Generator<_GeneratedInstanceBreakdown> get instanceBreakdown =>
      glados.CombinableAny(this).combine2(
        tokenLifecycle,
        glados.ListAnys(this).listWithLengthInRange(0, 30, tokenSummary),
        (
          _GeneratedTokenLifecycle lifecycle,
          List<_GeneratedTokenSummary> summaries,
        ) => _GeneratedInstanceBreakdown(
          lifecycle: lifecycle,
          summaries: summaries,
        ),
      );
}

void main() {
  group('AgentTokenUsageSummary', () {
    test('computes totalTokens as input + output + thoughts', () {
      const summary = AgentTokenUsageSummary(
        modelId: 'gemini-2.5-pro',
        inputTokens: 100,
        outputTokens: 50,
        thoughtsTokens: 25,
        cachedInputTokens: 10,
        wakeCount: 3,
      );

      // cachedInputTokens is a subset of inputTokens, not additive.
      expect(summary.totalTokens, 175);
    });

    test('defaults to zero for all counts', () {
      const summary = AgentTokenUsageSummary(modelId: 'test');

      expect(summary.inputTokens, 0);
      expect(summary.outputTokens, 0);
      expect(summary.thoughtsTokens, 0);
      expect(summary.cachedInputTokens, 0);
      expect(summary.wakeCount, 0);
      expect(summary.totalTokens, 0);
    });

    test('equality compares all fields', () {
      const a = AgentTokenUsageSummary(
        modelId: 'model-a',
        inputTokens: 100,
        outputTokens: 50,
        thoughtsTokens: 25,
        cachedInputTokens: 10,
        wakeCount: 2,
      );
      const b = AgentTokenUsageSummary(
        modelId: 'model-a',
        inputTokens: 100,
        outputTokens: 50,
        thoughtsTokens: 25,
        cachedInputTokens: 10,
        wakeCount: 2,
      );
      const c = AgentTokenUsageSummary(
        modelId: 'model-a',
        inputTokens: 100,
        outputTokens: 50,
        thoughtsTokens: 25,
        cachedInputTokens: 10,
        wakeCount: 3, // different
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('toString renders the exact labelled format', () {
      const summary = AgentTokenUsageSummary(
        modelId: 'gemini-2.5-pro',
        inputTokens: 100,
        outputTokens: 50,
        thoughtsTokens: 25,
        cachedInputTokens: 10,
        wakeCount: 3,
      );

      // Pin the full format string: this is the line shown in debug/diagnostic
      // output, so order, labels, and field selection are part of the contract.
      expect(
        summary.toString(),
        'AgentTokenUsageSummary(model: gemini-2.5-pro, in: 100, '
        'out: 50, thoughts: 25, cached: 10, wakes: 3)',
      );
    });

    glados.Glados(
      glados.any.tokenSummary,
      glados.ExploreConfig(numRuns: 160),
    ).test('matches generated total token semantics', (scenario) {
      final summary = scenario.summary;

      expect(summary.totalTokens, scenario.expectedTotalTokens);
      expect(summary.cachedInputTokens, scenario.cachedInputTokens);
      expect(summary.wakeCount, scenario.wakeCount);
    }, tags: 'glados');
  });

  group('InstanceTokenBreakdown', () {
    test('totalTokens computed correctly from summaries', () {
      const breakdown = InstanceTokenBreakdown(
        agentId: 'agent-1',
        displayName: 'Agent One',
        lifecycle: AgentLifecycle.active,
        summaries: [
          AgentTokenUsageSummary(
            modelId: 'gemini-2.5-pro',
            inputTokens: 100,
            outputTokens: 50,
            thoughtsTokens: 25,
          ),
          AgentTokenUsageSummary(
            modelId: 'claude-sonnet',
            inputTokens: 200,
            outputTokens: 100,
            thoughtsTokens: 50,
          ),
        ],
      );

      // (100+50+25) + (200+100+50) = 175 + 350 = 525
      expect(breakdown.totalTokens, 525);
    });

    test('empty summaries list returns 0 totalTokens', () {
      const breakdown = InstanceTokenBreakdown(
        agentId: 'agent-1',
        displayName: 'Agent One',
        lifecycle: AgentLifecycle.active,
        summaries: [],
      );

      expect(breakdown.totalTokens, 0);
    });

    test('equality and hashCode with const lists', () {
      const a = InstanceTokenBreakdown(
        agentId: 'agent-1',
        displayName: 'Agent One',
        lifecycle: AgentLifecycle.active,
        summaries: [
          AgentTokenUsageSummary(
            modelId: 'gemini-2.5-pro',
            inputTokens: 100,
            outputTokens: 50,
          ),
        ],
      );
      const b = InstanceTokenBreakdown(
        agentId: 'agent-1',
        displayName: 'Agent One',
        lifecycle: AgentLifecycle.active,
        summaries: [
          AgentTokenUsageSummary(
            modelId: 'gemini-2.5-pro',
            inputTokens: 100,
            outputTokens: 50,
          ),
        ],
      );
      const c = InstanceTokenBreakdown(
        agentId: 'agent-2',
        displayName: 'Agent Two',
        lifecycle: AgentLifecycle.dormant,
        summaries: [],
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('equality and hashCode with non-const lists', () {
      // Verifies element-wise comparison works for runtime-constructed lists
      // (non-const lists have different identity, so identity-based ==
      // would fail here).
      const summary = AgentTokenUsageSummary(
        modelId: 'gemini-2.5-pro',
        inputTokens: 100,
        outputTokens: 50,
      );
      // Use List.of to create distinct runtime list instances — if equality
      // were identity-based these would not compare equal.
      final a = InstanceTokenBreakdown(
        agentId: 'agent-1',
        displayName: 'Agent One',
        lifecycle: AgentLifecycle.active,
        summaries: List.of([summary]),
      );
      final b = InstanceTokenBreakdown(
        agentId: 'agent-1',
        displayName: 'Agent One',
        lifecycle: AgentLifecycle.active,
        summaries: List.of([summary]),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toString redacts identifying fields and includes safe fields', () {
      const breakdown = InstanceTokenBreakdown(
        agentId: 'agent-1',
        displayName: 'Agent One',
        lifecycle: AgentLifecycle.active,
        summaries: [
          AgentTokenUsageSummary(
            modelId: 'gemini-2.5-pro',
            inputTokens: 100,
            outputTokens: 50,
            thoughtsTokens: 25,
          ),
        ],
      );

      final str = breakdown.toString();
      expect(str, contains('agent: <redacted>'));
      expect(str, contains('name: <redacted>'));
      expect(str, isNot(contains('agent-1')));
      expect(str, isNot(contains('Agent One')));
      expect(str, contains('active'));
      expect(str, contains('175'));
    });

    glados.Glados(
      glados.any.instanceBreakdown,
      glados.ExploreConfig(numRuns: 160),
    ).test('matches generated per-instance total token semantics', (scenario) {
      expect(
        scenario.breakdown.totalTokens,
        scenario.expectedTotalTokens,
        reason: '$scenario',
      );
    }, tags: 'glados');
  });
}
