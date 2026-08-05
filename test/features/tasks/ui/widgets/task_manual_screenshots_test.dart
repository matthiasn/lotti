/// Deterministic manual screenshots for the production Tasks surfaces.
///
/// Opt in with `LOTTI_SCREENSHOT_DIR=<external-dir>`; generated PNGs are
/// staging inputs for the manual media manifest and are never committed here.
library;

import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/ai/ui/image_generation/cover_art_skill_modal.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_modal.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_task_modal.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_root_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/tasks/ui/task_form.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/fallbacks.dart';
import '../../../../helpers/manual_demo_world.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/change_set_factories.dart';
import '../../../agents/test_data/entity_factories.dart';
import '../../../daily_os_next/screenshot_harness.dart';
import '../pages/task_details_page_test_helpers.dart';

class _ManualRunningInferenceController extends InferenceStatusController {
  @override
  InferenceStatus build() => InferenceStatus.running;
}

/// Serves a fixed link list so the task's below-card entries render without a
/// Drift-level link graph behind them.
class _ManualLinkedEntriesController extends LinkedEntriesController {
  _ManualLinkedEntriesController(this._links);

  final List<EntryLink> _links;

  @override
  Future<List<EntryLink>> build() async => _links;
}

const _manualTaskAgentId = 'agent-habitat-watcher';
const _manualTaskAgentStateId = 'state-habitat-watcher';
String _t(String en, String de) => manualScreenshotText(en: en, de: de);

final String _manualTaskAgentName = _t('Habitat Watcher', 'Habitatwächter');

/// The proposed checklist item's title, shared by the fixture that supplies it
/// and the assertion that looks for it — the rendered row wraps this in
/// locale-specific quotation marks, so neither side may spell out the result.
final String _manualTaskAgentAddItemTitle = _t(
  'Run zero-gravity sardine feeder test',
  'Schwerelos-Futterautomaten testen',
);
final String _manualTaskAgentTldr = _t(
  'All 37 emperor penguins are accounted for. Habitat pressure held at '
      '101.3 kPa overnight; the remaining launch risk is the zero-gravity '
      'sardine feeder calibration.',
  'Alle 37 Kaiserpinguine sind vollzählig. Der Habitatdruck blieb über Nacht '
      'bei 101,3 kPa; als einziges Startrisiko bleibt die Kalibrierung des '
      'Schwerelos-Futterautomaten.',
);
final String _manualTaskAgentReport = manualScreenshotText(
  en: '''
## Latest assessment

- Pressure seals A–F stayed stable across the night shift.
- 840 sardines are loaded; feeder calibration still blocks sign-off.
- Mission Control clearance is due before the 06:30 roll call.

## Recommended next step

Run the feeder test, attach the telemetry image, then request launch approval.
''',
  de: '''
## Aktuelle Einschätzung

- Die Druckdichtungen A–F blieben während der Nachtschicht stabil.
- 840 Sardinen sind geladen; die Futterautomat-Kalibrierung verhindert noch die Freigabe.
- Die Freigabe der Missionskontrolle muss vor dem Zählappell um 06:30 Uhr vorliegen.

## Empfohlener nächster Schritt

Führe den Automatentest aus, hänge das Telemetriebild an und fordere dann die Startfreigabe an.
''',
  fr: '''
## Dernière évaluation

- Les joints de pression A–F sont restés stables pendant l'équipe de nuit.
- 840 sardines sont chargées ; le calibrage du distributeur bloque toujours la validation.
- L'autorisation de Mission Control est attendue avant l'appel de 6 h 30.

## Prochaine étape recommandée

Lance le test du distributeur, joins l'image de télémétrie puis demande l'autorisation de lancement.
''',
  it: '''
## Ultima valutazione

- Le guarnizioni di pressione A–F sono rimaste stabili durante il turno notturno.
- Sono caricate 840 sardine; la calibrazione dell'alimentatore blocca ancora l'approvazione.
- L'autorizzazione del Controllo missione è dovuta prima dell'appello delle 06:30.

## Prossimo passo consigliato

Esegui il test dell'alimentatore, allega l'immagine della telemetria, quindi richiedi l'approvazione al lancio.
''',
  pt: '''
## Última avaliação

- As vedações de pressão A–F permaneceram estáveis durante o turno da noite.
- São carregadas 840 sardinhas; a calibração do alimentador ainda bloqueia a aprovação.
- A autorização do Controle da Missão deve ser feita antes da chamada das 06:30.

## Próxima etapa recomendada

Execute o teste do alimentador, anexe a imagem de telemetria e solicite a aprovação do lançamento.
''',
  nl: '''
## Laatste beoordeling

- De drukafdichtingen A–F bleven gedurende de nachtdienst stabiel.
- Er zijn 840 sardines geladen; de kalibratie van de voederautomaat blokkeert de vrijgave nog steeds.
- De toestemming van Mission Control is nodig vóór de telling van 06:30.

## Aanbevolen volgende stap

Voer de voedertest uit, voeg de telemetrieafbeelding toe en vraag daarna toestemming voor de lancering.
''',
);

