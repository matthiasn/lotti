import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../harness/eval_harness.dart';
import '../scenarios/eval_scenarios.dart';

void main() {
  const profile = EvalProfile(
    name: 'repeatable-frontier',
    isLocal: false,
    modelClass: EvalModelClass.frontierReasoning,
    modelId: 'frontier-repeatable',
    tokenBudget: 10000,
    trialCount: 3,
  );

  test('reports per-trace pass rates and per-scenario pass^k reliability', () {
    final traces = [
      for (var trialIndex = 0; trialIndex < profile.trialCount; trialIndex++)
        _trace(
          scenario: taskReleaseNotesScenario,
          profile: profile,
          trialIndex: trialIndex,
        ),
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: profile,
      ),
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: profile,
        trialIndex: 1,
      ),
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: profile,
        trialIndex: 2,
        level1Passed: false,
        judgePassed: false,
      ),
    ];

    final summary = EvalReporter.summarize(traces).single;

    expect(summary.traceCount, 6);
    expect(summary.scenarioCount, 2);
    expect(summary.completeScenarioCount, 2);
    expect(summary.completeScenarioEstimate.successes, 2);
    expect(summary.completeScenarioEstimate.total, 2);
    expect(summary.level1PassCount, 5);
    expect(summary.level1PassRate, closeTo(5 / 6, 0.001));
    expect(summary.level1ReliableScenarioCount, 1);
    expect(summary.level1ReliableScenarioRate, 0.5);
    expect(summary.level1CompleteScenarioReliabilityEstimate.successes, 1);
    expect(summary.level1CompleteScenarioReliabilityEstimate.total, 2);
    expect(summary.judgedCount, 6);
    expect(summary.judgePassCount, 5);
    expect(summary.judgePassRate, closeTo(5 / 6, 0.001));
    expect(summary.judgeTracePassEstimate.successes, 5);
    expect(summary.judgeTracePassEstimate.total, 6);
    expect(summary.judgeTracePassEstimate.rate, closeTo(5 / 6, 0.001));
    expect(
      summary.judgeTracePassEstimate.lowerBound,
      lessThan(summary.judgePassRate),
    );
    expect(
      summary.judgeTracePassEstimate.upperBound,
      greaterThan(summary.judgePassRate),
    );
    expect(summary.judgeReliableScenarioCount, 1);
    expect(summary.judgeReliableScenarioRate, 0.5);
    expect(summary.judgePassEstimate.successes, 1);
    expect(summary.judgePassEstimate.total, 2);
    expect(summary.judgeCompleteScenarioReliabilityEstimate.successes, 1);
    expect(summary.judgeCompleteScenarioReliabilityEstimate.total, 2);

    final rendered = EvalReporter.render(traces);
    expect(rendered, contains('L1 pass^k'));
    expect(rendered, contains('judge pass^k'));
    expect(rendered, contains('Capability summary'));
    expect(rendered, contains('Split / model-class / capability summary'));
    expect(rendered, isNot(contains('Paired profile comparison')));
    expect(rendered, contains('task.grooming.basic'));
    expect(rendered, contains('83%'));
    expect(rendered, contains('50%'));
  });

  test('summary Wilson estimates cluster repeated trials by scenario', () {
    final traces = [
      for (var trialIndex = 0; trialIndex < profile.trialCount; trialIndex++)
        _trace(
          scenario: taskReleaseNotesScenario,
          profile: profile,
          trialIndex: trialIndex,
        ),
    ];

    final profileSummary = EvalReporter.summarize(traces).single;
    final capabilitySummary = EvalReporter.summarizeByCapability(traces).single;
    final sliceSummary = EvalReporter.summarizeBySlice(traces).single;

    expect(profileSummary.judgeTracePassEstimate.total, 3);
    expect(profileSummary.judgePassEstimate.total, 1);
    expect(profileSummary.judgePassEstimate.successes, 1);
    expect(capabilitySummary.judgeTracePassEstimate.total, 3);
    expect(capabilitySummary.judgePassEstimate.total, 1);
    expect(capabilitySummary.judgePassEstimate.successes, 1);
    expect(sliceSummary.judgeTracePassEstimate.total, 3);
    expect(sliceSummary.judgePassEstimate.total, 1);
    expect(sliceSummary.judgePassEstimate.successes, 1);
  });

  test('reports provider request stability and cache usage coverage', () {
    final traces = [
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: profile,
        inputTokens: 2048,
        cachedInputTokens: 0,
        providerRequests: [
          _providerRequest(),
        ],
      ),
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: profile,
        trialIndex: 1,
        inputTokens: 2048,
        cachedInputTokens: 1024,
        providerRequests: [
          _providerRequest(),
        ],
      ),
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: profile,
        trialIndex: 2,
        inputTokens: 2048,
        providerRequests: [
          _providerRequest(
            messageDigest: 'sha256:changed-messages',
            messageCount: 3,
            toolSchemaDigest: 'sha256:changed-tools',
          ),
        ],
      ),
    ];

    final requestSummary = EvalReporter.summarizeProviderRequestStability(
      traces,
    ).single;
    expect(requestSummary.traceCount, 3);
    expect(requestSummary.requestCount, 3);
    expect(requestSummary.uniqueMessageDigestCount, 2);
    expect(requestSummary.uniqueToolSchemaDigestCount, 2);
    expect(requestSummary.messageCounts, [2, 3]);
    expect(requestSummary.toolCounts, [19]);
    expect(requestSummary.requestShapeStable, isFalse);

    final usageSummary = EvalReporter.summarizeProviderUsageCache(
      traces,
    ).single;
    expect(usageSummary.inputTokenTraceCount, 3);
    expect(usageSummary.cachedInputTokenTraceCount, 2);
    expect(usageSummary.fullyReportedTraceCount, 2);
    expect(usageSummary.reportedInputTokens, 4096);
    expect(usageSummary.reportedCachedInputTokens, 1024);
    expect(usageSummary.reportedCacheRate, closeTo(0.25, 0.001));

    final rendered = EvalReporter.render(traces);
    expect(rendered, contains('Provider request fingerprints'));
    expect(rendered, contains('Provider usage cache coverage'));
    expect(rendered, contains('1024/4096'));
    expect(rendered, contains('25%'));
    expect(rendered, contains('no'));
  });

  test('excludes cascade wake traces from reliability summaries', () {
    final scenario = taskWorkflowChecklistTranscriptCascadeScenario;
    final traces = [
      for (
        var wakeIndex = 0;
        wakeIndex < scenario.appState.taskLogEntries.length;
        wakeIndex++
      )
        _trace(
          scenario: scenario,
          profile: profile,
          cascadeWake: EvalTraceCascadeWake(
            cascadeId: EvalTraceCascadeWake.taskLogCascadeId,
            wakeIndex: wakeIndex,
            wakeCount: scenario.appState.taskLogEntries.length,
          ),
          providerRequests: [
            _providerRequest(),
          ],
        ),
    ];

    final rendered = EvalReporter.render(traces);
    final requestSummary = EvalReporter.summarizeProviderRequestStability(
      traces,
    ).single;
    final usageSummary = EvalReporter.summarizeProviderUsageCache(
      traces,
    ).single;

    expect(EvalReporter.summarize(traces), isEmpty);
    expect(EvalReporter.summarizeByCapability(traces), isEmpty);
    expect(EvalReporter.compareProfiles(traces), isEmpty);
    expect(
      rendered,
      contains(
        'cascade wake traces excluded from reliability and promotion: 3',
      ),
    );
    expect(rendered, contains('No non-cascade traces'));
    expect(requestSummary.expectedTrialCount, 9);
    expect(requestSummary.traceCount, 3);
    expect(usageSummary.expectedTrialCount, 9);
    expect(usageSummary.traceCount, 3);
  });

  test('separates provider request stability by continuation turn', () {
    final traces = [
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: profile,
        providerRequests: [
          _providerRequest(),
          _providerRequest(
            requestIndex: 1,
            turnIndex: 2,
            messageDigest: 'sha256:turn-two-messages',
            messageCount: 5,
          ),
        ],
      ),
    ];

    final summaries = EvalReporter.summarizeProviderRequestStability(traces);

    expect(summaries, hasLength(2));
    expect(summaries.map((summary) => summary.turnIndex), [1, 2]);
    expect(summaries.map((summary) => summary.requestIndex), [0, 1]);
    expect(summaries.map((summary) => summary.messageCounts), [
      [2],
      [5],
    ]);
  });

  test('reports traces without provider request evidence in mixed runs', () {
    final traces = [
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: profile,
        providerRequests: [
          _providerRequest(),
        ],
      ),
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: profile,
        trialIndex: 1,
      ),
    ];

    final rendered = EvalReporter.render(traces);

    expect(rendered, contains('Provider request fingerprints'));
    expect(rendered, contains('traces without provider request evidence: 1'));
  });

  test('reports by profile and capability', () {
    final traces = [
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: profile,
      ),
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: profile,
        judgePassed: false,
      ),
    ];

    final summaries = EvalReporter.summarizeByCapability(traces);

    expect(
      summaries.map((summary) {
        return (
          summary.profileName,
          summary.capabilityId,
          summary.traceCount,
          summary.trialCount,
          summary.coverageRate,
          summary.judgedTraceRate,
          summary.judgePassRate,
          summary.judgeReliableScenarioRate,
        );
      }),
      [
        (
          'repeatable-frontier',
          'task.grooming.basic',
          1,
          3,
          1 / 3,
          1.0,
          1.0,
          0.0,
        ),
        (
          'repeatable-frontier',
          'task.grooming.labels',
          1,
          3,
          1 / 3,
          1.0,
          0.0,
          0.0,
        ),
      ],
    );
  });

  test('capability summary exposes missing trial and verdict coverage', () {
    final scenario = _scenarioWith(
      taskReleaseNotesScenario,
      id: 'capability_partial_judging',
      split: EvalScenarioSplit.holdout,
      capabilityId: 'task.capability.partial',
    );
    final traces = [
      _trace(
        scenario: scenario,
        profile: profile,
      ),
      _trace(
        scenario: scenario,
        profile: profile,
        trialIndex: 1,
        judged: false,
      ),
    ];

    final summary = EvalReporter.summarizeByCapability(traces).single;

    expect(summary.scenarioCount, 1);
    expect(summary.completeScenarioCount, 0);
    expect(summary.trialCount, 3);
    expect(summary.traceCount, 2);
    expect(summary.coverageRate, closeTo(2 / 3, 0.001));
    expect(summary.judgedCount, 1);
    expect(summary.judgedTraceRate, 0.5);
    expect(summary.judgePassRate, 1);
    expect(summary.judgeTracePassEstimate.total, 1);
    expect(summary.judgePassEstimate.total, 1);
    expect(summary.judgePassEstimate.successes, 0);
    expect(summary.judgeReliableScenarioCount, 0);
    expect(summary.judgeReliableScenarioRate, 0);

    final rendered = EvalReporter.render(traces);
    expect(rendered, contains('Capability summary'));
    expect(rendered, contains('coverage'));
    expect(rendered, contains('judged%'));
    expect(rendered, contains('judge pass^k'));
    expect(rendered, contains('task.capability.partial'));
    expect(rendered, contains('67%'));
    expect(rendered, contains('50%'));
  });

  test('reports split/model-class/capability denominators', () {
    const fastProfile = EvalProfile(
      name: 'frontier-fast-a',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-fast-a-model',
      tokenBudget: 10000,
      trialCount: 2,
    );
    const secondFastProfile = EvalProfile(
      name: 'frontier-fast-b',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-fast-b-model',
      tokenBudget: 10000,
    );
    final developmentScenario = _scenarioWith(
      taskReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.grooming.basic',
    );
    final holdoutScenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.holdout,
      capabilityId: 'task.grooming.basic',
    );
    final traces = [
      for (
        var trialIndex = 0;
        trialIndex < fastProfile.trialCount;
        trialIndex++
      )
        _trace(
          scenario: developmentScenario,
          profile: fastProfile,
          trialIndex: trialIndex,
        ),
      _trace(
        scenario: developmentScenario,
        profile: secondFastProfile,
        judged: false,
      ),
      _trace(
        scenario: holdoutScenario,
        profile: fastProfile,
      ),
    ];

    final summaries = EvalReporter.summarizeBySlice(traces);

    expect(summaries, hasLength(2));
    final development = summaries[0];
    expect(development.split, EvalScenarioSplit.development);
    expect(development.modelClass, EvalModelClass.frontierFast);
    expect(development.capabilityId, 'task.grooming.basic');
    expect(development.profileCount, 2);
    expect(development.scenarioCount, 1);
    expect(development.scenarioProfileCount, 2);
    expect(development.completeScenarioCount, 1);
    expect(development.completeScenarioProfileCount, 2);
    expect(development.trialCount, 3);
    expect(development.traceCount, 3);
    expect(development.level1ReliableScenarioProfileCount, 2);
    expect(development.judgedTraceCount, 2);
    expect(development.judgeReliableScenarioProfileCount, 1);
    expect(development.coverageRate, 1);
    expect(development.judgedTraceRate, closeTo(2 / 3, 0.001));

    final holdout = summaries[1];
    expect(holdout.split, EvalScenarioSplit.holdout);
    expect(holdout.modelClass, EvalModelClass.frontierFast);
    expect(holdout.capabilityId, 'task.grooming.basic');
    expect(holdout.profileCount, 1);
    expect(holdout.scenarioCount, 1);
    expect(holdout.scenarioProfileCount, 1);
    expect(holdout.completeScenarioCount, 0);
    expect(holdout.completeScenarioProfileCount, 0);
    expect(holdout.trialCount, 2);
    expect(holdout.traceCount, 1);
    expect(holdout.level1ReliableScenarioProfileCount, 0);
    expect(holdout.judgedTraceCount, 1);
    expect(holdout.judgeReliableScenarioProfileCount, 0);
    expect(holdout.coverageRate, 0.5);
    expect(holdout.judgedTraceRate, 1);
  });

  test('slice coverage counts missing scenario-profile cells', () {
    const firstProfile = EvalProfile(
      name: 'frontier-sparse-a',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-sparse-a-model',
      tokenBudget: 10000,
    );
    const secondProfile = EvalProfile(
      name: 'frontier-sparse-b',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-sparse-b-model',
      tokenBudget: 10000,
    );
    final firstScenario = _scenarioWith(
      taskReleaseNotesScenario,
      id: 'sparse_slice_first',
      split: EvalScenarioSplit.holdout,
      capabilityId: 'task.sparse.coverage',
    );
    final secondScenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      id: 'sparse_slice_second',
      split: EvalScenarioSplit.holdout,
      capabilityId: 'task.sparse.coverage',
    );
    final traces = [
      _trace(
        scenario: firstScenario,
        profile: firstProfile,
      ),
      _trace(
        scenario: secondScenario,
        profile: secondProfile,
      ),
    ];

    final summary = EvalReporter.summarizeBySlice(traces).single;

    expect(summary.profileCount, 2);
    expect(summary.scenarioCount, 2);
    expect(summary.scenarioProfileCount, 4);
    expect(summary.completeScenarioProfileCount, 2);
    expect(summary.completeScenarioCount, 0);
    expect(summary.trialCount, 4);
    expect(summary.traceCount, 2);
    expect(summary.coverageRate, 0.5);
  });

  test(
    'context slice coverage counts absent expected profiles and scenarios',
    () {
      const firstProfile = EvalProfile(
        name: 'frontier-expected-a',
        isLocal: false,
        modelClass: EvalModelClass.frontierFast,
        modelId: 'frontier-expected-a-model',
        tokenBudget: 10000,
      );
      const secondProfile = EvalProfile(
        name: 'frontier-expected-b',
        isLocal: false,
        modelClass: EvalModelClass.frontierFast,
        modelId: 'frontier-expected-b-model',
        tokenBudget: 10000,
        trialCount: 2,
      );
      final firstScenario = _scenarioWith(
        taskReleaseNotesScenario,
        id: 'expected_slice_first',
        split: EvalScenarioSplit.holdout,
        capabilityId: 'task.expected.coverage',
      );
      final secondScenario = _scenarioWith(
        taskWorkflowReleaseNotesScenario,
        id: 'expected_slice_second',
        split: EvalScenarioSplit.holdout,
        capabilityId: 'task.expected.coverage',
      );
      final traces = [
        _trace(
          scenario: firstScenario,
          profile: firstProfile,
        ),
      ];

      final observed = EvalReporter.summarizeBySlice(traces).single;
      final expected = EvalReporter.summarizeBySlice(
        traces,
        context: EvalReportContext(
          scenarios: [firstScenario, secondScenario],
          profiles: const [firstProfile, secondProfile],
        ),
      ).single;

      expect(observed.profileCount, 1);
      expect(observed.scenarioCount, 1);
      expect(observed.coverageRate, 1);
      expect(expected.profileCount, 2);
      expect(expected.scenarioCount, 2);
      expect(expected.scenarioProfileCount, 4);
      expect(expected.completeScenarioProfileCount, 1);
      expect(expected.completeScenarioCount, 0);
      expect(expected.trialCount, 6);
      expect(expected.traceCount, 1);
      expect(expected.coverageRate, closeTo(1 / 6, 0.001));

      final rendered = EvalReporter.render(
        traces,
        context: EvalReportContext(
          scenarios: [firstScenario, secondScenario],
          profiles: const [firstProfile, secondProfile],
        ),
      );
      expect(rendered, contains('expected matrix'));
      expect(rendered, contains('task.expected.coverage'));
      expect(rendered, contains('17%'));
    },
  );

  test('context slice coverage renders zero-trace expected slices', () {
    const expectedProfile = EvalProfile(
      name: 'frontier-empty-slice',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-empty-slice-model',
      tokenBudget: 10000,
    );
    final expectedScenario = _scenarioWith(
      taskReleaseNotesScenario,
      id: 'expected_empty_slice',
      split: EvalScenarioSplit.holdout,
      capabilityId: 'task.expected.empty',
    );

    final summaries = EvalReporter.summarizeBySlice(
      const <EvalTrace>[],
      context: EvalReportContext(
        scenarios: [expectedScenario],
        profiles: const [expectedProfile],
      ),
    );

    expect(summaries, hasLength(1));
    final summary = summaries.single;
    expect(summary.scenarioCount, 1);
    expect(summary.profileCount, 1);
    expect(summary.trialCount, 1);
    expect(summary.traceCount, 0);
    expect(summary.coverageRate, 0);
    final rendered = EvalReporter.render(
      const <EvalTrace>[],
      context: EvalReportContext(
        scenarios: [expectedScenario],
        profiles: const [expectedProfile],
      ),
    );
    expect(rendered, contains('expected matrix'));
    expect(rendered, contains('task.expected.empty'));
  });

  test('context slice coverage validates manifest digests', () {
    const expectedProfile = EvalProfile(
      name: 'frontier-digest-context',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-digest-context-model',
      tokenBudget: 10000,
    );
    final manifestScenario = _scenarioWith(
      taskReleaseNotesScenario,
      id: 'manifest_digest_slice',
      split: EvalScenarioSplit.holdout,
      capabilityId: 'task.expected.digest',
    );
    final extraScenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      id: 'extra_digest_slice',
      split: EvalScenarioSplit.holdout,
      capabilityId: 'task.expected.digest',
    );
    final manifest = _manifestFor(
      scenarios: [manifestScenario],
      profiles: const [expectedProfile],
    );

    expect(
      () => EvalReporter.summarizeBySlice(
        const <EvalTrace>[],
        context: EvalReportContext(
          scenarios: [manifestScenario, extraScenario],
          profiles: const [expectedProfile],
          manifest: manifest,
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('scenarioSetDigest'),
        ),
      ),
    );
  });

  test('context slice coverage uses canonical profile trial counts', () {
    const canonicalProfile = EvalProfile(
      name: 'frontier-canonical-trials',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-canonical-trials-model',
      tokenBudget: 10000,
      trialCount: 3,
    );
    const traceProfile = EvalProfile(
      name: 'frontier-canonical-trials',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-canonical-trials-model',
      tokenBudget: 10000,
    );
    final scenario = _scenarioWith(
      taskReleaseNotesScenario,
      id: 'canonical_trial_count_slice',
      split: EvalScenarioSplit.holdout,
      capabilityId: 'task.expected.trials',
    );
    final traces = [
      _trace(
        scenario: scenario,
        profile: traceProfile,
      ),
    ];

    final summary = EvalReporter.summarizeBySlice(
      traces,
      context: EvalReportContext(
        scenarios: [scenario],
        profiles: const [canonicalProfile],
      ),
    ).single;

    expect(summary.trialCount, 3);
    expect(summary.traceCount, 1);
    expect(summary.completeScenarioProfileCount, 0);
    expect(summary.coverageRate, closeTo(1 / 3, 0.001));
  });

  test('compares profiles over paired complete scenarios', () {
    const leftProfile = EvalProfile(
      name: 'frontier-a',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-a-model',
      tokenBudget: 10000,
    );
    const rightProfile = EvalProfile(
      name: 'frontier-b',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-b-model',
      tokenBudget: 10000,
    );
    final sameOutcomeScenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      id: 'task_same_outcome',
      split: EvalScenarioSplit.development,
      capabilityId: 'task.grooming.basic',
    );
    final missingVerdictScenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      id: 'task_missing_verdict',
      split: EvalScenarioSplit.development,
      capabilityId: 'task.grooming.basic',
    );
    final duplicateScenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      id: 'task_duplicate',
      split: EvalScenarioSplit.development,
      capabilityId: 'task.grooming.basic',
    );
    final leftOnlyScenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      id: 'task_left_only',
      split: EvalScenarioSplit.development,
      capabilityId: 'task.grooming.basic',
    );
    final rightOnlyScenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      id: 'task_right_only',
      split: EvalScenarioSplit.development,
      capabilityId: 'task.grooming.basic',
    );
    final traces = [
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: leftProfile,
        goalAttainment: 5,
        quality: 4,
        efficiency: 3,
      ),
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: rightProfile,
        level1Passed: false,
        judgePassed: false,
        goalAttainment: 2,
        quality: 3,
        efficiency: 4,
      ),
      _trace(
        scenario: sameOutcomeScenario,
        profile: leftProfile,
        level1Passed: false,
        judgePassed: false,
        goalAttainment: 2,
        quality: 2,
        efficiency: 2,
      ),
      _trace(
        scenario: sameOutcomeScenario,
        profile: rightProfile,
        level1Passed: false,
        judgePassed: false,
        goalAttainment: 2,
        quality: 2,
        efficiency: 2,
      ),
      _trace(
        scenario: missingVerdictScenario,
        profile: leftProfile,
      ),
      _trace(
        scenario: missingVerdictScenario,
        profile: rightProfile,
        judged: false,
      ),
      _trace(
        scenario: duplicateScenario,
        profile: leftProfile,
      ),
      _trace(
        scenario: duplicateScenario,
        profile: rightProfile,
      ),
      _trace(
        scenario: duplicateScenario,
        profile: rightProfile,
      ),
      _trace(
        scenario: leftOnlyScenario,
        profile: leftProfile,
      ),
      _trace(
        scenario: rightOnlyScenario,
        profile: rightProfile,
      ),
    ];

    final comparison = EvalReporter.compareProfiles(traces).single;

    expect(comparison.leftProfileName, 'frontier-a');
    expect(comparison.rightProfileName, 'frontier-b');
    expect(comparison.pairedScenarioCount, 3);
    expect(comparison.leftOnlyScenarioCount, 1);
    expect(comparison.rightOnlyScenarioCount, 1);
    expect(comparison.incompleteScenarioCount, 1);
    expect(comparison.level1LeftPassCount, 2);
    expect(comparison.level1RightPassCount, 1);
    expect(comparison.level1LeftOnlyPassCount, 1);
    expect(comparison.level1RightOnlyPassCount, 0);
    expect(comparison.level1SameOutcomeCount, 2);
    expect(comparison.level1PassDelta, closeTo(1 / 3, 0.001));
    expect(comparison.judgePairedScenarioCount, 2);
    expect(comparison.judgeMissingScenarioCount, 1);
    expect(comparison.judgeLeftPassCount, 1);
    expect(comparison.judgeRightPassCount, 0);
    expect(comparison.judgeDiscordantScenarioCount, 1);
    expect(comparison.judgePairedSignTestPValue, 0.5);
    expect(comparison.judgePassDelta, 0.5);
    expect(comparison.meanGoalAttainmentDelta, 1.5);
    expect(comparison.meanQualityDelta, 0.5);
    expect(comparison.meanEfficiencyDelta, -0.5);

    final rendered = EvalReporter.render(traces);
    expect(rendered, contains('Paired profile comparison'));
    expect(rendered, contains('+33%'));
    expect(rendered, contains('+50%'));
    expect(rendered, contains('+1.5 / +0.5 / -0.5'));
    expect(rendered, contains('low n'));
  });

  test('promotes a profile only with strong paired evidence', () {
    const candidate = EvalProfile(
      name: 'candidate-frontier',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'candidate-model',
      tokenBudget: 10000,
    );
    const baseline = EvalProfile(
      name: 'baseline-frontier',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'baseline-model',
      tokenBudget: 10000,
    );
    final scenarios = [
      for (var index = 0; index < 12; index++)
        _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'promotion_scenario_$index',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.promotion',
        ),
    ];
    final traces = [
      for (var index = 0; index < scenarios.length; index++) ...[
        _trace(
          scenario: scenarios[index],
          profile: candidate,
          inputTokens: 95,
          outputTokens: 35,
          goalAttainment: 5,
          quality: 5,
          efficiency: 4,
        ),
        _trace(
          scenario: scenarios[index],
          profile: baseline,
          inputTokens: 110,
          outputTokens: 40,
          judgePassed: index < 4,
          goalAttainment: index < 4 ? 4 : 2,
          quality: index < 4 ? 4 : 2,
          efficiency: 4,
        ),
      ],
    ];

    final decision = EvalReporter.evaluateProfilePromotion(
      traces: traces,
      policy: const ProfilePromotionPolicy(
        candidateProfileName: 'candidate-frontier',
        baselineProfileName: 'baseline-frontier',
        requireTuningReadiness: false,
        minJudgePassDelta: 0.4,
        minJudgePassDeltaLowerBound: 0.1,
        maxTotalTokenRatio: 1,
      ),
    );

    expect(decision.promote, isTrue);
    expect(decision.status, ProfilePromotionStatus.promote);
    expect(decision.failures, isEmpty);
    expect(decision.comparison?.pairedScenarioCount, 12);
    expect(decision.comparison?.judgePassDelta, closeTo(8 / 12, 0.001));
    expect(decision.comparison?.judgePassDeltaLowerBound, greaterThan(0.1));
    expect(decision.comparison?.judgeLeftOnlyPassCount, 8);
    expect(decision.comparison?.judgeRightOnlyPassCount, 0);
    expect(
      decision.comparison?.judgePairedSignTestPValue,
      closeTo(1 / 256, 0.0001),
    );
    expect(decision.comparison?.totalTokenRatio, closeTo(130 / 150, 0.001));
    final rendered = EvalReporter.renderProfilePromotion(decision);
    expect(rendered, contains('Profile promotion: candidate-frontier vs'));
    expect(rendered, contains('promote'));
    expect(
      rendered,
      contains('paired=12 leftOnly=0 rightOnly=0 incomplete=0'),
    );
    expect(rendered, contains('judgePaired=12 judgeMissing=0'));
    expect(rendered, contains('judgeDelta=+67%'));
    expect(rendered, contains('candidateWins=8'));
    expect(rendered, contains('baselineWins=0'));
    expect(rendered, contains('discordant=8'));
    expect(rendered, contains('candidateSignP=0.004'));
  });

  test(
    'promotion blocks unpaired profile-only scenarios even when paired subset '
    'clears gates',
    () {
      const candidate = EvalProfile(
        name: 'candidate-overlap',
        isLocal: false,
        modelClass: EvalModelClass.frontierFast,
        modelId: 'candidate-overlap-model',
        tokenBudget: 10000,
      );
      const baseline = EvalProfile(
        name: 'baseline-overlap',
        isLocal: false,
        modelClass: EvalModelClass.frontierFast,
        modelId: 'baseline-overlap-model',
        tokenBudget: 10000,
      );
      final pairedScenarios = [
        for (var index = 0; index < 12; index++)
          _scenarioWith(
            taskWorkflowReleaseNotesScenario,
            id: 'overlap_paired_scenario_$index',
            split: EvalScenarioSplit.holdout,
            capabilityId: 'task.promotion.overlap',
          ),
      ];
      final candidateOnlyScenario = _scenarioWith(
        taskWorkflowReleaseNotesScenario,
        id: 'overlap_candidate_only',
        split: EvalScenarioSplit.holdout,
        capabilityId: 'task.promotion.overlap',
      );
      final baselineOnlyScenario = _scenarioWith(
        taskWorkflowReleaseNotesScenario,
        id: 'overlap_baseline_only',
        split: EvalScenarioSplit.holdout,
        capabilityId: 'task.promotion.overlap',
      );
      final traces = [
        for (var index = 0; index < pairedScenarios.length; index++) ...[
          _trace(
            scenario: pairedScenarios[index],
            profile: candidate,
            inputTokens: 95,
            outputTokens: 35,
            goalAttainment: 5,
            quality: 5,
            efficiency: 4,
          ),
          _trace(
            scenario: pairedScenarios[index],
            profile: baseline,
            inputTokens: 110,
            outputTokens: 40,
            judgePassed: index < 4,
            goalAttainment: index < 4 ? 4 : 2,
            quality: index < 4 ? 4 : 2,
            efficiency: 4,
          ),
        ],
        _trace(
          scenario: candidateOnlyScenario,
          profile: candidate,
          goalAttainment: 5,
          quality: 5,
          efficiency: 4,
        ),
        _trace(
          scenario: baselineOnlyScenario,
          profile: baseline,
          judgePassed: false,
          goalAttainment: 2,
          quality: 2,
          efficiency: 4,
        ),
      ];

      final decision = EvalReporter.evaluateProfilePromotion(
        traces: traces,
        policy: const ProfilePromotionPolicy(
          candidateProfileName: 'candidate-overlap',
          baselineProfileName: 'baseline-overlap',
          requireTuningReadiness: false,
          minJudgePassDelta: 0.4,
          minJudgePassDeltaLowerBound: 0.1,
          maxTotalTokenRatio: 1,
        ),
      );

      expect(decision.promote, isFalse);
      expect(decision.status, ProfilePromotionStatus.blocked);
      expect(decision.comparison?.pairedScenarioCount, 12);
      expect(decision.comparison?.leftOnlyScenarioCount, 1);
      expect(decision.comparison?.rightOnlyScenarioCount, 1);
      expect(
        decision.failures,
        containsAll({
          'promotion blocked: candidate-only scenarios 1 > 0',
          'promotion blocked: baseline-only scenarios 1 > 0',
        }),
      );
      final rendered = EvalReporter.renderProfilePromotion(decision);
      expect(
        rendered,
        contains('paired=12 leftOnly=1 rightOnly=1 incomplete=0'),
      );
      expect(rendered, contains('judgePaired=12 judgeMissing=0'));
    },
  );

  test('promotion enforces discordant evidence when verdicts are missing', () {
    const candidate = EvalProfile(
      name: 'candidate-missing-discordance',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'candidate-missing-discordance-model',
      tokenBudget: 10000,
    );
    const baseline = EvalProfile(
      name: 'baseline-missing-discordance',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'baseline-missing-discordance-model',
      tokenBudget: 10000,
    );
    final scenarios = [
      for (var index = 0; index < 12; index++)
        _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'missing_discordance_promotion_scenario_$index',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.promotion.missing_discordance',
        ),
    ];
    final traces = [
      for (var index = 0; index < scenarios.length; index++) ...[
        _trace(
          scenario: scenarios[index],
          profile: candidate,
          judged: index != 11,
          inputTokens: 95,
          outputTokens: 35,
          goalAttainment: 5,
          quality: 5,
          efficiency: 4,
        ),
        _trace(
          scenario: scenarios[index],
          profile: baseline,
          inputTokens: 110,
          outputTokens: 40,
          judgePassed: index < 4,
          goalAttainment: index < 4 ? 4 : 2,
          quality: index < 4 ? 4 : 2,
          efficiency: 4,
        ),
      ],
    ];

    final decision = EvalReporter.evaluateProfilePromotion(
      traces: traces,
      policy: const ProfilePromotionPolicy(
        candidateProfileName: 'candidate-missing-discordance',
        baselineProfileName: 'baseline-missing-discordance',
        requireTuningReadiness: false,
        requireNoMissingJudgeVerdicts: false,
        minJudgePairedScenarioCount: 11,
        minJudgeDiscordantScenarioCount: 8,
      ),
    );

    expect(decision.status, ProfilePromotionStatus.inconclusive);
    expect(decision.comparison?.pairedScenarioCount, 12);
    expect(decision.comparison?.judgePairedScenarioCount, 11);
    expect(decision.comparison?.judgeMissingScenarioCount, 1);
    expect(decision.comparison?.judgeDiscordantScenarioCount, 7);
    expect(
      decision.failures,
      isNot(
        contains(
          'promotion blocked: paired scenarios with missing judge verdicts '
          '1 > 0',
        ),
      ),
    );
    expect(
      decision.failures,
      contains(
        'promotion inconclusive: paired judge discordant scenario count 7 < 8',
      ),
    );
    expect(
      EvalReporter.renderProfilePromotion(decision),
      contains('judgePaired=11 judgeMissing=1'),
    );
  });

  test('promotion policy JSON includes every decision threshold', () {
    const policy = ProfilePromotionPolicy(
      candidateProfileName: 'candidate-frontier',
      baselineProfileName: 'baseline-frontier',
      requireTuningReadiness: false,
      requireNoMissingJudgeVerdicts: false,
      requireNoLevel1Regression: false,
      minPairedScenarioCount: 13,
      minJudgePairedScenarioCount: 14,
      minJudgeDiscordantScenarioCount: 7,
      minJudgePassDelta: 0.11,
      minJudgePassDeltaLowerBound: 0.02,
      minLevel1PassDelta: 0.03,
      minLevel1PassDeltaLowerBound: -0.04,
      minMeanGoalAttainmentDelta: 0.5,
      minMeanQualityDelta: 0.25,
      minMeanEfficiencyDelta: -0.1,
      maxTotalTokenRatio: 1.1,
      maxEstimatedCostRatio: 1.2,
      maxJudgePairedSignTestPValue: 0.05,
    );

    expect(EvalReporter.promotionPolicyJson(policy), {
      'schemaVersion': 1,
      'candidateProfileName': 'candidate-frontier',
      'baselineProfileName': 'baseline-frontier',
      'requireTuningReadiness': false,
      'requireNoMissingJudgeVerdicts': false,
      'requireNoLevel1Regression': false,
      'minPairedScenarioCount': 13,
      'minJudgePairedScenarioCount': 14,
      'minJudgeDiscordantScenarioCount': 7,
      'minJudgePassDelta': 0.11,
      'minJudgePassDeltaLowerBound': 0.02,
      'minLevel1PassDelta': 0.03,
      'minLevel1PassDeltaLowerBound': -0.04,
      'minMeanGoalAttainmentDelta': 0.5,
      'minMeanQualityDelta': 0.25,
      'minMeanEfficiencyDelta': -0.1,
      'maxTotalTokenRatio': 1.1,
      'maxEstimatedCostRatio': 1.2,
      'maxJudgePairedSignTestPValue': 0.05,
    });
  });

  test('promotion decisions require tuning readiness by default', () {
    final decision = EvalReporter.evaluateProfilePromotion(
      traces: const [],
      policy: const ProfilePromotionPolicy(
        candidateProfileName: 'candidate-frontier',
        baselineProfileName: 'baseline-frontier',
      ),
    );

    expect(decision.promote, isFalse);
    expect(decision.status, ProfilePromotionStatus.blocked);
    expect(decision.comparison, isNull);
    expect(
      decision.failures,
      containsAll({
        'promotion blocked: tuning-readiness report is required',
        'promotion blocked: missing candidate profile candidate-frontier',
        'promotion blocked: missing baseline profile baseline-frontier',
      }),
    );
  });

  test('promotion is inconclusive when lower bound is too weak', () {
    const candidate = EvalProfile(
      name: 'candidate-close',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'candidate-close-model',
      tokenBudget: 10000,
    );
    const baseline = EvalProfile(
      name: 'baseline-close',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'baseline-close-model',
      tokenBudget: 10000,
    );
    final scenarios = [
      for (var index = 0; index < 12; index++)
        _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'close_promotion_scenario_$index',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.promotion.close',
        ),
    ];
    final traces = [
      for (var index = 0; index < scenarios.length; index++) ...[
        _trace(
          scenario: scenarios[index],
          profile: candidate,
          judgePassed: index < 8,
          goalAttainment: index < 8 ? 5 : 2,
          quality: index < 8 ? 5 : 2,
          efficiency: 4,
        ),
        _trace(
          scenario: scenarios[index],
          profile: baseline,
          judgePassed: index < 6,
          goalAttainment: index < 6 ? 4 : 2,
          quality: index < 6 ? 4 : 2,
          efficiency: 4,
        ),
      ],
    ];

    final decision = EvalReporter.evaluateProfilePromotion(
      traces: traces,
      policy: const ProfilePromotionPolicy(
        candidateProfileName: 'candidate-close',
        baselineProfileName: 'baseline-close',
        requireTuningReadiness: false,
      ),
    );

    expect(decision.status, ProfilePromotionStatus.inconclusive);
    expect(decision.comparison?.judgePassDelta, closeTo(2 / 12, 0.001));
    final plan = decision.evidencePlan!;
    expect(plan.additionalPairedScenariosForMinCount, 0);
    expect(plan.additionalJudgeScenariosForMinCount, 0);
    expect(plan.additionalJudgeScenariosForLowerBound, greaterThan(0));
    expect(plan.recommendedAdditionalJudgeScenarios, greaterThan(0));
    expect(plan.projectedJudgePassDeltaLowerBound, greaterThanOrEqualTo(0));
    expect(
      decision.failures,
      contains(
        startsWith(
          'promotion inconclusive: judge pass delta lower bound ',
        ),
      ),
    );
    final rendered = EvalReporter.renderProfilePromotion(decision);
    expect(rendered, contains('Promotion evidence plan (planning only)'));
    expect(rendered, contains('lower-bound sample gap'));
    expect(rendered, contains('recommended additional judged pairs'));
  });

  test('promotion is inconclusive when paired wins are underpowered', () {
    const candidate = EvalProfile(
      name: 'candidate-underpaired',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'candidate-underpaired-model',
      tokenBudget: 10000,
    );
    const baseline = EvalProfile(
      name: 'baseline-underpaired',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'baseline-underpaired-model',
      tokenBudget: 10000,
    );
    final scenarios = [
      for (var index = 0; index < 12; index++)
        _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'underpaired_promotion_scenario_$index',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.promotion.underpaired',
        ),
    ];
    final traces = [
      for (var index = 0; index < scenarios.length; index++) ...[
        _trace(
          scenario: scenarios[index],
          profile: candidate,
          judgePassed: index < 8,
          goalAttainment: index < 8 ? 5 : 2,
          quality: index < 8 ? 5 : 2,
          efficiency: 4,
        ),
        _trace(
          scenario: scenarios[index],
          profile: baseline,
          judgePassed: index >= 4 && index < 8,
          goalAttainment: index >= 4 && index < 8 ? 4 : 2,
          quality: index >= 4 && index < 8 ? 4 : 2,
          efficiency: 4,
        ),
      ],
    ];

    final decision = EvalReporter.evaluateProfilePromotion(
      traces: traces,
      policy: const ProfilePromotionPolicy(
        candidateProfileName: 'candidate-underpaired',
        baselineProfileName: 'baseline-underpaired',
        requireTuningReadiness: false,
        minJudgeDiscordantScenarioCount: 4,
        minJudgePassDelta: 0.2,
        minJudgePassDeltaLowerBound: -1,
        maxJudgePairedSignTestPValue: 0.05,
      ),
    );

    expect(decision.status, ProfilePromotionStatus.inconclusive);
    expect(decision.comparison?.judgePassDelta, closeTo(4 / 12, 0.001));
    expect(decision.comparison?.judgeLeftOnlyPassCount, 4);
    expect(decision.comparison?.judgeRightOnlyPassCount, 0);
    expect(decision.comparison?.judgePairedSignTestPValue, 0.0625);
    expect(
      decision.failures,
      contains(
        'promotion inconclusive: paired judge one-sided sign-test p-value '
        '0.063 > 0.050 (candidateWins 4, baselineWins 0, discordant 4)',
      ),
    );
    expect(
      decision.evidencePlan?.additionalJudgeScenariosForPairedSignTest,
      greaterThan(0),
    );
    expect(
      EvalReporter.renderProfilePromotion(decision),
      contains('paired discordant/sign-test sample gap'),
    );
  });

  test('promotion requires enough discordant paired judge outcomes', () {
    const candidate = EvalProfile(
      name: 'candidate-low-discordance',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'candidate-low-discordance-model',
      tokenBudget: 10000,
    );
    const baseline = EvalProfile(
      name: 'baseline-low-discordance',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'baseline-low-discordance-model',
      tokenBudget: 10000,
    );
    final scenarios = [
      for (var index = 0; index < 12; index++)
        _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'low_discordance_promotion_scenario_$index',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.promotion.low_discordance',
        ),
    ];
    final traces = [
      for (var index = 0; index < scenarios.length; index++) ...[
        _trace(
          scenario: scenarios[index],
          profile: candidate,
          judgePassed: index < 9,
          goalAttainment: index < 9 ? 5 : 2,
          quality: index < 9 ? 5 : 2,
          efficiency: 4,
        ),
        _trace(
          scenario: scenarios[index],
          profile: baseline,
          judgePassed: index >= 5 && index < 9,
          goalAttainment: index >= 5 && index < 9 ? 4 : 2,
          quality: index >= 5 && index < 9 ? 4 : 2,
          efficiency: 4,
        ),
      ],
    ];

    final decision = EvalReporter.evaluateProfilePromotion(
      traces: traces,
      policy: const ProfilePromotionPolicy(
        candidateProfileName: 'candidate-low-discordance',
        baselineProfileName: 'baseline-low-discordance',
        requireTuningReadiness: false,
        minJudgePassDelta: 0.2,
        minJudgePassDeltaLowerBound: -1,
      ),
    );

    expect(decision.status, ProfilePromotionStatus.inconclusive);
    expect(decision.comparison?.judgeLeftOnlyPassCount, 5);
    expect(decision.comparison?.judgeRightOnlyPassCount, 0);
    expect(decision.comparison?.judgePairedSignTestPValue, 0.03125);
    expect(
      decision.failures,
      contains(
        'promotion inconclusive: paired judge discordant scenario count 5 < 6',
      ),
    );
  });

  test('promotion reports no paired win evidence when outcomes match', () {
    const candidate = EvalProfile(
      name: 'candidate-same-outcomes',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'candidate-same-outcomes-model',
      tokenBudget: 10000,
    );
    const baseline = EvalProfile(
      name: 'baseline-same-outcomes',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'baseline-same-outcomes-model',
      tokenBudget: 10000,
    );
    final scenarios = [
      for (var index = 0; index < 12; index++)
        _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'same_outcome_promotion_scenario_$index',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.promotion.same_outcomes',
        ),
    ];
    final traces = [
      for (var index = 0; index < scenarios.length; index++) ...[
        _trace(
          scenario: scenarios[index],
          profile: candidate,
          judgePassed: index < 8,
          goalAttainment: index < 8 ? 5 : 2,
          quality: index < 8 ? 5 : 2,
          efficiency: 4,
        ),
        _trace(
          scenario: scenarios[index],
          profile: baseline,
          judgePassed: index < 8,
          goalAttainment: index < 8 ? 4 : 2,
          quality: index < 8 ? 4 : 2,
          efficiency: 4,
        ),
      ],
    ];

    final decision = EvalReporter.evaluateProfilePromotion(
      traces: traces,
      policy: const ProfilePromotionPolicy(
        candidateProfileName: 'candidate-same-outcomes',
        baselineProfileName: 'baseline-same-outcomes',
        requireTuningReadiness: false,
        minJudgePassDelta: 0,
        minJudgePassDeltaLowerBound: -1,
      ),
    );

    expect(decision.status, ProfilePromotionStatus.inconclusive);
    expect(decision.comparison?.judgeDiscordantScenarioCount, 0);
    expect(
      decision.failures,
      contains(
        'promotion inconclusive: no discordant paired judge outcomes; '
        'candidate and baseline have the same pass/fail outcomes',
      ),
    );
  });

  test('promotion rejects an expensive candidate despite quality gains', () {
    const candidate = EvalProfile(
      name: 'candidate-costly',
      isLocal: false,
      modelClass: EvalModelClass.frontierReasoning,
      modelId: 'candidate-costly-model',
      tokenBudget: 30000,
    );
    const baseline = EvalProfile(
      name: 'baseline-costly',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'baseline-costly-model',
      tokenBudget: 10000,
    );
    final scenarios = [
      for (var index = 0; index < 12; index++)
        _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'costly_promotion_scenario_$index',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.promotion.cost',
        ),
    ];
    final traces = [
      for (var index = 0; index < scenarios.length; index++) ...[
        _trace(
          scenario: scenarios[index],
          profile: candidate,
          inputTokens: 300,
          outputTokens: 100,
          goalAttainment: 5,
          quality: 5,
          efficiency: 4,
        ),
        _trace(
          scenario: scenarios[index],
          profile: baseline,
          judgePassed: index < 4,
          goalAttainment: index < 4 ? 4 : 2,
          quality: index < 4 ? 4 : 2,
          efficiency: 4,
        ),
      ],
    ];

    final decision = EvalReporter.evaluateProfilePromotion(
      traces: traces,
      policy: const ProfilePromotionPolicy(
        candidateProfileName: 'candidate-costly',
        baselineProfileName: 'baseline-costly',
        requireTuningReadiness: false,
      ),
    );

    expect(decision.status, ProfilePromotionStatus.reject);
    expect(
      decision.failures,
      contains(
        'promotion rejected: mean token regression +167% > +25% '
        '(ratio 2.67x > 1.25x)',
      ),
    );
  });

  test('promotion rejects weighted-cost regression despite stable tokens', () {
    const candidate = EvalProfile(
      name: 'candidate-weighted-costly',
      isLocal: false,
      modelClass: EvalModelClass.frontierReasoning,
      modelId: 'candidate-weighted-costly-model',
      tokenBudget: 10000,
      inputTokenCostMicros: 4,
      outputTokenCostMicros: 20,
      cachedInputTokenCostMicros: 4,
      thoughtsTokenCostMicros: 20,
    );
    const baseline = EvalProfile(
      name: 'baseline-weighted-cheap',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'baseline-weighted-cheap-model',
      tokenBudget: 10000,
    );
    final scenarios = [
      for (var index = 0; index < 12; index++)
        _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'weighted_costly_promotion_scenario_$index',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.promotion.weighted_cost',
        ),
    ];
    final traces = [
      for (var index = 0; index < scenarios.length; index++) ...[
        _trace(
          scenario: scenarios[index],
          profile: candidate,
          goalAttainment: 5,
          quality: 5,
          efficiency: 4,
        ),
        _trace(
          scenario: scenarios[index],
          profile: baseline,
          judgePassed: index < 4,
          goalAttainment: index < 4 ? 4 : 2,
          quality: index < 4 ? 4 : 2,
          efficiency: 4,
        ),
      ],
    ];

    final decision = EvalReporter.evaluateProfilePromotion(
      traces: traces,
      policy: const ProfilePromotionPolicy(
        candidateProfileName: 'candidate-weighted-costly',
        baselineProfileName: 'baseline-weighted-cheap',
        requireTuningReadiness: false,
      ),
    );

    expect(decision.status, ProfilePromotionStatus.reject);
    expect(decision.comparison?.usesEstimatedCost, isTrue);
    expect(decision.comparison?.totalTokenRatio, 1);
    expect(decision.comparison?.estimatedCostRatio, closeTo(1400 / 150, 0.001));
    expect(
      decision.failures,
      contains(
        'promotion rejected: mean estimated cost regression +833% > +25% '
        '(ratio 9.33x > 1.25x)',
      ),
    );
    expect(
      EvalReporter.renderProfilePromotion(decision),
      contains('costMode=weighted'),
    );
  });

  test('promotion uses weighted cost instead of raw token ratio', () {
    const candidate = EvalProfile(
      name: 'candidate-token-heavy-cheap',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'candidate-token-heavy-cheap-model',
      tokenBudget: 30000,
    );
    const baseline = EvalProfile(
      name: 'baseline-token-light-expensive',
      isLocal: false,
      modelClass: EvalModelClass.frontierReasoning,
      modelId: 'baseline-token-light-expensive-model',
      tokenBudget: 10000,
      inputTokenCostMicros: 10,
      outputTokenCostMicros: 10,
      cachedInputTokenCostMicros: 10,
      thoughtsTokenCostMicros: 10,
    );
    final scenarios = [
      for (var index = 0; index < 12; index++)
        _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'weighted_cheaper_promotion_scenario_$index',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.promotion.weighted_cheaper',
        ),
    ];
    final traces = [
      for (var index = 0; index < scenarios.length; index++) ...[
        _trace(
          scenario: scenarios[index],
          profile: candidate,
          inputTokens: 300,
          outputTokens: 100,
          goalAttainment: 5,
          quality: 5,
          efficiency: 4,
        ),
        _trace(
          scenario: scenarios[index],
          profile: baseline,
          judgePassed: index < 4,
          goalAttainment: index < 4 ? 4 : 2,
          quality: index < 4 ? 4 : 2,
          efficiency: 4,
        ),
      ],
    ];

    final decision = EvalReporter.evaluateProfilePromotion(
      traces: traces,
      policy: const ProfilePromotionPolicy(
        candidateProfileName: 'candidate-token-heavy-cheap',
        baselineProfileName: 'baseline-token-light-expensive',
        requireTuningReadiness: false,
      ),
    );

    expect(decision.status, ProfilePromotionStatus.promote);
    expect(decision.comparison?.usesEstimatedCost, isTrue);
    expect(decision.comparison?.totalTokenRatio, closeTo(400 / 150, 0.001));
    expect(decision.comparison?.estimatedCostRatio, closeTo(400 / 1500, 0.001));
    expect(
      decision.failures,
      isNot(
        contains(
          startsWith('promotion rejected: mean token regression'),
        ),
      ),
    );
  });

  test('promotion blocks when weighted cost evidence is missing', () {
    const candidate = EvalProfile(
      name: 'candidate-missing-cost',
      isLocal: false,
      modelClass: EvalModelClass.frontierReasoning,
      modelId: 'candidate-missing-cost-model',
      tokenBudget: 10000,
      inputTokenCostMicros: 4,
      outputTokenCostMicros: 20,
      cachedInputTokenCostMicros: 4,
      thoughtsTokenCostMicros: 20,
    );
    const baseline = EvalProfile(
      name: 'baseline-complete-cost',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'baseline-complete-cost-model',
      tokenBudget: 10000,
    );
    final scenarios = [
      for (var index = 0; index < 12; index++)
        _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'missing_cost_promotion_scenario_$index',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.promotion.missing_cost',
        ),
    ];
    final traces = [
      for (var index = 0; index < scenarios.length; index++) ...[
        _trace(
          scenario: scenarios[index],
          profile: candidate,
          outputTokens: index == 0 ? null : 50,
          goalAttainment: 5,
          quality: 5,
          efficiency: 4,
        ),
        _trace(
          scenario: scenarios[index],
          profile: baseline,
          judgePassed: index < 4,
          goalAttainment: index < 4 ? 4 : 2,
          quality: index < 4 ? 4 : 2,
          efficiency: 4,
        ),
      ],
    ];

    final decision = EvalReporter.evaluateProfilePromotion(
      traces: traces,
      policy: const ProfilePromotionPolicy(
        candidateProfileName: 'candidate-missing-cost',
        baselineProfileName: 'baseline-complete-cost',
        requireTuningReadiness: false,
      ),
    );

    expect(decision.status, ProfilePromotionStatus.blocked);
    expect(decision.comparison?.estimatedCostScenarioCount, 11);
    expect(decision.comparison?.estimatedCostMissingScenarioCount, 1);
    expect(
      decision.failures,
      contains(
        'promotion blocked: paired scenarios with missing token/cost evidence '
        '1 > 0',
      ),
    );
    expect(
      EvalReporter.renderProfilePromotion(decision),
      contains('missingCost=1'),
    );
  });

  test('promotion blocks when default token evidence is missing', () {
    const candidate = EvalProfile(
      name: 'candidate-missing-tokens',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'candidate-missing-tokens-model',
      tokenBudget: 10000,
    );
    const baseline = EvalProfile(
      name: 'baseline-complete-tokens',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'baseline-complete-tokens-model',
      tokenBudget: 10000,
    );
    final scenarios = [
      for (var index = 0; index < 12; index++)
        _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'missing_tokens_promotion_scenario_$index',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.promotion.missing_tokens',
        ),
    ];
    final traces = [
      for (var index = 0; index < scenarios.length; index++) ...[
        _trace(
          scenario: scenarios[index],
          profile: candidate,
          outputTokens: index == 0 ? null : 50,
          goalAttainment: 5,
          quality: 5,
          efficiency: 4,
        ),
        _trace(
          scenario: scenarios[index],
          profile: baseline,
          judgePassed: index < 4,
          goalAttainment: index < 4 ? 4 : 2,
          quality: index < 4 ? 4 : 2,
          efficiency: 4,
        ),
      ],
    ];

    final decision = EvalReporter.evaluateProfilePromotion(
      traces: traces,
      policy: const ProfilePromotionPolicy(
        candidateProfileName: 'candidate-missing-tokens',
        baselineProfileName: 'baseline-complete-tokens',
        requireTuningReadiness: false,
      ),
    );

    expect(decision.status, ProfilePromotionStatus.blocked);
    expect(decision.comparison?.estimatedCostScenarioCount, 11);
    expect(decision.comparison?.estimatedCostMissingScenarioCount, 1);
    expect(decision.comparison?.totalTokenRatio, 1);
    expect(
      decision.failures,
      contains(
        'promotion blocked: paired scenarios with missing token/cost evidence '
        '1 > 0',
      ),
    );
    final rendered = EvalReporter.renderProfilePromotion(decision);
    expect(rendered, contains('costMode=token'));
    expect(rendered, contains('missingCost=1'));
  });

  test('default profile comparisons ignore thought and cached tokens', () {
    const leftProfile = EvalProfile(
      name: 'left-default-cost',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'left-default-cost-model',
      tokenBudget: 10000,
    );
    const rightProfile = EvalProfile(
      name: 'right-default-cost',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'right-default-cost-model',
      tokenBudget: 10000,
    );
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      id: 'default_cost_mode_scenario',
      split: EvalScenarioSplit.holdout,
      capabilityId: 'task.promotion.default_cost',
    );
    final comparison = EvalReporter.compareProfiles([
      _trace(
        scenario: scenario,
        profile: leftProfile,
        thoughtsTokens: 1000,
        cachedInputTokens: 80,
      ),
      _trace(
        scenario: scenario,
        profile: rightProfile,
      ),
    ]).single;

    expect(comparison.usesEstimatedCost, isFalse);
    expect(comparison.totalTokenRatio, 1);
    expect(comparison.estimatedCostRatio, 1);
  });

  test('promotion evidence plan is unavailable when effect is too small', () {
    const candidate = EvalProfile(
      name: 'candidate-small-effect',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'candidate-small-effect-model',
      tokenBudget: 10000,
    );
    const baseline = EvalProfile(
      name: 'baseline-small-effect',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'baseline-small-effect-model',
      tokenBudget: 10000,
    );
    final scenarios = [
      for (var index = 0; index < 12; index++)
        _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'small_effect_promotion_scenario_$index',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.promotion.small_effect',
        ),
    ];
    final traces = [
      for (var index = 0; index < scenarios.length; index++) ...[
        _trace(
          scenario: scenarios[index],
          profile: candidate,
          judgePassed: index < 7,
          goalAttainment: index < 7 ? 5 : 2,
          quality: index < 7 ? 5 : 2,
          efficiency: 4,
        ),
        _trace(
          scenario: scenarios[index],
          profile: baseline,
          judgePassed: index < 6,
          goalAttainment: index < 6 ? 4 : 2,
          quality: index < 6 ? 4 : 2,
          efficiency: 4,
        ),
      ],
    ];

    final decision = EvalReporter.evaluateProfilePromotion(
      traces: traces,
      policy: const ProfilePromotionPolicy(
        candidateProfileName: 'candidate-small-effect',
        baselineProfileName: 'baseline-small-effect',
        requireTuningReadiness: false,
        minJudgePassDelta: 0.2,
      ),
    );

    expect(decision.status, ProfilePromotionStatus.inconclusive);
    expect(
      decision.evidencePlan?.additionalJudgeScenariosForLowerBound,
      isNull,
    );
    expect(
      decision.evidencePlan?.blockers,
      contains(
        'observed judge pass delta +8% is below required +20%',
      ),
    );
    expect(
      EvalReporter.renderProfilePromotion(decision),
      contains('lower-bound sample estimate unavailable'),
    );
  });

  test('promotion blocks when profiles share no complete scenarios', () {
    const candidate = EvalProfile(
      name: 'candidate-isolated',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'candidate-isolated-model',
      tokenBudget: 10000,
    );
    const baseline = EvalProfile(
      name: 'baseline-isolated',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'baseline-isolated-model',
      tokenBudget: 10000,
    );
    final traces = [
      _trace(
        scenario: _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'candidate_only_promotion',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.promotion.isolated',
        ),
        profile: candidate,
      ),
      _trace(
        scenario: _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'baseline_only_promotion',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.promotion.isolated',
        ),
        profile: baseline,
      ),
    ];

    final decision = EvalReporter.evaluateProfilePromotion(
      traces: traces,
      policy: const ProfilePromotionPolicy(
        candidateProfileName: 'candidate-isolated',
        baselineProfileName: 'baseline-isolated',
        requireTuningReadiness: false,
      ),
    );

    expect(decision.status, ProfilePromotionStatus.blocked);
    expect(
      decision.failures,
      contains('promotion blocked: paired scenario count 0 < 12'),
    );
  });

  test(
    'promotion blocks on missing verdicts, low sample, and token regression',
    () {
      const candidate = EvalProfile(
        name: 'candidate-expensive',
        isLocal: false,
        modelClass: EvalModelClass.frontierReasoning,
        modelId: 'candidate-expensive-model',
        tokenBudget: 20000,
      );
      const baseline = EvalProfile(
        name: 'baseline-cheap',
        isLocal: false,
        modelClass: EvalModelClass.frontierFast,
        modelId: 'baseline-cheap-model',
        tokenBudget: 10000,
      );
      final scenarios = [
        for (var index = 0; index < 3; index++)
          _scenarioWith(
            taskWorkflowReleaseNotesScenario,
            id: 'noisy_promotion_scenario_$index',
            split: EvalScenarioSplit.holdout,
            capabilityId: 'task.promotion.noisy',
          ),
      ];
      final traces = [
        for (var index = 0; index < scenarios.length; index++) ...[
          _trace(
            scenario: scenarios[index],
            profile: candidate,
            inputTokens: 300,
            outputTokens: 100,
            judged: index != 1,
            judgePassed: index != 2,
            goalAttainment: index == 2 ? 2 : 4,
            quality: index == 2 ? 2 : 4,
            efficiency: 2,
          ),
          _trace(
            scenario: scenarios[index],
            profile: baseline,
            goalAttainment: 4,
            quality: 4,
            efficiency: 4,
          ),
        ],
      ];

      final decision = EvalReporter.evaluateProfilePromotion(
        traces: traces,
        policy: const ProfilePromotionPolicy(
          candidateProfileName: 'candidate-expensive',
          baselineProfileName: 'baseline-cheap',
          requireTuningReadiness: false,
        ),
      );

      expect(decision.promote, isFalse);
      expect(decision.status, ProfilePromotionStatus.blocked);
      final plan = decision.evidencePlan!;
      expect(plan.additionalPairedScenariosForMinCount, 9);
      expect(plan.additionalJudgeScenariosForMinCount, 10);
      expect(plan.additionalJudgeScenariosForLowerBound, isNull);
      expect(
        plan.blockers,
        contains(
          'paired judge verdicts are missing; complete verdicts before using '
          'lower-bound sample estimates',
        ),
      );
      expect(
        plan.blockers,
        contains(
          'Level 1, quality, efficiency, or token/cost rejection remains; more '
          'samples alone cannot promote this candidate',
        ),
      );
      expect(
        decision.failures,
        containsAll({
          'promotion blocked: paired scenario count 3 < 12',
          'promotion blocked: paired judge scenario count 2 < 12',
          'promotion blocked: paired scenarios with missing judge verdicts 1 > 0',
          'promotion inconclusive: judge pass delta -50% < +5%',
          'promotion rejected: mean efficiency delta -2.0 < -0.3',
          'promotion rejected: mean token regression +167% > +25% (ratio 2.67x > 1.25x)',
        }),
      );
      expect(
        EvalReporter.renderProfilePromotion(decision),
        contains(
          'Profile promotion: candidate-expensive vs baseline-cheap: blocked',
        ),
      );
      expect(
        EvalReporter.renderProfilePromotion(decision),
        contains('lower-bound sample estimate unavailable'),
      );
    },
  );

  test(
    'marks profile pairs with no shared complete scenario as incomparable',
    () {
      const leftProfile = EvalProfile(
        name: 'frontier-left',
        isLocal: false,
        modelClass: EvalModelClass.frontierFast,
        modelId: 'frontier-left-model',
        tokenBudget: 10000,
      );
      const rightProfile = EvalProfile(
        name: 'frontier-right',
        isLocal: false,
        modelClass: EvalModelClass.frontierFast,
        modelId: 'frontier-right-model',
        tokenBudget: 10000,
      );
      final traces = [
        _trace(
          scenario: _scenarioWith(
            taskWorkflowReleaseNotesScenario,
            id: 'left-only-scenario',
            split: EvalScenarioSplit.development,
            capabilityId: 'task.grooming.basic',
          ),
          profile: leftProfile,
        ),
        _trace(
          scenario: _scenarioWith(
            taskWorkflowReleaseNotesScenario,
            id: 'right-only-scenario',
            split: EvalScenarioSplit.development,
            capabilityId: 'task.grooming.basic',
          ),
          profile: rightProfile,
        ),
      ];

      final comparison = EvalReporter.compareProfiles(traces).single;

      expect(comparison.pairedScenarioCount, 0);
      expect(comparison.leftOnlyScenarioCount, 1);
      expect(comparison.rightOnlyScenarioCount, 1);
      expect(comparison.isComparable, isFalse);
      expect(EvalReporter.render(traces), contains('not comparable'));
    },
  );

  test('incomplete trial groups are not counted as reliable', () {
    final traces = [
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: profile,
      ),
    ];

    final summary = EvalReporter.summarize(traces).single;

    expect(summary.scenarioCount, 1);
    expect(summary.completeScenarioCount, 0);
    expect(summary.level1PassRate, 1.0);
    expect(summary.level1ReliableScenarioRate, 0.0);
    expect(summary.judgePassRate, 1.0);
    expect(summary.judgeReliableScenarioRate, 0.0);
  });

  test('duplicate trial indices are not counted as complete reliability', () {
    final traces = [
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: profile,
      ),
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: profile,
      ),
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: profile,
        trialIndex: 2,
      ),
    ];

    final summary = EvalReporter.summarize(traces).single;

    expect(summary.traceCount, 3);
    expect(summary.scenarioCount, 1);
    expect(summary.completeScenarioCount, 0);
    expect(summary.level1PassRate, 1.0);
    expect(summary.level1ReliableScenarioRate, 0.0);
    expect(summary.judgePassRate, 1.0);
    expect(summary.judgeReliableScenarioRate, 0.0);
  });

  test('shifted or extra trial indices are not counted as complete', () {
    for (final trialIndices in const <List<int>>[
      [1, 2, 3],
      [0, 1, 2, 3],
    ]) {
      final traces = [
        for (final trialIndex in trialIndices)
          _trace(
            scenario: taskReleaseNotesScenario,
            profile: profile,
            trialIndex: trialIndex,
          ),
      ];

      final summary = EvalReporter.summarize(traces).single;

      expect(
        summary.completeScenarioCount,
        0,
        reason: 'trial indices $trialIndices',
      );
      expect(
        summary.level1ReliableScenarioRate,
        0.0,
        reason: 'trial indices $trialIndices',
      );
      expect(
        summary.judgeReliableScenarioRate,
        0.0,
        reason: 'trial indices $trialIndices',
      );
    }
  });

  test(
    'complete trial set with a missing verdict has no judge reliability',
    () {
      final traces = [
        for (var trialIndex = 0; trialIndex < profile.trialCount; trialIndex++)
          _trace(
            scenario: taskReleaseNotesScenario,
            profile: profile,
            trialIndex: trialIndex,
            judged: trialIndex != 1,
          ),
      ];

      final summary = EvalReporter.summarize(traces).single;

      expect(summary.completeScenarioCount, 1);
      expect(summary.level1ReliableScenarioCount, 1);
      expect(summary.level1ReliableScenarioRate, 1.0);
      expect(summary.judgedCount, 2);
      expect(summary.judgePassRate, 1.0);
      expect(summary.judgeReliableScenarioCount, 0);
      expect(summary.judgeReliableScenarioRate, 0.0);
    },
  );
}

