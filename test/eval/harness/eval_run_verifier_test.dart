import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../harness/eval_harness.dart';
import '../scenarios/eval_scenarios.dart';

void main() {
  final scenario = taskReleaseNotesScenario;
  const profile = EvalProfile(
    name: 'verifier-profile',
    isLocal: false,
    modelClass: EvalModelClass.frontierFast,
    modelId: 'verifier-model',
    tokenBudget: 10000,
  );

  test('passes a complete trace and verdict matrix', () {
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      level1Checks: runLevel1(scenario, _output, profile: profile),
    );

    final verification = EvalRunVerifier.verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      artifactNames: const ['trace.trace.json', 'trace.verdict.json'],
    );

    expect(verification.errors, isEmpty);
  });

  test('detects missing traces and orphan verdict artifacts', () {
    final verification = EvalRunVerifier.verify(
      runId: 'run-1',
      traces: const [],
      scenarios: [scenario],
      profiles: [profile],
      artifactNames: const ['orphan.verdict.json'],
    );

    expect(verification.errors, contains('run has no traces'));
    expect(
      verification.errors,
      contains(
        'missing trace for task_release_notes::verifier-profile::trial-0',
      ),
    );
    expect(
      verification.errors,
      contains('orphan verdict artifact for orphan'),
    );
  });

  test('rejects duplicated trace keys and wrong run ids', () {
    final checks = runLevel1(scenario, _output, profile: profile);
    final trace = _trace(
      runId: 'other-run',
      scenario: scenario,
      profile: profile,
      level1Checks: checks,
    );

    final verification = EvalRunVerifier.verify(
      runId: 'run-1',
      traces: [trace, trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'duplicate trace for task_release_notes::verifier-profile::trial-0',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 has runId other-run, '
        'expected run-1',
      ),
    );
  });

  test('recomputes Level 1 checks instead of trusting stored empty checks', () {
    final verification = EvalRunVerifier.verify(
      runId: 'run-1',
      traces: [
        _trace(
          scenario: scenario,
          profile: profile,
          level1Checks: const [],
        ),
      ],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'missing Level 1 check succeeded',
      ),
    );
  });

  test('rejects pass verdicts with low or out-of-range scores', () {
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      level1Checks: runLevel1(scenario, _output, profile: profile),
      verdict: const JudgeVerdict(
        traceDigest: 'sha256:abc',
        goalAttainment: 1,
        quality: 6,
        efficiency: 3,
        pass: true,
      ),
    );

    final verification = EvalRunVerifier.verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 verdict quality '
        'is outside 1..5: 6',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'verdict passes with a score below 3',
      ),
    );
  });
}

const _output = AgentRunOutput(
  success: true,
  usage: InferenceUsage(inputTokens: 100, outputTokens: 40),
  report: AgentReportRecord(
    oneLiner: 'Release notes groomed',
    tldr: 'Estimate and next steps are clear.',
    content: '## Done\nThe release-notes task is ready.',
  ),
);

EvalTrace _trace({
  required EvalScenario scenario,
  required EvalProfile profile,
  String runId = 'run-1',
  List<EvalCheck>? level1Checks,
  JudgeVerdict verdict = const JudgeVerdict(
    traceDigest: 'sha256:abc',
    goalAttainment: 5,
    quality: 5,
    efficiency: 4,
    pass: true,
  ),
}) {
  return EvalTrace(
    runId: runId,
    scenario: scenario,
    profile: profile,
    output: _output,
    level1Checks:
        level1Checks ?? runLevel1(scenario, _output, profile: profile),
    verdict: verdict,
  );
}
