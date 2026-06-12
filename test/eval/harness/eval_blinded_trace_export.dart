// First-class blinded judge export for Level 2 eval traces.
//
// Raw traces are the audit record and stay unchanged. This exporter creates a
// separate judge packet that preserves scenario/output evidence while hiding
// exact profile/model/provider identities from reviewers. The private key keeps
// the raw trace digest mapping for audit/import workflows.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'eval_models.dart';
import 'eval_provenance.dart';
import 'trace_writer.dart';

class EvalBlindedTraceExportResult {
  const EvalBlindedTraceExportResult({
    required this.judgeDir,
    required this.privateDir,
    required this.judgeManifestFile,
    required this.privateKeyFile,
    required this.blindedTraceFiles,
  });

  final Directory judgeDir;
  final Directory privateDir;
  final File judgeManifestFile;
  final File privateKeyFile;
  final List<File> blindedTraceFiles;
}

abstract final class EvalBlindedTraceExporter {
  static const schemaVersion = 1;

  static Future<EvalBlindedTraceExportResult> writeRun({
    required EvalRunArtifacts run,
    required TraceWriter writer,
    required Directory outputDir,
    bool overwrite = false,
    String? exportSeed,
  }) async {
    if (run.traces.isEmpty) {
      throw StateError(
        'Cannot write a blinded export for a run with no traces',
      );
    }
    if (outputDir.existsSync()) {
      final hasFiles = !(await outputDir.list().isEmpty);
      if (hasFiles) {
        if (!overwrite) {
          throw StateError(
            'Refusing to overwrite blinded export directory: ${outputDir.path}',
          );
        }
        await _clearPreviousExport(outputDir);
      }
    }

    final judgeDir = Directory('${outputDir.path}/judge');
    final tracesDir = Directory('${judgeDir.path}/traces');
    final privateDir = Directory('${outputDir.path}/private');
    await tracesDir.create(recursive: true);
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
    final orderedTraces = _shuffledTraces(run.traces, seed);

    final manifestEntries = <Map<String, dynamic>>[];
    final keyEntries = <Map<String, dynamic>>[];
    final traceFiles = <File>[];
    var index = 0;
    for (final trace in orderedTraces) {
      index += 1;
      final blindedTraceId = 'blind-${index.toString().padLeft(4, '0')}';
      final profileAlias = profileAliases[trace.profile.name]!;
      final promptVariantAlias =
          variantAliases[trace.agentDirectiveVariant.name]!;
      final rawTraceFile = writer.traceFileFor(
        runId: trace.runId,
        scenarioId: trace.scenario.id,
        profileName: trace.profile.name,
        agentDirectiveVariantName: trace.agentDirectiveVariant.name,
        trialIndex: trace.trialIndex,
        cascadeWake: trace.cascadeWake,
      );
      if (!rawTraceFile.existsSync()) {
        throw StateError('Missing raw trace for blinded export: $rawTraceFile');
      }
      final rawTraceDigest = await writer.traceDigest(rawTraceFile);
      final reviewPayload = _reviewPayloadJson(
        trace: trace,
        profileAlias: profileAlias,
        promptVariantAlias: promptVariantAlias,
      );
      final reviewPayloadDigest = EvalProvenance.digestJson(reviewPayload);
      final blindedTraceJson =
          <String, dynamic>{
              'schemaVersion': schemaVersion,
              'kind': 'lotti.blindedTraceExport.trace',
              'blindedTraceId': blindedTraceId,
              'reviewPayloadDigest': reviewPayloadDigest,
              'reviewPayload': reviewPayload,
            }
            ..['verdictContract'] = <String, dynamic>{
              'reviewPayloadDigest': reviewPayloadDigest,
              'judge.profileVisible': true,
              'judge.modelIdentityVisible': false,
            };
      _assertNoModelIdentityLeak(
        trace: trace,
        json: blindedTraceJson,
        label: blindedTraceId,
      );

      final relativeTracePath = 'traces/$blindedTraceId.blinded-trace.json';
      final traceFile = File('${judgeDir.path}/$relativeTracePath');
      await traceFile.writeAsString(_encoder.convert(blindedTraceJson));
      traceFiles.add(traceFile);

      manifestEntries.add(
        _judgeManifestEntry(
          trace: trace,
          blindedTraceId: blindedTraceId,
          relativeTracePath: relativeTracePath,
          reviewPayloadDigest: reviewPayloadDigest,
          profileAlias: profileAlias,
          promptVariantAlias: promptVariantAlias,
        ),
      );
      keyEntries.add(
        _privateKeyEntry(
          trace: trace,
          writer: writer,
          rawTraceFile: rawTraceFile,
          rawTraceDigest: rawTraceDigest,
          reviewPayloadDigest: reviewPayloadDigest,
          blindedTraceId: blindedTraceId,
          relativeTracePath: relativeTracePath,
          profileAlias: profileAlias,
          promptVariantAlias: promptVariantAlias,
        ),
      );
    }

    final judgeManifest = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': 'lotti.blindedTraceExport.judge',
      'exportSeedDigest': EvalProvenance.digestText(seed),
      'traceSchemaVersion': run.manifest.traceSchemaVersion,
      'promptDigest': run.manifest.promptDigest,
      'toolSchemaDigest': run.manifest.toolSchemaDigest,
      'profileVisible': true,
      'modelIdentityVisible': false,
      'traceOrderRandomized': true,
      'profileAliasRandomized': true,
      'promptVariantAliasRandomized': true,
      'traceCount': manifestEntries.length,
      'traces': manifestEntries,
    };
    for (final trace in run.traces) {
      _assertNoModelIdentityLeak(
        trace: trace,
        json: judgeManifest,
        label: 'judge manifest',
      );
    }
    final judgeManifestFile = File('${judgeDir.path}/manifest.json');
    await judgeManifestFile.writeAsString(_encoder.convert(judgeManifest));

