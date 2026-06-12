import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../harness/eval_harness.dart';
import '../harness/eval_profile_config.dart';
import '../scenarios/eval_scenarios.dart';

void main() {
  test('imports blinded verdicts as raw digest-bound verdicts', () async {
    final bench = await _ImportBench.create();
    await bench.writeBlindedVerdict();

    final result = await EvalBlindedVerdictImporter.importRun(
      run: bench.run,
      writer: bench.writer,
      exportDir: bench.exportDir,
    );
    final rawVerdictJson =
        jsonDecode(await result.importedVerdictFiles.single.readAsString())
            as Map<String, dynamic>;
    final importedRun = await bench.writer.readRun('blind-import-run');

    expect(result.importedCount, 1);
    expect(rawVerdictJson['traceDigest'], await bench.rawTraceDigest());
    expect(importedRun.traces.single.verdict, isNotNull);
    expect(
      importedRun.traces.single.verdict!.traceDigest,
      rawVerdictJson['traceDigest'],
    );
    expect(
      importedRun.traces.single.verdict!.judge.modelIdentityVisible,
      isFalse,
    );
    final importProvenance = importedRun.traces.single.verdict!.blindedImport!;
    expect(importProvenance.blindedTraceId, bench.blindedTraceId);
    expect(importProvenance.reviewPayloadDigest, bench.reviewPayloadDigest);
    expect(importProvenance.rawTraceDigest, await bench.rawTraceDigest());
    expect(
      importProvenance.privateKeyDigest,
      EvalProvenance.digestJson(await bench.privateKeyJson()),
    );
    final verification = EvalRunVerifier.verify(
      runId: 'blind-import-run',
      traces: importedRun.traces,
      scenarios: [taskReleaseNotesScenario],
      profiles: const [_profile],
      agentDirectiveVariants: const [_variant],
      manifest: importedRun.manifest,
      artifactNames: importedRun.artifactNames,
    );
    expect(
      verification.errors,
      isEmpty,
      reason: verification.errors.join('\n'),
    );
  });

  test('rejects incomplete blinded verdict sets', () async {
    final bench = await _ImportBench.create();

    await expectLater(
      EvalBlindedVerdictImporter.importRun(
        run: bench.run,
        writer: bench.writer,
        exportDir: bench.exportDir,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Missing blinded verdict for blind-0001'),
        ),
      ),
    );
    expect(bench.rawVerdictFile.existsSync(), isFalse);
  });

  test('rejects blinded verdicts with stale review payload digests', () async {
    final bench = await _ImportBench.create();
    await bench.writeBlindedVerdict(
      reviewPayloadDigest: EvalProvenance.digestText('stale-review-payload'),
    );

    await expectLater(
      EvalBlindedVerdictImporter.importRun(
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
    expect(bench.rawVerdictFile.existsSync(), isFalse);
  });

  test('rejects imports after raw trace drift', () async {
    final bench = await _ImportBench.create();
    await bench.writeBlindedVerdict();
    final rawTraceJson =
        jsonDecode(await bench.rawTraceFile.readAsString())
            as Map<String, dynamic>;
    rawTraceJson['trialIndex'] = 1;
    await bench.rawTraceFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(rawTraceJson),
    );

    await expectLater(
      EvalBlindedVerdictImporter.importRun(
        run: bench.run,
        writer: bench.writer,
        exportDir: bench.exportDir,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('rawTraceDigest'),
        ),
      ),
    );
    expect(bench.rawVerdictFile.existsSync(), isFalse);
  });

  test('rejects private key trace metadata drift', () async {
    final bench = await _ImportBench.create();
    await bench.writeBlindedVerdict();
    await bench.updatePrivateKeyEntry((entry) {
      entry['scenarioDigest'] = EvalProvenance.digestText('wrong-scenario');
    });

    await expectLater(
      EvalBlindedVerdictImporter.importRun(
        run: bench.run,
        writer: bench.writer,
        exportDir: bench.exportDir,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('scenarioDigest'),
        ),
      ),
    );
    expect(bench.rawVerdictFile.existsSync(), isFalse);
  });

  test('rejects unblinded judge provenance', () async {
    final bench = await _ImportBench.create();
    await bench.writeBlindedVerdict(modelIdentityVisible: true);

    await expectLater(
      EvalBlindedVerdictImporter.importRun(
        run: bench.run,
        writer: bench.writer,
        exportDir: bench.exportDir,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('judge.modelIdentityVisible must be false'),
        ),
      ),
    );
    expect(bench.rawVerdictFile.existsSync(), isFalse);
  });

  test('refuses to overwrite existing raw verdicts unless explicit', () async {
    final bench = await _ImportBench.create();
    await bench.writeBlindedVerdict(goalAttainment: 4);
    await bench.writer.writeVerdict(
      bench.rawTraceFile,
      _verdict(goalAttainment: 3),
    );

    await expectLater(
      EvalBlindedVerdictImporter.importRun(
        run: bench.run,
        writer: bench.writer,
        exportDir: bench.exportDir,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Refusing to overwrite existing raw verdict'),
        ),
      ),
    );

    await EvalBlindedVerdictImporter.importRun(
      run: bench.run,
      writer: bench.writer,
      exportDir: bench.exportDir,
      overwrite: true,
    );
    final importedRun = await bench.writer.readRun('blind-import-run');
    expect(importedRun.traces.single.verdict!.goalAttainment, 4);
  });
}

