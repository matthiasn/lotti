/// Deterministic manual screenshots for the production Projects surfaces.
///
/// The fixtures extend the shared Intergalactic Penguin Logistics world with
/// several distinct projects, real project health/report data, and linked
/// tasks. Captures render [ProjectsTabPage], [ProjectDetailsPage], and the
/// production filter/create modals directly; no Widgetbook or showcase host is
/// involved.
///
/// Opt in with an external output directory:
/// `LOTTI_SCREENSHOT_DIR=/tmp/projects fvm flutter test \
///   test/features/projects/ui/pages/projects_manual_screenshots_test.dart`
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/features/projects/state/project_detail_record_provider.dart';
import 'package:lotti/features/projects/state/project_one_liner_provider.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/pages/project_detail_page.dart';
import 'package:lotti/features/projects/ui/pages/project_details_page.dart';
import 'package:lotti/features/projects/ui/pages/projects_tab_page.dart';
import 'package:lotti/features/projects/ui/widgets/project_create_modal.dart';
import 'package:lotti/features/projects/ui/widgets/project_mobile_detail_content.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/form/lotti_text_field.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/manual_demo_world.dart';
import '../../../../helpers/target_platform.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';
import '../../../daily_os_next/screenshot_harness.dart';
import '../../test_utils.dart';

const _subdir = 'projects';
const _projectWaddleId = 'project-waddle';
String _t(String en, String de) => manualScreenshotText(en: en, de: de);

class _ManualProjectDetailController extends ProjectDetailController {
  _ManualProjectDetailController(this._record) : super(_record.project.meta.id);

  final ProjectRecord _record;

  @override
  ProjectDetailState build() => ProjectDetailState(
    project: _record.project,
    linkedTasks: _record.highlightedTaskSummaries
        .map((summary) => summary.task)
        .toList(growable: false),
    isLoading: false,
    isSaving: false,
    hasChanges: false,
  );

  @override
  void updateTitle(String title) {}

  @override
  void updateTargetDate(DateTime? targetDate) {}

  @override
  void updateCategoryId(String? categoryId) {}

  @override
  void updateStatus(ProjectStatus newStatus) {}

  @override
  Future<void> saveChanges() async {}
}

