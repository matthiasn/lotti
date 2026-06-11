import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../harness/eval_harness.dart';
import '../harness/eval_profile_config.dart';
import '../scenarios/eval_scenarios.dart';

void main() {
  const stableProfile = EvalProfile(
    name: 'stable-frontier',
    isLocal: false,
    modelClass: EvalModelClass.frontierFast,
    modelId: 'stable-frontier-model',
    tokenBudget: 10000,
    trialCount: 2,
  );
  const singleProfile = EvalProfile(
    name: 'single-local',
    isLocal: true,
    modelClass: EvalModelClass.localSmall,
    modelId: 'single-local-model',
    tokenBudget: 5000,
  );

  test(
    'rejects non-positive profile cost weights before running cells',
    () async {
      const badProfile = EvalProfile(
        name: 'bad-cost-profile',
        isLocal: false,
        modelClass: EvalModelClass.frontierFast,
        modelId: 'bad-cost-model',
        tokenBudget: 10000,
        cachedInputTokenCostMicros: 0,
      );
      final target = _RecordingTarget();
      final runner = EvalMatrixRunner(target: target);

      await expectLater(
        runner.run(
          runId: 'run-1',
          scenarios: [taskReleaseNotesScenario],
          profiles: const [badProfile],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'profile bad-cost-profile cachedInputTokenCostMicros must be at '
                'least 1',
          ),
        ),
      );
      expect(target.calls, isEmpty);
    },
  );

  test('plans the full matrix without running or writing artifacts', () async {
    final tempDir = await Directory.systemTemp.createTemp('lotti-eval-plan-');
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final target = _RecordingTarget();
    final writer = TraceWriter(runsRoot: tempDir.path);
    final runner = EvalMatrixRunner(target: target, writer: writer);
    final scenarios = [
      taskReleaseNotesScenario,
      plannerMorningCapacityScenario,
    ];
    const profiles = [stableProfile, singleProfile];

    final plan = runner.plan(
      runId: 'plan-1',
      scenarios: scenarios,
      profiles: profiles,
    );

    expect(target.calls, isEmpty);
    expect(plan.manifestFile.uri.pathSegments.last, 'manifest.json');
    expect(plan.manifestFile.existsSync(), isFalse);
    expect(plan.manifest.manifestDigest, startsWith('sha256:'));
    expect(plan.scenarios.map((scenario) => scenario.id), [
      'task_release_notes',
      'planner_morning_capacity',
    ]);
    expect(plan.profiles.map((profile) => profile.name), [
      stableProfile.name,
      singleProfile.name,
    ]);
    expect(
      plan.cells.map(
        (cell) => '${cell.scenarioId}::${cell.profileName}::${cell.trialIndex}',
      ),
      [
        'task_release_notes::stable-frontier::0',
        'task_release_notes::stable-frontier::1',
        'task_release_notes::single-local::0',
        'planner_morning_capacity::stable-frontier::0',
        'planner_morning_capacity::stable-frontier::1',
        'planner_morning_capacity::single-local::0',
      ],
    );
    expect(
      plan.cells.map((cell) => cell.traceFile.uri.pathSegments.last).toSet(),
      containsAll({
        'task_release_notes__stable-frontier.trace.json',
        'task_release_notes__stable-frontier__trial-1.trace.json',
        'task_release_notes__single-local.trace.json',
        'planner_morning_capacity__stable-frontier.trace.json',
        'planner_morning_capacity__stable-frontier__trial-1.trace.json',
        'planner_morning_capacity__single-local.trace.json',
      }),
    );
    expect(
      plan.cells.map((cell) => cell.verdictFile.uri.pathSegments.last).toSet(),
      containsAll({
        'task_release_notes__stable-frontier.verdict.json',
        'task_release_notes__stable-frontier__trial-1.verdict.json',
        'task_release_notes__single-local.verdict.json',
        'planner_morning_capacity__stable-frontier.verdict.json',
        'planner_morning_capacity__stable-frontier__trial-1.verdict.json',
        'planner_morning_capacity__single-local.verdict.json',
      }),
    );
    expect(
      plan.cells.every((cell) => !cell.traceFile.existsSync()),
      isTrue,
    );
    expect(plan.trialCountByProfile, {
      stableProfile.name: 2,
      singleProfile.name: 1,
    });

    final rendered = EvalMatrixPlanRenderer.render(
      plan,
      scenarioSourceLabel: 'public catalog filtered to smoke',
      profileSourceLabel: 'built-in profiles filtered to smoke',
    );
    expect(rendered, contains('Eval matrix plan'));
    expect(rendered, contains('trace cells: 6'));
    expect(rendered, contains('previewManifestDigest: sha256:'));
    expect(rendered, contains('providerModelId='));
    expect(rendered, contains('task_release_notes x stable-frontier trial=1'));
  });

  test('plan rejects promotion plans for another scenario set', () {
    final target = _RecordingTarget();
    final runner = EvalMatrixRunner(target: target);
    final promotionPlan = _promotionPlanFor(
      scenarios: [plannerMorningCapacityScenario],
      profiles: const [stableProfile],
    );

    expect(
      () => runner.plan(
        runId: 'plan-wrong-plan',
        scenarios: [taskReleaseNotesScenario],
        profiles: const [stableProfile],
        promotionPlan: promotionPlan,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Promotion plan scenarioSetDigest'),
        ),
      ),
    );
    expect(target.calls, isEmpty);
  });

  test('plan preflights stale verdicts before any target call', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'lotti-eval-plan-preflight-',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final writer = TraceWriter(runsRoot: tempDir.path);
    final existingTrace = EvalTrace(
      runId: 'plan-1',
      scenario: taskReleaseNotesScenario,
      profile: stableProfile,
      provenance: EvalProvenance.capture(
        scenario: taskReleaseNotesScenario,
        profile: stableProfile,
      ),
      trialIndex: 1,
      output: _outputFor(stableProfile),
      level1Checks: runLevel1(
        taskReleaseNotesScenario,
        _outputFor(stableProfile),
        profile: stableProfile,
      ),
    );
    final existingFile = await writer.writeTrace(existingTrace);
    await writer.writeVerdict(
      existingFile,
      _verdict(
        goalAttainment: 5,
        quality: 5,
        efficiency: 5,
        pass: true,
      ),
    );
    final target = _RecordingTarget();
    final runner = EvalMatrixRunner(target: target, writer: writer);

    expect(
      () => runner.plan(
        runId: 'plan-1',
        scenarios: [taskReleaseNotesScenario],
        profiles: const [stableProfile],
        overwrite: true,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('existing verdict'),
        ),
      ),
    );
    expect(target.calls, isEmpty);
  });

  test('writes the full scenario x profile x trial trace matrix', () async {
    final tempDir = await Directory.systemTemp.createTemp('lotti-eval-matrix-');
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final target = _RecordingTarget();
    final writer = TraceWriter(runsRoot: tempDir.path);
    final runner = EvalMatrixRunner(target: target, writer: writer);
    final scenarios = [
      taskReleaseNotesScenario,
      plannerMorningCapacityScenario,
    ];
    const profiles = [stableProfile, singleProfile];

    final result = await runner.run(
      runId: 'run-1',
      scenarios: scenarios,
      profiles: profiles,
    );

    expect(result.traces, hasLength(6));
    expect(result.traceFiles, hasLength(6));
    expect(result.manifestFile.uri.pathSegments.last, 'manifest.json');
    expect(result.manifest.manifestDigest, startsWith('sha256:'));
    expect(result.manifest.profileExecutionBindings, hasLength(2));
    expect(
      result.manifest.profileBindingSetDigest,
      EvalProvenance.profileBindingSetDigest(
        result.manifest.profileExecutionBindings,
      ),
    );
    expect(
      {
        for (final binding in result.manifest.profileExecutionBindings)
          binding.profileName: binding.providerModelId,
      },
      {
        stableProfile.name: 'models/eval-frontier-fast-stable-frontier-model',
        singleProfile.name: 'eval-local-small:single-local-model',
      },
    );
    expect(target.calls, [
      'task_release_notes::stable-frontier::run-1::0',
      'task_release_notes::stable-frontier::run-1::1',
      'task_release_notes::single-local::run-1::0',
      'planner_morning_capacity::stable-frontier::run-1::0',
      'planner_morning_capacity::stable-frontier::run-1::1',
      'planner_morning_capacity::single-local::run-1::0',
    ]);
    expect(
      target.cellIds,
      [
        'run-1::task_release_notes::stable-frontier::0',
        'run-1::task_release_notes::stable-frontier::1',
        'run-1::task_release_notes::single-local::0',
        'run-1::planner_morning_capacity::stable-frontier::0',
        'run-1::planner_morning_capacity::stable-frontier::1',
        'run-1::planner_morning_capacity::single-local::0',
      ],
    );
    expect(
      result.traceFiles.map((file) => file.uri.pathSegments.last).toSet(),
      containsAll({
        'task_release_notes__stable-frontier.trace.json',
        'task_release_notes__stable-frontier__trial-1.trace.json',
        'task_release_notes__single-local.trace.json',
        'planner_morning_capacity__stable-frontier.trace.json',
        'planner_morning_capacity__stable-frontier__trial-1.trace.json',
        'planner_morning_capacity__single-local.trace.json',
      }),
    );

    final loaded = await writer.readTraces('run-1');
    final loadedManifest = await writer.readManifest('run-1');
    expect(loadedManifest!.manifestDigest, result.manifest.manifestDigest);
    expect(
      loaded.map((trace) => trace.provenance.manifestDigest).toSet(),
      {result.manifest.manifestDigest},
    );
    expect(
      loaded.map(
        (trace) =>
            '${trace.scenario.id}::${trace.profile.name}::${trace.trialIndex}',
      ),
      [
        'planner_morning_capacity::single-local::0',
        'planner_morning_capacity::stable-frontier::0',
        'planner_morning_capacity::stable-frontier::1',
        'task_release_notes::single-local::0',
        'task_release_notes::stable-frontier::0',
        'task_release_notes::stable-frontier::1',
      ],
    );

    final verification = EvalRunVerifier.verify(
      runId: 'run-1',
      traces: loaded,
      scenarios: scenarios,
      profiles: profiles,
      manifest: loadedManifest,
      artifactNames: [
        result.manifestFile.uri.pathSegments.last,
        for (final file in result.traceFiles) file.uri.pathSegments.last,
      ],
      requireVerdicts: false,
    );
    expect(verification.errors, isEmpty);
  });

  test('records promotion plan evidence in the run manifest', () async {
    final tempDir = await Directory.systemTemp.createTemp('lotti-eval-matrix-');
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final target = _RecordingTarget();
    final writer = TraceWriter(runsRoot: tempDir.path);
    final runner = EvalMatrixRunner(target: target, writer: writer);
    final scenarios = [taskReleaseNotesScenario];
    const profiles = [stableProfile, singleProfile];
    final promotionPlan = _promotionPlanFor(
      scenarios: scenarios,
      profiles: profiles,
    );

    final result = await runner.run(
      runId: 'run-promotion-plan',
      scenarios: scenarios,
      profiles: profiles,
      promotionPlan: promotionPlan,
    );

    final evidence = result.manifest.promotionPlanEvidence;
    expect(evidence, isNotNull);
    expect(evidence!.planId, promotionPlan.planId);
    expect(evidence.candidateProfileName, promotionPlan.candidateProfileName);
    expect(evidence.baselineProfileName, promotionPlan.baselineProfileName);
    expect(
      evidence.promotionPlanSubjectDigest,
      EvalProvenance.promotionPlanSubjectDigest(promotionPlan),
    );
    final loaded = await writer.readManifest('run-promotion-plan');
    expect(
      loaded!.promotionPlanEvidence?.toJson(),
      evidence.toJson(),
    );
    expect(
      loaded.toJson().toString(),
      isNot(contains(tempDir.path)),
      reason: 'the manifest must not persist local promotion-plan paths',
    );
  });

  test(
    'fails the run after writing traces when Level 1 semantics fail',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'lotti-eval-matrix-level1-failure-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });
      final target = _RecordingTarget();
      final writer = TraceWriter(runsRoot: tempDir.path);
      final runner = EvalMatrixRunner(target: target, writer: writer);

      await expectLater(
        runner.run(
          runId: 'run-level1-failure',
          scenarios: [taskWorkflowStructuredUpdateScenario],
          profiles: const [singleProfile],
        ),
        throwsA(
          isA<StateError>()
              .having(
                (error) => error.message,
                'message',
                contains(
                  'task_workflow_structured_update::single-local::trial-0 '
                  'expected_tools:',
                ),
              )
              .having(
                (error) => error.message,
                'message',
                contains('missing required: update_report'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('expected_tool_calls:'),
              ),
        ),
      );

      expect(target.calls, [
        'task_workflow_structured_update::single-local::run-level1-failure::0',
      ]);
      final traces = await writer.readTraces('run-level1-failure');
      expect(traces, hasLength(1));
      final trace = traces.single;
      expect(trace.output.success, isTrue);
      expect(trace.level1Passed, isFalse);
      expect(
        trace.level1Checks
            .where((check) => !check.passed)
            .map(
              (check) => check.name,
            ),
        containsAll({
          'expected_tools',
          'expected_tool_calls',
          'expected_durable_state',
        }),
      );
      expect(await writer.readManifest('run-level1-failure'), isNotNull);
    },
  );

  test('rejects promotion plans for another scenario set before running', () {
    final target = _RecordingTarget();
    final runner = EvalMatrixRunner(target: target);
    final promotionPlan = _promotionPlanFor(
      scenarios: [plannerMorningCapacityScenario],
      profiles: const [stableProfile],
    );

    expect(
      () => runner.run(
        runId: 'run-wrong-plan',
        scenarios: [taskReleaseNotesScenario],
        profiles: const [stableProfile],
        promotionPlan: promotionPlan,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Promotion plan scenarioSetDigest'),
        ),
      ),
    );
    expect(target.calls, isEmpty);
  });

  test('rejects promotion plans for another profile set before running', () {
    final target = _RecordingTarget();
    final runner = EvalMatrixRunner(target: target);
    final promotionPlan = _promotionPlanFor(
      scenarios: [taskReleaseNotesScenario],
      profiles: const [singleProfile],
    );

    expect(
      () => runner.run(
        runId: 'run-wrong-profiles',
        scenarios: [taskReleaseNotesScenario],
        profiles: const [stableProfile],
        promotionPlan: promotionPlan,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Promotion plan profileSetDigest'),
        ),
      ),
    );
    expect(target.calls, isEmpty);
  });

  test(
    'captures target exceptions as failed traces instead of losing cells',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'lotti-eval-matrix-failure-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });
      final writer = TraceWriter(runsRoot: tempDir.path);
      final runner = EvalMatrixRunner(
        target: _ThrowingTarget(),
        writer: writer,
      );

      await expectLater(
        runner.run(
          runId: 'run-1',
          scenarios: [taskReleaseNotesScenario],
          profiles: const [singleProfile],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('missing resolvedModel provenance'),
          ),
        ),
      );

      final traces = await writer.readTraces('run-1');
      expect(traces, hasLength(1));
      final trace = traces.single;
      expect(trace.output.success, isFalse);
      expect(trace.output.error, contains('model transport failed'));
      expect(trace.level1Passed, isFalse);
    },
  );

  test('sanitizes target exception payloads before writing traces', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'lotti-eval-matrix-sensitive-failure-',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final writer = TraceWriter(runsRoot: tempDir.path);
    final runner = EvalMatrixRunner(
      target: _SensitiveThrowingTarget(),
      writer: writer,
    );

    await expectLater(
      runner.run(
        runId: 'run-sensitive-failure',
        scenarios: [taskReleaseNotesScenario],
        profiles: const [singleProfile],
      ),
      throwsA(isA<StateError>()),
    );

    final trace = (await writer.readTraces('run-sensitive-failure')).single;
    final error = trace.output.error!;
    expect(error, contains('model transport failed'));
    expect(error, contains('OPENAI_API_KEY=<redacted>'));
    expect(error, contains('Authorization: Bearer <redacted>'));
    expect(error, contains('prompt=<redacted-content>'));
    expect(error, isNot(contains('live-key')));
    expect(error, isNot(contains('sk-live-secret')));
    expect(error, isNot(contains('/private/tmp/protected_catalog.json')));
    expect(error, isNot(contains('private transcript text')));
  });

  test(
    'preflights stale trial verdicts before any target call',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'lotti-eval-matrix-preflight-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });
      final writer = TraceWriter(runsRoot: tempDir.path);
      final existingTrace = EvalTrace(
        runId: 'run-1',
        scenario: taskReleaseNotesScenario,
        profile: stableProfile,
        provenance: EvalProvenance.capture(
          scenario: taskReleaseNotesScenario,
          profile: stableProfile,
        ),
        trialIndex: 1,
        output: _outputFor(stableProfile),
        level1Checks: runLevel1(
          taskReleaseNotesScenario,
          _outputFor(stableProfile),
          profile: stableProfile,
        ),
      );
      final existingFile = await writer.writeTrace(existingTrace);
      await writer.writeVerdict(
        existingFile,
        _verdict(
          goalAttainment: 5,
          quality: 5,
          efficiency: 5,
          pass: true,
        ),
      );
      final target = _RecordingTarget();
      final runner = EvalMatrixRunner(target: target, writer: writer);

      await expectLater(
        runner.run(
          runId: 'run-1',
          scenarios: [taskReleaseNotesScenario],
          profiles: const [stableProfile],
          overwrite: true,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('existing verdict'),
          ),
        ),
      );
      expect(target.calls, isEmpty);
    },
  );

  test('snapshots scenario payloads before target execution', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'lotti-eval-matrix-snapshot-',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final mutableScenario = EvalScenario(
      id: 'mutable-task',
      title: 'Mutable task scenario',
      agentKind: AgentKind.taskAgent,
      metadata: const EvalScenarioMetadata(
        capabilityIds: ['task.grooming.mutable'],
      ),
      appState: MockedAppState(
        now: DateTime(2026, 6, 9, 12),
        tasks: [
          const MockTask(
            id: 'task-mutable',
            title: 'Mutable task',
            status: 'OPEN',
          ),
        ],
        categoryIds: ['cat-original'],
      ),
      userInput: const UserInput(
        transcript: 'Handle the mutable task.',
        triggerTokens: {'decided_task:task-mutable'},
      ),
    );
    final writer = TraceWriter(runsRoot: tempDir.path);
    final runner = EvalMatrixRunner(
      target: _MutatingTarget(),
      writer: writer,
    );

    final result = await runner.run(
      runId: 'run-1',
      scenarios: [mutableScenario],
      profiles: const [singleProfile],
    );

    expect(mutableScenario.appState.categoryIds, contains('cat-mutated'));
    expect(
      result.traces.single.scenario.appState.categoryIds,
      ['cat-original'],
      reason: 'trace payload must use the pre-target catalog snapshot',
    );
    final loaded = await writer.readTraces('run-1');
    expect(loaded.single.scenario.appState.categoryIds, ['cat-original']);
  });

  test(
    'rejects scenarios without capability metadata before target calls',
    () async {
      final target = _RecordingTarget();
      final runner = EvalMatrixRunner(target: target);
      final scenario = EvalScenario(
        id: 'missing-capability',
        title: 'Missing capability metadata',
        agentKind: AgentKind.taskAgent,
        appState: MockedAppState(
          now: DateTime(2026, 6, 9, 12),
          tasks: const [
            MockTask(
              id: 'task-missing-capability',
              title: 'Missing capability task',
              status: 'OPEN',
            ),
          ],
        ),
        userInput: const UserInput(
          transcript: 'Handle the task.',
          triggerTokens: {'decided_task:task-missing-capability'},
        ),
      );

      await expectLater(
        runner.run(
          runId: 'run-1',
          scenarios: [scenario],
          profiles: const [singleProfile],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('must declare at least one capability id'),
          ),
        ),
      );
      expect(target.calls, isEmpty);
    },
  );
}

