import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../harness/eval_harness.dart';
import '../scenarios/eval_scenarios.dart';

void main() {
  test('rejects trace files that embed verdicts', () async {
    final dir = await Directory.systemTemp.createTemp('lotti-trace-writer-');
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    final writer = TraceWriter(runsRoot: dir.path);
    final traceFile = await writer.writeTrace(
      EvalTrace(
        runId: 'run-1',
        scenario: taskReleaseNotesScenario,
        profile: kFrontierFastProfile,
        provenance: EvalProvenance.capture(
          scenario: taskReleaseNotesScenario,
          profile: kFrontierFastProfile,
        ),
        output: const AgentRunOutput(
          success: true,
          usage: InferenceUsage(inputTokens: 10, outputTokens: 5),
          report: AgentReportRecord(
            oneLiner: 'Done',
            tldr: 'Task was handled.',
            content: 'Handled.',
          ),
        ),
        level1Checks: runLevel1(
          taskReleaseNotesScenario,
          const AgentRunOutput(
            success: true,
            usage: InferenceUsage(inputTokens: 10, outputTokens: 5),
            report: AgentReportRecord(
              oneLiner: 'Done',
              tldr: 'Task was handled.',
              content: 'Handled.',
            ),
          ),
          profile: kFrontierFastProfile,
        ),
      ),
    );

    final json =
        jsonDecode(await traceFile.readAsString()) as Map<String, dynamic>;
    json['verdict'] = _verdict(
      traceDigest: 'sha256:embedded',
      goalAttainment: 5,
      quality: 5,
      efficiency: 5,
      pass: true,
    ).toJson();
    await traceFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );

    await expectLater(
      writer.readTraces('run-1'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('must not embed a verdict'),
        ),
      ),
    );
  });

  test('rejects legacy verdict JSON without a schema version', () async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-verdict-schema-',
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    final writer = TraceWriter(runsRoot: dir.path);
    final traceFile = await writer.writeTrace(_validTrace('run-1'));
    await writer
        .verdictFileForTrace(traceFile)
        .writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'traceDigest': await writer.traceDigest(traceFile),
            'goalAttainment': 5,
            'quality': 5,
            'efficiency': 5,
            'pass': true,
          }),
        );

    await expectLater(
      writer.readTraces('run-1'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Unsupported JudgeVerdict schemaVersion null'),
        ),
      ),
    );
  });

  test('rejects missing or mismatched trace schema versions', () async {
    final dir = await Directory.systemTemp.createTemp('lotti-trace-schema-');
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    final writer = TraceWriter(runsRoot: dir.path);
    for (final entry in const <String, Object?>{
      'missing-schema': null,
      'stale-schema': EvalTrace.schemaVersion - 1,
      'future-schema': EvalTrace.schemaVersion + 1,
      'fractional-schema': EvalTrace.schemaVersion + 0.5,
    }.entries) {
      final traceFile = await writer.writeTrace(_validTrace(entry.key));
      final json =
          jsonDecode(await traceFile.readAsString()) as Map<String, dynamic>;
      if (entry.value == null) {
        json.remove('schemaVersion');
      } else {
        json['schemaVersion'] = entry.value;
      }
      await traceFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(json),
      );

      await expectLater(
        writer.readTraces(entry.key),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Unsupported EvalTrace schemaVersion'),
          ),
        ),
      );
    }
  });

  test('writes and reads manifest with overwrite protection', () async {
    final dir = await Directory.systemTemp.createTemp('lotti-trace-manifest-');
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final writer = TraceWriter(runsRoot: dir.path);
    final manifest = _validManifest('run-1');

    final file = await writer.writeManifest(manifest);
    final loaded = await writer.readManifest('run-1');
    final run = await writer.readRun('run-1');

    expect(file.uri.pathSegments.last, 'manifest.json');
    expect(loaded!.manifestDigest, manifest.manifestDigest);
    expect(run.manifest.manifestDigest, manifest.manifestDigest);
    expect(loaded.scenarioSetDigest, manifest.scenarioSetDigest);
    expect(loaded.envPresence['LOTTI_EVAL_LIVE'], isFalse);
    await expectLater(
      writer.writeManifest(manifest),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Manifest already exists'),
        ),
      ),
    );
    await writer.writeManifest(manifest, overwrite: true);
  });

  test('writes cascade wake traces with distinct artifact names', () async {
    final dir = await Directory.systemTemp.createTemp('lotti-cascade-trace-');
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    final writer = TraceWriter(runsRoot: dir.path);
    final wake1 = await writer.writeTrace(
      _validTrace(
        'cascade-run',
        cascadeWake: const EvalTraceCascadeWake(
          cascadeId: EvalTraceCascadeWake.taskLogCascadeId,
          wakeIndex: 1,
          wakeCount: 3,
        ),
      ),
    );
    final wake0 = await writer.writeTrace(
      _validTrace(
        'cascade-run',
        cascadeWake: const EvalTraceCascadeWake(
          cascadeId: EvalTraceCascadeWake.taskLogCascadeId,
          wakeIndex: 0,
          wakeCount: 3,
        ),
      ),
    );

    expect(
      wake0.path,
      endsWith(
        'task_release_notes__frontier-fast__cascade-task-log__wake-0'
        '.trace.json',
      ),
    );
    expect(
      wake1.path,
      endsWith(
        'task_release_notes__frontier-fast__cascade-task-log__wake-1'
        '.trace.json',
      ),
    );
    expect(
      writer.verdictFileForTrace(wake1).path,
      endsWith('__cascade-task-log__wake-1.verdict.json'),
    );

    final traces = await writer.readTraces('cascade-run');

    expect(traces.map((trace) => trace.cascadeWake?.wakeIndex), [0, 1]);
    expect(traces.map((trace) => trace.trialIndex), [0, 0]);
    expect(
      traces.first.cascadeWake?.cascadeId,
      EvalTraceCascadeWake.taskLogCascadeId,
    );
  });

  test('readRun accepts traces bound to the run manifest', () async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-trace-bound-manifest-',
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final writer = TraceWriter(runsRoot: dir.path);
    final manifest = _validManifest('run-1');

    await writer.writeManifest(manifest);
    await writer.writeTrace(
      _validTrace(
        'run-1',
        manifestDigest: manifest.manifestDigest!,
      ),
    );

    final run = await writer.readRun('run-1');

    expect(run.traces, hasLength(1));
    expect(
      run.traces.single.provenance.manifestDigest,
      manifest.manifestDigest,
    );
  });

  test('writes and reads digest-bound pairwise preference artifacts', () async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-pairwise-preference-',
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final writer = TraceWriter(runsRoot: dir.path);
    final manifest = _validManifest(
      'run-1',
      profiles: const [kFrontierFastProfile, kFrontierProfile],
    );
    await writer.writeManifest(manifest);
    final baselineTrace = _validTrace(
      'run-1',
      manifestDigest: manifest.manifestDigest!,
    );
    final candidateTrace = _validTrace(
      'run-1',
      profile: kFrontierProfile,
      manifestDigest: manifest.manifestDigest!,
    );
    final baselineFile = await writer.writeTrace(baselineTrace);
    final candidateFile = await writer.writeTrace(candidateTrace);
    final vote = _preferenceVote(
      voteId: 'vote-1',
      optionA: EvalPairwiseTraceRef.fromTrace(
        candidateTrace,
        traceDigest: await writer.traceDigest(candidateFile),
      ),
      optionB: EvalPairwiseTraceRef.fromTrace(
        baselineTrace,
        traceDigest: await writer.traceDigest(baselineFile),
      ),
    );

    final preferenceFile = await writer.writePairwisePreferenceVote(vote);
    final votes = await writer.readPairwisePreferenceVotes('run-1');
    final run = await writer.readRun('run-1');
    final summary = EvalPairwisePreferenceReporter.summarize(
      votes,
      policy: const EvalPairwisePreferencePolicy(minVotes: 1),
    ).single;

    expect(preferenceFile.uri.pathSegments.last, 'vote-1.preference.json');
    expect(votes.map((vote) => vote.voteId), ['vote-1']);
    expect(run.traces, hasLength(2));
    expect(run.artifactNames, contains('vote-1.preference.json'));
    expect(summary.status, EvalPairwisePreferenceStatus.optionBWins);
    expect(summary.preferredTrace?.profileName, kFrontierProfile.name);
  });

  test('rejects stale pairwise preference trace bindings', () async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-stale-pairwise-preference-',
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final writer = TraceWriter(runsRoot: dir.path);
    final manifest = _validManifest(
      'run-1',
      profiles: const [kFrontierFastProfile, kFrontierProfile],
    );
    await writer.writeManifest(manifest);
    final baselineTrace = _validTrace(
      'run-1',
      manifestDigest: manifest.manifestDigest!,
    );
    final candidateTrace = _validTrace(
      'run-1',
      profile: kFrontierProfile,
      manifestDigest: manifest.manifestDigest!,
    );
    final baselineFile = await writer.writeTrace(baselineTrace);
    final candidateFile = await writer.writeTrace(candidateTrace);
    final staleVote = _preferenceVote(
      voteId: 'vote-stale',
      optionA: EvalPairwiseTraceRef.fromTrace(
        candidateTrace,
        traceDigest: EvalProvenance.digestText('stale-candidate'),
      ),
      optionB: EvalPairwiseTraceRef.fromTrace(
        baselineTrace,
        traceDigest: await writer.traceDigest(baselineFile),
      ),
    );
    final preferenceFile = writer.pairwisePreferenceFileFor(
      runId: 'run-1',
      voteId: staleVote.voteId,
    );
    await preferenceFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(staleVote.toJson()),
    );
    expect(candidateFile.existsSync(), isTrue);

    await expectLater(
      writer.readPairwisePreferenceVotes('run-1'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Stale pairwise preference vote-stale'),
        ),
      ),
    );
  });

  test('rejects orphan pairwise preference trace refs', () async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-orphan-pairwise-preference-',
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final writer = TraceWriter(runsRoot: dir.path);
    final manifest = _validManifest(
      'run-1',
      profiles: const [kFrontierFastProfile, kFrontierProfile],
    );
    await writer.writeManifest(manifest);
    final baselineTrace = _validTrace(
      'run-1',
      manifestDigest: manifest.manifestDigest!,
    );
    final candidateTrace = _validTrace(
      'run-1',
      profile: kFrontierProfile,
      manifestDigest: manifest.manifestDigest!,
    );
    final baselineFile = await writer.writeTrace(baselineTrace);
    final vote = _preferenceVote(
      voteId: 'vote-orphan',
      optionA: EvalPairwiseTraceRef.fromTrace(
        candidateTrace,
        traceDigest: EvalProvenance.digestText('missing-candidate'),
      ),
      optionB: EvalPairwiseTraceRef.fromTrace(
        baselineTrace,
        traceDigest: await writer.traceDigest(baselineFile),
      ),
    );
    final preferenceFile = writer.pairwisePreferenceFileFor(
      runId: 'run-1',
      voteId: vote.voteId,
    );
    await preferenceFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(vote.toJson()),
    );

    final run = await writer.readRun('run-1');
    expect(run.traces, hasLength(1));
    await expectLater(
      writer.readPairwisePreferenceVotes('run-1', traces: run.traces),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('references missing optionA trace'),
        ),
      ),
    );
  });

  test('trace overwrite protects pairwise preference bindings', () async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-overwrite-pairwise-preference-',
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final writer = TraceWriter(runsRoot: dir.path);
    final manifest = _validManifest(
      'run-1',
      profiles: const [kFrontierFastProfile, kFrontierProfile],
    );
    await writer.writeManifest(manifest);
    final baselineTrace = _validTrace(
      'run-1',
      manifestDigest: manifest.manifestDigest!,
    );
    final candidateTrace = _validTrace(
      'run-1',
      profile: kFrontierProfile,
      manifestDigest: manifest.manifestDigest!,
    );
    final baselineFile = await writer.writeTrace(baselineTrace);
    final candidateFile = await writer.writeTrace(candidateTrace);
    final vote = _preferenceVote(
      voteId: 'vote-1',
      optionA: EvalPairwiseTraceRef.fromTrace(
        candidateTrace,
        traceDigest: await writer.traceDigest(candidateFile),
      ),
      optionB: EvalPairwiseTraceRef.fromTrace(
        baselineTrace,
        traceDigest: await writer.traceDigest(baselineFile),
      ),
    );
    final preferenceFile = await writer.writePairwisePreferenceVote(vote);

    await expectLater(
      writer.writeTrace(candidateTrace, overwrite: true),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('existing pairwise preference vote'),
        ),
      ),
    );

    await writer.writeTrace(
      candidateTrace,
      overwrite: true,
      deletePairwisePreferencesOnOverwrite: true,
    );

    expect(preferenceFile.existsSync(), isFalse);
  });

  test('readRun rejects missing manifests', () async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-trace-missing-manifest-',
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final writer = TraceWriter(runsRoot: dir.path);
    await writer.writeTrace(_validTrace('run-1'));

    await expectLater(
      writer.readRun('run-1'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Missing run manifest'),
        ),
      ),
    );
  });

  test('readRun rejects traces bound to a stale manifest', () async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-trace-stale-manifest-',
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final writer = TraceWriter(runsRoot: dir.path);
    await writer.writeManifest(_validManifest('run-1'));
    await writer.writeTrace(_validTrace('run-1'));

    await expectLater(
      writer.readRun('run-1'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('cites manifestDigest'),
        ),
      ),
    );
  });

  test('readRun rejects tampered manifest digests', () async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-tampered-manifest-',
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final writer = TraceWriter(runsRoot: dir.path);
    final manifest = _validManifest('run-1');
    final file = await writer.writeManifest(manifest);
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>
      ..['command'] = 'tampered-command';
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );

    await expectLater(
      writer.readRun('run-1'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Stale manifest digest'),
        ),
      ),
    );
  });

  test('readRun rejects manifests for stale trace schemas', () async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-stale-trace-schema-manifest-',
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final writer = TraceWriter(runsRoot: dir.path);
    final file = await writer.writeManifest(_validManifest('run-1'));
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>
      ..['traceSchemaVersion'] = EvalTrace.schemaVersion - 1;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );

    await expectLater(
      writer.readRun('run-1'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('traceSchemaVersion'),
        ),
      ),
    );
  });

  test('rejects mismatched manifest schema versions', () async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-manifest-schema-',
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final writer = TraceWriter(runsRoot: dir.path);
    final file = await writer.writeManifest(_validManifest('run-1'));
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>
      ..['schemaVersion'] = EvalRunManifest.schemaVersion + 1;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );

    await expectLater(
      writer.readManifest('run-1'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Unsupported EvalRunManifest schemaVersion'),
        ),
      ),
    );
  });

  test('rejects path-like run ids before writing artifacts', () async {
    final dir = await Directory.systemTemp.createTemp('lotti-trace-run-id-');
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    final writer = TraceWriter(runsRoot: dir.path);

    for (final runId in const ['', '.', '..', '../escape', 'nested/run']) {
      expect(
        () => writer.traceFileFor(
          runId: runId,
          scenarioId: 'scenario',
          profileName: 'profile',
        ),
        throwsArgumentError,
        reason: 'runId=$runId',
      );
      await expectLater(
        writer.writeTrace(_validTrace(runId)),
        throwsArgumentError,
        reason: 'runId=$runId',
      );
    }
  });
}

