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

class TraceWriter {
  const TraceWriter({
    this.runsRoot = 'eval/runs',
    this.validateVerdictDigests = true,
  });

  final String runsRoot;
  final bool validateVerdictDigests;

  static const _encoder = JsonEncoder.withIndent('  ');

  String runDir(String runId) => '$runsRoot/$runId';

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
    final file = File('${dir.path}/${_stem(trace)}.trace.json');
    final verdictFile = File(_verdictPath(file.path));
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
      (a, b) => '${a.scenario.id}${a.profile.name}'.compareTo(
        '${b.scenario.id}${b.profile.name}',
      ),
    );
    return traces;
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

  String _stem(EvalTrace trace) {
    final base = '${_safe(trace.scenario.id)}__${_safe(trace.profile.name)}';
    if (trace.trialIndex == 0) return base;
    return '${base}__trial-${trace.trialIndex}';
  }

  String _safe(String value) =>
      value.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');

  Map<String, dynamic> _traceJson(EvalTrace trace) {
    final json = trace.toJson()..remove('verdict');
    return json;
  }
}