JudgeVerdict _verdict({
  required int goalAttainment,
  required int quality,
  required int efficiency,
  required bool pass,
}) => JudgeVerdict(
  goalAttainment: goalAttainment,
  quality: quality,
  efficiency: efficiency,
  pass: pass,
  judge: JudgeProvenanceRecord(
    judgeName: 'claude-code',
    judgeModel: 'test-judge',
    promptDigest: EvalProvenance.promptDigest(),
    calibrationSetVersion: 'test-gold-v1',
    profileVisible: true,
    modelIdentityVisible: true,
  ),
);

class _RecordingTarget extends EvalTarget {
  final calls = <String>[];
  final cellIds = <String>[];

  @override
  String get profileName => 'recording';

  @override
  String get targetKind => 'recording';

  @override
  Future<AgentRunOutput> run(
    EvalScenario scenario,
    EvalProfile profile, {
    EvalTargetRunContext context = EvalTargetRunContext.direct,
  }) async {
    calls.add(
      '${scenario.id}::${profile.name}::${context.runId}::'
      '${context.trialIndex}',
    );
    cellIds.add(context.cellId);
    return _outputForScenario(scenario, profile);
  }
}

class _ThrowingTarget extends EvalTarget {
  @override
  String get profileName => 'throwing';

  @override
  String get targetKind => 'throwing';

