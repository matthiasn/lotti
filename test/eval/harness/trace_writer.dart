// Trace persistence for the evaluation harness (ADR 0029).
//
// The Level 2 runner writes one `<scenario>__<profile>.trace.json` per run under
// `eval/runs/<runId>/`. The Claude Code judge (eval/grade_run.md) writes a
// sibling `<scenario>__<profile>.verdict.json`. `readTraces` reattaches verdicts
// so the reporter sees a complete `EvalTrace`.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'eval_models.dart';
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
  }) {
    return File(
      '${runDir(runId)}/'
      '${_stemFromParts(scenarioId, profileName, trialIndex)}.trace.json',
    );
  }

  File verdictFileForTrace(File traceFile) =>
      File(_verdictPath(traceFile.path));

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
  }) async {
    final dir = Directory(runDir(trace.runId));
    await dir.create(recursive: true);
    final file = traceFileFor(
      runId: trace.runId,
      scenarioId: trace.scenario.id,
      profileName: trace.profile.name,
      trialIndex: trace.trialIndex,
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
        return a.trialIndex.compareTo(b.trialIndex);
      },
    );
    return traces;
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
  ) {
    final base = '${_safe(scenarioId)}__${_safe(profileName)}';
    if (trialIndex == 0) return base;
    return '${base}__trial-$trialIndex';
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

  Map<String, dynamic> _traceJson(EvalTrace trace) {
    final json = trace.toJson()..remove('verdict');
    return json;
  }
}