EvalRunManifest _validManifest(
  String runId, {
  List<EvalProfile> profiles = const [kFrontierFastProfile],
}) => EvalProvenance.captureRunManifest(
  runId: runId,
  targetName: 'trace-writer-test',
  targetKind: 'test',
  scenarios: [taskReleaseNotesScenario],
  profiles: profiles,
  createdAt: DateTime(2026, 6, 10, 12),
  command: 'trace-writer-test',
  environment: const <String, String>{},
);

EvalTrace _validTrace(
  String runId, {
  String manifestDigest = EvalProvenance.unboundManifestDigest,
  EvalProfile profile = kFrontierFastProfile,
  EvalTraceCascadeWake? cascadeWake,
}) => EvalTrace(
  runId: runId,
  scenario: taskReleaseNotesScenario,
  profile: profile,
  provenance: EvalProvenance.capture(
    scenario: taskReleaseNotesScenario,
    profile: profile,
    manifestDigest: manifestDigest,
  ),
  cascadeWake: cascadeWake,
  output: const AgentRunOutput(
    success: true,
    usage: InferenceUsage(inputTokens: 10, outputTokens: 5),
    report: AgentReportRecord(
      oneLiner: 'Done',
      tldr: 'Task was handled.',
      content: 'Handled.',
    ),
  ),
  level1Checks: runLevel1(
    taskReleaseNotesScenario,
    const AgentRunOutput(
      success: true,
      usage: InferenceUsage(inputTokens: 10, outputTokens: 5),
      report: AgentReportRecord(
        oneLiner: 'Done',
        tldr: 'Task was handled.',
        content: 'Handled.',
      ),
    ),
    profile: profile,
  ),
);

JudgeVerdict _verdict({
  required int goalAttainment,
  required int quality,
  required int efficiency,
  required bool pass,
  String? traceDigest,
}) => JudgeVerdict(
  traceDigest: traceDigest,
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

EvalPairwisePreferenceVote _preferenceVote({
  required String voteId,
  required EvalPairwiseTraceRef optionA,
  required EvalPairwiseTraceRef optionB,
}) => EvalPairwisePreferenceVote(
  voteId: voteId,
  optionA: optionA,
  optionB: optionB,
  reviewerId: 'judge-a',
  reviewerKind: EvalPairwiseReviewerKind.llmJudge,
  reviewerModel: 'claude-code-test',
  promptDigest: EvalProvenance.digestText('pairwise-prompt'),
  calibrationSetVersion: 'pairwise-gold-v1',
  profileVisible: false,
  modelIdentityVisible: false,
  peerVotesVisible: false,
  traceOrderRandomized: true,
  choice: EvalPairwisePreferenceChoice.optionA,
  rationale: 'Option A is more faithful.',
);
