import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../harness/eval_harness.dart';
import '../scenarios/eval_scenarios.dart';

void main() {
  test(
    'exports and imports blinded pairwise preferences with provenance',
    () async {
      final bench = await _PairwiseBench.create();

      final publicPayload = await bench.publicPayload();
      final privatePayload = await bench.privatePayload();
      final pairJson = await bench.blindedPairJson();
      final reviewPayload = pairJson['reviewPayload'] as Map<String, dynamic>;
      final reviewPayloadDigest = EvalProvenance.digestJson(reviewPayload);
      final readinessPlan = await bench.readinessPlan();
      final readinessRegistration = await bench.readinessPlanRegistration();
      expect(pairJson['reviewPayloadDigest'], reviewPayloadDigest);
      expect(readinessPlan.manifestDigest, bench.run.manifest.manifestDigest);
      expect(readinessPlan.comparisons, hasLength(1));
      expect(
        readinessPlan.comparisons.single.reviewPayloadDigest,
        reviewPayloadDigest,
      );
      expect(
        readinessRegistration?.sourceManifestDigest,
        bench.run.manifest.manifestDigest,
      );
      expect(
        readinessRegistration?.evidence.toJson(),
        readinessPlan.toManifestEvidence().toJson(),
      );
      expect(
        bench._result.readinessPlanRegistrationFile.path,
        bench.writer
            .pairwiseReadinessPlanRegistrationFileFor('pairwise-blind-run')
            .path,
      );
      expect(publicPayload, isNot(contains('frontier-secret-profile')));
      expect(publicPayload, isNot(contains('local-secret-profile')));
      expect(publicPayload, isNot(contains('gpt-secret-model')));
      expect(publicPayload, isNot(contains('local-secret-model')));
      expect(publicPayload, isNot(contains(bench.optionA.traceDigest)));
      expect(publicPayload, isNot(contains(bench.optionB.traceDigest)));
      expect(privatePayload, contains('frontier-secret-profile'));
      expect(privatePayload, contains('local-secret-profile'));
      expect(privatePayload, contains(bench.optionA.traceDigest));
      expect(privatePayload, contains(bench.optionB.traceDigest));

      await bench.writeBlindedPreference(
        preferenceOverrides: const {
          'profileVisible': true,
          'modelIdentityVisible': true,
          'peerVotesVisible': true,
          'traceOrderRandomized': false,
        },
      );

      final result = await EvalBlindedPairwisePreference.importVotes(
        run: bench.run,
        writer: bench.writer,
        exportDir: bench.exportDir,
      );
      final votes = await bench.writer.readPairwisePreferenceVotes(
        'pairwise-blind-run',
      );
      final summary = EvalPairwisePreferenceReporter.summarize(
        votes,
        policy: const EvalPairwisePreferencePolicy(
          minVotes: 1,
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
      ).single;

      expect(result.importedCount, 1);
      expect(votes, hasLength(1));
      expect(votes.single.profileVisible, isFalse);
      expect(votes.single.modelIdentityVisible, isFalse);
      expect(votes.single.peerVotesVisible, isFalse);
      expect(votes.single.traceOrderRandomized, isTrue);
      expect(votes.single.blindedImport, isNotNull);
      expect(
        votes.single.reviewProtocolFingerprint,
        readinessPlan.reviewProtocolFingerprint,
      );
      expect(
        votes.single.blindedImport!.reviewPayloadDigest,
        reviewPayloadDigest,
      );
      expect(
        votes.single.blindedImport!.privateKeyDigest,
        EvalProvenance.digestJson(await bench.privateKeyJson()),
      );
      expect(
        votes.single.blindedImport!.optionARawTraceDigest,
        votes.single.optionA.traceDigest,
      );
      expect(
        votes.single.blindedImport!.optionBRawTraceDigest,
        votes.single.optionB.traceDigest,
      );
      expect(summary.status, EvalPairwisePreferenceStatus.optionAWins);
    },
  );

  test('rejects stale blinded preference review payload digests', () async {
    final bench = await _PairwiseBench.create();
    await bench.writeBlindedPreference(
      reviewPayloadDigest: EvalProvenance.digestText('stale-pair-payload'),
    );

    await expectLater(
      EvalBlindedPairwisePreference.importVotes(
        run: bench.run,
        writer: bench.writer,
        exportDir: bench.exportDir,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('reviewPayloadDigest'),
        ),
      ),
    );
    expect(
      await bench.writer.readPairwisePreferenceVotes('pairwise-blind-run'),
      isEmpty,
    );
  });

  test(
    'rejects unexpected blinded preference wrappers before writing',
    () async {
      final bench = await _PairwiseBench.create();
      await bench.writeBlindedPreference();
      await File(
        '${bench._result.judgeDir.path}/pairs/extra.blinded-preference.json',
      ).writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': EvalBlindedPairwisePreference.schemaVersion,
          'kind': EvalBlindedPairwisePreference.voteKind,
          'blindedPairId': 'extra',
          'reviewPayloadDigest': EvalProvenance.unboundManifestDigest,
          'preference': {'voteId': 'extra'},
        }),
      );

      await expectLater(
        EvalBlindedPairwisePreference.importVotes(
          run: bench.run,
          writer: bench.writer,
          exportDir: bench.exportDir,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Unexpected blinded pairwise preference file'),
          ),
        ),
      );
      expect(
        await bench.writer.readPairwisePreferenceVotes('pairwise-blind-run'),
        isEmpty,
      );
    },
  );

  test('rejects imports after raw trace drift', () async {
    final bench = await _PairwiseBench.create();
    await bench.writeBlindedPreference();
    final rawTraceJson =
        jsonDecode(await bench.optionAFile.readAsString())
            as Map<String, dynamic>;
    rawTraceJson['trialIndex'] = 1;
    await bench.optionAFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(rawTraceJson),
    );

    await expectLater(
      EvalBlindedPairwisePreference.importVotes(
        run: bench.run,
        writer: bench.writer,
        exportDir: bench.exportDir,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Stale pairwise blinded pair'),
        ),
      ),
    );
    expect(
      await bench.writer.readPairwisePreferenceVotes('pairwise-blind-run'),
      isEmpty,
    );
  });

  test('exports custom pairwise readiness plan settings', () async {
    final bench = await _PairwiseBench.create(export: false);
    final protocol = EvalPairwiseReadinessReviewProtocol(
      reviewerKind: EvalPairwiseReviewerKind.llmJudge,
      reviewerModel: 'gpt-5.4',
      promptDigest: EvalProvenance.digestText('llm-pairwise-review-v2'),
      calibrationSetVersion: 'pairwise-llm-gold-v2',
      profileVisible: false,
      modelIdentityVisible: false,
      peerVotesVisible: false,
      traceOrderRandomized: true,
    );

    final result = await bench.writePairs(
      readinessPlanId: 'custom-pairwise-gate',
      readinessReviewProtocol: protocol,
      readinessMinBlindedPairwisePreferenceDecisions: 1,
      readinessMinVotes: 2,
      readinessQuorumFraction: 0.75,
    );
    final plan = EvalPairwiseReadinessPlan.fromJson(
      jsonDecode(await result.readinessPlanFile.readAsString())
          as Map<String, dynamic>,
    );
    final registration = await bench.writer
        .readPairwiseReadinessPlanRegistration(
          bench.run.manifest.runId,
        );

    expect(plan.planId, 'custom-pairwise-gate');
    expect(plan.reviewProtocolFingerprint, protocol.fingerprint);
    expect(plan.minBlindedPairwisePreferenceDecisions, 1);
    expect(plan.preferencePolicy.minVotes, 2);
    expect(plan.preferencePolicy.quorumFraction, 0.75);
    expect(registration?.evidence.toJson(), plan.toManifestEvidence().toJson());
  });

  test('exports pairwise readiness plans that refine pre-run intent', () async {
    final bench = await _PairwiseBench.create(export: false);
    final intent = bench.readinessIntent();

    final result = await bench.writePairs(readinessIntent: intent);
    final plan = EvalPairwiseReadinessPlan.fromJson(
      jsonDecode(await result.readinessPlanFile.readAsString())
          as Map<String, dynamic>,
    );
    final registration = await bench.writer
        .readPairwiseReadinessPlanRegistration(
          bench.run.manifest.runId,
        );

    expect(plan.intent?.toJson(), intent.toJson());
    expect(
      plan.toManifestEvidence().toJson(),
      intent.toManifestEvidence().toJson(),
    );
    expect(
      plan.comparisons.single.intentKey,
      intent.comparisons.single.intentKey,
    );
    expect(
      plan.comparisons.single.comparisonKey,
      contains('pairwise-blind-run::task_release_notes'),
    );
    expect(
      registration?.evidence.toJson(),
      intent.toManifestEvidence().toJson(),
    );
  });

  test('rejects pairwise readiness intent option drift', () async {
    final bench = await _PairwiseBench.create(export: false);
    final intent = bench.readinessIntent(
      optionB: EvalPairwiseReadinessIntentOption(
        profileName: bench.optionB.profileName,
        profileDigest: EvalProvenance.digestText('stale-profile-digest'),
        modelClass: bench.optionB.modelClass,
        agentDirectiveVariantName: bench.optionB.agentDirectiveVariantName,
        agentDirectiveVariantDigest: bench.optionB.agentDirectiveVariantDigest,
      ),
    );

    await expectLater(
      bench.writePairs(readinessIntent: intent),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('does not match exported pair pair-1'),
        ),
      ),
    );
    expect(
      bench.writer
          .pairwiseReadinessPlanRegistrationFileFor(bench.run.manifest.runId)
          .existsSync(),
      isFalse,
    );
  });

  test(
    'rejects invalid readiness settings before writing export files',
    () async {
      final bench = await _PairwiseBench.create(export: false);

      await expectLater(
        bench.writePairs(
          readinessMinBlindedPairwisePreferenceDecisions: 2,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('cannot exceed pair count'),
          ),
        ),
      );
      expect(bench.exportDir.existsSync(), isFalse);
      expect(
        bench.writer
            .pairwiseReadinessPlanRegistrationFileFor(bench.run.manifest.runId)
            .existsSync(),
        isFalse,
      );

      await expectLater(
        bench.writePairs(readinessPlanId: '   '),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('plan id must not be blank'),
          ),
        ),
      );
      expect(bench.exportDir.existsSync(), isFalse);
    },
  );
}