final AiConfigModel _manualThinkingModel = manualDemoAiModels.firstWhere(
  (model) => model.id == manualWaddleCommandModelId,
);
final AiConfigInferenceProvider _manualThinkingProvider = manualDemoAiProviders
    .firstWhere(
      (provider) => provider.id == manualMissionControlProviderId,
    );
final _manualResolvedProfile = ResolvedProfile(
  thinkingModelId: _manualThinkingModel.providerModelId,
  thinkingProvider: _manualThinkingProvider,
  thinkingModel: _manualThinkingModel,
);
final _manualResolvedAgentSetup = ResolvedAgentSetup(
  status: AgentSetupResolutionStatus.resolved,
  profile: _manualResolvedProfile,
  source: AgentSetupResolutionSource.baseProfile,
  setupOrigin: AgentInferenceSetupOrigin.user,
);
final AgentTemplateEntity _manualTaskAgentTemplate =
    AgentDomainEntity.agentTemplate(
          id: 'template-habitat-watcher',
          agentId: 'template-habitat-watcher',
          displayName: _manualTaskAgentName,
          kind: AgentTemplateKind.taskAgent,
          modelId: manualWaddleCommandModelId,
          categoryIds: const {manualDemoCategoryId},
          createdAt: manualDemoNow.subtract(const Duration(days: 14)),
          updatedAt: manualDemoNow.subtract(const Duration(days: 2)),
          vectorClock: null,
        )
        as AgentTemplateEntity;
final AgentReportEntity _manualAgentReport = makeTestReport(
  id: 'report-habitat-watcher',
  agentId: _manualTaskAgentId,
  createdAt: manualDemoNow.subtract(const Duration(minutes: 4)),
  tldr: _manualTaskAgentTldr,
  content: _manualTaskAgentReport,
  oneLiner: _t(
    'Habitat stable; zero-gravity sardine feeder blocks sign-off.',
    'Habitat stabil; der Schwerelos-Futterautomat verhindert die Freigabe.',
  ),
  provenance: ReportInferenceProvenance(
    runKey: 'run-habitat-night-watch',
    threadId: 'thread-project-waddle-habitat',
    executor: InferenceRouteSnapshot.fromResolvedProfile(
      _manualResolvedProfile,
    ),
    finalContentAuthor: ReportContentAuthor.executor,
  ).toReportMap(),
);

AgentIdentityEntity _manualTaskAgentIdentity({
  required bool automaticUpdates,
}) => makeTestIdentity(
  id: _manualTaskAgentId,
  agentId: _manualTaskAgentId,
  displayName: _manualTaskAgentName,
  currentStateId: _manualTaskAgentStateId,
  createdAt: manualDemoNow.subtract(const Duration(days: 14)),
  updatedAt: manualDemoNow.subtract(const Duration(minutes: 3)),
  config: AgentConfig(
    automaticUpdatesEnabled: automaticUpdates,
    inferenceSetup: const AgentInferenceSetup(
      mode: AgentInferenceSetupMode.configured,
      origin: AgentInferenceSetupOrigin.user,
      baseProfileId: manualProjectWaddleProfileId,
    ),
  ),
);

AgentStateEntity _manualTaskAgentState({required bool automaticUpdates}) =>
    makeTestState(
      id: _manualTaskAgentStateId,
      agentId: _manualTaskAgentId,
      updatedAt: manualDemoNow,
      lastWakeAt: manualDemoNow.subtract(const Duration(minutes: 4)),
    ).copyWith(
      reportStaleAt: automaticUpdates
          ? null
          : manualDemoNow.subtract(const Duration(minutes: 1)),
      reportFreshAt: automaticUpdates
          ? manualDemoNow.subtract(const Duration(minutes: 4))
          : manualDemoNow.subtract(const Duration(minutes: 5)),
    );

