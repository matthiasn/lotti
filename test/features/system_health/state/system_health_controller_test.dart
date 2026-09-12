import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/system_health/domain/system_health_range.dart';
import 'package:lotti/features/system_health/domain/system_health_report.dart';
import 'package:lotti/features/system_health/service/log_file_reader.dart';
import 'package:lotti/features/system_health/service/system_health_analyzer.dart';
import 'package:lotti/features/system_health/service/system_health_report_store.dart';
import 'package:lotti/features/system_health/state/system_health_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../system_health_test_fixtures.dart';

void main() {
  // Late enough that the fixture's evening slow queries fall inside 24 h.
  final now = DateTime(2026, 9, 12, 20);
  final provider = testInferenceProvider();
  final modelA = testAiModel(id: 'model-a', providerModelId: 'wire/a');
  final modelB = testAiModel(id: 'model-b', providerModelId: 'wire/b');
  final profile = testInferenceProfile(
    id: 'profile-a',
    thinkingModelId: modelA.id,
  );

  late TestGetItMocks mocks;
  late Directory logs;
  late MockAiConfigRepository configs;
  late List<AiConfigModel> writerModels;
  late Future<String> Function() respond;

  setUp(() async {
    mocks = await setUpTestGetIt();
    logs = await Directory.systemTemp.createTemp('system_health_controller');
    await writeLogFile(logs, 'agentRuntime', fixtureDay, agentRuntimeFixture);
    await writeLogFile(logs, 'sync', fixtureDay, syncFixture);
    await writeLogFile(logs, 'error-safe', fixtureDay, errorSafeFixture);
    await writeLogFile(logs, 'slow_queries', fixtureDay, slowQueriesFixture);
    configs = MockAiConfigRepository();
    when(configs.getDefaultProfileId).thenAnswer((_) async => profile.id);
    when(
      () => mocks.journalDb.getConfigFlag(any()),
    ).thenAnswer((invocation) async {
      final flag = invocation.positionalArguments.single as String;
      return flag == LogDomain.agentRuntime.flagName ||
          flag == LogDomain.sync.flagName ||
          flag == logSlowQueriesFlag;
    });
    writerModels = [];
    respond = () async => '### Finding';
  });

  tearDown(() async {
    await logs.delete(recursive: true);
    await tearDownTestGetIt();
  });

  SystemHealthReportStore store() => SystemHealthReportStore(
    directory: Directory(p.join(logs.path, 'system_health')),
  );

  ProviderContainer makeContainer({
    List<AiConfigInferenceProfile>? profiles,
    SystemHealthAnalyzer? analyzer,
  }) {
    final container = ProviderContainer(
      overrides: [
        systemHealthReportStoreProvider.overrideWithValue(store()),
        aiConfigRepositoryProvider.overrideWithValue(configs),
        taskAgentSetupOptionsProvider.overrideWith(
          (ref) async => TaskAgentSetupOptions(
            profiles: profiles ?? [profile],
            models: [modelA, modelB],
            providers: [provider],
          ),
        ),
        systemHealthAnalyzerProvider.overrideWithValue(
          analyzer ??
              SystemHealthAnalyzer(
                reader: LogFileReader(logsDirectory: logs),
                findingsWriter:
                    ({
                      required systemMessage,
                      required prompt,
                      required model,
                    }) {
                      writerModels.add(model);
                      return respond();
                    },
              ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<SystemHealthState> run(ProviderContainer container) async {
    await withClock(
      Clock.fixed(now),
      () => container.read(systemHealthControllerProvider.notifier).run(),
    );
    return container.read(systemHealthControllerProvider);
  }

  group('choices', () {
    test('starts on the last 24 hours following the default model', () {
      final state = makeContainer().read(systemHealthControllerProvider);
      expect(state.preset, SystemHealthPreset.last24Hours);
      expect(state.useDefaultModel, isTrue);
      expect(state.selectedModelId, isNull);
      expect(state.report, isNull);
      expect(state.document, isNull);
      expect(state.isRunning, isFalse);
      final range = state.rangeAt(now);
      expect(range.start, now.subtract(const Duration(hours: 24)));
      expect(range.end, now);
    });

    test('switching to custom seeds the last seven whole days once', () {
      final container = makeContainer();
      final controller = container.read(
        systemHealthControllerProvider.notifier,
      );
      withClock(Clock.fixed(now), () {
        controller.selectPreset(SystemHealthPreset.custom);
      });
      var state = container.read(systemHealthControllerProvider);
      expect(state.customFirstDay, DateTime(2026, 9, 6));
      expect(state.customLastDay, DateTime(2026, 9, 12));

      controller
        ..selectPreset(SystemHealthPreset.last7Days)
        ..setCustomFirstDay(DateTime(2026, 9))
        ..selectPreset(SystemHealthPreset.custom);
      state = container.read(systemHealthControllerProvider);
      expect(state.customFirstDay, DateTime(2026, 9));
      expect(state.rangeAt(now).start, DateTime(2026, 9));
      expect(state.rangeAt(now).end.day, 12);
    });

    test('custom bounds keep first day on or before last day', () {
      final container = makeContainer();
      final controller = container.read(
        systemHealthControllerProvider.notifier,
      );
      withClock(Clock.fixed(now), () {
        controller.selectPreset(SystemHealthPreset.custom);
      });
      controller.setCustomFirstDay(DateTime(2026, 9, 20));
      var state = container.read(systemHealthControllerProvider);
      expect(state.customLastDay, DateTime(2026, 9, 20));

      controller.setCustomLastDay(DateTime(2026, 9, 2));
      state = container.read(systemHealthControllerProvider);
      expect(state.customFirstDay, DateTime(2026, 9, 2));
      expect(state.customLastDay, DateTime(2026, 9, 2));
    });

    test('a custom preset without bounds falls back to the last week', () {
      const state = SystemHealthState(preset: SystemHealthPreset.custom);
      final range = state.rangeAt(now);
      expect(range.start, DateTime(2026, 9, 6));
      expect(range.end.day, 12);
    });

    test(
      'selectModel makes the choice explicit and useDefaultModel undoes it',
      () {
        final container = makeContainer();
        final controller = container.read(
          systemHealthControllerProvider.notifier,
        )..selectModel(modelB.id);
        var state = container.read(systemHealthControllerProvider);
        expect(state.selectedModelId, modelB.id);
        expect(state.useDefaultModel, isFalse);

        controller.useDefaultModel();
        state = container.read(systemHealthControllerProvider);
        expect(state.useDefaultModel, isTrue);
        expect(state.selectedModelId, modelB.id);
      },
    );
  });

  group('device wiring', () {
    test('the analyzer reads logs beside the documents directory and the '
        'store keeps reports in a system_health folder', () {
      getIt.registerSingleton<Directory>(logs);
      final container = ProviderContainer(
        overrides: [aiConfigRepositoryProvider.overrideWithValue(configs)],
      );
      addTearDown(container.dispose);

      final analyzer = container.read(systemHealthAnalyzerProvider);
      expect(analyzer.reader.logsDirectory.path, p.join(logs.path, 'logs'));
      expect(analyzer.findingsWriter, isNotNull);

      final reportStore = container.read(systemHealthReportStoreProvider);
      expect(
        reportStore.directory.path,
        p.join(logs.path, 'logs', 'system_health'),
      );
    });
  });

  group('systemHealthDefaultModelProvider', () {
    test('resolves the default profile thinking model', () async {
      final model = await makeContainer().read(
        systemHealthDefaultModelProvider.future,
      );
      expect(model?.id, modelA.id);
    });

    test('is null without a default profile', () async {
      when(configs.getDefaultProfileId).thenAnswer((_) async => null);
      final model = await makeContainer().read(
        systemHealthDefaultModelProvider.future,
      );
      expect(model, isNull);
    });

    test(
      'is null when the profile is unknown or its model is not agentic',
      () async {
        when(configs.getDefaultProfileId).thenAnswer((_) async => 'missing');
        expect(
          await makeContainer().read(systemHealthDefaultModelProvider.future),
          isNull,
        );
        when(configs.getDefaultProfileId).thenAnswer((_) async => profile.id);
        final other = testInferenceProfile(
          id: profile.id,
          thinkingModelId: 'not-listed',
        );
        expect(
          await makeContainer(
            profiles: [other],
          ).read(systemHealthDefaultModelProvider.future),
          isNull,
        );
      },
    );
  });

  group('run', () {
    test('analyses the enabled domains with the default model', () async {
      final state = await run(makeContainer());

      expect(state.isRunning, isFalse);
      expect(state.failure, isNull);
      final report = state.report!;
      expect(report.request.domains, {LogDomain.agentRuntime, LogDomain.sync});
      expect(report.request.includeSlowQueries, isTrue);
      expect(report.request.model?.id, modelA.id);
      expect(report.request.range.end, now);
      expect(report.findingsSource, SystemHealthFindingsSource.model);
      expect(report.findings, '### Finding');
      expect(writerModels.map((m) => m.id), [modelA.id]);
      expect(report.digest.slowQueryCount, 4);
      // The report is written beside the logs and the page shows that file.
      final document = state.document!;
      expect(document.markdown, report.markdown);
      expect(document.path, endsWith('system-health-2026-09-12-200000.md'));
      expect(await File(document.path!).readAsString(), report.markdown);
    });

    test('the newest saved report is restored on build', () async {
      final first = makeContainer();
      await run(first);
      first.dispose();

      final container = makeContainer();
      final restored = Completer<SystemHealthState>();
      container.listen(systemHealthControllerProvider, (_, next) {
        if (next.document != null && !restored.isCompleted) {
          restored.complete(next);
        }
      }, fireImmediately: true);
      expect(container.read(systemHealthControllerProvider).document, isNull);
      final state = await restored.future;
      expect(state.report, isNull);
      expect(state.document?.summaryMarkdown, contains('### Finding'));
      expect(state.document?.path, endsWith('.md'));
      expect(state.document?.windowEnd, now);
      expect(state.savedReports, hasLength(1));
    });

    test(
      'every run is listed, and a saved report can be shown again',
      () async {
        final container = makeContainer();
        await run(container);
        final firstPath = container
            .read(systemHealthControllerProvider)
            .document
            ?.path;
        await withClock(
          Clock.fixed(now.add(const Duration(hours: 1))),
          () => container.read(systemHealthControllerProvider.notifier).run(),
        );
        var state = container.read(systemHealthControllerProvider);
        expect(state.savedReports, hasLength(2));
        expect(state.savedReports.first.path, state.document?.path);
        expect(state.savedReports.last.path, firstPath);

        container
            .read(systemHealthControllerProvider.notifier)
            .showSaved(state.savedReports.last);
        state = container.read(systemHealthControllerProvider);
        expect(state.document?.path, firstPath);
        expect(state.document?.windowEnd, now);
        // The last run's report object is untouched by browsing.
        expect(state.report?.generatedAt, now.add(const Duration(hours: 1)));
      },
    );

    test('a failed save still yields the report without a path', () async {
      final blocked = Directory(p.join(logs.path, 'system_health'));
      await File(blocked.path).writeAsString('not a directory');
      final state = await run(makeContainer());
      expect(state.report, isNotNull);
      expect(state.document?.path, isNull);
      expect(state.document?.markdown, state.report?.markdown);
    });

    test('uses the explicitly chosen model', () async {
      final container = makeContainer();
      container
          .read(systemHealthControllerProvider.notifier)
          .selectModel(modelB.id);
      final state = await run(container);
      expect(state.report?.request.model?.id, modelB.id);
    });

    test('an unknown explicit model yields a digest-only report', () async {
      final container = makeContainer();
      container
          .read(systemHealthControllerProvider.notifier)
          .selectModel('gone');
      final state = await run(container);
      expect(state.report?.request.model, isNull);
      expect(
        state.report?.findingsSource,
        SystemHealthFindingsSource.noModel,
      );
      expect(writerModels, isEmpty);
    });

    test('without a default profile the report is digest-only', () async {
      when(configs.getDefaultProfileId).thenAnswer((_) async => null);
      final state = await run(makeContainer());
      expect(state.report?.request.model, isNull);
      expect(
        state.report?.findingsSource,
        SystemHealthFindingsSource.noModel,
      );
    });

    test('records a redacted failure when the run cannot start', () async {
      when(() => mocks.journalDb.getConfigFlag(any())).thenAnswer(
        (_) async => throw StateError('flags unavailable for user@example.com'),
      );
      final state = await run(makeContainer());

      expect(state.isRunning, isFalse);
      expect(state.report, isNull);
      expect(state.failure, 'Bad state: flags unavailable for [email]');
    });

    test('a second run while one is in flight is ignored', () async {
      final gate = Completer<String>();
      final writerCalled = Completer<void>();
      respond = () {
        writerCalled.complete();
        return gate.future;
      };
      final container = makeContainer();
      final controller = container.read(
        systemHealthControllerProvider.notifier,
      );

      final first = withClock(Clock.fixed(now), controller.run);
      await writerCalled.future;
      expect(container.read(systemHealthControllerProvider).isRunning, isTrue);
      await controller.run();
      expect(writerModels, hasLength(1));

      gate.complete('### Late');
      await first;
      final state = container.read(systemHealthControllerProvider);
      expect(state.isRunning, isFalse);
      expect(state.report?.findings, '### Late');
    });

    test('a new run clears the previous failure', () async {
      when(
        () => mocks.journalDb.getConfigFlag(any()),
      ).thenAnswer((_) async => throw StateError('boom'));
      final container = makeContainer();
      await run(container);
      expect(container.read(systemHealthControllerProvider).failure, isNotNull);

      when(
        () => mocks.journalDb.getConfigFlag(any()),
      ).thenAnswer((_) async => true);
      final state = await run(container);
      expect(state.failure, isNull);
      expect(state.report, isNotNull);
    });
  });
}
