import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import 'eval_harness.dart';

void main() {
  test('profile cost weights round-trip and price cached/thought tokens', () {
    const profile = EvalProfile(
      name: 'frontier-costed',
      isLocal: false,
      modelClass: EvalModelClass.frontierReasoning,
      modelId: 'frontier-costed-model',
      tokenBudget: 10000,
      inputTokenCostMicros: 3,
      outputTokenCostMicros: 12,
      thoughtsTokenCostMicros: 12,
    );

    final roundTripped = EvalProfile.fromJson(profile.toJson());

    expect(roundTripped.toJson(), profile.toJson());
    expect(roundTripped.usesWeightedTokenCosts, isTrue);
    expect(
      roundTripped.estimatedUsageCostMicros(
        const InferenceUsage(
          inputTokens: 100,
          cachedInputTokens: 40,
          outputTokens: 10,
          thoughtsTokens: 5,
        ),
      ),
      400,
    );
  });

  test('default profiles keep legacy unweighted cost semantics', () {
    const profile = EvalProfile(
      name: 'frontier-default',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-default-model',
      tokenBudget: 10000,
    );

    final json = profile.toJson();

    expect(profile.usesWeightedTokenCosts, isFalse);
    expect(json, isNot(containsPair('inputTokenCostMicros', anything)));
    expect(json, isNot(containsPair('outputTokenCostMicros', anything)));
    expect(
      profile.estimatedUsageCostMicros(
        const InferenceUsage(inputTokens: 30, outputTokens: 12),
      ),
      42,
    );
  });

  test('directive variants round-trip and merge with a baseline', () {
    const variant = EvalAgentDirectiveVariant(
      name: 'metadata-first-v2',
      generalDirective: 'Call metadata tools before reports.',
      reportDirective: 'Report only after durable proposals are created.',
    );

    final roundTripped = EvalAgentDirectiveVariant.fromJson(variant.toJson());

    expect(roundTripped.toJson(), variant.toJson());
    expect(
      roundTripped.mergedGeneralDirective('Baseline.'),
      'Baseline.\n\nCall metadata tools before reports.',
    );
    expect(
      roundTripped.reportDirective,
      'Report only after durable proposals are created.',
    );
  });

  test('profile cost estimation clamps cached tokens to input tokens', () {
    const profile = EvalProfile(
      name: 'frontier-cached-clamp',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-cached-clamp-model',
      tokenBudget: 10000,
      inputTokenCostMicros: 5,
    );

    expect(
      profile.estimatedUsageCostMicros(
        const InferenceUsage(
          inputTokens: 10,
          cachedInputTokens: 25,
          outputTokens: 3,
        ),
      ),
      13,
    );
  });

  test('weighted profiles expose missing estimated-cost fields', () {
    const profile = EvalProfile(
      name: 'frontier-missing-cost',
      isLocal: false,
      modelClass: EvalModelClass.frontierReasoning,
      modelId: 'frontier-missing-cost-model',
      tokenBudget: 10000,
      inputTokenCostMicros: 5,
    );

    expect(
      profile.missingEstimatedCostFields(
        const InferenceUsage(outputTokens: 20),
        requireCoreTokenCounts: true,
      ),
      ['inputTokens', 'cachedInputTokens'],
    );
    expect(
      profile.estimatedUsageCostMicrosOrNull(
        const InferenceUsage(outputTokens: 20),
        requireCoreTokenCounts: true,
      ),
      isNull,
    );
  });
}
