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
    DateTime? assessedAt,
    String? decimal,
  }) => AiInteractionCost(
    id: id,
    interactionId: interactionId,
    source: source,
    assessedAt: assessedAt ?? DateTime(2026, 3, 15, 12),
    originalAmountDecimal: decimal ?? (micros == null ? null : '0.0001'),
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

  test('empty evidence has no effective cost or aggregate totals', () {
    expect(effectiveInteractionCost(const []), isNull);
    expect(aggregateEffectiveCosts(const []), same(AiCostTotals.empty));
  });

  test('authority, assessment time, and id form a deterministic ordering', () {
    const sources = AiCostSource.values;
    final evidence = [
      for (var index = 0; index < sources.length; index++)
        cost(
          id: 'cost-$index',
          source: sources[index],
          micros: sources[index] == AiCostSource.unknown ? null : 100,
          currency: sources[index] == AiCostSource.unknown ? null : 'USD',
        ),
    ];
    expect(effectiveInteractionCost(evidence), evidence.first);

    final older = cost(
      id: 'older',
      source: AiCostSource.providerReported,
      assessedAt: DateTime(2026, 3, 15, 11),
    );
    final sameTimeA = cost(
      id: 'same-a',
      source: AiCostSource.providerReported,
    );
    final sameTimeB = cost(
      id: 'same-b',
      source: AiCostSource.providerReported,
    );
    expect(effectiveInteractionCost([sameTimeB, older, sameTimeA]), sameTimeB);
  });

  test('rejects malformed evidence graphs and amount shapes', () {
    final valid = cost(id: 'valid', source: AiCostSource.providerReported);
    final invalidCases = <List<AiInteractionCost>>[
      [
        valid,
        cost(
          id: 'other-interaction',
          interactionId: 'call-2',
          source: AiCostSource.providerReported,
        ),
      ],
      [
        valid,
        valid.copyWith(reportingAmountMicros: 101),
      ],
      [
        cost(
          id: 'self',
          source: AiCostSource.providerReported,
          supersedes: 'self',
        ),
      ],
      [
        cost(
          id: 'dangling',
          source: AiCostSource.providerReported,
          supersedes: 'missing',
        ),
      ],
      [
        cost(
          id: 'bad-decimal',
          source: AiCostSource.providerReported,
          decimal: '01.2',
        ),
      ],
      [
        cost(
          id: 'missing-currency',
          source: AiCostSource.providerReported,
          currency: null,
        ),
      ],
      [
        cost(
          id: 'unknown-with-money',
          source: AiCostSource.unknown,
        ),
      ],
      [
        cost(
          id: 'cycle-a',
          source: AiCostSource.providerReported,
          supersedes: 'cycle-b',
        ),
        cost(
          id: 'cycle-b',
          source: AiCostSource.providerReported,
          supersedes: 'cycle-a',
        ),
      ],
    ];

    for (final evidence in invalidCases) {
      expect(
        () => effectiveInteractionCost(evidence),
        throwsA(isA<InvalidAiCostEvidence>()),
      );
    }
    expect(
      const InvalidAiCostEvidence('bad').toString(),
      'InvalidAiCostEvidence: bad',
    );
  });
}
