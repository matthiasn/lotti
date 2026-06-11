// Trace persistence for the evaluation harness (ADR 0029).
//
// The Level 2 runner writes one `<scenario>__<profile>.trace.json` per run under
// `eval/runs/<runId>/`. The Claude Code judge (eval/grade_run.md) writes a
// sibling `<scenario>__<profile>.verdict.json`. `readTraces` reattaches verdicts
// so the reporter sees a complete `EvalTrace`.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';

import 'eval_models.dart';
import 'eval_pairwise_preference.dart';
import 'eval_provenance.dart';

class EvalRunArtifacts {
  const EvalRunArtifacts({
    required this.manifest,
    required this.traces,
    required this.artifactNames,
  });

  final EvalRunManifest manifest;
  final List<EvalTrace> traces;
  final List<String> artifactNames;
}

class TraceWriter {
  const TraceWriter({
    this.runsRoot = 'eval/runs',
    this.validateVerdictDigests = true,
  });

  final String runsRoot;
  final bool validateVerdictDigests;

  static const _encoder = JsonEncoder.withIndent('  ');

  String runDir(String runId) => '$runsRoot/${_safeRunId(runId)}';

  File manifestFileFor(String runId) => File('${runDir(runId)}/manifest.json');

  File traceFileFor({
    required String runId,
    required String scenarioId,
    required String profileName,
    int trialIndex = 0,
    EvalTraceCascadeWake? cascadeWake,
  }) {
    return File(
      '${runDir(runId)}/'
      '${_stemFromParts(
        scenarioId,
        profileName,
        trialIndex,
        cascadeWake,
      )}.trace.json',
    );
  }

  File verdictFileForTrace(File traceFile) =>
      File(_verdictPath(traceFile.path));

  File pairwisePreferenceFileFor({
    required String runId,
    required String voteId,
  }) {
    return File(
      '${runDir(runId)}/${_safePreferenceVoteId(voteId)}.preference.json',
    );
  }

  Future<File> writeManifest(
    EvalRunManifest manifest, {
    bool overwrite = false,
  }) async {
    final dir = Directory(runDir(manifest.runId));
    await dir.create(recursive: true);
    final file = manifestFileFor(manifest.runId);
    if (file.existsSync() && !overwrite) {
      throw StateError('Manifest already exists: ${file.path}');
    }
    await file.writeAsString(_encoder.convert(manifest.toJson()));
    return file;
  }

  /// Writes [trace] and returns the trace file.
  ///
  /// Existing traces are never overwritten unless [overwrite] is explicit. If a
  /// verdict already exists, overwriting the trace is refused unless the caller
  /// also opts into deleting the stale verdict.
  Future<File> writeTrace(
    EvalTrace trace, {
    bool overwrite = false,
    bool deleteVerdictOnOverwrite = false,
    bool deletePairwisePreferencesOnOverwrite = false,
  }) async {
    final dir = Directory(runDir(trace.runId));
    await dir.create(recursive: true);
    final file = traceFileFor(
      runId: trace.runId,
      scenarioId: trace.scenario.id,
      profileName: trace.profile.name,
      trialIndex: trace.trialIndex,
      cascadeWake: trace.cascadeWake,
    );
    final verdictFile = verdictFileForTrace(file);
    if (file.existsSync() && !overwrite) {
      throw StateError('Trace already exists: ${file.path}');
    }
    if (verdictFile.existsSync()) {
      if (!overwrite || !deleteVerdictOnOverwrite) {
        throw StateError(
          'Refusing to overwrite trace with existing verdict: ${file.path}',
        );
      }
      await verdictFile.delete();
    }
    if (file.existsSync()) {
      final preferenceFiles = await _pairwisePreferenceFilesReferencingTrace(
        trace,
      );
      if (preferenceFiles.isNotEmpty) {
        if (!overwrite || !deletePairwisePreferencesOnOverwrite) {
          throw StateError(
            'Refusing to overwrite trace with existing pairwise preference '
            'vote(s): ${file.path}',
          );
        }
        for (final preferenceFile in preferenceFiles) {
          await preferenceFile.delete();
        }
      }
    }
    await file.writeAsString(_encoder.convert(_traceJson(trace)));
    return file;
  }

  /// Writes a judge verdict next to its trace file.
  Future<File> writeVerdict(File traceFile, JudgeVerdict verdict) async {
    if (!traceFile.existsSync()) {
      throw StateError('Cannot write verdict for missing trace: $traceFile');
    }
    final file = File(_verdictPath(traceFile.path));
    final boundVerdict = verdict.withTraceDigest(await traceDigest(traceFile));
    await file.writeAsString(_encoder.convert(boundVerdict.toJson()));
    return file;
  }

  /// Writes one subjective A/B preference vote for an existing run.
  ///
  /// Preference votes are diagnostic artifacts, so policy-level validity
  /// remains the reporter's job. The writer only enforces audit binding: both
  /// options must point at traces in this run, and their trace/scenario/profile
  /// digests must still match the current trace files.
  Future<File> writePairwisePreferenceVote(
    EvalPairwisePreferenceVote vote, {
    bool overwrite = false,
  }) async {
    final runId = _voteRunId(vote);
    final file = pairwisePreferenceFileFor(runId: runId, voteId: vote.voteId);
    if (file.existsSync() && !overwrite) {
      throw StateError('Pairwise preference already exists: ${file.path}');
    }
    final traces = await readTraces(runId);
    final refsByKey = await _pairwiseTraceRefsByKey(traces);
    _validatePreferenceTraceBindings(vote, runId, refsByKey, file.path);
    await file.parent.create(recursive: true);
    await file.writeAsString(_encoder.convert(vote.toJson()));
    return file;
  }

  /// Computes the digest a verdict must cite to prove which trace it graded.
  Future<String> traceDigest(File traceFile) async =>
      'sha256:${sha256.convert(await traceFile.readAsBytes())}';

  /// Reads every trace in [runId], reattaching any sibling verdict.
  Future<List<EvalTrace>> readTraces(String runId) async {
    final dir = Directory(runDir(runId));
    if (!dir.existsSync()) return const <EvalTrace>[];
    final traces = <EvalTrace>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.trace.json')) continue;
      final json =
          jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
      if (json.containsKey('verdict')) {
        throw StateError(
          'Trace file must not embed a verdict: ${entity.path}',
        );
      }
      var trace = EvalTrace.fromJson(json);
      final verdict = await _readVerdict(entity);
      if (verdict != null) trace = trace.withVerdict(verdict);
      traces.add(trace);
    }
    traces.sort(
      (a, b) {
        final scenarioOrder = a.scenario.id.compareTo(b.scenario.id);
        if (scenarioOrder != 0) return scenarioOrder;
        final profileOrder = a.profile.name.compareTo(b.profile.name);
        if (profileOrder != 0) return profileOrder;
        final trialOrder = a.trialIndex.compareTo(b.trialIndex);
        if (trialOrder != 0) return trialOrder;
        return _cascadeSortKey(a).compareTo(_cascadeSortKey(b));
      },
    );
    return traces;
  }

  /// Reads pairwise preference votes and validates their trace digest bindings.
  Future<List<EvalPairwisePreferenceVote>> readPairwisePreferenceVotes(
    String runId, {
    List<EvalTrace>? traces,
  }) async {
    final dir = Directory(runDir(runId));
    if (!dir.existsSync()) return const <EvalPairwisePreferenceVote>[];
    final boundTraces = traces ?? await readTraces(runId);
    final refsByKey = await _pairwiseTraceRefsByKey(boundTraces);
    final votes = <EvalPairwisePreferenceVote>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.preference.json')) {
        continue;
      }
      final json =
          jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
      final vote = EvalPairwisePreferenceVote.fromJson(json);
      _validatePreferenceTraceBindings(
        vote,
        runId,
        refsByKey,
        entity.path,
      );
      votes.add(vote);
    }
    final duplicateVoteIds = _duplicates(
      votes.map((vote) => vote.voteId),
    );
    if (duplicateVoteIds.isNotEmpty) {
      throw StateError(
        'Duplicate pairwise preference vote id(s): '
        '${(duplicateVoteIds.toList()..sort()).join(', ')}',
      );
    }
    votes.sort((a, b) {
      final comparisonOrder = a.comparisonKey.compareTo(b.comparisonKey);
      if (comparisonOrder != 0) return comparisonOrder;
      return a.voteId.compareTo(b.voteId);
    });
    return votes;
  }

  Future<EvalRunManifest?> readManifest(String runId) async {
    final file = manifestFileFor(runId);
    if (!file.existsSync()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return EvalRunManifest.fromJson(json);
  }

  Future<EvalRunArtifacts> readRun(String runId) async {
    final manifest = await readManifest(runId);
    if (manifest == null) {
      throw StateError('Missing run manifest: ${manifestFileFor(runId).path}');
    }
    if (manifest.runId != runId) {
      throw StateError(
        'Manifest runId ${manifest.runId} does not match directory $runId',
      );
    }
    if (manifest.traceSchemaVersion != EvalTrace.schemaVersion) {
      throw StateError(
        'Manifest traceSchemaVersion ${manifest.traceSchemaVersion} '
        'does not match EvalTrace.schemaVersion ${EvalTrace.schemaVersion}',
      );
    }
    final manifestDigest = manifest.manifestDigest;
    if (manifestDigest == null) {
      throw StateError('Manifest missing manifestDigest: $runId');
    }
    final actualManifestDigest = EvalProvenance.manifestDigest(manifest);
    if (actualManifestDigest != manifestDigest) {
      throw StateError(
        'Stale manifest digest for $runId: expected $actualManifestDigest, '
        'got $manifestDigest',
      );
    }
    final traces = await readTraces(runId);
    for (final trace in traces) {
      final traceKey =
          '${trace.scenario.id}::${trace.profile.name}::${trace.trialIndex}';
      if (trace.runId != manifest.runId) {
        throw StateError(
          'Trace $traceKey has runId ${trace.runId}, '
          'expected ${manifest.runId}',
        );
      }
      if (trace.provenance.manifestDigest != manifestDigest) {
        throw StateError(
          'Trace $traceKey cites manifestDigest '
          '${trace.provenance.manifestDigest}, expected $manifestDigest',
        );
      }
    }
    return EvalRunArtifacts(
      manifest: manifest,
      traces: traces,
      artifactNames: await artifactNames(runId),
    );
  }

  Future<List<String>> artifactNames(String runId) async {
    final dir = Directory(runDir(runId));
    if (!dir.existsSync()) return const <String>[];
    final names = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        names.add(entity.uri.pathSegments.last);
      }
    }
    names.sort();
    return names;
  }

  Future<JudgeVerdict?> _readVerdict(File traceFile) async {
    final file = File(_verdictPath(traceFile.path));
    if (!file.existsSync()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final verdict = JudgeVerdict.fromJson(json);
    if (!validateVerdictDigests) return verdict;
    final expected = await traceDigest(traceFile);
    final actual = verdict.traceDigest;
    if (actual == null) {
      throw StateError('Verdict missing traceDigest: ${file.path}');
    }
    if (actual != expected) {
      throw StateError(
        'Stale verdict for ${traceFile.path}: expected $expected, got $actual',
      );
    }
    return verdict;
  }

  String _verdictPath(String tracePath) =>
      tracePath.replaceFirst(RegExp(r'\.trace\.json$'), '.verdict.json');

  String _stemFromParts(
    String scenarioId,
    String profileName,
    int trialIndex,
    EvalTraceCascadeWake? cascadeWake,
  ) {
    final base = '${_safe(scenarioId)}__${_safe(profileName)}';
    final parts = <String>[base];
    if (trialIndex != 0) parts.add('trial-$trialIndex');
    if (cascadeWake != null) {
      parts
        ..add('cascade-${_safe(cascadeWake.cascadeId)}')
        ..add('wake-${cascadeWake.wakeIndex}');
    }
    return parts.join('__');
  }

  String _safe(String value) =>
      value.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');

  String _safeRunId(String runId) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(runId) ||
        runId == '.' ||
        runId == '..') {
      throw ArgumentError.value(
        runId,
        'runId',
        'must contain only A-Z, a-z, 0-9, dot, underscore, or dash, '
            'and must not be path-like',
      );
    }
    return runId;
  }

  String _safePreferenceVoteId(String voteId) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(voteId) ||
        voteId == '.' ||
        voteId == '..') {
      throw ArgumentError.value(
        voteId,
        'voteId',
        'must contain only A-Z, a-z, 0-9, dot, underscore, or dash, '
            'and must not be path-like',
      );
    }
    return voteId;
  }

  String _voteRunId(EvalPairwisePreferenceVote vote) {
    if (vote.optionA.runId != vote.optionB.runId) {
      throw StateError(
        'Pairwise preference ${vote.voteId} compares different runs: '
        '${vote.optionA.runId} vs ${vote.optionB.runId}',
      );
    }
    return _safeRunId(vote.optionA.runId);
  }

  Future<Map<String, EvalPairwiseTraceRef>> _pairwiseTraceRefsByKey(
    List<EvalTrace> traces,
  ) async {
    final refsByKey = <String, EvalPairwiseTraceRef>{};
    for (final trace in traces) {
      final traceFile = traceFileFor(
        runId: trace.runId,
        scenarioId: trace.scenario.id,
        profileName: trace.profile.name,
        trialIndex: trace.trialIndex,
        cascadeWake: trace.cascadeWake,
      );
      if (!traceFile.existsSync()) continue;
      final ref = EvalPairwiseTraceRef.fromTrace(
        trace,
        traceDigest: await traceDigest(traceFile),
      );
      refsByKey[ref.traceKey] = ref;
    }
    return refsByKey;
  }

  Future<List<File>> _pairwisePreferenceFilesReferencingTrace(
    EvalTrace trace,
  ) async {
    final dir = Directory(runDir(trace.runId));
    if (!dir.existsSync()) return const <File>[];
    final traceKey = EvalPairwiseTraceRef.fromTrace(
      trace,
      traceDigest: EvalProvenance.digestText('trace-key-only'),
    ).traceKey;
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.preference.json')) {
        continue;
      }
      final json =
          jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
      final vote = EvalPairwisePreferenceVote.fromJson(json);
      if (vote.optionA.traceKey == traceKey ||
          vote.optionB.traceKey == traceKey) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Set<String> _duplicates(Iterable<String> values) {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final value in values) {
      if (!seen.add(value)) duplicates.add(value);
    }
    return duplicates;
  }

  void _validatePreferenceTraceBindings(
    EvalPairwisePreferenceVote vote,
    String runId,
    Map<String, EvalPairwiseTraceRef> refsByKey,
    String artifactPath,
  ) {
    if (vote.optionA.runId != runId || vote.optionB.runId != runId) {
      throw StateError(
        'Pairwise preference ${vote.voteId} in $artifactPath is bound to '
        '${vote.optionA.runId}/${vote.optionB.runId}, expected $runId',
      );
    }
    _validatePreferenceTraceRef(
      voteId: vote.voteId,
      label: 'optionA',
      actual: vote.optionA,
      expected: refsByKey[vote.optionA.traceKey],
      artifactPath: artifactPath,
    );
    _validatePreferenceTraceRef(
      voteId: vote.voteId,
      label: 'optionB',
      actual: vote.optionB,
      expected: refsByKey[vote.optionB.traceKey],
      artifactPath: artifactPath,
    );
  }

  void _validatePreferenceTraceRef({
    required String voteId,
    required String label,
    required EvalPairwiseTraceRef actual,
    required EvalPairwiseTraceRef? expected,
    required String artifactPath,
  }) {
    if (expected == null) {
      throw StateError(
        'Pairwise preference $voteId in $artifactPath references missing '
        '$label trace ${actual.traceKey}',
      );
    }
    final expectedJson = expected.toJson();
    final actualJson = actual.toJson();
    if (const DeepCollectionEquality().equals(actualJson, expectedJson)) {
      return;
    }
    throw StateError(
      'Stale pairwise preference $voteId in $artifactPath for '
      '$label trace ${actual.traceKey}: expected ${_encoder.convert(expectedJson)}, '
      'got ${_encoder.convert(actualJson)}',
    );
  }

  Map<String, dynamic> _traceJson(EvalTrace trace) {
    final json = trace.toJson()..remove('verdict');
    return json;
  }

  String _cascadeSortKey(EvalTrace trace) {
    final cascadeWake = trace.cascadeWake;
    if (cascadeWake == null) return '';
    return '${cascadeWake.cascadeId}\n'
        '${cascadeWake.wakeIndex.toString().padLeft(12, '0')}';
  }
}
