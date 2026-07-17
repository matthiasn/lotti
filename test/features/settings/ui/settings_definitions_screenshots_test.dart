/// Screenshot harness for the revamped settings definition pages —
/// categories, labels, habits, measurables, and dashboards on the shared
/// `DefinitionsListPage` / `SettingsDetailScaffold` kit (list, edit, and
/// create surfaces, plus the empty and scrolled-behind-glass states).
///
/// Renders a coherent Intergalactic Penguin Logistics workspace: mission
/// categories, operational labels, expedition habits, habitat metrics, and
/// colony dashboards. PNGs land in
/// `screenshots/settings_definitions/` (gitignored) for design review.
/// Not a golden test — assertions only guard that each scenario renders.
///
/// Opt-in (real-font loading leaks process-wide — see the harness). Run:
/// `LOTTI_SCREENSHOT_DIR=/tmp/settings_shots fvm flutter test \
///   test/features/settings/ui/settings_definitions_screenshots_test.dart`
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/category_task_count_provider.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/categories/ui/pages/category_details_page.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/pages/label_details_page.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_details_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habits_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/manual_demo_world.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';
import '../../daily_os_next/screenshot_harness.dart';
import '../../labels/test_utils.dart';

const String _subdir = 'settings_definitions';

final DateTime _created = manualDemoNow;

// ---------------------------------------------------------------------------
// Story data — Intergalactic Penguin Logistics.
// ---------------------------------------------------------------------------

const _missionControlCategoryId = 'manual-mission-control';
const _fishDiplomacyCategoryId = 'manual-fish-diplomacy';
const _humanMaintenanceCategoryId = 'manual-human-maintenance';
const _awaitingMissionControlLabelId = 'manual-awaiting-mission-control';
const _sardineMarketLabelId = 'manual-sardine-market';

final CategoryDefinition _penguinOperations =
    CategoryTestUtils.createTestCategory(
      id: manualDemoCategoryId,
      name: 'Penguin Operations',
      color: '#8B5CF6',
      icon: CategoryIcon.airplane,
      favorite: true,
      isAvailableForDayPlan: true,
      defaultLanguageCode: 'en',
      speechDictionary: [
        'Project Waddle',
        'Sir Flaps-a-Lot',
        'sardine',
        'Europa',
      ],
      correctionExamples: [
        ChecklistCorrectionExample(
          before: 'sir flaps a lot',
          after: 'Sir Flaps-a-Lot',
          capturedAt: manualDemoNow.subtract(const Duration(days: 3)),
        ),
        ChecklistCorrectionExample(
          before: 'project waddle habitat',
          after: 'Project Waddle habitat',
          capturedAt: manualDemoNow.subtract(const Duration(days: 1)),
        ),
      ],
    );
final CategoryDefinition _missionControl = CategoryTestUtils.createTestCategory(
  id: _missionControlCategoryId,
  name: 'Mission Control',
  color: '#4F9DDE',
  icon: CategoryIcon.connectivity,
  isAvailableForDayPlan: true,
  private: true,
);
final CategoryDefinition _fishDiplomacy = CategoryTestUtils.createTestCategory(
  id: _fishDiplomacyCategoryId,
  name: 'Fish Diplomacy',
  color: '#E8A33D',
  icon: CategoryIcon.meeting,
);
final CategoryDefinition _humanMaintenance =
    CategoryTestUtils.createTestCategory(
      id: _humanMaintenanceCategoryId,
      name: 'Human Maintenance',
      color: '#34D399',
      icon: CategoryIcon.fitness,
      active: false,
    );

final List<CategoryDefinition> _allCategories = [
  _penguinOperations,
  _missionControl,
  _fishDiplomacy,
  _humanMaintenance,
];

const Map<String, int> _taskCounts = {
  manualDemoCategoryId: 37,
  _missionControlCategoryId: 12,
  _fishDiplomacyCategoryId: 8,
  _humanMaintenanceCategoryId: 4,
};