    final privateKey = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': 'lotti.blindedTraceExport.privateKey',
      'sourceRunId': run.manifest.runId,
      'sourceManifestDigest': run.manifest.manifestDigest,
      'sourceRunDigest': EvalProvenance.digestText(run.manifest.runId),
      'exportSeed': seed,
      'judgeManifestDigest': EvalProvenance.digestJson(judgeManifest),
      'traceCount': keyEntries.length,
      'entries': keyEntries,
    };
    final privateKeyFile = File('${privateDir.path}/key.json');
    await privateKeyFile.writeAsString(_encoder.convert(privateKey));

    return EvalBlindedTraceExportResult(
      judgeDir: judgeDir,
      privateDir: privateDir,
      judgeManifestFile: judgeManifestFile,
      privateKeyFile: privateKeyFile,
      blindedTraceFiles: List.unmodifiable(traceFiles),
    );
  }

  static Map<String, dynamic> _reviewPayloadJson({
    required EvalTrace trace,
    required String profileAlias,
    required String promptVariantAlias,
  }) {
    return <String, dynamic>{
      'promptDigest': trace.provenance.promptDigest,
      'toolSchemaDigest': trace.provenance.toolSchemaDigest,
      'profileVisible': true,
      'modelIdentityVisible': false,
      'trialIndex': trace.trialIndex,
      if (trace.cascadeWake != null) 'cascadeWake': trace.cascadeWake!.toJson(),
      'scenario': trace.scenario.toJson(),
      'profileContext': _profileContext(
        trace.profile,
        profileAlias: profileAlias,
      ),
      'promptVariantAlias': promptVariantAlias,
      'output': _redactedOutput(trace.output),
      'level1Checks': [
        for (final check in trace.level1Checks) check.toJson(),
      ],
    };
  }

  static Map<String, dynamic> _profileContext(
    EvalProfile profile, {
    required String profileAlias,
  }) {
    return <String, dynamic>{
      'profileAlias': profileAlias,
      'modelClass': profile.modelClass.name,
      'isLocal': profile.isLocal,
      'tokenBudget': profile.tokenBudget,
      if (profile.maxCompletionTokens != null)
        'maxCompletionTokens': profile.maxCompletionTokens,
      if (profile.usesWeightedTokenCosts)
        'tokenCostWeights': profile.tokenCostWeights,
    };
  }

  static Map<String, dynamic> _redactedOutput(AgentRunOutput output) {
    return <String, dynamic>{
      'success': output.success,
      'usage': output.usage.toJson(),
      if (output.error != null)
        'error': '[redacted: raw trace captured an error]',
      'toolCalls': [for (final call in output.toolCalls) call.toJson()],
      'toolResults': [for (final result in output.toolResults) result.toJson()],
      'plannedBlocks': [
        for (final block in output.plannedBlocks) block.toJson(),
      ],
      'parsedCaptureItems': [
        for (final item in output.parsedCaptureItems) item.toJson(),
      ],
      if (output.plannedCapacityMinutes != null)
        'plannedCapacityMinutes': output.plannedCapacityMinutes,
      if (output.report != null) 'report': output.report!.toJson(),
      'observations': output.observations,
      'proposals': [for (final proposal in output.proposals) proposal.toJson()],
      'mutatedEntryIds': output.mutatedEntryIds.toList()..sort(),
      'turnCount': output.turnCount,
      'wallClockMs': output.wallClockMs,
    };
  }

  static Map<String, dynamic> _judgeManifestEntry({
    required EvalTrace trace,
    required String blindedTraceId,
    required String relativeTracePath,
    required String reviewPayloadDigest,
    required String profileAlias,
    required String promptVariantAlias,
  }) {
    return <String, dynamic>{
      'blindedTraceId': blindedTraceId,
      'file': relativeTracePath,
      'reviewPayloadDigest': reviewPayloadDigest,
      'scenarioId': trace.scenario.id,
      'agentKind': trace.scenario.agentKind.name,
      'primaryCapability': trace.scenario.metadata.primaryCapabilityId,
      'profileAlias': profileAlias,
      'modelClass': trace.profile.modelClass.name,
      'isLocal': trace.profile.isLocal,
      'promptVariantAlias': promptVariantAlias,
      'trialIndex': trace.trialIndex,
      if (trace.cascadeWake != null) 'cascadeWake': trace.cascadeWake!.toJson(),
    };
  }

  static Map<String, dynamic> _privateKeyEntry({
    required EvalTrace trace,
    required TraceWriter writer,
    required File rawTraceFile,
    required String rawTraceDigest,
    required String reviewPayloadDigest,
    required String blindedTraceId,
    required String relativeTracePath,
    required String profileAlias,
    required String promptVariantAlias,
  }) {
    return <String, dynamic>{
      'blindedTraceId': blindedTraceId,
      'judgeFile': relativeTracePath,
      'rawTraceFile': rawTraceFile.uri.pathSegments.last,
      'rawVerdictFile': writer
          .verdictFileForTrace(rawTraceFile)
          .uri
          .pathSegments
          .last,
      'rawTraceDigest': rawTraceDigest,
      'reviewPayloadDigest': reviewPayloadDigest,
      'runId': trace.runId,
      'scenarioId': trace.scenario.id,
      'scenarioDigest': trace.provenance.scenarioDigest,
      'profileName': trace.profile.name,
      'profileModelId': trace.profile.modelId,
      'profileAlias': profileAlias,
      'profileDigest': trace.provenance.profileDigest,
      'modelClass': trace.profile.modelClass.name,
      'agentDirectiveVariantName': trace.agentDirectiveVariant.name,
      'agentDirectiveVariantDigest':
          trace.provenance.agentDirectiveVariantDigest,
      'promptVariantAlias': promptVariantAlias,
      'trialIndex': trace.trialIndex,
      if (trace.cascadeWake != null) 'cascadeWake': trace.cascadeWake!.toJson(),
    };
  }

  static Map<String, String> _aliases(
    Iterable<String> values, {
    required String prefix,
    required String seed,
  }) {
    final sorted = _seededOrder(values.toSet(), '$seed:$prefix');
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
      'lotti.blindedTraceExport.judge',
    );
    await _requireExportKind(
      File('${outputDir.path}/private/key.json'),
      'lotti.blindedTraceExport.privateKey',
    );
    await Directory('${outputDir.path}/judge').delete(recursive: true);
    await Directory('${outputDir.path}/private').delete(recursive: true);
  }

  static Future<void> _requireExportKind(File file, String expectedKind) async {
    if (!file.existsSync()) {
      throw StateError(
        'Refusing to overwrite blinded export without marker file: '
        '${file.path}',
      );
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (json['schemaVersion'] != schemaVersion ||
        json['kind'] != expectedKind) {
      throw StateError(
        'Refusing to overwrite ${file.parent.parent.path}; '
        '${file.path} is not a $expectedKind artifact.',
      );
    }
  }

  static List<EvalTrace> _shuffledTraces(List<EvalTrace> traces, String seed) {
    return [
      ...traces,
    ]..sort((a, b) {
      final aKey = _traceShuffleKey(a);
      final bKey = _traceShuffleKey(b);
      return EvalProvenance.digestText('$seed:trace:$aKey').compareTo(
        EvalProvenance.digestText('$seed:trace:$bKey'),
      );
    });
  }

  static List<String> _seededOrder(Iterable<String> values, String seed) {
    return [
      ...values,
    ]..sort(
      (a, b) => EvalProvenance.digestText('$seed:$a').compareTo(
        EvalProvenance.digestText('$seed:$b'),
      ),
    );
  }

  static String _traceShuffleKey(EvalTrace trace) {
    final variant = trace.agentDirectiveVariant.isDefault
        ? 'default'
        : trace.agentDirectiveVariant.name;
    final cascade = trace.cascadeWake?.keySuffix ?? 'main';
    return [
      trace.scenario.id,
      trace.profile.name,
      variant,
      trace.trialIndex.toString(),
      cascade,
    ].join('::');
  }

  static void _assertNoModelIdentityLeak({
    required EvalTrace trace,
    required Map<String, dynamic> json,
    required String label,
  }) {
    final encoded = jsonEncode(json);
    for (final forbidden in _modelIdentityStrings(trace)) {
      if (encoded.contains(forbidden)) {
        throw StateError(
          'Blinded export leaked model identity "$forbidden" in $label',
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
        if (output.resolvedModel!.templateId != null)
          output.resolvedModel!.templateId!,
        if (output.resolvedModel!.templateVersionId != null)
          output.resolvedModel!.templateVersionId!,
        if (output.resolvedModel!.wakeRunResolvedModelId != null)
          output.resolvedModel!.wakeRunResolvedModelId!,
        if (output.resolvedModel!.usageModelId != null)
          output.resolvedModel!.usageModelId!,
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
