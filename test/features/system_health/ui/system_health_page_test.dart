import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/system_health/domain/system_health_range.dart';
import 'package:lotti/features/system_health/domain/system_health_report.dart';
import 'package:lotti/features/system_health/service/log_file_reader.dart';
import 'package:lotti/features/system_health/service/system_health_analyzer.dart';
import 'package:lotti/features/system_health/service/system_health_report_store.dart';
import 'package:lotti/features/system_health/state/system_health_controller.dart';
import 'package:lotti/features/system_health/ui/system_health_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../system_health_test_fixtures.dart';

/// Widget tests run under a fake clock that never completes real file IO,
/// so the page is fed parsed records directly.
class _InMemoryLogReader extends LogFileReader {
  _InMemoryLogReader() : super(logsDirectory: Directory.current);

  @override
  Future<LogReadResult> read({
    required SystemHealthRange range,
    required Set<LogDomain> domains,
    required bool includeSlowQueries,
  }) async {
    final at = DateTime(2026, 9, 12, 0, 5);
    return LogReadResult(
      records: [
        logRecord(
          timestamp: at,
          message: 'wake failed for host 19d6f0b3-7d45-4ca1-aeb2-8829cac4b42e',
        ),
        logRecord(timestamp: at, level: 'WARN', message: 'drain skipped'),
      ],
      infoCounts: {LogDomain.agentRuntime: 4},
      slowQueries: [slowQuery(timestamp: at, elapsedMs: 300)],
      filesRead: 2,
      linesRead: 7,
    );
  }
}

/// No real file IO under the widget test clock: reports are kept in memory,
/// and [latest] seeds what a restart would restore.
class _InMemoryReportStore extends SystemHealthReportStore {
  _InMemoryReportStore() : super(directory: Directory.current);

  SystemHealthReportDocument? latest;
  final saved = <SystemHealthReport>[];

  @override
  Future<SystemHealthReportDocument> save(SystemHealthReport report) async {
    saved.add(report);
    return report.toDocument(path: '/reports/system-health.md');
  }

