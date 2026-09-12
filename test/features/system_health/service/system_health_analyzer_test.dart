import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/system_health/domain/system_health_report.dart';
import 'package:lotti/features/system_health/service/log_file_reader.dart';
import 'package:lotti/features/system_health/service/system_health_analyzer.dart';
import 'package:lotti/services/logging_domains.dart';

import '../../agents/test_data/ai_config_factories.dart';
import '../system_health_test_fixtures.dart';

void main() {
  late Directory logs;
  late List<({String systemMessage, String prompt, AiConfigModel model})> calls;
  final now = DateTime(2026, 9, 12, 14);

  setUp(() async {
    logs = await Directory.systemTemp.createTemp('system_health_analyzer');
    calls = [];
    await writeLogFile(logs, 'agentRuntime', fixtureDay, agentRuntimeFixture);
    await writeLogFile(logs, 'sync', fixtureDay, syncFixture);
    await writeLogFile(logs, 'error-safe', fixtureDay, errorSafeFixture);
    await writeLogFile(logs, 'slow_queries', fixtureDay, slowQueriesFixture);
    await writeLogFile(
      logs,
      'super_slow_queries',
      fixtureDay,
      superSlowQueriesFixture,
    );
  });

  tearDown(() => logs.delete(recursive: true));

  SystemHealthAnalyzer analyzer({
    Future<String> Function()? respond,
  }) => SystemHealthAnalyzer(
    reader: LogFileReader(logsDirectory: logs),
    findingsWriter: respond == null
        ? null
        : ({required systemMessage, required prompt, required model}) {
            calls.add(
              (systemMessage: systemMessage, prompt: prompt, model: model),
            );
            return respond();
          },
  );

  SystemHealthRequest request({
    AiConfigModel? model,
    Set<LogDomain>? domains,
  }) => SystemHealthRequest(
    range: fixtureRange(),
    domains: domains ?? {LogDomain.agentRuntime, LogDomain.sync},
    includeSlowQueries: true,
    model: model,
  );

  test(
    'sends the redacted digest to the model and embeds its findings',
    () async {
      final report = await withClock(
        Clock.fixed(now),
        () => analyzer(
          respond: () async => '### Goal wakes fail\nEvidence.',
        ).analyze(request(model: testAiModel())),
      );

      expect(report.generatedAt, now);
      expect(report.findingsSource, SystemHealthFindingsSource.model);
      expect(report.findings, '### Goal wakes fail\nEvidence.');
      expect(calls, hasLength(1));
      expect(calls.single.systemMessage, SystemHealthAnalyzer.systemMessage);
      expect(calls.single.model.id, 'model-1');
      // The prompt is the digest: aggregated, redacted, no raw UUID or email.
      expect(calls.single.prompt, contains('### Issues'));
      expect(calls.single.prompt, contains('[id:19d6f0]'));
      expect(calls.single.prompt, isNot(contains('19d6f0b3-7d45')));
      expect(calls.single.prompt, isNot(contains('user@example.com')));
      expect(calls.single.prompt, contains('[email]'));
      // Raw exception text never reaches the prompt; the safe line does.
      expect(calls.single.prompt, isNot(contains('Bad state')));
      expect(calls.single.prompt, contains('(errorType=StateError)'));
      expect(report.markdown, contains('### Goal wakes fail'));
      expect(report.markdown, contains('<details>'));
      expect(report.summaryMarkdown, isNot(contains('<details>')));
      expect(report.digestMarkdown, calls.single.prompt);
    },
  );

  test(
    'the digest covers errors, warnings and both slow-query tiers',
    () async {
      final report = await analyzer().analyze(request());

      expect(report.digest.errorCount, 3);
      expect(report.digest.warningCount, 2);
      expect(report.digest.slowQueryCount, 4);
      expect(report.digest.superSlowQueryCount, 2);
      expect(report.digest.issues.first.count, 2);
      expect(report.digest.slowQueries.first.planShapes, isNotEmpty);
      expect(report.digest.filesRead, 5);
    },
  );

  test('without a model the report is digest-only', () async {
    final report = await analyzer().analyze(request());

    expect(report.findingsSource, SystemHealthFindingsSource.noModel);
    expect(report.findings, isNull);
    expect(report.markdown, contains('*No model was selected.'));
    expect(calls, isEmpty);
  });

  test('a model without a writer is treated as no model', () async {
    final report = await analyzer().analyze(request(model: testAiModel()));
    expect(report.findingsSource, SystemHealthFindingsSource.noModel);
  });

  test(
    'a failing model call falls back to the digest with a redacted reason',
    () async {
      final report = await analyzer(
        respond: () async => throw StateError(
          'provider for user@example.com has no key',
        ),
      ).analyze(request(model: testAiModel()));

      expect(report.findingsSource, SystemHealthFindingsSource.inferenceFailed);
      expect(
        report.failureDescription,
        'Bad state: provider for [email] has no key',
      );
      expect(report.markdown, contains('*The model call failed: Bad state:'));
      expect(report.markdown, contains('### Issues'));
    },
  );

  test('an empty model response counts as a failure', () async {
    final report = await analyzer(
      respond: () async => '   ',
    ).analyze(request(model: testAiModel()));

    expect(report.findingsSource, SystemHealthFindingsSource.inferenceFailed);
    expect(report.findings, isNull);
    expect(report.failureDescription, 'the model returned an empty response');
  });

  test('nothing to analyse skips the model entirely', () async {
    final report =
        await analyzer(
          respond: () async => 'should not be called',
        ).analyze(
          SystemHealthRequest(
            range: fixtureRange(),
            domains: const {LogDomain.theming},
            includeSlowQueries: false,
            model: testAiModel(),
          ),
        );

    expect(report.findingsSource, SystemHealthFindingsSource.nothingToAnalyse);
    expect(calls, isEmpty);
    expect(report.markdown, contains('*No errors, warnings or slow queries'));
  });
}
