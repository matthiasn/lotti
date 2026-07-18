import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';

/// Thrown when append-only cost evidence violates a convergence invariant.
class InvalidAiCostEvidence implements Exception {
  const InvalidAiCostEvidence(this.message);

  final String message;

  @override
  String toString() => 'InvalidAiCostEvidence: $message';
}

/// Known reporting totals plus the number of interactions whose cost is
/// unknown. Different currencies are kept separate and are never added.
class AiCostTotals {
  const AiCostTotals({
    required this.reportingMicrosByCurrency,
    required this.knownInteractionCount,
    required this.unknownInteractionCount,
  });

  static const empty = AiCostTotals(
    reportingMicrosByCurrency: {},
    knownInteractionCount: 0,
    unknownInteractionCount: 0,
  );

  final Map<String, int> reportingMicrosByCurrency;
  final int knownInteractionCount;
  final int unknownInteractionCount;
}

/// Selects the single convergent effective assessment for one interaction.
///
/// Evidence is append-only. Explicit supersession is validated first; among
/// concurrent leaves, source authority wins, followed by assessment time and
/// lexical id. This makes selection independent of arrival order.
AiInteractionCost? effectiveInteractionCost(
  Iterable<AiInteractionCost> evidence,
) {
  final costs = evidence.toList(growable: false);
  if (costs.isEmpty) return null;

  final interactionId = costs.first.interactionId;
  final byId = <String, AiInteractionCost>{};
  for (final cost in costs) {
    if (cost.interactionId != interactionId) {
      throw const InvalidAiCostEvidence(
        'one selection may contain only one interaction id',
      );
    }
    if (byId.containsKey(cost.id)) {
      throw InvalidAiCostEvidence('duplicate cost id ${cost.id}');
    }
    byId[cost.id] = cost;
    _validateAmountShape(cost);
  }

  final superseded = <String>{};
  for (final cost in costs) {
    final predecessorId = cost.supersedesCostId;
    if (predecessorId == null) continue;
    if (predecessorId == cost.id) {
      throw InvalidAiCostEvidence('cost ${cost.id} supersedes itself');
    }
    final predecessor = byId[predecessorId];
    if (predecessor == null) {
      throw InvalidAiCostEvidence(
        'cost ${cost.id} has dangling predecessor $predecessorId',
      );
    }
    if (_authority(cost.source) < _authority(predecessor.source)) {
      throw InvalidAiCostEvidence(
        'cost ${cost.id} is an authority downgrade from $predecessorId',
      );
    }
    superseded.add(predecessorId);
  }

  _validateAcyclic(byId);

  final leaves = costs.where((cost) => !superseded.contains(cost.id)).toList()
    ..sort(_compareCostAuthority);
  return leaves.last;
}

/// Aggregates effective costs once per interaction without mixing currencies.
AiCostTotals aggregateEffectiveCosts(Iterable<AiInteractionCost> evidence) {
  final byInteraction = <String, List<AiInteractionCost>>{};
  for (final cost in evidence) {
    byInteraction.putIfAbsent(cost.interactionId, () => []).add(cost);
  }

  if (byInteraction.isEmpty) return AiCostTotals.empty;

  final totals = <String, int>{};
  var known = 0;
  var unknown = 0;
  for (final costs in byInteraction.values) {
    try {
      final effective = effectiveInteractionCost(costs);
      final amount = effective?.reportingAmountMicros;
      final currency = effective?.reportingCurrency;
      if (amount == null || currency == null) {
        unknown++;
        continue;
      }
      known++;
      totals.update(
        currency,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
    } on InvalidAiCostEvidence {
      unknown++;
    }
  }

  return AiCostTotals(
    reportingMicrosByCurrency: Map.unmodifiable(totals),
    knownInteractionCount: known,
    unknownInteractionCount: unknown,
  );
}

void _validateAmountShape(AiInteractionCost cost) {
  final decimal = cost.originalAmountDecimal;
  if (decimal != null && !_decimalPattern.hasMatch(decimal)) {
    throw InvalidAiCostEvidence(
      'cost ${cost.id} has invalid decimal evidence',
    );
  }
  if ((cost.reportingAmountMicros == null) !=
      (cost.reportingCurrency == null)) {
    throw InvalidAiCostEvidence(
      'cost ${cost.id} must provide reporting amount and currency together',
    );
  }
  if (cost.source == AiCostSource.unknown &&
      (decimal != null || cost.reportingAmountMicros != null)) {
    throw InvalidAiCostEvidence(
      'unknown cost ${cost.id} cannot carry a monetary amount',
    );
  }
}

void _validateAcyclic(Map<String, AiInteractionCost> byId) {
  final visited = <String>{};
  final active = <String>{};

  void visit(String id) {
    if (active.contains(id)) {
      throw InvalidAiCostEvidence('cost supersession cycle at $id');
    }
    if (!visited.add(id)) return;
    active.add(id);
    final predecessorId = byId[id]!.supersedesCostId;
    if (predecessorId != null) visit(predecessorId);
    active.remove(id);
  }

  byId.keys.forEach(visit);
}

int _compareCostAuthority(AiInteractionCost a, AiInteractionCost b) {
  final authority = _authority(a.source).compareTo(_authority(b.source));
  if (authority != 0) return authority;
  final assessed = a.assessedAt.compareTo(b.assessedAt);
  if (assessed != 0) return assessed;
  return a.id.compareTo(b.id);
}

int _authority(AiCostSource source) => switch (source) {
  AiCostSource.unknown => 0,
  AiCostSource.localCompute => 1,
  AiCostSource.locallyEstimated => 2,
  AiCostSource.legacyReported => 3,
  AiCostSource.providerReported => 4,
  AiCostSource.externallyReconciled => 5,
};

final RegExp _decimalPattern = RegExp(
  r'^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$',
);

/// Converts exact decimal evidence to reporting micros using half-even ties.
int decimalAmountToMicros(String decimal) {
  final match = _decimalWithExponentPattern.firstMatch(decimal);
  if (match == null) {
    throw InvalidAiCostEvidence('invalid decimal amount $decimal');
  }
  final negative = match.namedGroup('sign') == '-';
  final integer = match.namedGroup('integer')!;
  final fraction = match.namedGroup('fraction') ?? '';
  final exponent = int.parse(match.namedGroup('exponent') ?? '0');
  final unscaled = BigInt.parse('$integer$fraction');
  final power = exponent - fraction.length + 6;
  BigInt micros;
  if (power >= 0) {
    micros = unscaled * BigInt.from(10).pow(power);
  } else {
    final divisor = BigInt.from(10).pow(-power);
    var quotient = unscaled ~/ divisor;
    final remainder = unscaled.remainder(divisor);
    final comparison = (remainder * BigInt.two).compareTo(divisor);
    if (comparison > 0 || (comparison == 0 && quotient.isOdd)) {
      quotient += BigInt.one;
    }
    micros = quotient;
  }
  return (negative ? -micros : micros).toInt();
}

final RegExp _decimalWithExponentPattern = RegExp(
  r'^(?<sign>-?)(?<integer>0|[1-9]\d*)'
  r'(?:\.(?<fraction>\d+))?(?:[eE](?<exponent>[+-]?\d+))?$',
);