  @override
  Future<List<SystemHealthReportDocument>> list() async => [
    ...saved.map((r) => r.toDocument(path: '/reports/system-health.md')),
    ?latest,
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final provider = testInferenceProvider();
  final modelA = testAiModel(id: 'model-a', providerModelId: 'wire/a');
  final modelB = testAiModel(id: 'model-b', providerModelId: 'wire/b');
  final profile = testInferenceProfile(
    id: 'profile-a',
    thinkingModelId: modelA.id,
  );

  late MockJournalDb journalDb;
  late MockAiConfigRepository configs;
  late _InMemoryReportStore reportStore;
  late List<String> clipboard;
  late bool failFlags;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    clipboard = [];
    failFlags = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });

    journalDb = MockJournalDb();
    when(
      () => journalDb.watchConfigFlag(any()),
    ).thenAnswer((_) => Stream.value(true));
    when(() => journalDb.getConfigFlag(any())).thenAnswer((_) async {
      if (failFlags) throw StateError('flags unavailable');
      return true;
    });
    when(
      () => journalDb.getConfigFlagByName(any()),
    ).thenAnswer((_) async => null);
    final persistence = MockPersistenceLogic();
    when(() => persistence.setConfigFlag(any())).thenAnswer((_) async {});
    configs = MockAiConfigRepository();
    when(configs.getDefaultProfileId).thenAnswer((_) async => profile.id);
    reportStore = _InMemoryReportStore();

    getIt
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UserActivityService>(UserActivityService())
      ..registerSingleton<PersistenceLogic>(persistence);
    ensureThemingServicesRegistered();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await getIt.reset();
  });

  List<Override> overrides({
    String findings = '### Finding one\nText.',
    List<AiConfigInferenceProfile>? profiles,
    List<AiConfigModel>? models,
    Completer<String>? findingsGate,
  }) => [
    systemHealthReportStoreProvider.overrideWithValue(reportStore),
    aiConfigRepositoryProvider.overrideWithValue(configs),
    taskAgentSetupOptionsProvider.overrideWith(
      (ref) async => TaskAgentSetupOptions(
        profiles: profiles ?? [profile],
        models: models ?? [modelA, modelB],
        providers: [provider],
      ),
    ),
    systemHealthAnalyzerProvider.overrideWithValue(
      SystemHealthAnalyzer(
        reader: _InMemoryLogReader(),
        findingsWriter:
            ({required systemMessage, required prompt, required model}) =>
                findingsGate?.future ?? Future.value(findings),
      ),
    ),
  ];

  Future<void> pumpBody(
    WidgetTester tester, {
    Widget child = const SystemHealthBody(),
    bool scroll = true,
    List<Override>? providerOverrides,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        // The body is taller than the test viewport; the real hosts scroll.
        scroll ? SingleChildScrollView(child: child) : child,
        overrides: providerOverrides ?? overrides(),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Scrolls the target into the viewport, then taps it.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
  }

  DesignSystemListItem modelRow(WidgetTester tester) =>
      tester.widget<DesignSystemListItem>(
        find.byKey(const Key('system_health_model')),
      );

  testWidgets('shows the controls, the default model and the domain toggles', (
    tester,
  ) async {
    await pumpBody(tester);
    final messages = tester.element(find.byType(SystemHealthBody)).messages;

    expect(find.text(messages.systemHealthDescription), findsOneWidget);
    // The segmented toggle paints each label twice (a bold ghost reserves
    // the selected width), so labels are asserted present, not single.
    expect(find.text(messages.systemHealthPresetLast24Hours), findsWidgets);
    expect(find.text(messages.systemHealthPresetCustom), findsWidgets);
    expect(modelRow(tester).title, 'Test Model');
    expect(find.byType(LoggingSettingsBody), findsOneWidget);
    expect(find.byKey(const Key('system_health_run')), findsOneWidget);
    expect(find.byKey(const Key('system_health_custom_from')), findsNothing);
    expect(find.byKey(const Key('system_health_summary')), findsNothing);
  });

  testWidgets('the mobile page wraps the body with its title', (tester) async {
    await pumpBody(tester, child: const SystemHealthPage(), scroll: false);
    await tester.pump(const Duration(milliseconds: 600));
    final messages = tester.element(find.byType(SystemHealthBody)).messages;
    expect(find.text(messages.settingsSystemHealthTitle), findsOneWidget);
  });

  testWidgets('choosing Custom reveals seeded From and To pickers', (
    tester,
  ) async {
    await pumpBody(tester);
    final messages = tester.element(find.byType(SystemHealthBody)).messages;

    await tester.tap(find.text(messages.systemHealthPresetCustom).first);
    await tester.pump();

    final from = tester.widget<SettingsPickerField>(
      find.byKey(const Key('system_health_custom_from')),
    );
    final to = tester.widget<SettingsPickerField>(
      find.byKey(const Key('system_health_custom_to')),
    );
    expect(from.valueText, isNotNull);
    expect(to.valueText, isNotNull);
    final state = ProviderScope.containerOf(
      tester.element(find.byType(SystemHealthBody)),
    ).read(systemHealthControllerProvider);
    expect(state.preset, SystemHealthPreset.custom);
    expect(
      state.customLastDay!.difference(state.customFirstDay!),
      const Duration(days: 6),
    );
  });

  testWidgets('the From picker opens the date sheet and Done keeps the day', (
    tester,
  ) async {
    await pumpBody(tester);
    final messages = tester.element(find.byType(SystemHealthBody)).messages;
    await tester.tap(find.text(messages.systemHealthPresetCustom).first);
    await tester.pump();
    final before = ProviderScope.containerOf(
      tester.element(find.byType(SystemHealthBody)),
    ).read(systemHealthControllerProvider).customFirstDay;

    await tapVisible(
      tester,
      find.byKey(const Key('system_health_custom_from')),
    );
    await tester.pumpAndSettle();
    expect(find.text(messages.doneButton), findsOneWidget);
    await tester.tap(find.text(messages.doneButton));
    await tester.pumpAndSettle();

    final after = ProviderScope.containerOf(
      tester.element(find.byType(SystemHealthBody)),
    ).read(systemHealthControllerProvider).customFirstDay;
    expect(after, before);
    expect(find.text(messages.doneButton), findsNothing);
  });

  testWidgets('the To picker opens the date sheet and Done keeps the day', (
    tester,
  ) async {
    await pumpBody(tester);
    final messages = tester.element(find.byType(SystemHealthBody)).messages;
    await tester.tap(find.text(messages.systemHealthPresetCustom).first);
    await tester.pump();
    final before = ProviderScope.containerOf(
      tester.element(find.byType(SystemHealthBody)),
    ).read(systemHealthControllerProvider).customLastDay;

    await tapVisible(tester, find.byKey(const Key('system_health_custom_to')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(messages.doneButton));
    await tester.pumpAndSettle();

    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SystemHealthBody)),
      ).read(systemHealthControllerProvider).customLastDay,
      before,
    );
  });

  testWidgets('the model row opens the picker and applies the choice', (
    tester,
  ) async {
    await pumpBody(tester);
    final messages = tester.element(find.byType(SystemHealthBody)).messages;

    await tapVisible(tester, find.byKey(const Key('system_health_model')));
    await tester.pumpAndSettle();
    expect(find.text(messages.taskAgentProfileDefaultBadge), findsOneWidget);
    // Both models are named "Test Model"; rows are told apart by their
    // provider model id subtitle.
    expect(find.text('wire/a'), findsOneWidget);
    expect(find.text('wire/b'), findsOneWidget);

    await tester.tap(find.text('wire/b'));
    await tester.pumpAndSettle();

    final state = ProviderScope.containerOf(
      tester.element(find.byType(SystemHealthBody)),
    ).read(systemHealthControllerProvider);
    expect(state.useDefaultModel, isFalse);
    expect(state.selectedModelId, modelB.id);
  });

  testWidgets('picking the default model again follows the default', (
    tester,
  ) async {
    await pumpBody(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SystemHealthBody)),
    );
    container
        .read(systemHealthControllerProvider.notifier)
        .selectModel(modelB.id);
    await tester.pump();

    await tapVisible(tester, find.byKey(const Key('system_health_model')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('wire/a'));
    await tester.pumpAndSettle();

    expect(
      container.read(systemHealthControllerProvider).useDefaultModel,
      isTrue,
    );
  });

  testWidgets('running renders the report, copies it and toggles the digest', (
    tester,
  ) async {
    final gate = Completer<String>();
    await pumpBody(tester, providerOverrides: overrides(findingsGate: gate));
    final messages = tester.element(find.byType(SystemHealthBody)).messages;

    await tapVisible(tester, find.byKey(const Key('system_health_run')));
    await tester.pump();
    expect(
      tester
          .widget<DesignSystemButton>(
            find.byKey(const Key('system_health_run')),
          )
          .isLoading,
      isTrue,
    );
    gate.complete('### Finding one\nText.');
    await tester.pumpAndSettle();

    final summary = tester.widget<AgentMarkdownView>(
      find.byKey(const Key('system_health_summary')),
    );
    expect(summary.text, contains('## Top findings'));
    expect(summary.text, contains('### Finding one'));
    expect(summary.text, isNot(contains('<details>')));
    expect(find.byKey(const Key('system_health_digest')), findsNothing);
    expect(reportStore.saved, hasLength(1));
    final meta = tester
        .widget<Text>(find.byKey(const Key('system_health_document_meta')))
        .data!;
    expect(
      meta,
      contains(messages.systemHealthSavedTo('/reports/system-health.md')),
    );
    expect(meta, contains('Analyzed'));
    expect(meta, contains('Generated'));
    // The fresh run is now listed as a previous report.
    expect(find.byKey(const Key('system_health_saved_0')), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('system_health_copy')));
    await tester.pump();
    expect(clipboard, hasLength(1));
    expect(clipboard.single, contains('### Finding one'));
    expect(clipboard.single, contains('<details>'));
    expect(clipboard.single, contains('### Counts by domain'));
    expect(clipboard.single, isNot(contains('19d6f0b3-7d45')));
    expect(find.text(messages.systemHealthCopiedToast), findsOneWidget);

    await tapVisible(
      tester,
      find.byKey(const Key('system_health_toggle_digest')),
    );
    await tester.pump();
    final digest = tester.widget<AgentMarkdownView>(
      find.byKey(const Key('system_health_digest')),
    );
    expect(digest.text, contains('### Counts by domain'));
    expect(digest.text, contains('| agentRuntime |'));
    expect(find.text(messages.systemHealthHideDigest), findsOneWidget);

    await tapVisible(
      tester,
      find.byKey(const Key('system_health_toggle_digest')),
    );
    await tester.pump();
    expect(find.byKey(const Key('system_health_digest')), findsNothing);
    expect(find.text(messages.systemHealthShowDigest), findsOneWidget);
  });

  testWidgets('a saved report is shown before any run', (tester) async {
    reportStore.latest = SystemHealthReportDocument.fromMarkdown(
      '# Lotti system health report\n\n## Top findings\n\n### Restored\n\n'
      '<details>\n<summary>D</summary>\n\n### Counts by domain\n\n</details>\n',
      generatedAt: DateTime(2026, 9, 11, 8),
      path: '/reports/system-health-2026-09-11-080000.md',
    );
    await pumpBody(tester);
    await tester.pump();

    final summary = tester.widget<AgentMarkdownView>(
      find.byKey(const Key('system_health_summary')),
    );
    expect(summary.text, contains('### Restored'));
    final meta = tester
        .widget<Text>(find.byKey(const Key('system_health_document_meta')))
        .data!;
    expect(meta, contains('2026'));
    expect(meta, contains('/reports/system-health-2026-09-11-080000.md'));
    expect(
      tester
          .widget<DesignSystemListItem>(
            find.byKey(const Key('system_health_saved_0')),
          )
          .activated,
      isTrue,
    );
    await tapVisible(
      tester,
      find.byKey(const Key('system_health_toggle_digest')),
    );
    await tester.pump();
    expect(
      tester
          .widget<AgentMarkdownView>(
            find.byKey(const Key('system_health_digest')),
          )
          .text,
      contains('### Counts by domain'),
    );
  });

  testWidgets('tapping a previous report shows it and marks it selected', (
    tester,
  ) async {
    reportStore.latest = SystemHealthReportDocument.fromMarkdown(
      '# Lotti system health report\n\n'
      '- Window: 2026-09-04 08:00 → 2026-09-11 08:00 (last 7 days)\n\n'
      '## Top findings\n\n### Older\n',
      generatedAt: DateTime(2026, 9, 11, 8),
      path: '/reports/system-health-2026-09-11-080000.md',
    );
    await pumpBody(tester);
    await tester.pump();
    await tapVisible(tester, find.byKey(const Key('system_health_run')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AgentMarkdownView>(
            find.byKey(const Key('system_health_summary')),
          )
          .text,
      contains('### Finding one'),
    );
    final olderRow = find.byKey(const Key('system_health_saved_1'));
    final messages = tester.element(find.byType(SystemHealthBody)).messages;
    expect(
      tester.widget<DesignSystemListItem>(olderRow).subtitle,
      messages.systemHealthAnalyzedWindow(
        'Sep 4, 2026 08:00',
        'Sep 11, 2026 08:00',
      ),
    );

    await tapVisible(tester, olderRow);
    await tester.pump();

    expect(
      tester
          .widget<AgentMarkdownView>(
            find.byKey(const Key('system_health_summary')),
          )
          .text,
      contains('### Older'),
    );
    expect(tester.widget<DesignSystemListItem>(olderRow).activated, isTrue);
    expect(
      tester
          .widget<DesignSystemListItem>(
            find.byKey(const Key('system_health_saved_0')),
          )
          .activated,
      isFalse,
    );
  });

  testWidgets('a run that cannot start shows a failure toast', (tester) async {
    failFlags = true;
    await pumpBody(tester);
    final messages = tester.element(find.byType(SystemHealthBody)).messages;

    await tapVisible(tester, find.byKey(const Key('system_health_run')));
    await tester.pumpAndSettle();

    expect(find.text(messages.systemHealthFailedTitle), findsOneWidget);
    expect(find.textContaining('flags unavailable'), findsOneWidget);
    expect(find.byKey(const Key('system_health_summary')), findsNothing);
  });

  testWidgets('without any agentic model the row is inert', (tester) async {
    when(configs.getDefaultProfileId).thenAnswer((_) async => null);
    await pumpBody(
      tester,
      providerOverrides: overrides(profiles: const [], models: const []),
    );
    final messages = tester.element(find.byType(SystemHealthBody)).messages;

    final row = modelRow(tester);
    expect(row.title, messages.systemHealthModelNone);
    expect(row.subtitle, messages.systemHealthModelNoneDescription);
    expect(row.onTap, isNull);
  });

  test('the domain set the page analyses is the enabled logging set', () {
    // Documented contract: the embedded body and the run share the flags.
    expect(
      LogDomain.values.map((d) => d.flagName),
      everyElement(startsWith('log_')),
    );
  });
}
