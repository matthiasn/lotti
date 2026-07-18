import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/logic/attribution_cost.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';

void main() {
  AiInteractionCost cost({
    required String id,
    required AiCostSource source,
    String interactionId = 'call-1',
    String? supersedes,
    int? micros = 100,
    String? currency = 'USD',
  }) => AiInteractionCost(
    id: id,
    interactionId: interactionId,
    source: source,
    assessedAt: DateTime(2026, 3, 15, 12),
    originalAmountDecimal: micros == null ? null : '0.0001',
    originalUnit: micros == null ? null : 'USD',
    reportingAmountMicros: micros,
    reportingCurrency: currency,
    supersedesCostId: supersedes,
  );

  test('higher-authority concurrent evidence wins independent of order', () {
    final estimate = cost(
      id: 'estimate',
      source: AiCostSource.locallyEstimated,
    );
    final provider = cost(
      id: 'provider',
      source: AiCostSource.providerReported,
      micros: 125,
    );

    expect(effectiveInteractionCost([estimate, provider]), provider);
    expect(effectiveInteractionCost([provider, estimate]), provider);
  });

  test('rejects authority downgrade in an explicit supersession chain', () {
    final provider = cost(
      id: 'provider',
      source: AiCostSource.providerReported,
    );
    final estimate = cost(
      id: 'estimate',
      source: AiCostSource.locallyEstimated,
      supersedes: provider.id,
    );

    expect(
      () => effectiveInteractionCost([provider, estimate]),
      throwsA(isA<InvalidAiCostEvidence>()),
    );
  });

  test('aggregates once per interaction and keeps currencies separate', () {
    final totals = aggregateEffectiveCosts([
      cost(id: 'usd-old', source: AiCostSource.locallyEstimated),
      cost(
        id: 'usd-final',
        source: AiCostSource.providerReported,
        supersedes: 'usd-old',
        micros: 150,
      ),
      cost(
        id: 'eur',
        interactionId: 'call-2',
        source: AiCostSource.providerReported,
        micros: 200,
        currency: 'EUR',
      ),
      cost(
        id: 'unknown',
        interactionId: 'call-3',
        source: AiCostSource.unknown,
        micros: null,
        currency: null,
      ),
    ]);

    expect(totals.reportingMicrosByCurrency, {'USD': 150, 'EUR': 200});
    expect(totals.knownInteractionCount, 2);
    expect(totals.unknownInteractionCount, 1);
  });
}
