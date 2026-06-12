/// Screenshot harness for the revamped settings definition pages —
/// categories, labels, habits, measurables, and dashboards on the shared
/// `DefinitionsListPage` / `SettingsDetailScaffold` kit (list, edit, and
/// create surfaces, plus the empty and scrolled-behind-glass states).
///
/// Renders a realistic personal productivity journal: categories for deep
/// work, health, client work, and admin; triage labels; daily habits;
/// body metrics; and two dashboards. PNGs land in
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

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';
import '../../daily_os_next/screenshot_harness.dart';
import '../../labels/test_utils.dart';

const String _subdir = 'settings_definitions';

final DateTime _created = DateTime(2024, 3, 15);

// ---------------------------------------------------------------------------
// Story data — a personal productivity journal.
// ---------------------------------------------------------------------------

final CategoryDefinition _deepWork = CategoryTestUtils.createTestCategory(
  id: 'cat-deep',
  name: 'Deep Work',
  color: '#8B5CF6',
  icon: CategoryIcon.brain,
  defaultLanguageCode: 'en',
  speechDictionary: ['Lotti', 'Pomodoro'],
);
final CategoryDefinition _health = CategoryTestUtils.createTestCategory(
  id: 'cat-health',
  name: 'Health',
  color: '#34D399',
);
final CategoryDefinition _clientWork = CategoryTestUtils.createTestCategory(
  id: 'cat-client',
  name: 'Client Work',
  color: '#4F9DDE',
  private: true,
);
final CategoryDefinition _admin = CategoryTestUtils.createTestCategory(
  id: 'cat-admin',
  name: 'Admin',
  color: '#E8A33D',
  active: false,
);

final List<CategoryDefinition> _allCategories = [
  _deepWork,
  _health,
  _clientWork,
  _admin,
];

const Map<String, int> _taskCounts = {
  'cat-deep': 12,
  'cat-health': 4,
  'cat-client': 7,
  'cat-admin': 23,
};

final LabelDefinition _urgent = LabelTestUtils.createTestLabel(
  id: 'label-urgent',
  name: 'Urgent',
  color: '#EF4444',
  description: 'Needs attention today — blocks other work.',
  applicableCategoryIds: ['cat-client', 'cat-deep'],
);
final LabelDefinition _waiting = LabelTestUtils.createTestLabel(
  id: 'label-waiting',
  name: 'Waiting',
  color: '#3B82F6',
);
final LabelDefinition _someday = LabelTestUtils.createTestLabel(
  id: 'label-someday',
  name: 'Someday',
  color: '#9CA3AF',
  private: true,
);

final List<LabelDefinition> _allLabels = [_urgent, _waiting, _someday];

