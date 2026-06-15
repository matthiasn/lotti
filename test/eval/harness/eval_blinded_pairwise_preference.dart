// Blinded pairwise A/B preference review for eval traces.
//
// Raw traces remain the audit record. This module creates reviewer-facing pair
// packets with exact profile/model/provider identities removed, then imports
// blinded preference wrappers back into raw digest-bound `.preference.json`
// votes carrying explicit blinded-import provenance.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'eval_models.dart';
import 'eval_pairwise_preference.dart';
import 'eval_provenance.dart';
import 'eval_tuning_readiness.dart';
import 'trace_writer.dart';

class EvalPairwiseReviewPair {
  const EvalPairwiseReviewPair({
    required this.pairId,
    required this.optionA,
    required this.optionB,
  });

  final String pairId;
  final EvalPairwiseTraceRef optionA;
  final EvalPairwiseTraceRef optionB;
}

class EvalBlindedPairwiseExportResult {
  const EvalBlindedPairwiseExportResult({
    required this.judgeDir,
    required this.privateDir,
    required this.judgeManifestFile,
    required this.privateKeyFile,
    required this.readinessPlanFile,
    required this.readinessPlanRegistrationFile,
    required this.blindedPairFiles,
  });

  final Directory judgeDir;
  final Directory privateDir;
  final File judgeManifestFile;
  final File privateKeyFile;
  final File readinessPlanFile;
  final File readinessPlanRegistrationFile;
  final List<File> blindedPairFiles;
}

class EvalBlindedPairwiseImportResult {
  const EvalBlindedPairwiseImportResult({
    required this.importedPreferenceFiles,
    required this.privateKeyFile,
    required this.judgeManifestFile,
  });

  final List<File> importedPreferenceFiles;
  final File privateKeyFile;
  final File judgeManifestFile;

  int get importedCount => importedPreferenceFiles.length;
}

abstract final class EvalBlindedPairwisePreference {
  static const schemaVersion = 1;
  static const pairKind = 'lotti.blindedPairwisePreferenceExport.pair';
  static const voteKind = 'lotti.blindedPairwisePreferenceExport.vote';
  static const judgeManifestKind =
      'lotti.blindedPairwisePreferenceExport.judge';
  static const privateKeyKind =
      'lotti.blindedPairwisePreferenceExport.privateKey';

  static Future<EvalBlindedPairwiseExportResult> writePairs({
    required EvalRunArtifacts run,
    required TraceWriter writer,
    required Directory outputDir,
    required List<EvalPairwiseReviewPair> pairs,
    bool overwrite = false,
    String? exportSeed,
    String? readinessPlanId,
    EvalPairwiseReadinessIntent? readinessIntent,
    EvalPairwiseReadinessReviewProtocol? readinessReviewProtocol,
    int? readinessMinBlindedPairwisePreferenceDecisions,
    int readinessMinVotes = 1,
    double readinessQuorumFraction = 1,
  }) async {
    if (pairs.isEmpty) {
      throw StateError('Cannot write a blinded pairwise export with no pairs');
    }
    _validateReadinessPlanSettings(
      pairCount: pairs.length,
      planId: readinessPlanId,
      intent: readinessIntent,
      reviewProtocol: readinessReviewProtocol,
      minBlindedPairwisePreferenceDecisions:
          readinessMinBlindedPairwisePreferenceDecisions,
      minVotes: readinessMinVotes,
      quorumFraction: readinessQuorumFraction,
    );
    final manifestDigest = run.manifest.manifestDigest;
    if (manifestDigest == null) {
      throw StateError(
        'Cannot write a blinded pairwise export without a run manifestDigest',
      );
    }
    final registrationFile = writer.pairwiseReadinessPlanRegistrationFileFor(
      run.manifest.runId,
    );
    if (registrationFile.existsSync() && !overwrite) {
      throw StateError(
        'Pairwise readiness plan registration already exists: '
        '${registrationFile.path}',
      );
    }
    if (outputDir.existsSync()) {
      final hasFiles = !(await outputDir.list().isEmpty);
      if (hasFiles) {
        if (!overwrite) {
          throw StateError(
            'Refusing to overwrite blinded pairwise export directory: '
            '${outputDir.path}',
          );
        }
        await _clearPreviousExport(outputDir);
      }
    }

    final judgeDir = Directory('${outputDir.path}/judge');
    final pairsDir = Directory('${judgeDir.path}/pairs');
    final privateDir = Directory('${outputDir.path}/private');
    await pairsDir.create(recursive: true);
    await privateDir.create(recursive: true);

    final seed =
        exportSeed ??
        '${DateTime.now().toUtc().microsecondsSinceEpoch}:'
            '${run.manifest.manifestDigest ?? run.manifest.runId}';
    final profileAliases = _aliases(
      run.traces.map((trace) => trace.profile.name),
      prefix: 'profile',
      seed: seed,
    );
    final variantAliases = _aliases(
      run.traces.map((trace) => trace.agentDirectiveVariant.name),
      prefix: 'prompt-variant',
      seed: seed,
    );
    final refsByKey = await _traceRefsByKey(run, writer);
    final tracesByKey = _tracesByRefKey(run.traces);

    final manifestEntries = <Map<String, dynamic>>[];
    final keyEntries = <Map<String, dynamic>>[];
    final readinessComparisons = <EvalPairwiseReadinessComparison>[];
    final pairFiles = <File>[];
    final pairIds = <String>{};
    var index = 0;
    for (final pair in pairs) {
      if (!pairIds.add(pair.pairId)) {
        throw StateError('Duplicate pairwise review pair id: ${pair.pairId}');
      }
      _validatePair(
        pair: pair,
        runId: run.manifest.runId,
        refsByKey: refsByKey,
      );
      index += 1;
      final blindedPairId = 'pair-${index.toString().padLeft(4, '0')}';
      final orderedOptions = _reviewOptionOrder(pair, seed);
      final optionA = orderedOptions.$1;
      final optionB = orderedOptions.$2;
      final traceA = tracesByKey[optionA.traceKey]!;
      final traceB = tracesByKey[optionB.traceKey]!;
      final reviewPayload = _reviewPayloadJson(
        pair: pair,
        comparisonAxis: _comparisonAxis(optionA, optionB),
        optionA: traceA,
        optionB: traceB,
        profileAliases: profileAliases,
        variantAliases: variantAliases,
      );
      final reviewPayloadDigest = EvalProvenance.digestJson(reviewPayload);
      final intentComparison = _intentComparisonForPair(
        pair: pair,
        optionA: optionA,
        optionB: optionB,
        intent: readinessIntent,
      );
      readinessComparisons.add(
        EvalPairwiseReadinessComparison(
          comparisonKey: _comparisonKey(optionA, optionB),
          intentKey:
              intentComparison?.intentKey ?? _comparisonKey(optionA, optionB),
          reviewPayloadDigest: reviewPayloadDigest,
          outcomeExpectation: intentComparison?.outcomeExpectation,
        ),
      );
      final blindedPairJson = <String, dynamic>{
        'schemaVersion': schemaVersion,
        'kind': pairKind,
        'blindedPairId': blindedPairId,
        'reviewPayloadDigest': reviewPayloadDigest,
        'reviewPayload': reviewPayload,
        'preferenceContract': <String, dynamic>{
          'reviewPayloadDigest': reviewPayloadDigest,
          'profileVisible': false,
          'modelIdentityVisible': false,
          'peerVotesVisible': false,
          'traceOrderRandomized': true,
        },
      };
      _assertNoModelIdentityLeak(traceA, blindedPairJson, blindedPairId);
      _assertNoModelIdentityLeak(traceB, blindedPairJson, blindedPairId);

      final relativePairPath = 'pairs/$blindedPairId.blinded-pair.json';
      final pairFile = File('${judgeDir.path}/$relativePairPath');
      await pairFile.writeAsString(_encoder.convert(blindedPairJson));
      pairFiles.add(pairFile);
      manifestEntries.add(
        _judgeManifestEntry(
          pair: pair,
          blindedPairId: blindedPairId,
          relativePairPath: relativePairPath,
          reviewPayloadDigest: reviewPayloadDigest,
          optionA: optionA,
          optionB: optionB,
        ),
      );
      keyEntries.add(
        _privateKeyEntry(
          pair: pair,
          blindedPairId: blindedPairId,
          relativePairPath: relativePairPath,
          reviewPayloadDigest: reviewPayloadDigest,
          optionA: optionA,
          optionB: optionB,
        ),
      );
    }

    final judgeManifest = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': judgeManifestKind,
      'exportSeedDigest': EvalProvenance.digestText(seed),
      'traceSchemaVersion': run.manifest.traceSchemaVersion,
      'profileVisible': false,
      'modelIdentityVisible': false,
      'peerVotesVisible': false,
      'traceOrderRandomized': true,
      'pairCount': manifestEntries.length,
      'pairs': manifestEntries,
    };
    for (final trace in run.traces) {
      _assertNoModelIdentityLeak(trace, judgeManifest, 'judge manifest');
    }
    final judgeManifestFile = File('${judgeDir.path}/manifest.json');
    await judgeManifestFile.writeAsString(_encoder.convert(judgeManifest));