class _PairwiseBench {
  const _PairwiseBench({
    required this.writer,
    required this.run,
    required this.exportDir,
    required this.result,
    required this.optionA,
    required this.optionB,
    required this.optionAFile,
    required this.optionBFile,
  });

  final TraceWriter writer;
  final EvalRunArtifacts run;
  final Directory exportDir;
  final EvalBlindedPairwiseExportResult? result;
  final EvalPairwiseTraceRef optionA;
  final EvalPairwiseTraceRef optionB;
  final File optionAFile;
  final File optionBFile;

  static Future<_PairwiseBench> create({bool export = true}) async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-blinded-pairwise-',
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final writer = TraceWriter(runsRoot: '${dir.path}/runs');
    final manifest = _manifest();
    await writer.writeManifest(manifest);
    final optionATrace = _trace(
      manifestDigest: manifest.manifestDigest!,
      profile: _frontierProfile,
    );
    final optionBTrace = _trace(
      manifestDigest: manifest.manifestDigest!,
      profile: _localProfile,
    );
    final optionAFile = await writer.writeTrace(optionATrace);
    final optionBFile = await writer.writeTrace(optionBTrace);
    final optionA = EvalPairwiseTraceRef.fromTrace(
      optionATrace,
      traceDigest: await writer.traceDigest(optionAFile),
    );
    final optionB = EvalPairwiseTraceRef.fromTrace(
      optionBTrace,
      traceDigest: await writer.traceDigest(optionBFile),
    );
    final run = await writer.readRun('pairwise-blind-run');
    final exportDir = Directory('${dir.path}/blind-pairwise');
    final bench = _PairwiseBench(
      writer: writer,
      run: run,
      exportDir: exportDir,
      result: null,
      optionA: optionA,
      optionB: optionB,
      optionAFile: optionAFile,
      optionBFile: optionBFile,
    );
    if (!export) return bench;
    return bench.withResult(await bench.writePairs());
  }

  EvalBlindedPairwiseExportResult get _result {
    final exportResult = result;
    if (exportResult == null) {
      throw StateError('Pairwise bench has no export result.');
    }
    return exportResult;
  }

  _PairwiseBench withResult(EvalBlindedPairwiseExportResult result) =>
      _PairwiseBench(
        writer: writer,
        run: run,
        exportDir: exportDir,
        result: result,
        optionA: optionA,
        optionB: optionB,
        optionAFile: optionAFile,
        optionBFile: optionBFile,
      );

  Future<EvalBlindedPairwiseExportResult> writePairs({
    String? readinessPlanId,
    EvalPairwiseReadinessIntent? readinessIntent,
    EvalPairwiseReadinessReviewProtocol? readinessReviewProtocol,
    int? readinessMinBlindedPairwisePreferenceDecisions,
    int readinessMinVotes = 1,
    double readinessQuorumFraction = 1,
  }) {
    return EvalBlindedPairwisePreference.writePairs(
      run: run,
      writer: writer,
      outputDir: exportDir,
      exportSeed: 'pairwise-test-seed',
      pairs: [
        EvalPairwiseReviewPair(
          pairId: 'pair-1',
          optionA: optionA,
          optionB: optionB,
        ),
      ],
      readinessPlanId: readinessPlanId,
      readinessIntent: readinessIntent,
      readinessReviewProtocol: readinessReviewProtocol,
      readinessMinBlindedPairwisePreferenceDecisions:
          readinessMinBlindedPairwisePreferenceDecisions,
      readinessMinVotes: readinessMinVotes,
      readinessQuorumFraction: readinessQuorumFraction,
    );
  }

  EvalPairwiseReadinessIntent readinessIntent({
    EvalPairwiseReadinessIntentOption? optionA,
    EvalPairwiseReadinessIntentOption? optionB,
  }) => EvalPairwiseReadinessIntent(
    planId: 'pairwise-readiness-pairwise-blind-run',
    baseReadinessPolicy: 'modelClassTuning',
    scenarioSetDigest: run.manifest.scenarioSetDigest,
    profileSetDigest: run.manifest.profileSetDigest,
    profileBindingSetDigest: run.manifest.profileBindingSetDigest,
    agentDirectiveVariantSetDigest:
        EvalProvenance.agentDirectiveVariantSetDigest(
          const [EvalAgentDirectiveVariant()],
        ),
    minBlindedPairwisePreferenceDecisions: 1,
    comparisons: [
      EvalPairwiseReadinessIntentComparison(
        pairId: 'pair-1',
        intentKey: 'profile::task_release_notes::frontier-vs-local',
        axis: EvalPairwiseComparisonAxis.profile,
        scenarioId: this.optionA.scenarioId,
        scenarioDigest: this.optionA.scenarioDigest,
        agentKind: this.optionA.agentKind,
        capabilityId: this.optionA.capabilityId,
        trialIndex: this.optionA.trialIndex,
        optionA: optionA ?? _intentOptionFor(this.optionA),
        optionB: optionB ?? _intentOptionFor(this.optionB),
        preferredOption: EvalPairwiseReadinessPreferredOption.optionA,
        outcomeRequirement: EvalPairwiseReadinessOutcomeRequirement.mustNotLose,
      ),
    ],
    reviewProtocol:
        EvalBlindedPairwisePreference.defaultReadinessReviewProtocol(),
    minVotes: 1,
    quorumFraction: 1,
    notes: 'test intent fixture',
  );

  Future<Map<String, dynamic>> blindedPairJson() async =>
      jsonDecode(await _result.blindedPairFiles.single.readAsString())
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> privateKeyJson() async =>
      jsonDecode(await _result.privateKeyFile.readAsString())
          as Map<String, dynamic>;

  Future<EvalPairwiseReadinessPlan> readinessPlan() async =>
      EvalPairwiseReadinessPlan.fromJson(
        jsonDecode(await _result.readinessPlanFile.readAsString())
            as Map<String, dynamic>,
      );

  Future<EvalPairwiseReadinessPlanRegistration?> readinessPlanRegistration() =>
      writer.readPairwiseReadinessPlanRegistration('pairwise-blind-run');

  Future<String> publicPayload() async => jsonEncode({
    'manifest': jsonDecode(await _result.judgeManifestFile.readAsString()),
    'pair': await blindedPairJson(),
  });

  Future<String> privatePayload() async => jsonEncode(await privateKeyJson());

  Future<void> writeBlindedPreference({
    String? reviewPayloadDigest,
    Map<String, Object?> preferenceOverrides = const {},
  }) async {
    final pair = await blindedPairJson();
    final blindedPairId = pair['blindedPairId'] as String;
    final digest =
        reviewPayloadDigest ?? (pair['reviewPayloadDigest'] as String);
    final file = File(
      _result.blindedPairFiles.single.path.replaceFirst(
        '.blinded-pair.json',
        '.blinded-preference.json',
      ),
    );
    final preference = <String, Object?>{
      'voteId': 'vote-1',
      'reviewerId': 'reviewer-a',
      'reviewerKind': EvalPairwiseReviewerKind.human.name,
      'promptDigest':
          EvalBlindedPairwisePreference.defaultReadinessReviewProtocol()
              .promptDigest,
      'calibrationSetVersion':
          EvalBlindedPairwisePreference.defaultReadinessReviewProtocol()
              .calibrationSetVersion,
      'profileVisible': false,
      'modelIdentityVisible': false,
      'peerVotesVisible': false,
      'traceOrderRandomized': true,
      'choice': EvalPairwisePreferenceChoice.optionA.name,
      'rationale': 'Option A is more faithful and concise.',
      'issues': <String>[],
      ...preferenceOverrides,
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': EvalBlindedPairwisePreference.schemaVersion,
        'kind': EvalBlindedPairwisePreference.voteKind,
        'blindedPairId': blindedPairId,
        'reviewPayloadDigest': digest,
        'preference': preference,
      }),
    );
  }
}