final LabelDefinition _projectWaddle = LabelTestUtils.createTestLabel(
  id: manualDemoProjectLabelId,
  name: 'Project Waddle',
  color: '#1F9CF5',
  description:
      'Launch-critical work for the first interplanetary penguin habitat.',
  applicableCategoryIds: [
    manualDemoCategoryId,
    _missionControlCategoryId,
    _fishDiplomacyCategoryId,
  ],
);
final LabelDefinition _habitatCritical = LabelTestUtils.createTestLabel(
  id: manualDemoCriticalLabelId,
  name: 'Habitat critical',
  color: '#FBA337',
  description:
      'Must be resolved before emperor penguins enter the orbital habitat.',
  applicableCategoryIds: [manualDemoCategoryId, _missionControlCategoryId],
);
final LabelDefinition _awaitingMissionControl = LabelTestUtils.createTestLabel(
  id: _awaitingMissionControlLabelId,
  name: 'Awaiting Mission Control',
  color: '#8B5CF6',
  description: 'Blocked until the lunar shift sends clearance.',
  applicableCategoryIds: [manualDemoCategoryId, _missionControlCategoryId],
);
final LabelDefinition _sardineMarket = LabelTestUtils.createTestLabel(
  id: _sardineMarketLabelId,
  name: 'Sardine market sensitive',
  color: '#34D399',
  description: 'Private negotiations with the Europa fish exchange.',
  private: true,
  applicableCategoryIds: [_fishDiplomacyCategoryId],
);

final List<LabelDefinition> _allLabels = [
  _projectWaddle,
  _habitatCritical,
  _awaitingMissionControl,
  _sardineMarket,
];

const Map<String, int> _labelUsage = {
  manualDemoProjectLabelId: 14,
  manualDemoCriticalLabelId: 6,
  _awaitingMissionControlLabelId: 5,
  _sardineMarketLabelId: 3,
};

HabitDefinition _habit({
  required String id,
  required String name,
  required String description,
  String? categoryId,
  bool priority = false,
  bool private = false,
  bool active = true,
}) => HabitDefinition(
  id: id,
  name: name,
  description: description,
  createdAt: _created,
  updatedAt: _created,
  vectorClock: null,
  habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  active: active,
  private: private,
  priority: priority,
  categoryId: categoryId,
);

final HabitDefinition _rollCall = _habit(
  id: 'habit-emperor-roll-call',
  name: 'Emperor penguin roll call',
  description: 'Account for all 37 expedition penguins before launch.',
  categoryId: manualDemoCategoryId,
  priority: true,
);
final HabitDefinition _habitatSealWalk = _habit(
  id: 'habit-habitat-seals',
  name: 'Walk the habitat seals',
  description: 'Inspect every pressure seal after the artificial sunrise.',
  categoryId: manualDemoCategoryId,
  private: true,
);
final HabitDefinition _sardineForecast = _habit(
  id: 'habit-sardine-forecast',
  name: 'Review sardine forecast',
  description: 'Paused while the Europa exchange recalibrates its fish index.',
  categoryId: _fishDiplomacyCategoryId,
  active: false,
);

final List<HabitDefinition> _allHabits = [
  _rollCall,
  _habitatSealWalk,
  _sardineForecast,
];

MeasurableDataType _measurable({
  required String id,
  required String displayName,
  required String unitName,
  String description = '',
  AggregationType aggregationType = AggregationType.dailySum,
  bool favorite = false,
}) => MeasurableDataType(
  id: id,
  displayName: displayName,
  description: description,
  unitName: unitName,
  createdAt: _created,
  updatedAt: _created,
  vectorClock: null,
  version: 1,
  aggregationType: aggregationType,
  favorite: favorite,
);

final MeasurableDataType _habitatPressure = _measurable(
  id: 'meas-habitat-pressure',
  displayName: 'Habitat pressure',
  unitName: 'kPa',
  description: 'Average pressure across the orbital habitat.',
  aggregationType: AggregationType.dailyAvg,
);
final MeasurableDataType _sardinesConsumed = _measurable(
  id: 'meas-sardines-consumed',
  displayName: 'Sardines consumed',
  unitName: 'sardines',
);
final MeasurableDataType _penguinsAccountedFor = _measurable(
  id: 'meas-penguins-accounted-for',
  displayName: 'Penguins accounted for',
  unitName: 'penguins',
  favorite: true,
);

final List<MeasurableDataType> _allMeasurables = [
  _habitatPressure,
  _sardinesConsumed,
  _penguinsAccountedFor,
];

DashboardDefinition _dashboard({
  required String id,
  required String name,
  required String description,
  required List<DashboardItem> items,
  String? categoryId,
  bool private = false,
}) => DashboardDefinition(
  id: id,
  name: name,
  description: description,
  items: items,
  createdAt: _created,
  updatedAt: _created,
  lastReviewed: _created,
  vectorClock: null,
  private: private,
  version: '',
  active: true,
  categoryId: categoryId,
);