    final privateKey = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': privateKeyKind,
      'sourceRunId': run.manifest.runId,
      'sourceManifestDigest': run.manifest.manifestDigest,
      'sourceRunDigest': EvalProvenance.digestText(run.manifest.runId),
      'exportSeed': seed,
      'judgeManifestDigest': EvalProvenance.digestJson(judgeManifest),
      'pairCount': keyEntries.length,
      'entries': keyEntries,
    };
    final privateKeyDigest = EvalProvenance.digestJson(privateKey);
    final privateKeyFile = File('${privateDir.path}/key.json');
    await privateKeyFile.writeAsString(_encoder.convert(privateKey));
    final readinessPlan = _readinessPlan(
      run: run,
      manifestDigest: manifestDigest,
      planId: readinessPlanId,
      intent: readinessIntent,
      reviewProtocol: readinessReviewProtocol,
      minBlindedPairwisePreferenceDecisions:
          readinessMinBlindedPairwisePreferenceDecisions,
      minVotes: readinessMinVotes,
      quorumFraction: readinessQuorumFraction,
      comparisons: readinessComparisons,
      judgeManifestDigest: EvalProvenance.digestJson(judgeManifest),
      privateKeyDigest: privateKeyDigest,
    );
    final readinessPlanFile = File(
      '${privateDir.path}/pairwise_readiness_plan.json',
    );
    await readinessPlanFile.writeAsString(
      _encoder.convert(readinessPlan.toJson()),
    );
    final readinessRegistrationFile = await writer
        .writePairwiseReadinessPlanRegistration(
          EvalPairwiseReadinessPlanRegistration(
            runId: run.manifest.runId,
            sourceManifestDigest: manifestDigest,
            evidence: readinessPlan.toManifestEvidence(),
          ),
          overwrite: overwrite,
        );

    return EvalBlindedPairwiseExportResult(
      judgeDir: judgeDir,
      privateDir: privateDir,
      judgeManifestFile: judgeManifestFile,
      privateKeyFile: privateKeyFile,
      readinessPlanFile: readinessPlanFile,
      readinessPlanRegistrationFile: readinessRegistrationFile,
      blindedPairFiles: List.unmodifiable(pairFiles),
    );
  }

  static Future<EvalBlindedPairwiseImportResult> importVotes({
    required EvalRunArtifacts run,
    required TraceWriter writer,
    required Directory exportDir,
    bool overwrite = false,
  }) async {
    final privateKeyFile = File('${exportDir.path}/private/key.json');
    final judgeManifestFile = File('${exportDir.path}/judge/manifest.json');
    final judgeDir = Directory('${exportDir.path}/judge');
    final privateKey = await _readJsonObject(privateKeyFile);
    final judgeManifest = await _readJsonObject(judgeManifestFile);
    final privateKeyDigest = EvalProvenance.digestJson(privateKey);
    final judgeManifestDigest = EvalProvenance.digestJson(judgeManifest);
    _validateExportRoots(
      run: run,
      privateKey: privateKey,
      judgeManifest: judgeManifest,
      judgeManifestDigest: judgeManifestDigest,
      judgeManifestFile: judgeManifestFile,
    );

    final manifestEntries = _manifestEntriesById(judgeManifest);
    final bindings = _privateKeyBindings(privateKey);
    _validatePairCount(
      label: 'private key',
      expected: _requiredInt(privateKey, 'pairCount'),
      actual: bindings.length,
    );
    _validatePairCount(
      label: 'judge manifest',
      expected: _requiredInt(judgeManifest, 'pairCount'),
      actual: manifestEntries.length,
    );
    final refsByKey = await _traceRefsByKey(run, writer);
    final writes = <EvalPairwisePreferenceVote>[];
    final expectedVotePaths = <String>{};
    for (final binding in bindings) {
      final manifestEntry = manifestEntries[binding.blindedPairId];
      if (manifestEntry == null) {
        throw StateError(
          'Private key references blinded pair ${binding.blindedPairId} '
          'missing from judge manifest.',
        );
      }
      _validateManifestBinding(binding, manifestEntry);
      _validateImportedPairBinding(
        binding: binding,
        run: run,
        refsByKey: refsByKey,
      );
      await _validateBlindedPairFile(binding, judgeDir);
      final blindedVoteFile = File(
        p.join(judgeDir.path, _blindedVotePath(binding.judgeFile)),
      );
      expectedVotePaths.add(p.normalize(blindedVoteFile.path));
      if (!blindedVoteFile.existsSync()) {
        throw StateError(
          'Missing blinded pairwise preference for ${binding.blindedPairId}: '
          '${blindedVoteFile.path}',
        );
      }
      final vote = await _readBlindedVote(
        file: blindedVoteFile,
        binding: binding,
        judgeManifestDigest: judgeManifestDigest,
        privateKeyDigest: privateKeyDigest,
        sourceManifestDigest: _requiredString(
          privateKey,
          'sourceManifestDigest',
        ),
      );
      writes.add(vote);
    }
    await _rejectUnexpectedVotes(
      judgeDir: judgeDir,
      expectedPaths: expectedVotePaths,
    );
    final imported = <File>[];
    for (final vote in writes) {
      imported.add(
        await writer.writePairwisePreferenceVote(vote, overwrite: overwrite),
      );
    }
    return EvalBlindedPairwiseImportResult(
      importedPreferenceFiles: List.unmodifiable(imported),
      privateKeyFile: privateKeyFile,
      judgeManifestFile: judgeManifestFile,
    );
  }

  static Map<String, dynamic> _reviewPayloadJson({
    required EvalPairwiseReviewPair pair,
    required EvalPairwiseComparisonAxis comparisonAxis,
    required EvalTrace optionA,
    required EvalTrace optionB,
    required Map<String, String> profileAliases,
    required Map<String, String> variantAliases,
  }) {
    return <String, dynamic>{
      'pairId': pair.pairId,
      'comparisonAxis': comparisonAxis.name,
      'profileVisible': false,
      'modelIdentityVisible': false,
      'peerVotesVisible': false,
      'traceOrderRandomized': true,
      'scenario': optionA.scenario.toJson(),
      'optionA': _reviewOptionJson(
        trace: optionA,
        profileAlias: profileAliases[optionA.profile.name]!,
        promptVariantAlias: variantAliases[optionA.agentDirectiveVariant.name]!,
      ),
      'optionB': _reviewOptionJson(
        trace: optionB,
        profileAlias: profileAliases[optionB.profile.name]!,
        promptVariantAlias: variantAliases[optionB.agentDirectiveVariant.name]!,
      ),
    };
  }

  static Map<String, dynamic> _reviewOptionJson({
    required EvalTrace trace,
    required String profileAlias,
    required String promptVariantAlias,
  }) {
    return <String, dynamic>{
      'profileAlias': profileAlias,
      'modelClass': trace.profile.modelClass.name,
      'isLocal': trace.profile.isLocal,
      'tokenBudget': trace.profile.tokenBudget,
      'promptVariantAlias': promptVariantAlias,
      'trialIndex': trace.trialIndex,
      if (trace.cascadeWake != null) 'cascadeWake': trace.cascadeWake!.toJson(),
      'output': _redactedOutput(trace.output),
      'level1Checks': [
        for (final check in trace.level1Checks) check.toJson(),
      ],
    };
  }

  static Map<String, dynamic> _redactedOutput(AgentRunOutput output) {
    return <String, dynamic>{
      'success': output.success,
      'usage': output.usage.toJson(),
      if (output.error != null) 'error': '[redacted: raw trace captured error]',
      'toolCalls': [for (final call in output.toolCalls) call.toJson()],
      'toolResults': [for (final result in output.toolResults) result.toJson()],
      'plannedBlocks': [
        for (final block in output.plannedBlocks) block.toJson(),
      ],
      if (output.report != null) 'report': output.report!.toJson(),
      'observations': output.observations,
      'proposals': [for (final proposal in output.proposals) proposal.toJson()],
      'turnCount': output.turnCount,
      'wallClockMs': output.wallClockMs,
    };
  }

  static Map<String, dynamic> _judgeManifestEntry({
    required EvalPairwiseReviewPair pair,
    required String blindedPairId,
    required String relativePairPath,
    required String reviewPayloadDigest,
    required EvalPairwiseTraceRef optionA,
    required EvalPairwiseTraceRef optionB,
  }) {
    return <String, dynamic>{
      'blindedPairId': blindedPairId,
      'pairId': pair.pairId,
      'file': relativePairPath,
      'reviewPayloadDigest': reviewPayloadDigest,
      'comparisonAxis': _comparisonAxis(optionA, optionB).name,
      'scenarioId': optionA.scenarioId,
      'agentKind': optionA.agentKind.name,
      'primaryCapability': optionA.capabilityId,
      'optionAModelClass': optionA.modelClass.name,
      'optionBModelClass': optionB.modelClass.name,
      'trialIndex': optionA.trialIndex,
      if (optionA.cascadeWake != null)
        'cascadeWake': optionA.cascadeWake!.toJson(),
    };
  }

  static Map<String, dynamic> _privateKeyEntry({
    required EvalPairwiseReviewPair pair,
    required String blindedPairId,
    required String relativePairPath,
    required String reviewPayloadDigest,
    required EvalPairwiseTraceRef optionA,
    required EvalPairwiseTraceRef optionB,
  }) {
    return <String, dynamic>{
      'blindedPairId': blindedPairId,
      'pairId': pair.pairId,
      'judgeFile': relativePairPath,
      'reviewPayloadDigest': reviewPayloadDigest,
      'optionA': optionA.toJson(),
      'optionB': optionB.toJson(),
    };
  }

  static Future<EvalPairwisePreferenceVote> _readBlindedVote({
    required File file,
    required _BlindedPairBinding binding,
    required String judgeManifestDigest,
    required String privateKeyDigest,
    required String sourceManifestDigest,
  }) async {
    final json = await _readJsonObject(file);
    _requireKind(json, voteKind, file.path);
    if (_requiredString(json, 'blindedPairId') != binding.blindedPairId) {
      throw StateError(
        'Blinded pairwise preference ${file.path} is for '
        '${json['blindedPairId']}, expected ${binding.blindedPairId}.',
      );
    }
    final reviewPayloadDigest = _requiredString(json, 'reviewPayloadDigest');
    if (reviewPayloadDigest != binding.reviewPayloadDigest) {
      throw StateError(
        'Blinded pairwise preference ${file.path} reviewPayloadDigest '
        '"$reviewPayloadDigest" does not match private key '
        '"${binding.reviewPayloadDigest}".',
      );
    }
    final preference = _requiredObject(json, 'preference');
    final vote =
        EvalPairwisePreferenceVote(
          voteId: _requiredString(preference, 'voteId'),
          optionA: binding.optionA,
          optionB: binding.optionB,
          reviewerId: _requiredString(preference, 'reviewerId'),
          reviewerKind: EvalPairwiseReviewerKind.fromName(
            _requiredString(preference, 'reviewerKind'),
          ),
          reviewerModel: preference['reviewerModel'] as String?,
          promptDigest: _requiredString(preference, 'promptDigest'),
          calibrationSetVersion: _requiredString(
            preference,
            'calibrationSetVersion',
          ),
          profileVisible: false,
          modelIdentityVisible: false,
          peerVotesVisible: false,
          traceOrderRandomized: true,
          choice: EvalPairwisePreferenceChoice.fromName(
            _requiredString(preference, 'choice'),
          ),
          rationale: _requiredString(preference, 'rationale'),
          issues:
              ((preference['issues'] as List<dynamic>?) ?? const <dynamic>[])
                  .map((e) => e as String)
                  .toList(),
        ).withBlindedImport(
          BlindedPairwisePreferenceImportRecord(
            blindedPairId: binding.blindedPairId,
            reviewPayloadDigest: binding.reviewPayloadDigest,
            judgeManifestDigest: judgeManifestDigest,
            privateKeyDigest: privateKeyDigest,
            sourceManifestDigest: sourceManifestDigest,
            optionARawTraceDigest: binding.optionA.traceDigest,
            optionBRawTraceDigest: binding.optionB.traceDigest,
          ),
        );
    final failures = vote.validate(
      const EvalPairwisePreferencePolicy(
        minVotes: 1,
        requireProfileBlind: true,
        requireTraceOrderRandomized: true,
        requireBlindedImport: true,
      ),
    );
    if (failures.isNotEmpty) {
      throw StateError(
        'Invalid blinded pairwise preference ${file.path}: '
        '${failures.join(', ')}',
      );
    }
    return vote;
  }

  static Future<void> _validateBlindedPairFile(
    _BlindedPairBinding binding,
    Directory judgeDir,
  ) async {
    final pairFile = File(p.join(judgeDir.path, binding.judgeFile));
    if (!pairFile.existsSync()) {
      throw StateError(
        'Missing blinded pair for ${binding.blindedPairId}: ${pairFile.path}',
      );
    }
    final json = await _readJsonObject(pairFile);
    _requireKind(json, pairKind, pairFile.path);
    if (_requiredString(json, 'blindedPairId') != binding.blindedPairId) {
      throw StateError(
        'Blinded pair id in ${pairFile.path} does not match private key '
        '${binding.blindedPairId}.',
      );
    }
    final reviewPayload = _requiredObject(json, 'reviewPayload');
    final actualReviewDigest = EvalProvenance.digestJson(reviewPayload);
    final declaredReviewDigest = _requiredString(json, 'reviewPayloadDigest');
    if (declaredReviewDigest != actualReviewDigest) {
      throw StateError(
        'Blinded pair ${binding.blindedPairId} reviewPayloadDigest '
        '$declaredReviewDigest does not match $actualReviewDigest.',
      );
    }
    if (binding.reviewPayloadDigest != actualReviewDigest) {
      throw StateError(
        'Private key reviewPayloadDigest for ${binding.blindedPairId} is '
        '${binding.reviewPayloadDigest}, expected $actualReviewDigest.',
      );
    }
    final contract = _requiredObject(json, 'preferenceContract');
    if (contract['reviewPayloadDigest'] != binding.reviewPayloadDigest ||
        contract['profileVisible'] != false ||
        contract['modelIdentityVisible'] != false ||
        contract['peerVotesVisible'] != false ||
        contract['traceOrderRandomized'] != true) {
      throw StateError(
        'Blinded pair ${binding.blindedPairId} preferenceContract does not '
        'match the private key and blinded-review policy.',
      );
    }
  }

  static void _validateExportRoots({
    required EvalRunArtifacts run,
    required Map<String, dynamic> privateKey,
    required Map<String, dynamic> judgeManifest,
    required String judgeManifestDigest,
    required File judgeManifestFile,
  }) {
    _requireKind(privateKey, privateKeyKind, 'private key');
    _requireKind(judgeManifest, judgeManifestKind, 'judge manifest');
    final runId = _requiredString(privateKey, 'sourceRunId');
    if (runId != run.manifest.runId) {
      throw StateError(
        'Blinded pairwise private key sourceRunId "$runId" does not match '
        'run "${run.manifest.runId}".',
      );
    }
    final sourceRunDigest = _requiredString(privateKey, 'sourceRunDigest');
    final expectedRunDigest = EvalProvenance.digestText(run.manifest.runId);
    if (sourceRunDigest != expectedRunDigest) {
      throw StateError(
        'Blinded pairwise private key sourceRunDigest "$sourceRunDigest" '
        'does not match "$expectedRunDigest".',
      );
    }
    final sourceManifestDigest = _requiredString(
      privateKey,
      'sourceManifestDigest',
    );
    if (sourceManifestDigest != run.manifest.manifestDigest) {
      throw StateError(
        'Blinded pairwise private key sourceManifestDigest '
        '"$sourceManifestDigest" does not match run manifest '
        '"${run.manifest.manifestDigest}".',
      );
    }
    final expectedJudgeManifestDigest = _requiredString(
      privateKey,
      'judgeManifestDigest',
    );
    if (expectedJudgeManifestDigest != judgeManifestDigest) {
      throw StateError(
        'Blinded pairwise private key judgeManifestDigest '
        '"$expectedJudgeManifestDigest" does not match '
        '${judgeManifestFile.path} "$judgeManifestDigest".',
      );
    }
    if (judgeManifest['modelIdentityVisible'] != false ||
        judgeManifest['profileVisible'] != false ||
        judgeManifest['peerVotesVisible'] != false ||
        judgeManifest['traceOrderRandomized'] != true) {
      throw StateError('Judge manifest is not a blinded pairwise packet.');
    }
  }

  static void _validateManifestBinding(
    _BlindedPairBinding binding,
    Map<String, dynamic> manifestEntry,
  ) {
    if (_requiredString(manifestEntry, 'file') != binding.judgeFile) {
      throw StateError(
        'Judge manifest file for ${binding.blindedPairId} does not match '
        'private key.',
      );
    }
    if (_requiredString(manifestEntry, 'reviewPayloadDigest') !=
        binding.reviewPayloadDigest) {
      throw StateError(
        'Judge manifest reviewPayloadDigest for ${binding.blindedPairId} '
        'does not match private key.',
      );
    }
  }

  static void _validatePair({
    required EvalPairwiseReviewPair pair,
    required String runId,
    required Map<String, EvalPairwiseTraceRef> refsByKey,
  }) {
    if (pair.optionA.runId != runId || pair.optionB.runId != runId) {
      throw StateError(
        'Pairwise review pair ${pair.pairId} is bound to '
        '${pair.optionA.runId}/${pair.optionB.runId}, expected $runId.',
      );
    }
    _validateTraceRefBinding(
      pairId: pair.pairId,
      label: 'optionA',
      actual: pair.optionA,
      expected: refsByKey[pair.optionA.traceKey],
    );
    _validateTraceRefBinding(
      pairId: pair.pairId,
      label: 'optionB',
      actual: pair.optionB,
      expected: refsByKey[pair.optionB.traceKey],
    );
    final draft = EvalPairwisePreferenceVote(
      voteId: pair.pairId,
      optionA: pair.optionA,
      optionB: pair.optionB,
      reviewerId: 'export-validation',
      reviewerKind: EvalPairwiseReviewerKind.human,
      promptDigest: EvalProvenance.digestText('pairwise-export-validation'),
      calibrationSetVersion: 'pairwise-export-validation',
      profileVisible: false,
      modelIdentityVisible: false,
      peerVotesVisible: false,
      traceOrderRandomized: true,
      choice: EvalPairwisePreferenceChoice.tie,
      rationale: 'Export validation.',
    );
    final failures = draft.validate(
      const EvalPairwisePreferencePolicy(
        minVotes: 1,
        requireProfileBlind: true,
        requireTraceOrderRandomized: true,
      ),
    );
    if (failures.isNotEmpty) {
      throw StateError(
        'Invalid pairwise review pair ${pair.pairId}: '
        '${failures.join(', ')}',
      );
    }
  }

  static void _validateImportedPairBinding({
    required _BlindedPairBinding binding,
    required EvalRunArtifacts run,
    required Map<String, EvalPairwiseTraceRef> refsByKey,
  }) {
    if (binding.optionA.runId != run.manifest.runId ||
        binding.optionB.runId != run.manifest.runId) {
      throw StateError(
        'Private key pair ${binding.blindedPairId} is bound to '
        '${binding.optionA.runId}/${binding.optionB.runId}, expected '
        '${run.manifest.runId}.',
      );
    }
    _validateTraceRefBinding(
      pairId: binding.blindedPairId,
      label: 'optionA',
      actual: binding.optionA,
      expected: refsByKey[binding.optionA.traceKey],
    );
    _validateTraceRefBinding(
      pairId: binding.blindedPairId,
      label: 'optionB',
      actual: binding.optionB,
      expected: refsByKey[binding.optionB.traceKey],
    );
  }

  static void _validateTraceRefBinding({
    required String pairId,
    required String label,
    required EvalPairwiseTraceRef actual,
    required EvalPairwiseTraceRef? expected,
  }) {
    if (expected == null) {
      throw StateError(
        'Pairwise blinded pair $pairId references missing $label trace '
        '${actual.traceKey}.',
      );
    }
    if (jsonEncode(actual.toJson()) == jsonEncode(expected.toJson())) return;
    throw StateError(
      'Stale pairwise blinded pair $pairId for $label trace '
      '${actual.traceKey}: expected ${_encoder.convert(expected.toJson())}, '
      'got ${_encoder.convert(actual.toJson())}.',
    );
  }

  static Future<Map<String, EvalPairwiseTraceRef>> _traceRefsByKey(
    EvalRunArtifacts run,
    TraceWriter writer,
  ) async {
    final refsByKey = <String, EvalPairwiseTraceRef>{};
    for (final trace in run.traces) {
      final traceFile = writer.traceFileFor(
        runId: trace.runId,
        scenarioId: trace.scenario.id,
        profileName: trace.profile.name,
        agentDirectiveVariantName: trace.agentDirectiveVariant.name,
        trialIndex: trace.trialIndex,
        cascadeWake: trace.cascadeWake,
      );
      if (!traceFile.existsSync()) continue;
      final ref = EvalPairwiseTraceRef.fromTrace(
        trace,
        traceDigest: await writer.traceDigest(traceFile),
      );
      refsByKey[ref.traceKey] = ref;
    }
    return refsByKey;
  }

  static Map<String, EvalTrace> _tracesByRefKey(List<EvalTrace> traces) => {
    for (final trace in traces)
      EvalPairwiseTraceRef.fromTrace(
        trace,
        traceDigest: EvalProvenance.digestText('trace-key-only'),
      ).traceKey: trace,
  };

  static (EvalPairwiseTraceRef, EvalPairwiseTraceRef) _reviewOptionOrder(
    EvalPairwiseReviewPair pair,
    String seed,
  ) {
    final orderDigest = EvalProvenance.digestText('$seed:${pair.pairId}:order');
    if (orderDigest.codeUnitAt(orderDigest.length - 1).isEven) {
      return (pair.optionA, pair.optionB);
    }
    return (pair.optionB, pair.optionA);
  }

  static EvalPairwiseComparisonAxis _comparisonAxis(
    EvalPairwiseTraceRef optionA,
    EvalPairwiseTraceRef optionB,
  ) => EvalPairwisePreferenceVote(
    voteId: 'axis',
    optionA: optionA,
    optionB: optionB,
    reviewerId: 'axis',
    reviewerKind: EvalPairwiseReviewerKind.human,
    promptDigest: EvalProvenance.digestText('axis'),
    calibrationSetVersion: 'axis',
    profileVisible: false,
    modelIdentityVisible: false,
    peerVotesVisible: false,
    traceOrderRandomized: true,
    choice: EvalPairwisePreferenceChoice.tie,
    rationale: 'axis',
  ).comparisonAxis;

  static EvalPairwiseReadinessIntentComparison? _intentComparisonForPair({
    required EvalPairwiseReviewPair pair,
    required EvalPairwiseTraceRef optionA,
    required EvalPairwiseTraceRef optionB,
    required EvalPairwiseReadinessIntent? intent,
  }) {
    if (intent == null) return null;
    final matches = intent.comparisons
        .where((comparison) => comparison.pairId == pair.pairId)
        .toList();
    if (matches.length != 1) {
      throw StateError(
        'Pairwise readiness intent must contain exactly one comparison for '
        'pairId ${pair.pairId}; found ${matches.length}.',
      );
    }
    final comparison = matches.single;
    final failures = _intentRefFailures(
      comparison: comparison,
      optionA: optionA,
      optionB: optionB,
    );
    if (failures.isNotEmpty) {
      throw StateError(
        'Pairwise readiness intent comparison ${comparison.intentKey} does '
        'not match exported pair ${pair.pairId}: ${failures.join('; ')}',
      );
    }
    return comparison;
  }

  static List<String> _intentRefFailures({
    required EvalPairwiseReadinessIntentComparison comparison,
    required EvalPairwiseTraceRef optionA,
    required EvalPairwiseTraceRef optionB,
  }) => comparison.validateTraceRefs(optionA: optionA, optionB: optionB);

  static String _comparisonKey(
    EvalPairwiseTraceRef optionA,
    EvalPairwiseTraceRef optionB,
  ) => EvalPairwisePreferenceVote(
    voteId: 'comparison-key',
    optionA: optionA,
    optionB: optionB,
    reviewerId: 'comparison-key',
    reviewerKind: EvalPairwiseReviewerKind.human,
    promptDigest: EvalProvenance.digestText('comparison-key'),
    calibrationSetVersion: 'comparison-key',
    profileVisible: false,
    modelIdentityVisible: false,
    peerVotesVisible: false,
    traceOrderRandomized: true,
    choice: EvalPairwisePreferenceChoice.tie,
    rationale: 'comparison key',
  ).comparisonKey;

  static EvalPairwiseReadinessPlan _readinessPlan({
    required EvalRunArtifacts run,
    required String manifestDigest,
    required String? planId,
    required EvalPairwiseReadinessIntent? intent,
    required EvalPairwiseReadinessReviewProtocol? reviewProtocol,
    required int? minBlindedPairwisePreferenceDecisions,
    required int minVotes,
    required double quorumFraction,
    required List<EvalPairwiseReadinessComparison> comparisons,
    required String judgeManifestDigest,
    required String privateKeyDigest,
  }) {
    final resolvedPlanId = planId?.trim();
    final resolvedIntent = intent;
    final plan = EvalPairwiseReadinessPlan(
      planId:
          resolvedIntent?.planId ??
          (resolvedPlanId == null || resolvedPlanId.isEmpty
              ? 'pairwise-readiness-${run.manifest.runId}'
              : resolvedPlanId),
      baseReadinessPolicy: 'modelClassTuning',
      scenarioSetDigest: run.manifest.scenarioSetDigest,
      profileSetDigest: run.manifest.profileSetDigest,
      profileBindingSetDigest: run.manifest.profileBindingSetDigest,
      manifestDigest: manifestDigest,
      minBlindedPairwisePreferenceDecisions:
          resolvedIntent?.minBlindedPairwisePreferenceDecisions ??
          minBlindedPairwisePreferenceDecisions ??
          comparisons.length,
      comparisons: List.unmodifiable(comparisons),
      intent: resolvedIntent,
      reviewProtocol:
          resolvedIntent?.reviewProtocol ??
          reviewProtocol ??
          defaultReadinessReviewProtocol(),
      importBinding: EvalPairwiseReadinessImportBinding(
        judgeManifestDigest: judgeManifestDigest,
        privateKeyDigest: privateKeyDigest,
      ),
      minVotes: resolvedIntent?.minVotes ?? minVotes,
      quorumFraction: resolvedIntent?.quorumFraction ?? quorumFraction,
      notes: 'Generated by blinded pairwise export before preference import.',
    );
    final failures = plan.validate();
    if (failures.isNotEmpty) {
      throw StateError(
        'Invalid generated pairwise readiness plan: ${failures.join('; ')}',
      );
    }
    return plan;
  }

  static void _validateReadinessPlanSettings({
    required int pairCount,
    required String? planId,
    required EvalPairwiseReadinessIntent? intent,
    required EvalPairwiseReadinessReviewProtocol? reviewProtocol,
    required int? minBlindedPairwisePreferenceDecisions,
    required int minVotes,
    required double quorumFraction,
  }) {
    if (planId != null && planId.trim().isEmpty) {
      throw StateError('Pairwise readiness plan id must not be blank.');
    }
    if (intent != null) {
      if (planId != null &&
          planId.trim().isNotEmpty &&
          planId != intent.planId) {
        throw StateError(
          'Pairwise readiness plan id "$planId" does not match intent '
          '"${intent.planId}".',
        );
      }
      if (reviewProtocol != null &&
          reviewProtocol.fingerprint != intent.reviewProtocol.fingerprint) {
        throw StateError(
          'Pairwise readiness review protocol does not match intent.',
        );
      }
      if (minBlindedPairwisePreferenceDecisions != null &&
          minBlindedPairwisePreferenceDecisions !=
              intent.minBlindedPairwisePreferenceDecisions) {
        throw StateError(
          'Pairwise readiness min decisions does not match intent.',
        );
      }
      if (minVotes != intent.minVotes) {
        throw StateError('Pairwise readiness min votes does not match intent.');
      }
      if (quorumFraction != intent.quorumFraction) {
        throw StateError(
          'Pairwise readiness quorum fraction does not match intent.',
        );
      }
      if (pairCount != intent.comparisons.length) {
        throw StateError(
          'Pairwise readiness pair count $pairCount does not match intent '
          'comparison count ${intent.comparisons.length}.',
        );
      }
    }
    if (minBlindedPairwisePreferenceDecisions != null) {
      if (minBlindedPairwisePreferenceDecisions < 1) {
        throw StateError(
          'Pairwise readiness min decisions must be at least 1.',
        );
      }
      if (minBlindedPairwisePreferenceDecisions > pairCount) {
        throw StateError(
          'Pairwise readiness min decisions '
          '$minBlindedPairwisePreferenceDecisions cannot exceed pair count '
          '$pairCount.',
        );
      }
    }
    if (minVotes < 1) {
      throw StateError('Pairwise readiness min votes must be at least 1.');
    }
    if (!quorumFraction.isFinite || quorumFraction <= 0 || quorumFraction > 1) {
      throw StateError(
        'Pairwise readiness quorum fraction must be > 0 and <= 1.',
      );
    }
    if (reviewProtocol == null) return;
    final failures = reviewProtocol.validate();
    if (failures.isNotEmpty) {
      throw StateError(
        'Invalid pairwise readiness review protocol: ${failures.join('; ')}',
      );
    }
  }

  static EvalPairwiseReadinessReviewProtocol defaultReadinessReviewProtocol() =>
      EvalPairwiseReadinessReviewProtocol(
        reviewerKind: EvalPairwiseReviewerKind.human,
        reviewerModel: null,
        promptDigest: EvalProvenance.digestText(
          'lotti-pairwise-preference-review-v1',
        ),
        calibrationSetVersion: 'pairwise-human-gold-v1',
        profileVisible: false,
        modelIdentityVisible: false,
        peerVotesVisible: false,
        traceOrderRandomized: true,
      );

  static Map<String, String> _aliases(
    Iterable<String> values, {
    required String prefix,
    required String seed,
  }) {
    final sorted =
        [
          ...values.toSet(),
        ]..sort(
          (a, b) => EvalProvenance.digestText('$seed:$prefix:$a').compareTo(
            EvalProvenance.digestText('$seed:$prefix:$b'),
          ),
        );
    return {
      for (var i = 0; i < sorted.length; i++)
        sorted[i]: '$prefix-${(i + 1).toString().padLeft(2, '0')}',
    };
  }

  static Future<void> _clearPreviousExport(Directory outputDir) async {
    final entries = await outputDir.list().toList();
    final unexpected =
        entries
            .map((entry) => p.basename(entry.path))
            .where((name) => name != 'judge' && name != 'private')
            .toList()
          ..sort();
    if (unexpected.isNotEmpty) {
      throw StateError(
        'Refusing to overwrite ${outputDir.path}; non-export entries exist: '
        '${unexpected.join(', ')}',
      );
    }
    await _requireExportKind(
      File('${outputDir.path}/judge/manifest.json'),
      judgeManifestKind,
    );
    await _requireExportKind(
      File('${outputDir.path}/private/key.json'),
      privateKeyKind,
    );
    await Directory('${outputDir.path}/judge').delete(recursive: true);
    await Directory('${outputDir.path}/private').delete(recursive: true);
  }

  static Future<void> _requireExportKind(File file, String expectedKind) async {
    if (!file.existsSync()) {
      throw StateError(
        'Refusing to overwrite blinded pairwise export without marker file: '
        '${file.path}',
      );
    }
    final json = await _readJsonObject(file);
    if (json['schemaVersion'] != schemaVersion ||
        json['kind'] != expectedKind) {
      throw StateError(
        'Refusing to overwrite ${file.parent.parent.path}; '
        '${file.path} is not a $expectedKind artifact.',
      );
    }
  }

  static List<_BlindedPairBinding> _privateKeyBindings(
    Map<String, dynamic> privateKey,
  ) {
    final entries = _requiredObjectList(privateKey, 'entries');
    _indexByBlindedPairId(entries, 'private key');
    return [
      for (final entry in entries) _BlindedPairBinding.fromJson(entry),
    ];
  }

  static Map<String, Map<String, dynamic>> _manifestEntriesById(
    Map<String, dynamic> judgeManifest,
  ) {
    final entries = _requiredObjectList(judgeManifest, 'pairs');
    return _indexByBlindedPairId(entries, 'judge manifest');
  }

  static Map<String, Map<String, dynamic>> _indexByBlindedPairId(
    List<Map<String, dynamic>> entries,
    String label,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    final duplicates = <String>{};
    for (final entry in entries) {
      final id = _requiredString(entry, 'blindedPairId');
      if (byId.containsKey(id)) duplicates.add(id);
      byId[id] = entry;
    }
    if (duplicates.isNotEmpty) {
      throw StateError(
        'Duplicate blindedPairId(s) in $label: '
        '${(duplicates.toList()..sort()).join(', ')}',
      );
    }
    return byId;
  }

  static Future<void> _rejectUnexpectedVotes({
    required Directory judgeDir,
    required Set<String> expectedPaths,
  }) async {
    final pairsDir = Directory('${judgeDir.path}/pairs');
    if (!pairsDir.existsSync()) return;
    final unexpected = <String>[];
    await for (final entity in pairsDir.list()) {
      if (entity is! File ||
          !entity.path.endsWith('.blinded-preference.json')) {
        continue;
      }
      final normalized = p.normalize(entity.path);
      if (!expectedPaths.contains(normalized)) {
        unexpected.add(entity.uri.pathSegments.last);
      }
    }
    if (unexpected.isEmpty) return;
    unexpected.sort();
    throw StateError(
      'Unexpected blinded pairwise preference file(s): '
      '${unexpected.join(', ')}',
    );
  }

  static String _blindedVotePath(String judgeFile) {
    _validateRelativePath(judgeFile, 'judgeFile');
    if (!judgeFile.endsWith('.blinded-pair.json')) {
      throw StateError('judgeFile must end with .blinded-pair.json.');
    }
    return judgeFile.replaceFirst(
      RegExp(r'\.blinded-pair\.json$'),
      '.blinded-preference.json',
    );
  }

  static Future<Map<String, dynamic>> _readJsonObject(File file) async {
    if (!file.existsSync()) {
      throw StateError('Missing blinded pairwise artifact: ${file.path}');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Expected JSON object in ${file.path}.');
    }
    return decoded;
  }

  static Map<String, dynamic> _requiredObject(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is Map<String, dynamic>) return value;
    throw StateError('Expected object field "$key".');
  }

  static List<Map<String, dynamic>> _requiredObjectList(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is! List) throw StateError('Expected $key to be a list.');
    return [
      for (final item in value)
        if (item is Map<String, dynamic>)
          item
        else
          throw StateError('Expected $key entries to be objects.'),
    ];
  }

  static void _requireKind(
    Map<String, dynamic> json,
    String expectedKind,
    String label,
  ) {
    if (json['schemaVersion'] != schemaVersion ||
        json['kind'] != expectedKind) {
      throw StateError(
        'Expected $label to be $expectedKind schemaVersion $schemaVersion.',
      );
    }
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw StateError('Expected non-empty string field "$key".');
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw StateError('Expected integer field "$key".');
  }

  static void _validatePairCount({
    required String label,
    required int expected,
    required int actual,
  }) {
    if (expected == actual) return;
    throw StateError('$label pairCount is $expected, expected $actual.');
  }

  static void _validateRelativePath(String value, String field) {
    if (p.isAbsolute(value)) {
      throw StateError('$field must be relative: $value');
    }
    final normalized = p.normalize(value);
    final segments = p.split(normalized);
    if (segments.any((segment) => segment == '..' || segment.isEmpty)) {
      throw StateError('$field must not escape export directory: $value');
    }
    if (normalized != value) {
      throw StateError('$field must be normalized: $value');
    }
  }

  static void _assertNoModelIdentityLeak(
    EvalTrace trace,
    Map<String, dynamic> json,
    String label,
  ) {
    final encoded = jsonEncode(json);
    for (final forbidden in _modelIdentityStrings(trace)) {
      if (encoded.contains(forbidden)) {
        throw StateError(
          'Blinded pairwise export leaked model identity "$forbidden" in '
          '$label',
        );
      }
    }
  }

  static Set<String> _modelIdentityStrings(EvalTrace trace) {
    final output = trace.output;
    return <String>{
      trace.profile.name,
      trace.profile.modelId,
      if (!trace.agentDirectiveVariant.isDefault)
        trace.agentDirectiveVariant.name,
      if (output.resolvedModel != null) ...[
        output.resolvedModel!.profileId,
        output.resolvedModel!.modelConfigId,
        output.resolvedModel!.providerModelId,
        output.resolvedModel!.providerId,
        output.resolvedModel!.providerType,
        if (output.resolvedModel!.providerEndpointOrigin != null)
          output.resolvedModel!.providerEndpointOrigin!,
        if (output.resolvedModel!.providerBaseUrlDigest != null)
          output.resolvedModel!.providerBaseUrlDigest!,
      ],
      if (output.providerDecision != null) ...[
        output.providerDecision!.profileName,
        output.providerDecision!.profileId,
        output.providerDecision!.selectedModelConfigId,
        output.providerDecision!.selectedProviderId,
        output.providerDecision!.selectedProviderType,
        output.providerDecision!.selectedProviderModelId,
        if (output.providerDecision!.selectedProviderEndpointOrigin != null)
          output.providerDecision!.selectedProviderEndpointOrigin!,
        if (output.providerDecision!.selectedProviderBaseUrlDigest != null)
          output.providerDecision!.selectedProviderBaseUrlDigest!,
        ...output.providerDecision!.candidateModelConfigIds,
        ...output.providerDecision!.decoyModelConfigIds,
        ...output.providerDecision!.legacyModelConfigIds,
        ...output.providerDecision!.candidateProviderIds,
      ],
      for (final invocation in output.modelInvocations) ...[
        invocation.providerModelId,
        invocation.providerId,
        invocation.providerType,
        if (invocation.providerEndpointOrigin != null)
          invocation.providerEndpointOrigin!,
        if (invocation.providerBaseUrlDigest != null)
          invocation.providerBaseUrlDigest!,
      ],
      for (final request in output.providerRequests) ...[
        request.providerModelId,
        request.providerId,
        request.providerType,
        if (request.providerEndpointOrigin != null)
          request.providerEndpointOrigin!,
        if (request.providerBaseUrlDigest != null)
          request.providerBaseUrlDigest!,
      ],
      for (final response in output.providerResponses) ...[
        response.providerType,
        ...response.responseModelIds,
        ...response.systemFingerprints,
        ...response.providerNames,
        ...response.serviceTiers,
      ],
    }.where((value) => value.trim().length >= 4).toSet();
  }

  static const _encoder = JsonEncoder.withIndent('  ');
}

