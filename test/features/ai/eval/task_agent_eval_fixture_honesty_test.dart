/// Fixture-honesty tests: every scenario must actually ASK its question.
///
/// A scenario whose every check is satisfied by copying salient nouns out of
/// its own context measures summarisation, which every candidate model does
/// for free. It then reports 100% forever and reads in a matrix exactly like
/// a scenario that was hard and passed — the vacuous pass the goal suite's
/// first tier-2 table was made of.
///
/// These tests are cheap, offline, and run in CI. They cannot judge whether a
/// question is INTERESTING; they can only prove one was asked.
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/local_task_agent_inference_eval.dart';

/// Whether [value] can be produced by lifting text straight out of [context].
bool _isEchoable(String context, Object? value) {
  if (value == null) return true;
  if (value is String) return context.contains(value.toLowerCase());
  if (value is num || value is bool) {
    return context.contains(value.toString().toLowerCase());
  }
  if (value is List) return value.every((item) => _isEchoable(context, item));
  if (value is Map) {
    return value.values.every((item) => _isEchoable(context, item));
  }
  return false;
}

/// The checks in [scenario] that copying its context cannot satisfy.
///
/// Three kinds count. A required term no phrasing of which appears in the
/// context has to be DERIVED. Any forbidden term, claim or tool is restraint,
/// which echoing actively works against. An expected tool argument whose value
/// is absent from the context is the derivation the report prose is
/// deliberately not asked for — "two and a half hours" becoming `minutes: 150`
/// is asserted here and nowhere else, because requiring the prose to narrate
/// metadata contradicts the shipped report directive.
List<String> _discriminatingChecks(LocalTaskAgentEvalScenario scenario) {
  final context = scenario.userMessage.toLowerCase();
  return [
    for (final group in scenario.requiredReportTermGroups)
      if (!group.any((term) => context.contains(term.toLowerCase())))
        'requires deriving "${group.first}"',
    for (final term in scenario.forbiddenReportTerms) 'must not write "$term"',
    for (final claim in scenario.forbiddenReportClaims)
      'must not assert "$claim"',
    for (final name in scenario.forbiddenToolNames) 'must not call $name',
    // Restraint expressed at the argument level rather than the tool level:
    // "add the credential item but NOT a duplicate of the finished sandbox
    // one" cannot be said by forbidding the tool, since the tool must be
    // called. Missing this made the guard reject a scenario whose whole
    // question was a forbidden argument.
    for (final entry in scenario.forbiddenToolArgumentTerms.entries)
      for (final term in entry.value) 'must keep "$term" out of ${entry.key}',
    for (final expected in scenario.expectedToolCalls)
      for (final entry in expected.expectedArgumentsSubset.entries)
        if (!_isEchoable(context, entry.value))
          'must derive ${expected.name}.${entry.key}=${entry.value}',
  ];
}

void main() {
  final scenarios = defaultMeliousTaskAgentEvalScenarios(
    variants: LocalTaskAgentEvalPromptVariant.values,
  );

  test('the suite has scenarios to check at all', () {
    expect(scenarios, isNotEmpty);
  });

  group('every scenario asks something echoing cannot answer', () {
    for (final scenario in scenarios) {
      test(scenario.id, () {
        expect(
          _discriminatingChecks(scenario),
          isNotEmpty,
          reason:
              'Every check in ${scenario.id} is satisfied by copying its own '
              'context. Add a derived value, a restraint check, or a tool '
              'argument the context does not already spell out.',
        );
      });
    }
  });

  group('a scenario that requires a report also constrains it', () {
    // Expecting a report and then checking nothing about it is the same
    // vacuum one level up: the wake passes for emitting the call, whatever
    // the call said.
    for (final scenario in scenarios.where((s) => s.requiresReport)) {
      test(scenario.id, () {
        expect(
          scenario.requiredReportTermGroups.length +
              scenario.forbiddenReportTerms.length +
              scenario.forbiddenReportClaims.length,
          greaterThan(0),
          reason:
              '${scenario.id} requires a report but asserts nothing about its '
              'content.',
        );
      });
    }
  });
}
