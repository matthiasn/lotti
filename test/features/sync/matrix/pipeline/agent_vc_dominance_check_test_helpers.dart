import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/vector_clock.dart';

/// Unit tests for the standalone VC-dominance check. The class is
/// performance-critical — it runs once per incoming agent attachment
/// and the hot path was previously a 36 ms per-call `SELECT *` that
/// fired 1600+ times per hour during a sync drain. The tests cover:
///
///   * every early-exit shape the caller relies on to stay
///     conservative (null incoming VC, unparseable path, no local
///     row, malformed local VC JSON, concurrent clocks — all should
///     return false so the ingestor proceeds with the download),
///   * the cache invariants (hit, TTL expiry, capacity eviction),
///   * the three `VclockStatus` outcomes that `VectorClock.compare`
///     can return, pinned to the "skip download" vs "proceed" bit
///     the caller keys on.
enum GeneratedAgentVcPathKind {
  entity,
  link,
  wrongPrefix,
  noExtension,
  empty,
}

enum GeneratedIncomingVcKind { absent, present }

enum GeneratedLocalVcKind {
  missing,
  missingVectorClock,
  malformedVectorClock,
  dominates,
  equal,
  older,
  concurrent,
  invalid,
}

class GeneratedAgentVcScenario {
  const GeneratedAgentVcScenario({
    required this.pathKind,
    required this.incomingKind,
    required this.localKind,
    required this.slot,
  });

  final GeneratedAgentVcPathKind pathKind;
  final GeneratedIncomingVcKind incomingKind;
  final GeneratedLocalVcKind localKind;
  final int slot;

  String get id => 'generated-$slot';

  String get relativePath {
    switch (pathKind) {
      case GeneratedAgentVcPathKind.entity:
        return '/agent_entities/$id.json';
      case GeneratedAgentVcPathKind.link:
        return '/agent_links/$id.json';
      case GeneratedAgentVcPathKind.wrongPrefix:
        return '/attachments/$id.json';
      case GeneratedAgentVcPathKind.noExtension:
        return '/agent_entities/$id';
      case GeneratedAgentVcPathKind.empty:
        return '';
    }
  }

  VectorClock? get incomingVc {
    switch (incomingKind) {
      case GeneratedIncomingVcKind.absent:
        return null;
      case GeneratedIncomingVcKind.present:
        return const VectorClock({'host': 3});
    }
  }

  Map<String, dynamic>? get localVcJson {
    switch (localKind) {
      case GeneratedLocalVcKind.dominates:
        return {'host': 4};
      case GeneratedLocalVcKind.equal:
        return {'host': 3};
      case GeneratedLocalVcKind.older:
        return {'host': 2};
      case GeneratedLocalVcKind.concurrent:
        return {'other': 3};
      case GeneratedLocalVcKind.invalid:
        return {'host': -1};
      case GeneratedLocalVcKind.missing:
      case GeneratedLocalVcKind.missingVectorClock:
      case GeneratedLocalVcKind.malformedVectorClock:
        return null;
    }
  }

  String serialized() {
    switch (localKind) {
      case GeneratedLocalVcKind.missing:
        throw StateError('missing local row has no serialized value');
      case GeneratedLocalVcKind.missingVectorClock:
        return '{"id":"$id","deletedAt":null}';
      case GeneratedLocalVcKind.malformedVectorClock:
        return '{"id":"$id","vectorClock":"nope","deletedAt":null}';
      case GeneratedLocalVcKind.dominates:
      case GeneratedLocalVcKind.equal:
      case GeneratedLocalVcKind.older:
      case GeneratedLocalVcKind.concurrent:
      case GeneratedLocalVcKind.invalid:
        return '{"id":"$id","vectorClock":${jsonVc(localVcJson!)},"deletedAt":null}';
    }
  }

  bool get validLookupPath =>
      pathKind == GeneratedAgentVcPathKind.entity ||
      pathKind == GeneratedAgentVcPathKind.link;

  bool get expected =>
      validLookupPath &&
      incomingKind == GeneratedIncomingVcKind.present &&
      (localKind == GeneratedLocalVcKind.dominates ||
          localKind == GeneratedLocalVcKind.equal);

  @override
  String toString() {
    return 'GeneratedAgentVcScenario('
        'pathKind: $pathKind, '
        'incomingKind: $incomingKind, '
        'localKind: $localKind, '
        'slot: $slot'
        ')';
  }
}

extension AnyGeneratedAgentVcScenario on glados.Any {
  glados.Generator<GeneratedAgentVcPathKind> get agentVcPathKind =>
      glados.AnyUtils(this).choose(GeneratedAgentVcPathKind.values);

  glados.Generator<GeneratedIncomingVcKind> get incomingVcKind =>
      glados.AnyUtils(this).choose(GeneratedIncomingVcKind.values);

  glados.Generator<GeneratedLocalVcKind> get localVcKind =>
      glados.AnyUtils(this).choose(GeneratedLocalVcKind.values);

  glados.Generator<GeneratedAgentVcScenario> get agentVcScenario =>
      glados.CombinableAny(this).combine4(
        agentVcPathKind,
        incomingVcKind,
        localVcKind,
        glados.IntAnys(this).intInRange(0, 8),
        (
          GeneratedAgentVcPathKind pathKind,
          GeneratedIncomingVcKind incomingKind,
          GeneratedLocalVcKind localKind,
          int slot,
        ) => GeneratedAgentVcScenario(
          pathKind: pathKind,
          incomingKind: incomingKind,
          localKind: localKind,
          slot: slot,
        ),
      );
}

String jsonVc(Map<String, dynamic> vc) {
  final entries = vc.entries.map((e) => '"${e.key}":${e.value}').join(',');
  return '{$entries}';
}
