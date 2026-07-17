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
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_modal.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_task_modal.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_root_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
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

const _manualTaskAgentId = 'agent-habitat-watcher';
const _manualTaskAgentStateId = 'state-habitat-watcher';
String _t(String en, String de) => manualScreenshotText(en: en, de: de);

final String _manualTaskAgentName = _t('Habitat Watcher', 'Habitatwächter');
final String _manualTaskAgentTldr = _t(
  'All 37 emperor penguins are accounted for. Habitat pressure held at '
      '101.3 kPa overnight; the remaining launch risk is the zero-gravity '
      'sardine feeder calibration.',
  'Alle 37 Kaiserpinguine sind vollzählig. Der Habitatdruck blieb über Nacht '
      'bei 101,3 kPa; als einziges Startrisiko bleibt die Kalibrierung des '
      'Schwerelos-Futterautomaten.',
);
final String _manualTaskAgentReport = _t(
  '''
## Latest assessment

- Pressure seals A–F stayed stable across the night shift.
- 840 sardines are loaded; feeder calibration still blocks sign-off.
- Mission Control clearance is due before the 06:30 roll call.

## Recommended next step

Run the feeder test, attach the telemetry image, then request launch approval.
''',
  '''
## Aktuelle Einschätzung

- Die Druckdichtungen A–F blieben während der Nachtschicht stabil.
- 840 Sardinen sind geladen; die Futterautomat-Kalibrierung verhindert noch die Freigabe.
- Die Freigabe der Missionskontrolle muss vor dem Zählappell um 06:30 Uhr vorliegen.

## Empfohlener nächster Schritt

Führe den Automatentest aus, hänge das Telemetriebild an und fordere dann die Startfreigabe an.
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
  routeFingerprint: InferenceRouteFingerprint.fromProfile(
    _manualResolvedProfile,
  ),
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
        args: {
          'title': _t(
            'Run zero-gravity sardine feeder test',
            'Schwerelos-Futterautomaten testen',
          ),
        },
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
    final installedMedia = await world.installMedia(testDocumentsDirectory);
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
    when(
      () => mocks.journalDb.getBulkLinkedTimeSpans(any()),
    ).thenAnswer((_) async => <String, List<LinkedEntityTimeSpan>>{});
    when(
      () => mocks.journalDb.getLinkedEntities(any()),
    ).thenAnswer((_) async => <JournalEntity>[]);
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
        await _pumpTaskSurface(
          tester,
          device: device,
          brightness: brightness,
          world: world,
          pageController: pageController,
          journalRepository: journalRepository,
          surface: TaskDetailsPage(taskId: world.orbitalHabitatTask.meta.id),
        );

        expect(find.byType(TaskDetailsPage), findsOneWidget);
        expect(
          find.text(
            _t(
              'Inspect orbital penguin habitat',
              'Pinguin-Habitat im Orbit inspizieren',
            ),
          ),
          findsWidgets,
        );
        expect(find.text(_manualTaskAgentName), findsOneWidget);
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
        expect(
          find.text(_t('AI summary', 'KI-Zusammenfassung')),
          findsOneWidget,
        );
        expect(find.text(_manualTaskAgentName), findsOneWidget);
        expect(find.text(_manualTaskAgentTldr), findsOneWidget);
        expect(
          find.text(_t('Automatic updates', 'Automatische Updates')),
          findsOneWidget,
        );
        expect(
          find.text(
            _t(
              'Bundle task changes and update after two minutes.',
              'Aufgabenänderungen werden gebündelt und nach zwei Minuten '
                  'aktualisiert.',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(_t('Waddle Command 70B', 'Watschelkommando 70B')),
          findsOneWidget,
        );
        expect(find.text(_t('Read more', 'Mehr lesen')), findsOneWidget);
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
          find.text(_t('Open agent internals', 'Agent-Internes öffnen')),
          findsOneWidget,
        );
        expect(find.text(_t('Show less', 'Weniger anzeigen')), findsOneWidget);
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
        expect(
          find.text(_t('Proposed changes', 'Vorgeschlagene Änderungen')),
          findsOneWidget,
        );
        expect(find.text(_t('2 pending', '2 ausstehend')), findsOneWidget);
        expect(
          find.text(
            _t(
              '"Run zero-gravity sardine feeder test"',
              '"Schwerelos-Futterautomaten testen"',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(_t('45m → 1h 15m', '45 Min. → 1 Std. 15 Min.')),
          findsOneWidget,
        );
        expect(find.text(_t('Confirm all', 'Alle bestätigen')), findsOneWidget);
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
        expect(
          find.text(
            _t(
              'Automatic updates are off. Wake the agent when you want a fresh '
                  'report.',
              'Automatische Updates sind aus. Wecke den Agenten, wenn du einen '
                  'aktuellen Bericht möchtest.',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _t(
              'This summary is out of date',
              'Diese Zusammenfassung ist veraltet',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _t(
              'The task changed after this summary was generated.',
              'Die Aufgabe hat sich geändert, nachdem diese Zusammenfassung '
                  'erstellt wurde.',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(_t('Wake agent', 'Agenten aufwecken')),
          findsOneWidget,
        );
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

        await tester.tap(find.byIcon(Icons.filter_list_rounded).first);
        await settleFrames(tester, 6);
        expect(
          find.text(_t('Filter tasks', 'Aufgaben filtern')),
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
        expect(find.text(_t('Generate…', 'Generieren…')), findsOneWidget);
        expect(find.text(_t('Skills', 'Skills')), findsOneWidget);
        expect(
          find.text(_t('Inspect habitat photo', 'Habitatfoto prüfen')),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            _t('pressure-gauge anomalies', 'auffällige Druckanzeigen'),
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
        expect(find.text(_t('Add', 'Hinzufügen')), findsOneWidget);
        expect(find.text(_t('Checklist', 'Checkliste')), findsOneWidget);
        expect(
          find.text(_t('Audio Recording', 'Audioaufnahme')),
          findsOneWidget,
        );
        expect(find.text(_t('Timer', 'Timer')), findsOneWidget);
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
        expect(
          find.text(
            _t('Select Reference Images', 'Referenzbilder auswählen'),
          ),
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

        await tester.tap(find.text(_t('Continue', 'Weiter')));
        await settleFrames(tester, 8);
        await tester.pump(const Duration(milliseconds: 720));
        expect(
          find.text(_t('Generating image...', 'Bild wird generiert...')),
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
            existingLinkedIds: {world.fishFeederTask.id},
          ),
        );
        await settleFrames(tester, 30);
        expect(
          find.text(
            _t(
              'Link existing task...',
              'Vorhandene Aufgabe verknüpfen...',
            ),
          ),
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
      imageIds: const {manualHabitatCoverImageId},
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
                manualOrbitalHabitatTaskId => _t(
                  'Pressure stable · 37 penguins accounted for',
                  'Druck stabil · 37 Pinguine vollzählig',
                ),
                manualFishFeederTaskId => _t(
                  'Feeder calibration blocks the habitat demo',
                  'Futterautomat-Kalibrierung blockiert die Habitat-Demo',
                ),
                manualSardineCargoTaskId => _t(
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

Future<void> _focusTaskAgentCard(
  WidgetTester tester, {
  required ScreenshotDevice device,
}) async {
  final summary = find.text(_t('AI summary', 'KI-Zusammenfassung'));
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
  final proposals = find.text(
    _t('Proposed changes', 'Vorgeschlagene Änderungen'),
  );
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