EvalScenario _scenarioWith(
  EvalScenario scenario, {
  required EvalScenarioSplit split,
  required String capabilityId,
  String? id,
}) {
  final json = scenario.toJson();
  if (id != null) {
    json['id'] = id;
  }
  json['metadata'] = <String, dynamic>{
    ...(json['metadata'] as Map<String, dynamic>),
    'split': split.name,
    'capabilityIds': [capabilityId],
  };
  return EvalScenario.fromJson(json);
}

EvalRunManifest _manifestFor({
  required List<EvalScenario> scenarios,
  required List<EvalProfile> profiles,
}) {
  return EvalProvenance.captureRunManifest(
    runId: 'reporter-manifest-test',
    targetName: 'reporter-test',
    targetKind: 'fixture',
    scenarios: scenarios,
    profiles: profiles,
    createdAt: DateTime(2026, 6, 10, 12),
    command: 'reporter-test',
    environment: const <String, String>{},
  );
}

ProviderRequestRecord _providerRequest({
  int invocationIndex = 0,
  int requestIndex = 0,
  int turnIndex = 1,
  String providerModelId = 'frontier-repeatable-model',
  String providerId = 'provider-frontier-repeatable',
  String providerType = 'openAi',
  String providerEndpointOrigin = 'http://localhost:8003',
  String providerBaseUrlDigest = 'sha256:provider-base',
  String messageDigest = 'sha256:stable-messages',
  int messageCount = 2,
  String toolSchemaDigest = 'sha256:stable-tools',
  int toolCount = 19,
  List<String> toolNames = const ['update_report'],
  double temperature = 1,
  int thoughtSignatureCount = 0,
}) {
  return ProviderRequestRecord(
    invocationIndex: invocationIndex,
    requestIndex: requestIndex,
    turnIndex: turnIndex,
    providerModelId: providerModelId,
    providerId: providerId,
    providerType: providerType,
    providerEndpointOrigin: providerEndpointOrigin,
    providerBaseUrlDigest: providerBaseUrlDigest,
    messageDigest: messageDigest,
    messageCount: messageCount,
    toolSchemaDigest: toolSchemaDigest,
    toolCount: toolCount,
    toolNames: toolNames,
    temperature: temperature,
    thoughtSignatureCount: thoughtSignatureCount,
  );
}

