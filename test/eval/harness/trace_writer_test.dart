import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../harness/eval_harness.dart';
import '../scenarios/eval_scenarios.dart';

void main() {
  test('rejects trace files that embed verdicts', () async {
    final dir = await Directory.systemTemp.createTemp('lotti-trace-writer-');
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    final writer = TraceWriter(runsRoot: dir.path);
    final traceFile = await writer.writeTrace(
      EvalTrace(
        runId: 'run-1',
        scenario: taskReleaseNotesScenario,
        profile: kFrontierFastProfile,
        output: const AgentRunOutput(
          success: true,
          usage: InferenceUsage(inputTokens: 10, outputTokens: 5),
          report: AgentReportRecord(
            oneLiner: 'Done',
            tldr: 'Task was handled.',
            content: 'Handled.',
          ),
        ),
        level1Checks: runLevel1(
          taskReleaseNotesScenario,
          const AgentRunOutput(
            success: true,
            usage: InferenceUsage(inputTokens: 10, outputTokens: 5),
            report: AgentReportRecord(
              oneLiner: 'Done',
              tldr: 'Task was handled.',
              content: 'Handled.',
            ),
          ),
          profile: kFrontierFastProfile,
        ),
      ),
    );

    final json =
        jsonDecode(await traceFile.readAsString()) as Map<String, dynamic>;
    json['verdict'] = const JudgeVerdict(
      traceDigest: 'sha256:embedded',
      goalAttainment: 5,
      quality: 5,
      efficiency: 5,
      pass: true,
    ).toJson();
    await traceFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );

    await expectLater(
      writer.readTraces('run-1'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('must not embed a verdict'),
        ),
      ),
    );
  });
}
