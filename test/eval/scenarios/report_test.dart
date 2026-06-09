// Level 2 report/verify entrypoint.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../harness/eval_harness.dart';
import 'eval_scenarios.dart';

const _runId = String.fromEnvironment('EVAL_RUN');

void main() {
  test(
    'verifies complete trace/verdict matrix for an eval run',
    () async {
      const writer = TraceWriter();
      final traces = await writer.readTraces(_runId);
      final verification = EvalRunVerifier.verify(
        runId: _runId,
        traces: traces,
        scenarios: allEvalScenarios,
        profiles: kDefaultProfiles,
        artifactNames: await _artifactNames(writer.runDir(_runId)),
      );
      expect(
        verification.errors,
        isEmpty,
        reason: verification.errors.join('\n'),
      );
    },
    tags: 'eval-report',
    skip: _runId.isEmpty
        ? 'Set EVAL_RUN=<runId> to verify an eval run.'
        : false,
  );

  test(
    'renders eval run summary',
    () async {
      final traces = await const TraceWriter().readTraces(_runId);
      expect(traces, isNotEmpty, reason: 'EVAL_RUN=$_runId has no traces');
      // ignore: avoid_print
      print(EvalReporter.render(traces));
    },
    tags: 'eval-report',
    skip: _runId.isEmpty
        ? 'Set EVAL_RUN=<runId> to report an eval run.'
        : false,
  );
}

Future<List<String>> _artifactNames(String runDir) async {
  final dir = Directory(runDir);
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