EvalTrace _trace({
  required EvalScenario scenario,
  required EvalProfile profile,
  int trialIndex = 0,
  bool level1Passed = true,
  bool judged = true,
  bool judgePassed = true,
  int? goalAttainment,
  int? quality,
  int? efficiency,
  int? inputTokens = 100,
  int? outputTokens = 50,
  int? cachedInputTokens,
  int? thoughtsTokens,
  List<ProviderRequestRecord> providerRequests =
      const <ProviderRequestRecord>[],
  EvalTraceCascadeWake? cascadeWake,
}) {
  return EvalTrace(
    runId: 'run-1',
    scenario: scenario,
    profile: profile,
    provenance: EvalProvenance.capture(scenario: scenario, profile: profile),
    trialIndex: trialIndex,
    cascadeWake: cascadeWake,
    output: AgentRunOutput(
      success: true,
      usage: InferenceUsage(
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        cachedInputTokens: cachedInputTokens,
        thoughtsTokens: thoughtsTokens,
      ),
      report: const AgentReportRecord(
        oneLiner: 'Handled',
        tldr: 'The wake produced durable state.',
        content: 'Done.',
      ),
      providerRequests: providerRequests,
    ),
    level1Checks: [
      if (level1Passed)
        const EvalCheck(name: 'example', passed: true)
      else
        const EvalCheck(name: 'example', passed: false, detail: 'failed'),
    ],
    verdict: judged
        ? JudgeVerdict(
            traceDigest: EvalProvenance.digestText('trace-$trialIndex'),
            goalAttainment: goalAttainment ?? (judgePassed ? 5 : 2),
            quality: quality ?? (judgePassed ? 5 : 2),
            efficiency: efficiency ?? 4,
            pass: judgePassed,
            judge: JudgeProvenanceRecord(
              judgeName: 'claude-code',
              judgeModel: 'test-judge',
              promptDigest: EvalProvenance.promptDigest(),
              calibrationSetVersion: 'test-gold-v1',
              profileVisible: true,
              modelIdentityVisible: true,
            ),
            issues: judgePassed ? const [] : const ['trial failed'],
          )
        : null,
  );
}