class _ImportBench {
  _ImportBench({
    required this.writer,
    required this.exportDir,
    required this.run,
    required this.rawTraceFile,
    required this.rawVerdictFile,
    required this.privateKeyFile,
    required this.reviewPayloadDigest,
    required this.blindedTraceId,
    required this.blindedVerdictFile,
  });

  static Future<_ImportBench> create() async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-blinded-verdict-import-',
    );
    final writer = TraceWriter(runsRoot: '${dir.path}/runs');
    final manifest = _manifest();
    await writer.writeManifest(manifest);
    final rawTraceFile = await writer.writeTrace(
      _trace(manifestDigest: manifest.manifestDigest!),
    );
    final run = await writer.readRun('blind-import-run');
    final exportDir = Directory('${dir.path}/blind');
    final export = await EvalBlindedTraceExporter.writeRun(
      run: run,
      writer: writer,
      outputDir: exportDir,
      exportSeed: 'import-test-seed',
    );
    final privateKey =
        jsonDecode(await export.privateKeyFile.readAsString())
            as Map<String, dynamic>;
    final entry =
        (privateKey['entries'] as List).single as Map<String, dynamic>;
    final blindedTraceId = entry['blindedTraceId'] as String;
    final judgeFile = entry['judgeFile'] as String;
    final blindedVerdictFile = File(
      '${export.judgeDir.path}/'
      '${judgeFile.replaceFirst('.blinded-trace.json', '.blinded-verdict.json')}',
    );
    final bench = _ImportBench(
      writer: writer,
      exportDir: exportDir,
      run: run,
      rawTraceFile: rawTraceFile,
      rawVerdictFile: writer.verdictFileForTrace(rawTraceFile),
      privateKeyFile: export.privateKeyFile,
      reviewPayloadDigest: entry['reviewPayloadDigest'] as String,
      blindedTraceId: blindedTraceId,
      blindedVerdictFile: blindedVerdictFile,
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    return bench;
  }

  final TraceWriter writer;
  final Directory exportDir;
  final EvalRunArtifacts run;
  final File rawTraceFile;
  final File rawVerdictFile;
  final File privateKeyFile;
  final String reviewPayloadDigest;
  final String blindedTraceId;
  final File blindedVerdictFile;

  Future<String> rawTraceDigest() => writer.traceDigest(rawTraceFile);

  Future<Map<String, dynamic>> privateKeyJson() async =>
      jsonDecode(await privateKeyFile.readAsString()) as Map<String, dynamic>;

  Future<void> updatePrivateKeyEntry(
    void Function(Map<String, dynamic> entry) update,
  ) async {
    final json = await privateKeyJson();
    update((json['entries'] as List).single as Map<String, dynamic>);
    await privateKeyFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }

  Future<void> writeBlindedVerdict({
    String? reviewPayloadDigest,
    int goalAttainment = 5,
    bool modelIdentityVisible = false,
  }) async {
    await blindedVerdictFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': EvalBlindedVerdictImporter.schemaVersion,
        'kind': EvalBlindedVerdictImporter.verdictKind,
        'blindedTraceId': blindedTraceId,
        'reviewPayloadDigest': reviewPayloadDigest ?? this.reviewPayloadDigest,
        'verdict': _verdict(
          goalAttainment: goalAttainment,
          modelIdentityVisible: modelIdentityVisible,
        ).toJson(),
      }),
    );
  }
}