  @override
  Future<AgentRunOutput> run(
    EvalScenario scenario,
    EvalProfile profile, {
    EvalTargetRunContext context = EvalTargetRunContext.direct,
  }) async {
    throw StateError('model transport failed');
  }
}

class _SensitiveThrowingTarget extends EvalTarget {
  @override
  String get profileName => 'sensitive-throwing';

  @override
  String get targetKind => 'sensitive-throwing';

  @override
  Future<AgentRunOutput> run(
    EvalScenario scenario,
    EvalProfile profile, {
    EvalTargetRunContext context = EvalTargetRunContext.direct,
  }) async {
    throw StateError(
      'model transport failed OPENAI_API_KEY=live-key '
      'Authorization: Bearer sk-live-secret '
      'prompt=private transcript text '
      'catalog=/private/tmp/protected_catalog.json',
    );
  }
}

class _MutatingTarget extends EvalTarget {
  @override
  String get profileName => 'mutating';

  @override
  String get targetKind => 'mutating';

  @override
  Future<AgentRunOutput> run(
    EvalScenario scenario,
    EvalProfile profile, {
    EvalTargetRunContext context = EvalTargetRunContext.direct,
  }) async {
    scenario.appState.categoryIds.add('cat-mutated');
    return _outputFor(profile);
  }
}