final DashboardDefinition _colonyOperations = _dashboard(
  id: 'dash-colony-operations',
  name: 'Colony operations',
  description: 'Habitat pressure, sardine demand, and crew headcount.',
  categoryId: manualDemoCategoryId,
  items: const [
    DashboardMeasurementItem(
      id: 'meas-habitat-pressure',
      aggregationType: AggregationType.dailyAvg,
    ),
    DashboardMeasurementItem(
      id: 'meas-sardines-consumed',
      aggregationType: AggregationType.dailySum,
    ),
    DashboardMeasurementItem(
      id: 'meas-penguins-accounted-for',
      aggregationType: AggregationType.dailySum,
    ),
  ],
);
final DashboardDefinition _missionReadiness = _dashboard(
  id: 'dash-mission-readiness',
  name: 'Mission readiness',
  description: 'Private launch review for Project Waddle.',
  categoryId: _missionControlCategoryId,
  private: true,
  items: const [],
);

final List<DashboardDefinition> _allDashboards = [
  _colonyOperations,
  _missionReadiness,
];

// ---------------------------------------------------------------------------
// Harness plumbing.
// ---------------------------------------------------------------------------

Widget _app({
  required Widget home,
  required Brightness brightness,
  required Size size,
  List<Override> overrides = const [],
  double textScale = 1.0,
}) {
  return RepaintBoundary(
    key: screenshotBoundaryKey,
    child: ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FormBuilderLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    ),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Widget home,
  required ScreenshotDevice device,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  List<Override> overrides = const [],
}) async {
  applyScreenshotDevice(tester, device);
  await tester.pumpWidget(
    _app(
      home: home,
      brightness: brightness,
      size: device.size,
      textScale: textScale,
      overrides: overrides,
    ),
  );
  await settleFrames(tester);
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'settings-definitions screenshot harness (opt-in)',
      () {},
      skip:
          'Design-review screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true) '
          'because the real-font loading leaks process-wide.',
    );
    return;
  }

  // The SettingsPageHeader title now uses the Inter-pinned `heading3`
  // token (it previously used a null-family style that painted as
  // FlutterTest blocks), so every title renders with real glyphs in
  // these captures.
  setUpAll(loadScreenshotFonts);

  late TestGetItMocks mocks;
  late MockCategoryRepository categoryRepo;
  late MockLabelsRepository labelsRepo;
  late MockEntitiesCacheService cache;

  setUp(() async {
    categoryRepo = MockCategoryRepository();
    labelsRepo = MockLabelsRepository();
    cache = MockEntitiesCacheService();

    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          // CategoryIconCompact (habits/dashboards rows), the habit
          // editor's category field, and label category chips all resolve
          // categories through the entities cache.
          ..registerSingleton<EntitiesCacheService>(cache)
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<NotificationService>(MockNotificationService());
      },
    );

    when(() => cache.getCategoryById(any())).thenReturn(null);
    for (final category in _allCategories) {
      when(() => cache.getCategoryById(category.id)).thenReturn(category);
    }
    when(() => cache.sortedCategories).thenReturn(_allCategories);

    when(categoryRepo.watchCategories).thenAnswer(
      (_) => Stream.value(_allCategories),
    );
    when(() => categoryRepo.watchCategory(_penguinOperations.id)).thenAnswer(
      (_) => Stream.value(_penguinOperations),
    );

    when(labelsRepo.watchLabels).thenAnswer((_) => Stream.value(_allLabels));
    when(() => labelsRepo.watchLabel(_projectWaddle.id)).thenAnswer(
      (_) => Stream.value(_projectWaddle),
    );

    // The habit editor loads via habitsRepositoryProvider → getIt
    // <JournalDb>; the dashboard editor reads habit/measurable selections
    // straight from JournalDb.
    when(() => mocks.journalDb.getHabitById(any())).thenAnswer(
      (_) async => null,
    );
    when(() => mocks.journalDb.getHabitById(_rollCall.id)).thenAnswer(
      (_) async => _rollCall,
    );
    when(mocks.journalDb.getAllDashboards).thenAnswer(
      (_) async => _allDashboards,
    );
    // SelectDashboardCategoryWidget resolves the dashboard's category
    // straight from JournalDb (not the entities cache).
    when(mocks.journalDb.getAllCategories).thenAnswer(
      (_) async => _allCategories,
    );
    when(mocks.journalDb.getAllHabitDefinitions).thenAnswer(
      (_) async => _allHabits,
    );
    when(mocks.journalDb.getAllMeasurableDataTypes).thenAnswer(
      (_) async => _allMeasurables,
    );
    when(() => mocks.journalDb.getMeasurableDataTypeById(any())).thenAnswer(
      (_) async => null,
    );
    for (final measurable in _allMeasurables) {
      when(
        () => mocks.journalDb.getMeasurableDataTypeById(measurable.id),
      ).thenAnswer((_) async => measurable);
    }

    // Row taps and back affordances route through the top-level
    // `beamToNamed`; no NavService is registered here.
    beamToNamedOverride = (_) {};
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  List<Override> categoriesListOverrides() => [
    categoryRepositoryProvider.overrideWithValue(categoryRepo),
    categoryTaskCountProvider.overrideWith(
      (ref, categoryId) async => _taskCounts[categoryId] ?? 0,
    ),
  ];

  List<Override> categoriesDetailOverrides() => [
    categoryRepositoryProvider.overrideWithValue(categoryRepo),
  ];

  List<Override> labelsListOverrides() => [
    labelsStreamProvider.overrideWith((ref) => Stream.value(_allLabels)),
    labelUsageStatsProvider.overrideWith((ref) => Stream.value(_labelUsage)),
  ];

  List<Override> labelsDetailOverrides() => [
    labelsRepositoryProvider.overrideWithValue(labelsRepo),
  ];

  // -------------------------------------------------------------------------
  // Categories.
  // -------------------------------------------------------------------------

  for (final device in [miniDevice, desktopDevice]) {
    final viewport = device.isPhone ? 'mobile' : 'desktop';
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;

      testWidgets('$viewport categories list — $theme', (tester) async {
        await _pumpScreen(
          tester,
          device: device,
          brightness: brightness,
          overrides: categoriesListOverrides(),
          home: const CategoriesListPage(),
        );
        expect(find.text('Penguin Operations'), findsOneWidget);
        expect(find.text('Mission Control'), findsOneWidget);
        expect(find.text('37 tasks'), findsOneWidget);
        await captureScreenshot(
          tester,
          'categories_list_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport categories detail — $theme', (tester) async {
        await _pumpScreen(
          tester,
          device: device,
          brightness: brightness,
          overrides: categoriesDetailOverrides(),
          home: CategoryDetailsPage(categoryId: _penguinOperations.id),
        );
        expect(find.text('Edit category'), findsOneWidget);
        expect(find.text('Penguin Operations'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller
              ?.text,
          'Penguin Operations',
        );
        await captureScreenshot(
          tester,
          'categories_detail_${viewport}_$theme',
          subdir: _subdir,
        );

        await tester.scrollUntilVisible(
          find.text('Checklist correction examples'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await settleFrames(tester);
        expect(find.text('Speech recognition'), findsOneWidget);
        expect(find.textContaining('Project Waddle'), findsWidgets);
        await captureScreenshot(
          tester,
          'categories_automation_${viewport}_$theme',
          subdir: _subdir,
        );
      });
    }
  }

  testWidgets('mini categories create — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      overrides: categoriesDetailOverrides(),
      home: const CategoryDetailsPage(),
    );
    expect(find.text('Create category'), findsOneWidget);
    await captureScreenshot(
      tester,
      'mini_categories_create_dark',
      subdir: _subdir,
    );
  });

  testWidgets('mini categories list (empty state) — dark', (tester) async {
    when(categoryRepo.watchCategories).thenAnswer(
      (_) => Stream.value(<CategoryDefinition>[]),
    );
    await _pumpScreen(
      tester,
      device: miniDevice,
      overrides: categoriesListOverrides(),
      home: const CategoriesListPage(),
    );
    expect(find.text('No categories yet'), findsOneWidget);
    await captureScreenshot(
      tester,
      'mini_categories_list_empty_dark',
      subdir: _subdir,
    );
  });

  testWidgets('mini categories detail (edit, scrolled to bottom) — dark', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      overrides: categoriesDetailOverrides(),
      home: CategoryDetailsPage(categoryId: _penguinOperations.id),
    );
    // Scroll the form to its end so content visibly slides behind the
    // glass action bar.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await settleFrames(tester);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.pixels, greaterThan(0));
    await captureScreenshot(
      tester,
      'mini_categories_detail_dark_scrolled',
      subdir: _subdir,
    );
  });

  // -------------------------------------------------------------------------
  // Labels.
  // -------------------------------------------------------------------------

  for (final device in [miniDevice, desktopDevice]) {
    final viewport = device.isPhone ? 'mobile' : 'desktop';
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;

      testWidgets('$viewport labels list — $theme', (tester) async {
        await _pumpScreen(
          tester,
          device: device,
          brightness: brightness,
          overrides: labelsListOverrides(),
          home: const LabelsListPage(),
        );
        expect(find.text('Project Waddle'), findsOneWidget);
        expect(find.text('Habitat critical'), findsOneWidget);
        expect(find.text('14 tasks'), findsOneWidget);
        await captureScreenshot(
          tester,
          'labels_list_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport labels detail — $theme', (tester) async {
        await _pumpScreen(
          tester,
          device: device,
          brightness: brightness,
          overrides: labelsDetailOverrides(),
          home: LabelDetailsPage(labelId: _projectWaddle.id),
        );
        expect(find.text('Edit label'), findsOneWidget);
        expect(find.text('Project Waddle'), findsOneWidget);
        // Demonstrate the armed action state while preserving the story.
        await tester.enterText(
          find.byType(TextField).first,
          'Project Waddle — launch',
        );
        await settleFrames(tester, 4);
        expect(find.text('Project Waddle — launch'), findsOneWidget);
        await captureScreenshot(
          tester,
          'labels_detail_${viewport}_$theme',
          subdir: _subdir,
        );
      });
    }
  }

  // 2.0x — the upper end of common accessibility text sizes; the action
  // bar stacks its pills vertically at this scale.
  testWidgets('mini labels detail (edit) — dark, 2.0x text', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      textScale: 2,
      overrides: labelsDetailOverrides(),
      home: LabelDetailsPage(labelId: _projectWaddle.id),
    );
    expect(find.text('Edit label'), findsOneWidget);
    await captureScreenshot(
      tester,
      'mini_labels_detail_dark_2x',
      subdir: _subdir,
    );
  });

  // -------------------------------------------------------------------------
  // Habits.
  // -------------------------------------------------------------------------

  testWidgets('mini habits list — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      overrides: [
        habitDefinitionsStreamProvider.overrideWith(
          (ref) => Stream.value(_allHabits),
        ),
      ],
      home: const HabitsPage(),
    );
    expect(find.text('Emperor penguin roll call'), findsOneWidget);
    expect(find.text('Walk the habitat seals'), findsOneWidget);
    await captureScreenshot(tester, 'mini_habits_list_dark', subdir: _subdir);
  });

  testWidgets('mini habits detail (edit) — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      home: EditHabitPage(habitId: _rollCall.id),
    );
    expect(find.text('Edit habit'), findsOneWidget);
    expect(find.text('Emperor penguin roll call'), findsOneWidget);
    await captureScreenshot(tester, 'mini_habits_detail_dark', subdir: _subdir);
  });

  // -------------------------------------------------------------------------
  // Measurables.
  // -------------------------------------------------------------------------

  testWidgets('mini measurables list — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      overrides: [
        measurableDataTypesStreamProvider.overrideWith(
          (ref) => Stream.value(_allMeasurables),
        ),
      ],
      home: const MeasurablesPage(),
    );
    expect(find.text('Habitat pressure'), findsOneWidget);
    expect(find.text('Penguins accounted for'), findsOneWidget);
    await captureScreenshot(
      tester,
      'mini_measurables_list_dark',
      subdir: _subdir,
    );
  });

  testWidgets('mini measurables detail (edit) — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      home: MeasurableDetailsPage(dataType: _habitatPressure),
    );
    expect(find.text('Edit measurable'), findsOneWidget);
    expect(find.text('Habitat pressure'), findsOneWidget);
    await captureScreenshot(
      tester,
      'mini_measurables_detail_dark',
      subdir: _subdir,
    );
  });

  // -------------------------------------------------------------------------
  // Dashboards.
  // -------------------------------------------------------------------------

  testWidgets('mini dashboards list — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      overrides: [
        allDashboardsStreamProvider.overrideWith(
          (ref) => Stream.value(_allDashboards),
        ),
      ],
      home: const DashboardSettingsPage(),
    );
    expect(find.text('Colony operations'), findsOneWidget);
    expect(find.text('Mission readiness'), findsOneWidget);
    await captureScreenshot(
      tester,
      'mini_dashboards_list_dark',
      subdir: _subdir,
    );
  });

  testWidgets('mini dashboards detail (edit, with items) — dark', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      home: DashboardDefinitionPage(dashboard: _colonyOperations),
    );
    expect(find.text('Edit dashboard'), findsOneWidget);
    expect(find.text('Colony operations'), findsOneWidget);
    // The reorderable charts list renders one dismissible card per item.
    expect(find.byType(Dismissible), findsNWidgets(3));
    await captureScreenshot(
      tester,
      'mini_dashboards_detail_dark',
      subdir: _subdir,
    );
  });
}
