// Pure verification for Level 2 eval run artifacts.
//
// This validates the run as a complete matrix, not just the traces that happen
// to exist on disk. It is intentionally IO-free so the report entrypoint can
// pass file names from `eval/runs/<runId>` while unit tests exercise adversarial
// cases directly.

import 'eval_assertions.dart';
import 'eval_models.dart';

class EvalRunVerification {
  const EvalRunVerification(this.errors);

  final List<String> errors;

  bool get passed => errors.isEmpty;

  void throwIfFailed() {
    if (passed) return;
    throw StateError(errors.join('\n'));
  }
}

abstract final class EvalRunVerifier {
  static EvalRunVerification verify({
    required String runId,
    required List<EvalTrace> traces,
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    Iterable<String> artifactNames = const <String>[],
    bool requireVerdicts = true,
  }) {
    final errors = <String>[];
    final expectedKeys = _expectedKeys(scenarios, profiles);
    final traceKeys = traces.map(_traceKey).toList(growable: false);
    final actualKeys = traceKeys.toSet();

    if (traces.isEmpty) {
      errors.add('run has no traces');
    }

    final duplicates = _duplicates(traceKeys);
    for (final key in duplicates) {
      errors.add('duplicate trace for $key');
    }

    for (final key in expectedKeys.difference(actualKeys).toList()..sort()) {
      errors.add('missing trace for $key');
    }
    for (final key in actualKeys.difference(expectedKeys).toList()..sort()) {
      errors.add('unexpected trace for $key');
    }

    if (artifactNames.isNotEmpty) {
      final traceStems = <String>{};
      final verdictStems = <String>{};
      for (final name in artifactNames) {
        if (name.endsWith('.trace.json')) {
          traceStems.add(_stripSuffix(name, '.trace.json'));
        } else if (name.endsWith('.verdict.json')) {
          verdictStems.add(_stripSuffix(name, '.verdict.json'));
        }
      }
      for (final stem in verdictStems.difference(traceStems).toList()..sort()) {
        errors.add('orphan verdict artifact for $stem');
      }
    }

    for (final trace in traces) {
      final key = _traceKey(trace);
      if (trace.runId != runId) {
        errors.add('$key has runId ${trace.runId}, expected $runId');
      }
      final recomputedChecks = _validateLevel1(trace, key, errors);
      final verdict = trace.verdict;
      if (requireVerdicts && verdict == null) {
        errors.add('missing verdict for $key');
        continue;
      }
      if (verdict == null) continue;
      _validateVerdict(verdict, recomputedChecks, key, errors);
    }

    return EvalRunVerification(errors);
  }

  static Set<String> _expectedKeys(
    List<EvalScenario> scenarios,
    List<EvalProfile> profiles,
  ) {
    return {
      for (final scenario in scenarios)
        for (final profile in profiles)
          for (
            var trialIndex = 0;
            trialIndex < profile.trialCount;
            trialIndex++
          )
            _key(scenario.id, profile.name, trialIndex),
    };
  }

  static Set<String> _duplicates(List<String> values) {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final value in values) {
      if (!seen.add(value)) duplicates.add(value);
    }
    return duplicates;
  }

  static void _validateVerdict(
    JudgeVerdict verdict,
    List<EvalCheck> recomputedChecks,
    String key,
    List<String> errors,
  ) {
    for (final dimension in [
      ('goalAttainment', verdict.goalAttainment),
      ('quality', verdict.quality),
      ('efficiency', verdict.efficiency),
    ]) {
      final (name, value) = dimension;
      if (value < 1 || value > 5) {
        errors.add('$key verdict $name is outside 1..5: $value');
      }
    }

    final minScore = [
      verdict.goalAttainment,
      verdict.quality,
      verdict.efficiency,
    ].reduce((a, b) => a < b ? a : b);
    if (verdict.pass && minScore < 3) {
      errors.add('$key verdict passes with a score below 3');
    }
    if (verdict.pass && recomputedChecks.any((check) => !check.passed)) {
      errors.add('$key verdict passes despite failed Level 1 checks');
    }
    if (!verdict.pass && verdict.issues.isEmpty) {
      errors.add('$key failing verdict must list at least one issue');
    }
  }

  static List<EvalCheck> _validateLevel1(
    EvalTrace trace,
    String key,
    List<String> errors,
  ) {
    final recomputed = runLevel1(
      trace.scenario,
      trace.output,
      profile: trace.profile,
    );
    final actual = trace.level1Checks;
    final duplicateNames = _duplicates(actual.map((c) => c.name).toList());
    for (final name in duplicateNames) {
      errors.add('$key has duplicate Level 1 check $name');
    }

    final expectedByName = <String, EvalCheck>{
      for (final check in recomputed) check.name: check,
    };
    final actualByName = <String, EvalCheck>{
      for (final check in actual) check.name: check,
    };
    for (final name in expectedByName.keys.toSet().difference(
      actualByName.keys.toSet(),
    )) {
      errors.add('$key missing Level 1 check $name');
    }
    for (final name in actualByName.keys.toSet().difference(
      expectedByName.keys.toSet(),
    )) {
      errors.add('$key has unexpected Level 1 check $name');
    }
    for (final name in expectedByName.keys) {
      final actualCheck = actualByName[name];
      if (actualCheck == null) continue;
      final expectedCheck = expectedByName[name]!;
      if (actualCheck.passed != expectedCheck.passed) {
        errors.add(
          '$key Level 1 check $name stored ${actualCheck.passed} '
          'but recomputed ${expectedCheck.passed}',
        );
      }
    }
    return recomputed;
  }

  static String _traceKey(EvalTrace trace) =>
      _key(trace.scenario.id, trace.profile.name, trace.trialIndex);

  static String _key(String scenarioId, String profileName, int trialIndex) =>
      '$scenarioId::$profileName::trial-$trialIndex';

  static String _stripSuffix(String value, String suffix) =>
      value.substring(0, value.length - suffix.length);
}