List<PendingSuggestion> _manualTaskAgentSuggestions() {
  final changeSet = makeTestChangeSet(
    id: 'changes-habitat-launch-readiness',
    agentId: _manualTaskAgentId,
    taskId: manualOrbitalHabitatTaskId,
    threadId: 'thread-project-waddle-habitat',
    runKey: 'run-habitat-night-watch',
    createdAt: manualDemoNow.subtract(const Duration(minutes: 3)),
    items: [
      ChangeItem(
        toolName: 'add_checklist_item',
        args: {'title': _manualTaskAgentAddItemTitle},
        humanSummary: _t(
          'Add: "Run zero-gravity sardine feeder test"',
          'Hinzufügen: "Schwerelos-Futterautomaten testen"',
        ),
      ),
      ChangeItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 75},
        humanSummary: _t(
          'Estimate: 45m → 1h 15m',
          'Schätzung: 45 Min. → 1 Std. 15 Min.',
        ),
      ),
    ],
  );

  return [
    for (var index = 0; index < changeSet.items.length; index++)
      PendingSuggestion(
        changeSet: changeSet,
        itemIndex: index,
        item: changeSet.items[index],
        fingerprint: ChangeItem.fingerprint(changeSet.items[index]),
      ),
  ];
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'task manual screenshot harness (opt-in)',
      () {},
      skip: 'Set LOTTI_SCREENSHOT_DIR to capture manual screenshots.',
    );
    return;
  }

  late ManualDemoWorld world;
  Directory? documentsDirectory;
  late PagingController<int, JournalEntity> pagingController;
  late FakeJournalPageController pageController;
  late ValueNotifier<String?> selectedTaskId;
  late ValueNotifier<List<String>> detailStack;
  late MockJournalRepository journalRepository;

  setUpAll(() async {
    registerAllFallbackValues();
    await loadScreenshotFonts();
  });

  setUp(() async {
    world = ManualDemoWorld.penguinLogistics();
    final testDocumentsDirectory = Directory.systemTemp.createTempSync(
      'lotti-manual-tasks-',
    );
    documentsDirectory = testDocumentsDirectory;
    final installedMedia = await world.installMediaFromRemote(
      testDocumentsDirectory,
      fetchUrl: fetchManualDemoSeedMedia,
    );
    await transcodeManualDemoMediaToPng(installedMedia);

    final entitiesCache = MockEntitiesCacheService();
    final navService = MockNavService();
    final timeService = MockTimeService();
    final persistenceLogic = MockPersistenceLogic();
    final userActivityService = MockUserActivityService();
    final editorStateService = MockEditorStateService();
    final fts5Db = MockFts5Db();
    journalRepository = MockJournalRepository();

    selectedTaskId = ValueNotifier<String?>(world.orbitalHabitatTask.meta.id);
    detailStack = ValueNotifier<List<String>>(<String>[
      world.orbitalHabitatTask.meta.id,
    ]);

    when(userActivityService.updateActivity).thenReturn(null);
    when(
      () => navService.beamToNamed(any(), data: any(named: 'data')),
    ).thenReturn(null);
    when(() => navService.desktopSelectedTaskId).thenReturn(selectedTaskId);
    when(() => navService.desktopTaskDetailStack).thenReturn(detailStack);
    when(() => navService.isDesktopMode).thenReturn(true);
    when(timeService.getStream).thenAnswer((_) => const Stream.empty());
    when(() => timeService.linkedFrom).thenReturn(null);
    when(
      () => editorStateService.getUnsavedStream(any(), any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => fts5Db.watchFullTextMatches(any()),
    ).thenAnswer((_) => Stream.value(<String>[]));
    when(
      () => journalRepository.getLinkedImagesForTask(any()),
    ).thenAnswer((_) async => world.coverImages.take(5).toList());
    when(
      () => journalRepository.getLinksFromId(any()),
    ).thenAnswer((_) async => []);
    when(
      () => journalRepository.getLinkedToEntities(
        linkedTo: any(named: 'linkedTo'),
      ),
    ).thenAnswer((_) async => []);

    when(() => entitiesCache.sortedCategories).thenReturn([world.category]);
    when(() => entitiesCache.sortedLabels).thenReturn(world.labels);
    when(() => entitiesCache.showPrivateEntries).thenReturn(true);
    when(
      () => entitiesCache.getCategoryById(manualDemoCategoryId),
    ).thenReturn(world.category);
    for (final label in world.labels) {
      when(() => entitiesCache.getLabelById(label.id)).thenReturn(label);
    }

    final mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<Directory>(testDocumentsDirectory)
          ..registerSingleton<EntitiesCacheService>(entitiesCache)
          ..registerSingleton<NavService>(navService)
          ..registerSingleton<TimeService>(timeService)
          ..registerSingleton<PersistenceLogic>(persistenceLogic)
          ..registerSingleton<UserActivityService>(userActivityService)
          ..registerSingleton<EditorStateService>(editorStateService)
          ..registerSingleton<Fts5Db>(fts5Db)
          ..registerSingleton<LinkService>(MockLinkService())
          ..registerSingleton<HealthImport>(MockHealthImport());
      },
    );

    when(
      () => mocks.journalDb.journalEntityById(any()),
    ).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as String;
      // Yield a full event-loop turn rather than resolving on the next
      // microtask. A real Drift lookup always crosses a timer boundary, and
      // controllers that aggregate several of these (checklist completion
      // counts) only settle correctly when their own build future has
      // resolved first.
      await Future<void>.delayed(Duration.zero);
      return world.entityById(id);
    });
    when(
      () => mocks.journalDb.getCategoryById(manualDemoCategoryId),
    ).thenAnswer((_) async => world.category);
    when(
      () => mocks.journalDb.getProjectsForCategory(any()),
    ).thenAnswer((_) async => <ProjectEntry>[]);
    when(mocks.journalDb.getVisibleProjects).thenAnswer(
      (_) async => <ProjectEntry>[],
    );
    when(
      () => mocks.journalDb.getTaskEstimatesByIds(any()),
    ).thenAnswer((invocation) async {
      final ids = invocation.positionalArguments.first as Set<String>;
      return {
        for (final id in ids)
          id: world.entityById(id) is Task
              ? (world.entityById(id)! as Task).data.estimate
              : null,
      };
    });
    // The habitat task is the one fixture that has logged time, so the manual
    // screenshots show real progress ("1h 10m of 2h") instead of "0m of 2h".
    when(
      () => mocks.journalDb.getBulkLinkedTimeSpans(any()),
    ).thenAnswer((invocation) async {
      final fromIds = invocation.positionalArguments.first as Set<String>;
      final record = world.habitatTimeRecord;
      return {
        for (final id in fromIds)
          id: id == manualOrbitalHabitatTaskId
              ? <LinkedEntityTimeSpan>[
                  (
                    id: record.meta.id,
                    dateFrom: record.meta.dateFrom,
                    dateTo: record.meta.dateTo,
                  ),
                ]
              : <LinkedEntityTimeSpan>[],
      };
    });
    when(
      () => mocks.journalDb.getLinkedEntities(any()),
    ).thenAnswer((invocation) async {
      final linkedFrom = invocation.positionalArguments.first as String;
      return linkedFrom == manualOrbitalHabitatTaskId
          ? <JournalEntity>[world.habitatTimeRecord]
          : <JournalEntity>[];
    });
    when(mocks.journalDb.watchConfigFlags).thenAnswer(
      (_) => const Stream.empty(),
    );
    when(
      () => mocks.journalDb.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => world.taskBrowseTasks);

    pagingController =
        PagingController<int, JournalEntity>(
            getNextPageKey: (_) => null,
            fetchPage: (_) async => const <JournalEntity>[],
          )
          ..value = PagingState<int, JournalEntity>(
            pages: [world.taskBrowseTasks],
            keys: const [0],
            hasNextPage: false,
          );
    pageController = FakeJournalPageController(
      JournalPageState(
        showTasks: true,
        pagingController: pagingController,
        taskStatuses: const ['OPEN', 'IN PROGRESS', 'GROOMED'],
        selectedTaskStatuses: const {'OPEN', 'IN PROGRESS', 'GROOMED'},
        selectedEntryTypes: const ['Task'],
        sortOption: TaskSortOption.byDueDate,
      ),
    );
  });

  tearDown(() async {
    pagingController.dispose();
    selectedTaskId.dispose();
    detailStack.dispose();
    await tearDownTestGetIt();
    final testDocumentsDirectory = documentsDirectory;
    documentsDirectory = null;
    if (testDocumentsDirectory?.existsSync() ?? false) {
      testDocumentsDirectory!.deleteSync(recursive: true);
    }
  });

  for (final device in [proDevice, desktopDevice]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final viewport = device.isPhone ? 'mobile' : 'desktop';
      final theme = brightness.name;

      testWidgets('$viewport task workspace — $theme', (tester) async {
        await _pumpTaskSurface(
          tester,
          device: device,
          brightness: brightness,
          world: world,
          pageController: pageController,
          journalRepository: journalRepository,
          surface: const TasksRootPage(),
        );

        expect(find.byType(TasksTabPage), findsOneWidget);
        expect(
          find.text(
            _t(
              'Inspect orbital penguin habitat',
              'Pinguin-Habitat im Orbit inspizieren',
            ),
          ),
          findsAtLeastNWidgets(1),
        );
        expect(find.byType(CoverArtThumbnail), findsAtLeastNWidgets(3));
        expect(
          tester
              .widgetList<CoverArtThumbnail>(find.byType(CoverArtThumbnail))
              .map((thumbnail) => thumbnail.imageId)
              .toSet(),
          containsAll(<String>{
            manualHabitatCoverImageId,
            manualFishFeederCoverImageId,
            manualSardineCargoCoverImageId,
          }),
        );
        expect(
          find.descendant(
            of: find.byType(CoverArtThumbnail),
            matching: find.byType(Image),
          ),
          findsAtLeastNWidgets(3),
        );
        if (!device.isPhone) {
          expect(find.byType(TaskDetailsPage), findsOneWidget);
        }
        await captureScreenshot(
          tester,
          'task_workspace_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport task detail — $theme', (tester) async {
        // Desktop never shows the task detail full-bleed: it lives in the
        // right pane of [TasksRootPage]. Capturing the page standalone at
        // 1440pt made the 16:9 cover art 810pt tall and pushed the entire
        // record off screen, so the manual's lead screenshot was nothing but
        // cover art. Capture the real layout instead, scrolled so the record
        // — not the artwork — is what the reader sees.
        await _pumpTaskSurface(
          tester,
          device: device,
          brightness: brightness,
          world: world,
          pageController: pageController,
          journalRepository: journalRepository,
          surface: device.isPhone
              ? TaskDetailsPage(taskId: world.orbitalHabitatTask.meta.id)
              : const TasksRootPage(),
        );
        if (!device.isPhone) {
          await _focusTaskDetailBody(tester);
        }

        expect(find.byType(TaskDetailsPage), findsOneWidget);
        final title = _t(
          'Inspect orbital penguin habitat',
          'Pinguin-Habitat im Orbit inspizieren',
        );
        expect(find.text(title), findsWidgets);
        expect(find.text(_manualTaskAgentName), findsOneWidget);
        // The record itself has to be on screen, not merely in the tree.
        _expectVisible(tester, device, find.text(title).last);
        _expectVisible(
          tester,
          device,
          find.text(
            _t('Pre-launch checks', 'Checks vor dem Start'),
          ),
        );
        await captureScreenshot(
          tester,
          'task_detail_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport task agent collapsed — $theme', (tester) async {
        await _pumpTaskSurface(
          tester,
          device: device,
          brightness: brightness,
          world: world,
          pageController: pageController,
          journalRepository: journalRepository,
          surface: TaskDetailsPage(
            taskId: world.orbitalHabitatTask.meta.id,
          ),
        );

        await _focusTaskAgentCard(tester, device: device);
        final messages = AppLocalizations.of(
          tester.element(find.byType(TaskDetailsPage)),
        )!;
        expect(
          find.text(messages.aiCardTitle),
          findsOneWidget,
        );
        expect(find.text(_manualTaskAgentName), findsOneWidget);
        expect(find.text(_manualTaskAgentTldr), findsOneWidget);
        expect(
          find.text(messages.taskAgentAutomaticUpdatesLabel),
          findsOneWidget,
        );
        expect(
          find.textContaining(_t('Waddle Command 70B', 'Watschelkommando 70B')),
          findsOneWidget,
        );
        expect(find.text(messages.aiCardReadMore), findsOneWidget);
        await captureScreenshot(
          tester,
          'task_agent_collapsed_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport task agent expanded — $theme', (tester) async {
        await _pumpTaskSurface(
          tester,
          device: device,
          brightness: brightness,
          world: world,
          pageController: pageController,
          journalRepository: journalRepository,
          surface: TaskDetailsPage(
            taskId: world.orbitalHabitatTask.meta.id,
          ),
        );

        await _focusTaskAgentCard(tester, device: device);
        final messages = AppLocalizations.of(
          tester.element(find.byType(TaskDetailsPage)),
        )!;
        await tester.tap(
          find.byKey(const ValueKey('taskAgentReportDisclosure')),
        );
        await settleFrames(tester, 8);
        await _focusTaskAgentCard(tester, device: device);
        expect(
          find.text(_t('Latest assessment', 'Aktuelle Einschätzung')),
          findsOneWidget,
        );
        expect(
          find.text(
            _t('Recommended next step', 'Empfohlener nächster Schritt'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(messages.aiCardOpenAgentInternals),
          findsOneWidget,
        );
        expect(find.text(messages.aiCardShowLess), findsOneWidget);
        await captureScreenshot(
          tester,
          'task_agent_expanded_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport task agent suggestions — $theme', (tester) async {
        final captureDevice = device.isPhone ? proMaxDevice : device;
        await _pumpTaskSurface(
          tester,
          device: captureDevice,
          brightness: brightness,
          world: world,
          pageController: pageController,
          journalRepository: journalRepository,
          showAgentSuggestions: true,
          surface: TaskDetailsPage(
            taskId: world.orbitalHabitatTask.meta.id,
          ),
        );

        await _focusTaskAgentCard(tester, device: captureDevice);
        await _focusTaskAgentSuggestions(tester, device: captureDevice);
        final messages = AppLocalizations.of(
          tester.element(find.byType(TaskDetailsPage)),
        )!;
        expect(
          find.text(messages.changeSetCardTitle),
          findsOneWidget,
        );
        expect(find.text(messages.changeSetPendingCount(2)), findsOneWidget);
        // Both proposal rows are composed from the tool's arguments at render
        // time now, so the persisted English summaries on the fixture are no
        // longer what a reader sees.
        //
        // Match the item's title alone. The row drops the leading kind label
        // its chip already shows and re-adds it as `Add · `, so the localized
        // template never appears whole; and the quotation marks around the
        // title are locale-specific („…“ in German and Czech), which is what
        // made the previous ASCII-quoted literal an English-only assertion.
        expect(
          find.textContaining(_manualTaskAgentAddItemTitle),
          findsOneWidget,
        );
        expect(
          find.textContaining(messages.agentSummarySetEstimate(75)),
          findsOneWidget,
        );
        expect(find.text(messages.changeSetConfirmAll), findsOneWidget);
        await captureScreenshot(
          tester,
          'task_agent_suggestions_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport task agent manual updates — $theme', (
        tester,
      ) async {
        await _pumpTaskSurface(
          tester,
          device: device,
          brightness: brightness,
          world: world,
          pageController: pageController,
          journalRepository: journalRepository,
          automaticUpdates: false,
          surface: TaskDetailsPage(
            taskId: world.orbitalHabitatTask.meta.id,
          ),
        );

        await _focusTaskAgentCard(tester, device: device);
        final messages = AppLocalizations.of(
          tester.element(find.byType(TaskDetailsPage)),
        )!;
        // The automation row shows the short status word next to the stale
        // glyph; the long outdated sentence lives in the glyph's tooltip.
        expect(
          find.text(messages.taskAgentStatusOutOfDate),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('taskAgentStaleGlyph')),
          findsOneWidget,
        );
        // The automation row keeps the worded Update-now button on every
        // viewport; the icon-only phone variant no longer exists.
        expect(
          find.byKey(const ValueKey('taskAgentWakeButton')),
          findsOneWidget,
        );
        expect(find.text(messages.taskAgentUpdateNow), findsOneWidget);
        await captureScreenshot(
          tester,
          'task_agent_manual_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport task filters — $theme', (tester) async {
        await _pumpTaskSurface(
          tester,
          device: device,
          brightness: brightness,
          world: world,
          pageController: pageController,
          journalRepository: journalRepository,
          surface: const TasksRootPage(),
        );

        // The collapsing header keeps both states in the tree at once, so the
        // same filter icon exists twice: once in the expanded header a reader
        // sees, once in the compact bar behind `IgnorePointer`. Scope to the
        // expanded header and take no `.first` — an ambiguous finder here
        // silently tapped the unhittable copy instead of failing.
        await tester.tap(
          find.descendant(
            of: find.byType(TabSectionHeader),
            matching: find.byIcon(Icons.filter_list_rounded),
          ),
        );
        await settleFrames(tester, 6);
        final messages = AppLocalizations.of(
          tester.element(find.byType(TasksRootPage)),
        )!;
        expect(
          find.text(messages.tasksFilterTitle),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey('design-system-task-filter-priority-p1'),
          ),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'task_filters_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport task AI skills — $theme', (tester) async {
        final habitatImage = world.coverImages.firstWhere(
          (image) => image.id == manualHabitatCoverImageId,
        );
        await _pumpTaskSurface(
          tester,
          device: device,
          brightness: brightness,
          world: world,
          pageController: pageController,
          journalRepository: journalRepository,
          surface: Scaffold(
            body: SingleChildScrollView(
              child: EntryDetailsWidget(
                itemId: habitatImage.id,
                linkedFrom: world.orbitalHabitatTask,
                showAiEntry: true,
                showTaskDetails: true,
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.assistant_outlined));
        await settleFrames(tester, 6);
        final messages = AppLocalizations.of(
          tester.element(find.byType(EntryDetailsWidget)),
        )!;
        expect(find.text(messages.aiAssistantTitle), findsOneWidget);
        expect(find.text(messages.skillsSectionTitle), findsOneWidget);
        expect(
          find.text(_t('Inspect habitat photo', 'Habitatfoto prüfen')),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            _t(
              'Find pressure-gauge anomalies and task-relevant seal damage.',
              'Finde auffällige Druckanzeigen und relevante Schäden an Dichtungen.',
            ),
          ),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'ai_skills_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport task create menu — $theme', (tester) async {
        await _pumpTaskSurface(
          tester,
          device: device,
          brightness: brightness,
          world: world,
          pageController: pageController,
          journalRepository: journalRepository,
          surface: TaskDetailsPage(
            taskId: world.orbitalHabitatTask.meta.id,
          ),
        );

        final context = tester.element(find.byType(TaskDetailsPage));
        unawaited(
          CreateEntryModal.show(
            context: context,
            linkedFromId: world.orbitalHabitatTask.id,
            categoryId: manualDemoCategoryId,
          ),
        );
        await settleFrames(tester, 8);
        final messages = AppLocalizations.of(context)!;
        // findsWidgets, not findsOneWidget: on a wide bar the labeled Add
        // trigger says the same word as the sheet's title — deliberately.
        expect(find.text(messages.createEntryTitle), findsWidgets);
        expect(find.text(messages.taskFirstRunAddChecklist), findsOneWidget);
        expect(find.text(messages.taskFirstRunRecordAudio), findsOneWidget);
        // No Timer row on a task host: the bar's Track time pill is that
        // same action under its own name.
        expect(find.text(messages.addActionAddTimer), findsNothing);
        expect(find.text(messages.addActionCreateLinkedTask), findsOneWidget);
        await captureScreenshot(
          tester,
          'create_entry_task_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport task cover art — $theme', (tester) async {
        late WidgetRef parentRef;
        await _pumpTaskSurface(
          tester,
          device: device,
          brightness: brightness,
          world: world,
          pageController: pageController,
          journalRepository: journalRepository,
          surface: Consumer(
            builder: (context, ref, child) {
              parentRef = ref;
              return TaskDetailsPage(
                taskId: world.orbitalHabitatTask.meta.id,
              );
            },
          ),
        );

        final context = tester.element(find.byType(TaskDetailsPage));
        await primeManualDemoCoverArt(
          tester,
          documentsDirectory: getIt<Directory>(),
          world: world,
          extents: const [],
          imageIds: world.coverImages.take(5).map((image) => image.id).toSet(),
          includeRawFileImage: true,
        );
        unawaited(
          CoverArtSkillModal.show(
            context: context,
            entityId: world.orbitalHabitatTask.id,
            skillId: 'skill-waddle-cover-art',
            linkedTaskId: world.orbitalHabitatTask.id,
            ref: parentRef,
          ),
        );
        await settleFrames(tester, 10);
        final messages = AppLocalizations.of(
          tester.element(find.byType(TaskDetailsPage)),
        )!;
        expect(
          find.text(messages.referenceImageSelectionTitle),
          findsOneWidget,
        );
        final modalImages = find.descendant(
          of: find.byType(CoverArtSkillModal),
          matching: find.byType(Image),
        );
        final referenceGrid = find.descendant(
          of: find.byType(CoverArtSkillModal),
          matching: find.byType(GridView),
        );
        expect(modalImages, findsNWidgets(5));
        expect(referenceGrid, findsOneWidget);
        expect(tester.getSize(referenceGrid).height, greaterThan(200));
        await captureScreenshot(
          tester,
          'task_cover_references_${viewport}_$theme',
          subdir: 'manual',
        );

        await tester.tap(find.text(messages.referenceImageContinue));
        await settleFrames(tester, 8);
        await tester.pump(const Duration(milliseconds: 720));
        expect(
          find.text(messages.imageGenerationGenerating),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'task_cover_generating_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport task link picker — $theme', (tester) async {
        await _pumpTaskSurface(
          tester,
          device: device,
          brightness: brightness,
          world: world,
          pageController: pageController,
          journalRepository: journalRepository,
          surface: TaskDetailsPage(
            taskId: world.orbitalHabitatTask.meta.id,
          ),
        );

        final context = tester.element(find.byType(TaskDetailsPage));
        unawaited(
          LinkTaskModal.show(
            context: context,
            currentTaskId: world.orbitalHabitatTask.id,
            existingRelations: {
              ExistingRelation(
                taskId: world.fishFeederTask.id,
                relation: const DirectedRelation(EntryLinkType.basic),
              ),
            },
          ),
        );
        await settleFrames(tester, 30);
        final messages = AppLocalizations.of(
          tester.element(find.byType(TaskDetailsPage)),
        )!;
        // The modal's title dropped the trailing ellipsis: the action label
        // (linkExistingTask) stays on the trigger button underneath, while
        // the sheet itself is titled linkExistingTaskTitle.
        expect(
          find.text(messages.linkExistingTaskTitle),
          findsOneWidget,
        );
        expect(
          find.text(
            _t(
              'Confirm the interplanetary sardine cargo pods',
              'Interplanetare Sardinen-Frachtkapseln bestätigen',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _t(
              'Ask Legal whether a penguin is a passenger',
              'Rechtsabteilung fragen, ob ein Pinguin Passagier ist',
            ),
          ),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'task_link_picker_${viewport}_$theme',
          subdir: 'manual',
        );
      });
    }
  }
}

Future<void> _pumpTaskSurface(
  WidgetTester tester, {
  required ScreenshotDevice device,
  required Brightness brightness,
  required ManualDemoWorld world,
  required FakeJournalPageController pageController,
  required JournalRepository journalRepository,
  required Widget surface,
  bool automaticUpdates = true,
  bool showAgentSuggestions = false,
}) async {
  applyScreenshotDevice(tester, device);
  final tasksById = {
    for (final task in world.taskBrowseTasks) task.meta.id: task,
  };
  final taskAgentIdentity = _manualTaskAgentIdentity(
    automaticUpdates: automaticUpdates,
  );
  final taskAgentState = _manualTaskAgentState(
    automaticUpdates: automaticUpdates,
  );

  await withClock(Clock.fixed(manualDemoNow), () async {
    await primeManualDemoCoverArt(
      tester,
      documentsDirectory: getIt<Directory>(),
      world: world,
      extents: const [48, 96, 144, 216],
    );
    await primeManualDemoCoverArt(
      tester,
      documentsDirectory: getIt<Directory>(),
      world: world,
      extents: [
        (device.size.width * device.devicePixelRatio).round(),
        1280,
        2048,
        3072,
      ],
      imageIds: {manualHabitatCoverImageId},
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotBoundaryKey,
        child: ProviderScope(
          overrides: [
            journalRepositoryProvider.overrideWithValue(journalRepository),
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(
              true,
            ).overrideWith(() => pageController),
            taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(false),
            ),
            taskLiveDataProvider.overrideWith(
              (ref, taskId) async => tasksById[taskId],
            ),
            taskOneLinerProvider.overrideWith(
              (ref, taskId) async => switch (taskId) {
                final id when id == manualOrbitalHabitatTaskId => _t(
                  'Pressure stable · 37 penguins accounted for',
                  'Druck stabil · 37 Pinguine vollzählig',
                ),
                final id when id == manualFishFeederTaskId => _t(
                  'Feeder calibration blocks the habitat demo',
                  'Futterautomat-Kalibrierung blockiert die Habitat-Demo',
                ),
                final id when id == manualSardineCargoTaskId => _t(
                  'Europa cold-chain manifest ready to reconcile',
                  'Europa-Kühlkettenmanifest bereit zum Abgleich',
                ),
                _ => _t(
                  'Awaiting an answer from orbital transport counsel',
                  'Warte auf Antwort der orbitalen Transportrechtsberatung',
                ),
              },
            ),
            hasAvailableSkillsProvider((
              entityId: manualHabitatCoverImageId,
              linkedFromId: world.orbitalHabitatTask.id,
            )).overrideWith((ref) => Future.value(true)),
            availableSkillsForEntityProvider((
              entityId: manualHabitatCoverImageId,
              linkedFromId: world.orbitalHabitatTask.id,
            )).overrideWith(
              (ref) => Future.value([manualDemoAiSkills[1]]),
            ),
            agentUpdateStreamProvider.overrideWith(
              (ref, agentId) => const Stream<Set<String>>.empty(),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) async => taskId == manualOrbitalHabitatTaskId
                  ? taskAgentIdentity
                  : null,
            ),
            agentIdentityProvider.overrideWith(
              (ref, agentId) async =>
                  agentId == _manualTaskAgentId ? taskAgentIdentity : null,
            ),
            taskAgentResolvedSetupProvider.overrideWith(
              (ref, agentId) async => agentId == _manualTaskAgentId
                  ? _manualResolvedAgentSetup
                  : null,
            ),
            agentReportProvider.overrideWith(
              (ref, agentId) async =>
                  agentId == _manualTaskAgentId ? _manualAgentReport : null,
            ),
            templateForAgentProvider.overrideWith(
              (ref, agentId) async => agentId == _manualTaskAgentId
                  ? _manualTaskAgentTemplate
                  : null,
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
            agentStateProvider.overrideWith(
              (ref, agentId) async =>
                  agentId == _manualTaskAgentId ? taskAgentState : null,
            ),
            unifiedSuggestionListProvider.overrideWith(
              (ref, taskId) async => UnifiedSuggestionList(
                open: showAgentSuggestions
                    ? _manualTaskAgentSuggestions()
                    : const [],
                activity: const [],
                agentName: _manualTaskAgentName,
              ),
            ),
            triggerSkillProvider((
              entityId: world.orbitalHabitatTask.id,
              skillId: 'skill-waddle-cover-art',
              linkedTaskId: world.orbitalHabitatTask.id,
              referenceImages: null,
              overrideModelId: null,
              geminiThinkingMode: null,
            )).overrideWith((ref) async {}),
            inferenceStatusControllerProvider((
              id: world.orbitalHabitatTask.id,
              aiResponseType: AiResponseType.imageGeneration,
            )).overrideWith(_ManualRunningInferenceController.new),
            // The habitat task's below-card list: one time record, resolved
            // from memory rather than through the Drift link graph.
            linkedEntriesControllerProvider(
              manualOrbitalHabitatTaskId,
            ).overrideWith(
              () => _ManualLinkedEntriesController(<EntryLink>[
                EntryLink.basic(
                  id: 'link-habitat-time-record',
                  fromId: manualOrbitalHabitatTaskId,
                  toId: world.habitatTimeRecord.meta.id,
                  createdAt: world.habitatTimeRecord.meta.createdAt,
                  updatedAt: world.habitatTimeRecord.meta.updatedAt,
                  vectorClock: null,
                ),
              ]),
            ),
            createEntryControllerOverride(world.habitatTimeRecord),
            for (final coverImage in world.coverImages)
              createEntryControllerOverride(coverImage),
            for (final task in world.taskBrowseTasks)
              createEntryControllerOverride(task),
            ...hTaskDetailsPageOverrides(),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: brightness == Brightness.dark
                ? DesignSystemTheme.dark()
                : DesignSystemTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: manualScreenshotLocale,
            home: surface,
          ),
        ),
      ),
    );
    await settleFrames(tester, 8);
  });
}

/// Scrolls the task detail pane so the task form sits just below a slim band
/// of cover art, leaving the record — title, chips, notes, checklist, logged
/// time — as the subject of the frame.
Future<void> _focusTaskDetailBody(WidgetTester tester) async {
  const coverBand = 70.0;
  final scrollable = find
      .descendant(
        of: find.byType(TaskDetailsPage),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  final targetTop = tester.getTopLeft(find.byType(TaskForm)).dy;
  position.jumpTo(
    (position.pixels + targetTop - coverBand).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    ),
  );
  await settleFrames(tester, 4);
}

/// Fails when [finder]'s widget is laid out outside the captured viewport.
///
/// `find.text` matches widgets that are in the tree but scrolled far off
/// screen, which is exactly how the desktop task-detail capture silently
/// became a full-bleed cover art shot while its assertions stayed green.
void _expectVisible(
  WidgetTester tester,
  ScreenshotDevice device,
  Finder finder,
) {
  final viewport = Offset.zero & device.size;
  final rect = tester.getRect(finder);
  expect(
    rect.overlaps(viewport),
    isTrue,
    reason:
        'Expected ${finder.describeMatch(Plurality.one)} to be visible '
        'within $viewport, '
        'but it is laid out at $rect.',
  );
}

Future<void> _focusTaskAgentCard(
  WidgetTester tester, {
  required ScreenshotDevice device,
}) async {
  final messages = AppLocalizations.of(
    tester.element(find.byType(TaskDetailsPage)),
  )!;
  final summary = find.text(messages.aiCardTitle);
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(
    summary,
    420,
    scrollable: scrollable,
  );
  await settleFrames(tester, 6);

  final position = tester.state<ScrollableState>(scrollable).position;
  final targetTop = tester.getTopLeft(summary).dy;
  final desiredTop = device.isPhone ? 112.0 : 24.0;
  position.jumpTo(
    (position.pixels + targetTop - desiredTop).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    ),
  );
  await settleFrames(tester, 4);
}

Future<void> _focusTaskAgentSuggestions(
  WidgetTester tester, {
  required ScreenshotDevice device,
}) async {
  final messages = AppLocalizations.of(
    tester.element(find.byType(TaskDetailsPage)),
  )!;
  final proposals = find.text(messages.changeSetCardTitle);
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(
    proposals,
    320,
    scrollable: scrollable,
  );
  await settleFrames(tester, 4);

  final position = tester.state<ScrollableState>(scrollable).position;
  final targetTop = tester.getTopLeft(proposals).dy;
  final desiredTop = device.isPhone ? 560.0 : 740.0;
  position.jumpTo(
    (position.pixels + targetTop - desiredTop).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    ),
  );
  await settleFrames(tester, 4);
}
