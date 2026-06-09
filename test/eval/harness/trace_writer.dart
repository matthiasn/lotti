// Trace persistence for the evaluation harness (ADR 0029).
//
// The Level 2 runner writes one `<scenario>__<profile>.trace.json` per run under
// `eval/runs/<runId>/`. The Claude Code judge (eval/grade_run.md) writes a
// sibling `<scenario>__<profile>.verdict.json`. `readTraces` reattaches verdicts
// so the reporter sees a complete `EvalTrace`.

import 'dart:convert';
import 'dart:io';

import 'eval_models.dart';

class TraceWriter {
  const TraceWriter({this.runsRoot = 'eval/runs'});

  final String runsRoot;

  static const _encoder = JsonEncoder.withIndent('  ');

  String runDir(String runId) => '$runsRoot/$runId';

  /// Writes [trace] and returns the trace file.
  Future<File> writeTrace(EvalTrace trace) async {
    final dir = Directory(runDir(trace.runId));
    await dir.create(recursive: true);
    final file = File('${dir.path}/${_stem(trace)}.trace.json');
    await file.writeAsString(_encoder.convert(trace.toJson()));
    return file;
  }

  /// Writes a judge verdict next to its trace file.
  Future<File> writeVerdict(File traceFile, JudgeVerdict verdict) async {
    final file = File(_verdictPath(traceFile.path));
    await file.writeAsString(_encoder.convert(verdict.toJson()));
    return file;
  }

  /// Reads every trace in [runId], reattaching any sibling verdict.
  Future<List<EvalTrace>> readTraces(String runId) async {
    final dir = Directory(runDir(runId));
    if (!dir.existsSync()) return const <EvalTrace>[];
    final traces = <EvalTrace>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.trace.json')) continue;
      final json =
          jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
      var trace = EvalTrace.fromJson(json);
      final verdict = await _readVerdict(entity.path);
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

  Future<JudgeVerdict?> _readVerdict(String tracePath) async {
    final file = File(_verdictPath(tracePath));
    if (!file.existsSync()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return JudgeVerdict.fromJson(json);
  }

  String _verdictPath(String tracePath) =>
      tracePath.replaceFirst(RegExp(r'\.trace\.json$'), '.verdict.json');

  String _stem(EvalTrace trace) =>
      '${_safe(trace.scenario.id)}__${_safe(trace.profile.name)}';

  String _safe(String value) =>
      value.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
}