const _variant = EvalAgentDirectiveVariant(
  name: 'metadata-import-v1',
  generalDirective: 'Create durable metadata before writing reports.',
);

const _profile = EvalProfile(
  name: 'frontier-import-profile',
  isLocal: false,
  modelClass: EvalModelClass.frontierFast,
  modelId: 'gpt-import-model',
  tokenBudget: 50000,
  maxCompletionTokens: 4096,
);

EvalRunManifest _manifest() => EvalProvenance.captureRunManifest(
  runId: 'blind-import-run',
  targetName: 'blind-import-test',
  targetKind: 'test',
  scenarios: [taskReleaseNotesScenario],
  profiles: const [_profile],
  agentDirectiveVariants: const [_variant],
  createdAt: DateTime(2026, 6, 12, 14),
  command: 'blind-import-test',
  environment: const <String, String>{},
);

EvalTrace _trace({required String manifestDigest}) {
  final output = _outputFor(_profile);
  return EvalTrace(
    runId: 'blind-import-run',
    scenario: taskReleaseNotesScenario,
    profile: _profile,
    agentDirectiveVariant: _variant,
    provenance: EvalProvenance.capture(
      scenario: taskReleaseNotesScenario,
      profile: _profile,
      agentDirectiveVariant: _variant,
      manifestDigest: manifestDigest,
    ),
    output: output,
    level1Checks: runLevel1(
      taskReleaseNotesScenario,
      output,
      profile: _profile,
    ),
  );
}

AgentRunOutput _outputFor(EvalProfile profile) {
  final profileConfig = evalProfileConfig(profile);
  return AgentRunOutput(
    success: true,
    usage: const InferenceUsage(inputTokens: 100, outputTokens: 40),
    report: const AgentReportRecord(
      oneLiner: 'Release notes groomed',
      tldr: 'Estimate and next steps are clear.',
      content: '## Done\nThe release-notes task is ready.',
    ),
    resolvedModel: profileConfig.toResolvedModelRecord(
      wakeRunResolvedModelId: profileConfig.providerModelId,
      usageModelId: profileConfig.providerModelId,
    ),
    providerDecision: profileConfig.toProviderDecisionRecord(
      envPresence: const {'OPENAI_API_KEY': true},
    ),
    turnCount: 1,
  );
}

JudgeVerdict _verdict({
  int goalAttainment = 5,
  bool modelIdentityVisible = false,
}) => JudgeVerdict(
  goalAttainment: goalAttainment,
  quality: 5,
  efficiency: 4,
  pass: true,
  judge: JudgeProvenanceRecord(
    judgeName: 'claude-code',
    judgeModel: 'test-judge',
    promptDigest: EvalProvenance.promptDigest(),
    calibrationSetVersion: 'human-gold-v1',
    profileVisible: true,
    modelIdentityVisible: modelIdentityVisible,
  ),
  rationale: 'Reviewed blinded trace and matched the rubric.',
);