const Map<String, int> _labelUsage = {
  'label-urgent': 8,
  'label-waiting': 3,
  'label-someday': 12,
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

final HabitDefinition _meditation = _habit(
  id: 'habit-meditation',
  name: 'Meditation',
  description: 'Ten quiet minutes before the first deep-work block.',
  categoryId: 'cat-deep',
  priority: true,
);
final HabitDefinition _run5k = _habit(
  id: 'habit-run',
  name: 'Run 5k',
  description: 'Easy pace after work, three times a week.',
  categoryId: 'cat-health',
  private: true,
);
final HabitDefinition _journaling = _habit(
  id: 'habit-journal',
  name: 'Journaling',
  description: 'Evening reflection — paused for now.',
  active: false,
);

final List<HabitDefinition> _allHabits = [_meditation, _run5k, _journaling];

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

final MeasurableDataType _weight = _measurable(
  id: 'meas-weight',
  displayName: 'Weight',
  unitName: 'kg',
  description: 'Morning weight, same scale every day.',
  aggregationType: AggregationType.dailyAvg,
);
final MeasurableDataType _water = _measurable(
  id: 'meas-water',
  displayName: 'Water',
  unitName: 'ml',
);
final MeasurableDataType _steps = _measurable(
  id: 'meas-steps',
  displayName: 'Steps',
  unitName: 'steps',
  favorite: true,
);

final List<MeasurableDataType> _allMeasurables = [_weight, _water, _steps];

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

final DashboardDefinition _healthOverview = _dashboard(
  id: 'dash-health',
  name: 'Health overview',
  description: 'Weight, water, and steps at a glance.',
  categoryId: 'cat-health',
  items: const [
    DashboardHealthItem(
      color: '#34D399',
      healthType: 'HealthDataType.WEIGHT',
    ),
    DashboardMeasurementItem(
      id: 'meas-water',
      aggregationType: AggregationType.dailySum,
    ),
    DashboardMeasurementItem(
      id: 'meas-steps',
      aggregationType: AggregationType.dailySum,
    ),
  ],
);
final DashboardDefinition _productivity = _dashboard(
  id: 'dash-prod',
  name: 'Productivity',
  description: '',
  categoryId: 'cat-deep',
  private: true,
  items: const [],
);

final List<DashboardDefinition> _allDashboards = [
  _healthOverview,
  _productivity,
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

  // KNOWN CAPTURE ARTIFACT: `settingsHeaderTitleTextStyle` (the
  // SettingsPageHeader title) does not pin a fontFamily, so the header
  // title paints with the test environment's default family
  // ('FlutterTest'), whose glyphs are solid boxes. The engine resolves
  // null-family text to that font directly — registering a real font
  // under 'FlutterTest'/'Roboto' via FontLoader does not change it — so
  // the page titles render as colored blocks in these captures.
  // Production is unaffected (real devices fall back to the platform
  // font). All token-styled text pins Inter and renders normally.
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
    when(() => categoryRepo.watchCategory(_deepWork.id)).thenAnswer(
      (_) => Stream.value(_deepWork),
    );

    when(labelsRepo.watchLabels).thenAnswer((_) => Stream.value(_allLabels));
    when(() => labelsRepo.watchLabel(_urgent.id)).thenAnswer(
      (_) => Stream.value(_urgent),
    );

    // The habit editor loads via habitsRepositoryProvider → getIt
    // <JournalDb>; the dashboard editor reads habit/measurable selections
    // straight from JournalDb.
    when(() => mocks.journalDb.getHabitById(any())).thenAnswer(
      (_) async => null,
    );
    when(() => mocks.journalDb.getHabitById(_meditation.id)).thenAnswer(
      (_) async => _meditation,
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

  testWidgets('mini categories list — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      overrides: categoriesListOverrides(),
      home: const CategoriesListPage(),
    );
    expect(find.text('Deep Work'), findsOneWidget);
    expect(find.text('Client Work'), findsOneWidget);
    await captureScreenshot(
      tester,
      'mini_categories_list_dark',
      subdir: _subdir,
    );
  });

  testWidgets('mini categories list — light', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      brightness: Brightness.light,
      overrides: categoriesListOverrides(),
      home: const CategoriesListPage(),
    );
    expect(find.text('Deep Work'), findsOneWidget);
    await captureScreenshot(
      tester,
      'mini_categories_list_light',
      subdir: _subdir,
    );
  });

  testWidgets('desktop categories list — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: desktopDevice,
      overrides: categoriesListOverrides(),
      home: const CategoriesListPage(),
    );
    expect(find.text('Deep Work'), findsOneWidget);
    await captureScreenshot(
      tester,
      'desktop_categories_list_dark',
      subdir: _subdir,
    );
  });

  testWidgets('mini categories detail (edit) — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      overrides: categoriesDetailOverrides(),
      home: CategoryDetailsPage(categoryId: _deepWork.id),
    );
    expect(find.text('Edit category'), findsOneWidget);
    expect(find.text('Deep Work'), findsOneWidget);
    await captureScreenshot(
      tester,
      'mini_categories_detail_dark',
      subdir: _subdir,
    );
  });

  testWidgets('mini categories detail (edit) — light', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      brightness: Brightness.light,
      overrides: categoriesDetailOverrides(),
      home: CategoryDetailsPage(categoryId: _deepWork.id),
    );
    expect(find.text('Edit category'), findsOneWidget);
    await captureScreenshot(
      tester,
      'mini_categories_detail_light',
      subdir: _subdir,
    );
  });

  testWidgets('desktop categories detail (edit) — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: desktopDevice,
      overrides: categoriesDetailOverrides(),
      home: CategoryDetailsPage(categoryId: _deepWork.id),
    );
    expect(find.text('Edit category'), findsOneWidget);
    await captureScreenshot(
      tester,
      'desktop_categories_detail_dark',
      subdir: _subdir,
    );
  });

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
      home: CategoryDetailsPage(categoryId: _deepWork.id),
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

  testWidgets('mini labels list — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      overrides: labelsListOverrides(),
      home: const LabelsListPage(),
    );
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('Someday'), findsOneWidget);
    await captureScreenshot(tester, 'mini_labels_list_dark', subdir: _subdir);
  });

  testWidgets('mini labels detail (edit) — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      overrides: labelsDetailOverrides(),
      home: LabelDetailsPage(labelId: _urgent.id),
    );
    expect(find.text('Edit label'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    await captureScreenshot(tester, 'mini_labels_detail_dark', subdir: _subdir);
  });

  testWidgets('mini labels detail (edit) — light', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      brightness: Brightness.light,
      overrides: labelsDetailOverrides(),
      home: LabelDetailsPage(labelId: _urgent.id),
    );
    expect(find.text('Edit label'), findsOneWidget);
    await captureScreenshot(
      tester,
      'mini_labels_detail_light',
      subdir: _subdir,
    );
  });

  // 2.0x — the upper end of common accessibility text sizes; the action
  // bar stacks its pills vertically at this scale.
  testWidgets('mini labels detail (edit) — dark, 2.0x text', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      textScale: 2,
      overrides: labelsDetailOverrides(),
      home: LabelDetailsPage(labelId: _urgent.id),
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
    expect(find.text('Meditation'), findsOneWidget);
    expect(find.text('Run 5k'), findsOneWidget);
    await captureScreenshot(tester, 'mini_habits_list_dark', subdir: _subdir);
  });

  testWidgets('mini habits detail (edit) — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      home: EditHabitPage(habitId: _meditation.id),
    );
    expect(find.text('Edit habit'), findsOneWidget);
    expect(find.text('Meditation'), findsOneWidget);
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
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
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
      home: MeasurableDetailsPage(dataType: _weight),
    );
    expect(find.text('Edit measurable'), findsOneWidget);
    expect(find.text('Weight'), findsOneWidget);
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
    expect(find.text('Health overview'), findsOneWidget);
    expect(find.text('Productivity'), findsOneWidget);
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
      home: DashboardDefinitionPage(dashboard: _healthOverview),
    );
    expect(find.text('Edit dashboard'), findsOneWidget);
    expect(find.text('Health overview'), findsOneWidget);
    // The reorderable charts list renders one dismissible card per item.
    expect(find.byType(Dismissible), findsNWidgets(3));
    await captureScreenshot(
      tester,
      'mini_dashboards_detail_dark',
      subdir: _subdir,
    );
  });
}
