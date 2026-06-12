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
      expect(pairJson['reviewPayloadDigest'], reviewPayloadDigest);
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
        '${bench.result.judgeDir.path}/pairs/extra.blinded-preference.json',
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
  final EvalBlindedPairwiseExportResult result;
  final EvalPairwiseTraceRef optionA;
  final EvalPairwiseTraceRef optionB;
  final File optionAFile;
  final File optionBFile;

  static Future<_PairwiseBench> create() async {
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
    final result = await EvalBlindedPairwisePreference.writePairs(
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
    );
    return _PairwiseBench(
      writer: writer,
      run: run,
      exportDir: exportDir,
      result: result,
      optionA: optionA,
      optionB: optionB,
      optionAFile: optionAFile,
      optionBFile: optionBFile,
    );
  }

  Future<Map<String, dynamic>> blindedPairJson() async =>
      jsonDecode(await result.blindedPairFiles.single.readAsString())
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> privateKeyJson() async =>
      jsonDecode(await result.privateKeyFile.readAsString())
          as Map<String, dynamic>;

  Future<String> publicPayload() async => jsonEncode({
    'manifest': jsonDecode(await result.judgeManifestFile.readAsString()),
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
      result.blindedPairFiles.single.path.replaceFirst(
        '.blinded-pair.json',
        '.blinded-preference.json',
      ),
    );
    final preference = <String, Object?>{
      'voteId': 'vote-1',
      'reviewerId': 'reviewer-a',
      'reviewerKind': EvalPairwiseReviewerKind.human.name,
      'promptDigest': EvalProvenance.digestText('pairwise-review-prompt'),
      'calibrationSetVersion': 'pairwise-gold-v1',
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
  final output = AgentRunOutput(
    success: true,
    usage: const InferenceUsage(inputTokens: 100, outputTokens: 25),
    report: const AgentReportRecord(
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