Widget _app({
  required Widget home,
  required Brightness brightness,
  required ScreenshotDevice device,
  required List<Override> overrides,
  required TargetPlatform platform,
}) {
  return RepaintBoundary(
    key: screenshotBoundaryKey,
    child: ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(size: device.size),
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
          home: AppCommandHost(
            handlers: const {},
            platform: platform,
            child: home,
          ),
        ),
      ),
    ),
  );
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'projects manual screenshot harness (opt-in)',
      () {},
      skip: 'Set LOTTI_SCREENSHOT_DIR to capture manual screenshots.',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  late ManualDemoWorld world;
  late List<CategoryDefinition> categories;
  late List<ProjectRecord> records;
  late List<ProjectCategoryGroup> groups;
  late ValueNotifier<String?> selectedProjectId;

  setUp(() async {
    world = ManualDemoWorld.penguinLogistics();
    final missionControl = CategoryTestUtils.createTestCategory(
      id: 'manual-mission-control',
      name: _t('Mission Control', 'Missionskontrolle'),
      color: '#6750A4',
    );
    final fishDiplomacy = CategoryTestUtils.createTestCategory(
      id: 'manual-fish-diplomacy',
      name: _t('Fish Diplomacy', 'Fischdiplomatie'),
      color: '#FBA337',
    );
    final humanMaintenance = CategoryTestUtils.createTestCategory(
      id: 'manual-human-maintenance',
      name: _t('Human Maintenance', 'Menschenwartung'),
      color: '#3CB371',
    );
    categories = [
      world.category,
      missionControl,
      fishDiplomacy,
      humanMaintenance,
    ];

    ProjectEntry project({
      required String id,
      required String title,
      required ProjectStatus status,
      required CategoryDefinition category,
      required DateTime targetDate,
    }) => makeTestProject(
      id: id,
      title: title,
      status: status,
      categoryId: category.id,
      targetDate: targetDate,
      createdAt: DateTime(2026, 7),
    );

    final projectWaddle = project(
      id: _projectWaddleId,
      title: 'Project Waddle',
      status: ProjectStatus.active(
        id: 'project-waddle-active',
        createdAt: DateTime(2026, 7, 2),
        utcOffset: 120,
      ),
      category: world.category,
      targetDate: DateTime(2026, 8),
    );
    final coldChain = project(
      id: 'europa-sardine-cold-chain',
      title: _t('Europa sardine cold chain', 'Europa-Sardinenkühlkette'),
      status: ProjectStatus.monitoring(
        id: 'cold-chain-monitoring',
        createdAt: DateTime(2026, 7, 3),
        utcOffset: 120,
      ),
      category: missionControl,
      targetDate: DateTime(2026, 8, 14),
    );
    final passengerTreaty = project(
      id: 'penguin-passenger-treaty',
      title: _t('Penguin passenger treaty', 'Pinguin-Passagiervertrag'),
      status: ProjectStatus.open(
        id: 'passenger-treaty-open',
        createdAt: DateTime(2026, 7, 4),
        utcOffset: 120,
      ),
      category: fishDiplomacy,
      targetDate: DateTime(2026, 9, 3),
    );
    final iceGarden = project(
      id: 'orbital-ice-garden',
      title: _t(
        'Orbital ice-garden wellness program',
        'Wellnessprogramm im orbitalen Eisgarten',
      ),
      status: ProjectStatus.completed(
        id: 'ice-garden-completed',
        createdAt: DateTime(2026, 7, 5),
        utcOffset: 120,
      ),
      category: humanMaintenance,
      targetDate: DateTime(2026, 7, 12),
    );

    records = [
      makeTestProjectRecord(
        project: projectWaddle,
        category: world.category,
        healthScore: 82,
        healthMetrics: makeTestProjectHealthMetrics(
          rationale: _t(
            'Habitat telemetry is stable; the zero-gravity feeder remains '
                'the only launch blocker.',
            'Die Habitattelemetrie ist stabil; der Schwerelos-Futterautomat '
                'bleibt der einzige Startblocker.',
          ),
          confidence: 0.91,
        ),
        completedTaskCount: 5,
        totalTaskCount: 8,
        aiSummary: _t(
          'Project Waddle is on track for the orbital habitat demo. Clear '
              'the fish-feeder blocker before the emperor penguin roll call.',
          'Project Waddle liegt für die Demo des Orbital-Habitats im Plan. '
              'Löse den Futterautomaten-Blocker vor dem Zählappell der '
              'Kaiserpinguine.',
        ),
        reportContent: _t(
          'Pressure seals and cargo routing are green. Mission Control is '
              'waiting on the final feeder calibration and passenger manifest.',
          'Druckdichtungen und Frachtrouting sind grün. Die Missionskontrolle '
              'wartet auf die finale Futterautomaten-Kalibrierung und die '
              'Passagierliste.',
        ),
        reportUpdatedAt: manualDemoNow.subtract(const Duration(hours: 2)),
        recommendations: [
          _t(
            'Recalibrate the zero-gravity fish feeder.',
            'Schwerelos-Futterautomaten neu kalibrieren.',
          ),
          _t(
            'Confirm the interplanetary sardine cargo pods.',
            'Interplanetare Sardinen-Frachtkapseln bestätigen.',
          ),
        ],
        highlightedTaskSummaries: [
          makeTestTaskSummary(
            task: world.orbitalHabitatTask,
            oneLiner: _t(
              'Pressure stable · 37 penguins accounted for',
              'Druck stabil · 37 Pinguine vollzählig',
            ),
          ),
          makeTestTaskSummary(
            task: world.fishFeederTask,
            estimatedDuration: const Duration(hours: 1, minutes: 30),
            oneLiner: _t(
              'The feeder still launches lunch toward Mission Control',
              'Der Automat schleudert das Mittagessen noch zur Missionskontrolle',
            ),
          ),
          makeTestTaskSummary(
            task: world.sardineCargoTask,
            estimatedDuration: const Duration(minutes: 45),
            oneLiner: _t(
              'Europa cold-chain manifest ready to reconcile',
              'Europa-Kühlkettenmanifest bereit zum Abgleich',
            ),
          ),
        ],
        highlightedTasksTotalDuration: const Duration(hours: 4, minutes: 15),
      ),
      makeTestProjectRecord(
        project: coldChain,
        category: missionControl,
        healthScore: 74,
        totalTaskCount: 6,
        blockedTaskCount: 0,
        aiSummary: _t(
          'Cargo temperatures are holding across the Europa relay.',
          'Die Frachttemperaturen bleiben entlang des Europa-Relais stabil.',
        ),
      ),
      makeTestProjectRecord(
        project: passengerTreaty,
        category: fishDiplomacy,
        healthScore: 61,
        completedTaskCount: 1,
        totalTaskCount: 4,
        aiSummary: _t(
          'Legal still has not decided whether Sir Flaps-a-Lot is cargo.',
          'Die Rechtsabteilung hat noch nicht entschieden, ob Sir Flaps-a-Lot '
              'als Fracht gilt.',
        ),
      ),
      makeTestProjectRecord(
        project: iceGarden,
        category: humanMaintenance,
        healthScore: 100,
        completedTaskCount: 5,
        blockedTaskCount: 0,
        aiSummary: _t(
          'The quiet-lap experiment completed without a headset.',
          'Das Experiment mit der stillen Runde endete ohne Headset.',
        ),
      ),
    ];
    groups = ProjectListData(
      categories: categories,
      projects: records,
      currentTime: manualDemoNow,
    ).overviewSnapshot.groups;

    selectedProjectId = ValueNotifier<String?>(null);
    final navService = MockNavService();
    final userActivityService = MockUserActivityService();
    final entitiesCache = MockEntitiesCacheService();

    when(userActivityService.updateActivity).thenReturn(null);
    when(() => navService.desktopSelectedProjectId).thenReturn(
      selectedProjectId,
    );
    when(() => navService.isDesktopMode).thenReturn(false);
    when(
      () => navService.beamToNamed(any(), data: any(named: 'data')),
    ).thenReturn(null);
    when(() => entitiesCache.sortedCategories).thenReturn(categories);
    when(() => entitiesCache.showPrivateEntries).thenReturn(true);
    when(() => entitiesCache.getCategoryById(any())).thenAnswer(
      (invocation) {
        final id = invocation.positionalArguments.first as String?;
        return categories.where((category) => category.id == id).firstOrNull;
      },
    );

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<NavService>(navService)
          ..registerSingleton<UserActivityService>(userActivityService)
          ..registerSingleton<EntitiesCacheService>(entitiesCache);
      },
    );
  });

  tearDown(() async {
    selectedProjectId.dispose();
    await tearDownTestGetIt();
  });

  List<Override> overrides() => [
    projectsOverviewProvider.overrideWith(
      (ref) => Stream.value(ProjectsOverviewSnapshot(groups: groups)),
    ),
    visibleProjectGroupsProvider.overrideWith(
      (ref) => AsyncValue.data(groups),
    ),
    for (final record in records) ...[
      projectDetailControllerProvider(record.project.meta.id).overrideWith(
        () => _ManualProjectDetailController(record),
      ),
      projectHealthMetricsProvider(record.project.meta.id).overrideWith(
        (ref) async => record.healthMetrics,
      ),
      projectDetailRecordProvider(record.project.meta.id).overrideWith(
        (ref) async => record,
      ),
      projectAgentProvider(record.project.meta.id).overrideWith(
        (ref) async => null,
      ),
      projectOneLinerProvider(record.project.meta.id).overrideWith(
        (ref) async => switch (record.project.meta.id) {
          _projectWaddleId => _t(
            'Orbital launch readiness and habitat safety',
            'Orbitale Startbereitschaft und Habitatsicherheit',
          ),
          'europa-sardine-cold-chain' => _t(
            'Keep every cargo pod below the emergency fish ceiling',
            'Jede Frachtkapsel unter der Fisch-Notfallgrenze halten',
          ),
          'penguin-passenger-treaty' => _t(
            'Settle the passenger-versus-cargo question before launch',
            'Passagier-oder-Fracht-Frage vor dem Start klären',
          ),
          _ => _t(
            'One quiet lap around the orbital ice garden',
            'Eine stille Runde durch den orbitalen Eisgarten',
          ),
        },
      ),
    ],
    projectDetailNowProvider.overrideWithValue(() => manualDemoNow),
    agentIsRunningProvider.overrideWith(
      (ref, agentId) => const Stream<bool>.empty(),
    ),
  ];

  Future<void> pumpSurface(
    WidgetTester tester, {
    required ScreenshotDevice device,
    required Brightness brightness,
    required Widget mobile,
    required Widget desktop,
    String? selectedId,
  }) async {
    applyScreenshotDevice(tester, device);
    selectedProjectId.value = selectedId;
    final platform = device.isPhone
        ? TargetPlatform.android
        : TargetPlatform.linux;
    await withTargetPlatform(platform, () async {
      await withClock(Clock.fixed(manualDemoNow), () async {
        await tester.pumpWidget(
          _app(
            home: device.isPhone ? mobile : desktop,
            brightness: brightness,
            device: device,
            overrides: overrides(),
            platform: platform,
          ),
        );
        await settleFrames(tester, 10);
      });
    });
  }

  for (final device in [proDevice, desktopDevice]) {
    final viewport = device.isPhone ? 'mobile' : 'desktop';
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;

      testWidgets('$viewport project list — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          mobile: const ProjectsTabPage(),
          desktop: const ProjectsTabPage(),
        );
        expect(find.text('Project Waddle'), findsOneWidget);
        expect(
          find.text(
            _t('Europa sardine cold chain', 'Europa-Sardinenkühlkette'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(_t('Penguin Operations', 'Pinguinbetrieb')),
          findsWidgets,
        );
        await captureScreenshot(
          tester,
          'projects_list_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport project detail — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          mobile: const ProjectDetailsPage(projectId: _projectWaddleId),
          desktop: const ProjectsTabPage(),
          selectedId: _projectWaddleId,
        );
        expect(find.text('Project Waddle'), findsWidgets);
        expect(find.text('82'), findsOneWidget);
        expect(
          find.textContaining(
            _t(
              'Project Waddle is on track',
              'Project Waddle liegt',
            ),
          ),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'projects_detail_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport project tasks — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          mobile: const ProjectDetailsPage(projectId: _projectWaddleId),
          desktop: const ProjectsTabPage(),
          selectedId: _projectWaddleId,
        );
        final details = find.byType(ProjectMobileDetailContent);
        final detailScrollable = find.descendant(
          of: details,
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text(
            _t(
              'Inspect orbital penguin habitat',
              'Pinguin-Habitat im Orbit inspizieren',
            ),
          ),
          320,
          scrollable: detailScrollable.first,
        );
        await settleFrames(tester, 4);
        expect(
          find.text(
            _t(
              'Inspect orbital penguin habitat',
              'Pinguin-Habitat im Orbit inspizieren',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _t(
              'Recalibrate the zero-gravity fish feeder',
              'Schwerelosen Fischfütterer neu kalibrieren',
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
        await captureScreenshot(
          tester,
          'projects_tasks_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport project filters — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          mobile: const ProjectsTabPage(),
          desktop: const ProjectsTabPage(),
        );
        await tester.tap(find.byIcon(Icons.filter_list_rounded));
        await settleFrames(tester, 6);
        expect(
          find.text(_t('Filter projects', 'Projekte filtern')),
          findsOneWidget,
        );
        expect(find.text('Status'), findsOneWidget);
        expect(find.text(_t('Category', 'Kategorie')), findsOneWidget);
        await captureScreenshot(
          tester,
          'projects_filters_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport project create — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          mobile: const ProjectsTabPage(),
          desktop: const ProjectsTabPage(),
        );
        final context = tester.element(find.byType(ProjectsTabPage));
        unawaited(
          showProjectCreateModal(
            context: context,
            categoryId: manualDemoCategoryId,
          ),
        );
        await settleFrames(tester, 6);
        expect(find.byType(ProjectCreateForm), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byType(LottiTextField),
            matching: find.byType(TextField),
          ),
          _t(
            'Establish the lunar sardine reserve',
            'Lunare Sardinenreserve einrichten',
          ),
        );
        await settleFrames(tester, 2);
        expect(
          find.text(_t('Penguin Operations', 'Pinguinbetrieb')),
          findsWidgets,
        );
        expect(
          find.text(
            _t(
              'Establish the lunar sardine reserve',
              'Lunare Sardinenreserve einrichten',
            ),
          ),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'projects_create_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport project settings editor — $theme', (
        tester,
      ) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          mobile: const ProjectDetailPage(projectId: _projectWaddleId),
          desktop: const ProjectDetailPage(projectId: _projectWaddleId),
        );
        expect(
          find.text(_t('Project Details', 'Projektdetails')),
          findsOneWidget,
        );
        expect(find.text(_t('Change status', 'Status ändern')), findsOneWidget);
        expect(find.text('Project Waddle'), findsOneWidget);
        expect(find.text(_t('Target Date', 'Zieldatum')), findsOneWidget);
        expect(
          find.text(_t('Project health', 'Projektgesundheit')),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'projects_editor_${viewport}_$theme',
          subdir: _subdir,
        );
      });
    }
  }
}