AgentRunOutput _outputFor(EvalProfile profile) {
  final profileConfig = evalProfileConfig(profile);
  return AgentRunOutput(
    success: true,
    usage: const InferenceUsage(inputTokens: 100, outputTokens: 50),
    report: const AgentReportRecord(
      oneLiner: 'Handled',
      tldr: 'The wake produced durable state.',
      content: 'Done.',
    ),
    resolvedModel: profileConfig.toResolvedModelRecord(
      wakeRunResolvedModelId: profileConfig.providerModelId,
      usageModelId: profileConfig.providerModelId,
    ),
    providerDecision: profileConfig.toProviderDecisionRecord(
      envPresence: const {'OPENAI_API_KEY': true},
    ),
  );
}

AgentRunOutput _outputForScenario(EvalScenario scenario, EvalProfile profile) {
  if (scenario.id != plannerMorningCapacityScenario.id) {
    return _outputFor(profile);
  }
  final base = _outputFor(profile);
  return AgentRunOutput(
    success: base.success,
    usage: base.usage,
    report: base.report,
    toolCalls: const [
      ToolCallRecord(
        name: 'draft_day_plan',
        args: {
          'dayId': kPlannerWorkflowDayId,
          'decidedTaskIds': ['task-run', 'task-adr'],
        },
      ),
    ],
    toolResults: const [
      ToolResultRecord(name: 'draft_day_plan', success: true),
    ],
    plannedBlocks: [
      PlannedBlockRecord(
        id: 'plan-run',
        categoryId: 'cat-health',
        start: DateTime(2026, 6, 9, 7, 30),
        end: DateTime(2026, 6, 9, 8, 10),
        taskId: 'task-run',
      ),
      PlannedBlockRecord(
        id: 'plan-adr',
        categoryId: 'cat-work',
        start: DateTime(2026, 6, 9, 9),
        end: DateTime(2026, 6, 9, 11),
        taskId: 'task-adr',
      ),
    ],
    plannedCapacityMinutes: scenario.appState.capacityMinutes,
    resolvedModel: base.resolvedModel,
    providerDecision: base.providerDecision,
  );
}

EvalPromotionPlan _promotionPlanFor({
  required List<EvalScenario> scenarios,
  required List<EvalProfile> profiles,
}) => EvalPromotionPlan(
  planId: 'promotion-plan-test',
  candidateProfileName: 'stable-frontier',
  baselineProfileName: 'single-local',
  scenarioSetDigest: EvalProvenance.scenarioSetDigest(scenarios),
  profileSetDigest: EvalProvenance.profileSetDigest(profiles),
  policyDigest: EvalProvenance.digestText('promotion-policy'),
  createdAt: '2026-06-10T00:00:00Z',
  notes: 'test fixture',
);