EvalPairwiseReadinessIntentOption _intentOptionFor(EvalPairwiseTraceRef ref) =>
    EvalPairwiseReadinessIntentOption(
      profileName: ref.profileName,
      profileDigest: ref.profileDigest,
      modelClass: ref.modelClass,
      agentDirectiveVariantName: ref.agentDirectiveVariantName,
      agentDirectiveVariantDigest: ref.agentDirectiveVariantDigest,
    );

const _frontierProfile = EvalProfile(
  name: 'frontier-secret-profile',
  isLocal: false,
  modelClass: EvalModelClass.frontierFast,
  modelId: 'gpt-secret-model',
  tokenBudget: 50000,
);

const _localProfile = EvalProfile(
  name: 'local-secret-profile',
  isLocal: true,
  modelClass: EvalModelClass.localSmall,
  modelId: 'local-secret-model',
  tokenBudget: 10000,
);

EvalRunManifest _manifest() => EvalProvenance.captureRunManifest(
  runId: 'pairwise-blind-run',
  targetName: 'pairwise-blind-test',
  targetKind: 'test',
  scenarios: [taskReleaseNotesScenario],
  profiles: const [_frontierProfile, _localProfile],
  createdAt: DateTime(2026, 6, 12, 12),
  command: 'pairwise-blind-test',
  environment: const <String, String>{},
);

EvalTrace _trace({
  required String manifestDigest,
  required EvalProfile profile,
}) {
  const output = AgentRunOutput(
    success: true,
    usage: InferenceUsage(inputTokens: 100, outputTokens: 25),
    report: AgentReportRecord(
      oneLiner: 'Updated metadata',
      tldr: 'Task metadata was updated.',
      content: 'Task metadata was updated with the requested fields.',
    ),
    turnCount: 1,
    wallClockMs: 1234,
  );
  return EvalTrace(
    runId: 'pairwise-blind-run',
    scenario: taskReleaseNotesScenario,
    profile: profile,
    provenance: EvalProvenance.capture(
      scenario: taskReleaseNotesScenario,
      profile: profile,
      manifestDigest: manifestDigest,
    ),
    output: output,
    level1Checks: runLevel1(
      taskReleaseNotesScenario,
      output,
      profile: profile,
    ),
  );
}