class _BlindedPairBinding {
  const _BlindedPairBinding({
    required this.blindedPairId,
    required this.pairId,
    required this.judgeFile,
    required this.reviewPayloadDigest,
    required this.optionA,
    required this.optionB,
  });

  factory _BlindedPairBinding.fromJson(Map<String, dynamic> json) {
    return _BlindedPairBinding(
      blindedPairId: EvalBlindedPairwisePreference._requiredString(
        json,
        'blindedPairId',
      ),
      pairId: EvalBlindedPairwisePreference._requiredString(json, 'pairId'),
      judgeFile: EvalBlindedPairwisePreference._requiredString(
        json,
        'judgeFile',
      ),
      reviewPayloadDigest: EvalBlindedPairwisePreference._requiredString(
        json,
        'reviewPayloadDigest',
      ),
      optionA: EvalPairwiseTraceRef.fromJson(
        EvalBlindedPairwisePreference._requiredObject(json, 'optionA'),
      ),
      optionB: EvalPairwiseTraceRef.fromJson(
        EvalBlindedPairwisePreference._requiredObject(json, 'optionB'),
      ),
    );
  }

  final String blindedPairId;
  final String pairId;
  final String judgeFile;
  final String reviewPayloadDigest;
  final EvalPairwiseTraceRef optionA;
  final EvalPairwiseTraceRef optionB;
}
