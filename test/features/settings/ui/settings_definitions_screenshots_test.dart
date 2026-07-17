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

import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/category_task_count_provider.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/categories/ui/pages/category_details_page.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboard_page.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboards_list_page.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_survey_chart.dart';
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
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:research_package/research_package.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/manual_demo_world.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';
import '../../daily_os_next/screenshot_harness.dart';
import '../../labels/test_utils.dart';

const String _subdir = 'settings_definitions';
String _t(String en, String de) => manualScreenshotText(en: en, de: de);

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
      name: _t('Penguin Operations', 'Pinguinbetrieb'),
      color: '#8B5CF6',
      icon: CategoryIcon.airplane,
      favorite: true,
      isAvailableForDayPlan: true,
      defaultLanguageCode: manualScreenshotLocale.languageCode,
      defaultProfileId: manualProjectWaddleProfileId,
      speechDictionary: [
        'Project Waddle',
        'Sir Flaps-a-Lot',
        _t('sardine', 'Sardine'),
        'Europa',
      ],
      correctionExamples: [
        ChecklistCorrectionExample(
          before: 'sir flaps a lot',
          after: 'Sir Flaps-a-Lot',
          capturedAt: manualDemoNow.subtract(const Duration(days: 3)),
        ),
        ChecklistCorrectionExample(
          before: _t('project waddle habitat', 'projekt waddle habitat'),
          after: _t('Project Waddle habitat', 'Project-Waddle-Habitat'),
          capturedAt: manualDemoNow.subtract(const Duration(days: 1)),
        ),
      ],
    );
final CategoryDefinition _missionControl = CategoryTestUtils.createTestCategory(
  id: _missionControlCategoryId,
  name: _t('Mission Control', 'Missionskontrolle'),
  color: '#4F9DDE',
  icon: CategoryIcon.connectivity,
  isAvailableForDayPlan: true,
  private: true,
);
final CategoryDefinition _fishDiplomacy = CategoryTestUtils.createTestCategory(
  id: _fishDiplomacyCategoryId,
  name: _t('Fish Diplomacy', 'Fischdiplomatie'),
  color: '#E8A33D',
  icon: CategoryIcon.meeting,
);
final CategoryDefinition _humanMaintenance =
    CategoryTestUtils.createTestCategory(
      id: _humanMaintenanceCategoryId,
      name: _t('Human Maintenance', 'Menschenwartung'),
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
  name: _t('Project Waddle', 'Project Waddle'),
  color: '#1F9CF5',
  description: _t(
    'Launch-critical work for the first interplanetary penguin habitat.',
    'Startkritische Arbeit für das erste interplanetare Pinguin-Habitat.',
  ),
  applicableCategoryIds: [
    manualDemoCategoryId,
    _missionControlCategoryId,
    _fishDiplomacyCategoryId,
  ],
);
final LabelDefinition _habitatCritical = LabelTestUtils.createTestLabel(
  id: manualDemoCriticalLabelId,
  name: _t('Habitat critical', 'Habitatkritisch'),
  color: '#FBA337',
  description: _t(
    'Must be resolved before emperor penguins enter the orbital habitat.',
    'Muss gelöst sein, bevor die Kaiserpinguine das Orbital-Habitat betreten.',
  ),
  applicableCategoryIds: [manualDemoCategoryId, _missionControlCategoryId],
);
final LabelDefinition _awaitingMissionControl = LabelTestUtils.createTestLabel(
  id: _awaitingMissionControlLabelId,
  name: _t('Awaiting Mission Control', 'Wartet auf Missionskontrolle'),
  color: '#8B5CF6',
  description: _t(
    'Blocked until the lunar shift sends clearance.',
    'Blockiert, bis die Mondschicht die Freigabe sendet.',
  ),
  applicableCategoryIds: [manualDemoCategoryId, _missionControlCategoryId],
);
final LabelDefinition _sardineMarket = LabelTestUtils.createTestLabel(
  id: _sardineMarketLabelId,
  name: _t('Sardine market sensitive', 'Sardinenmarktsensibel'),
  color: '#34D399',
  description: _t(
    'Private negotiations with the Europa fish exchange.',
    'Private Verhandlungen mit der Europa-Fischbörse.',
  ),
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
  HabitSchedule? schedule,
  DateTime? activeFrom,
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
  habitSchedule: schedule ?? const HabitSchedule.daily(requiredCompletions: 1),
  activeFrom: activeFrom,
  active: active,
  private: private,
  priority: priority,
  categoryId: categoryId,
);

final HabitDefinition _rollCall = _habit(
  id: 'habit-emperor-roll-call',
  name: _t('Emperor penguin roll call', 'Kaiserpinguine durchzählen'),
  description: _t(
    'Account for all 37 expedition penguins before launch.',
    'Vor dem Start alle 37 Expeditionspinguine erfassen.',
  ),
  categoryId: manualDemoCategoryId,
  schedule: HabitSchedule.daily(
    requiredCompletions: 1,
    showFrom: DateTime(2026, 7, 17, 6),
    alertAtTime: DateTime(2026, 7, 17, 6, 30),
  ),
  activeFrom: DateTime(2026, 7),
  priority: true,
);
final HabitDefinition _habitatSealWalk = _habit(
  id: 'habit-habitat-seals',
  name: _t('Walk the habitat seals', 'Habitatdichtungen ablaufen'),
  description: _t(
    'Inspect every pressure seal after the artificial sunrise.',
    'Nach dem künstlichen Sonnenaufgang jede Druckdichtung inspizieren.',
  ),
  categoryId: manualDemoCategoryId,
  private: true,
);
final HabitDefinition _sardineForecast = _habit(
  id: 'habit-sardine-forecast',
  name: _t('Review sardine forecast', 'Sardinenprognose prüfen'),
  description: _t(
    'Paused while the Europa exchange recalibrates its fish index.',
    'Pausiert, während die Europa-Börse ihren Fischindex neu kalibriert.',
  ),
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
  displayName: _t('Habitat pressure', 'Habitatdruck'),
  unitName: 'kPa',
  description: _t(
    'Average pressure across the orbital habitat.',
    'Durchschnittlicher Druck im gesamten Orbital-Habitat.',
  ),
  aggregationType: AggregationType.dailyAvg,
);
final MeasurableDataType _sardinesConsumed = _measurable(
  id: 'meas-sardines-consumed',
  displayName: _t('Sardines consumed', 'Verzehrte Sardinen'),
  unitName: _t('sardines', 'Sardinen'),
);
final MeasurableDataType _penguinsAccountedFor = _measurable(
  id: 'meas-penguins-accounted-for',
  displayName: _t('Penguins accounted for', 'Gezählte Pinguine'),
  unitName: _t('penguins', 'Pinguine'),
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
  name: _t('Colony operations', 'Koloniebetrieb'),
  description: _t(
    'Habitat pressure, sardine demand, and crew headcount.',
    'Habitatdruck, Sardinenbedarf und Besatzungsstärke.',
  ),
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
    DashboardSurveyItem(
      surveyType: 'panasSurveyTask',
      surveyName: 'PANAS',
      colorsByScoreKey: {
        'Positive Affect Score': '#00FF00',
        'Negative Affect Score': '#FF0000',
      },
    ),
  ],
);
final DashboardDefinition _missionReadiness = _dashboard(
  id: 'dash-mission-readiness',
  name: _t('Mission readiness', 'Missionsbereitschaft'),
  description: _t(
    'Private launch review for Project Waddle.',
    'Private Startprüfung für Project Waddle.',
  ),
  categoryId: _missionControlCategoryId,
  private: true,
  items: const [],
);

final List<DashboardDefinition> _allDashboards = [
  _colonyOperations,
  _missionReadiness,
];

List<JournalEntity> _dashboardMeasurements({
  required String type,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final start = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
  final days = rangeEnd.difference(start).inDays;
  return [
    for (var day = 0; day <= days; day++)
      () {
        final at = start.add(Duration(days: day));
        final value = switch (type) {
          'meas-habitat-pressure' =>
            101.2 + math.sin(day / 7) * 0.7 + (day % 5) * 0.08,
          'meas-sardines-consumed' =>
            680 + math.sin(day / 4) * 95 + (day % 6) * 21,
          'meas-penguins-accounted-for' => day % 19 == 0 ? 36 : 37,
          _ => 0,
        };
        return MeasurementEntry(
          meta: Metadata(
            id: '$type-$day',
            createdAt: at,
            updatedAt: at,
            dateFrom: at,
            dateTo: at,
            private: false,
          ),
          data: MeasurementData(
            value: value.toDouble(),
            dataTypeId: type,
            dateFrom: at,
            dateTo: at,
          ),
        );
      }(),
  ];
}

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
          locale: manualScreenshotLocale,
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

void _alignInOuterScrollView(
  WidgetTester tester,
  Finder target, {
  double top = 72,
}) {
  final position = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .map((state) => state.position)
      .reduce(
        (largest, candidate) =>
            candidate.maxScrollExtent > largest.maxScrollExtent
            ? candidate
            : largest,
      );
  final targetTop = tester.getTopLeft(target).dy;
  final offset = (position.pixels + targetTop - top).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  position.jumpTo(offset);
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
  late String? previousIntlDefaultLocale;

  setUpAll(() async {
    previousIntlDefaultLocale = Intl.defaultLocale;
    final locale = manualScreenshotLocale.toLanguageTag();
    await initializeDateFormatting(locale);
    Intl.defaultLocale = locale;
    registerAllFallbackValues();
    await loadScreenshotFonts();
  });

  tearDownAll(() {
    Intl.defaultLocale = previousIntlDefaultLocale;
  });

  late TestGetItMocks mocks;
  late MockCategoryRepository categoryRepo;
  late MockLabelsRepository labelsRepo;
  late MockAiConfigRepository aiConfigRepo;
  late MockEntitiesCacheService cache;
  late MockTimeService timeService;
  late NavService navService;

  setUp(() async {
    categoryRepo = MockCategoryRepository();
    labelsRepo = MockLabelsRepository();
    aiConfigRepo = MockAiConfigRepository();
    cache = MockEntitiesCacheService();
    timeService = MockTimeService();

    mocks = await setUpTestGetIt(
      additionalSetup: () {
        navService = NavService();
        getIt
          // CategoryIconCompact (habits/dashboards rows), the habit
          // editor's category field, and label category chips all resolve
          // categories through the entities cache.
          ..registerSingleton<EntitiesCacheService>(cache)
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<NotificationService>(MockNotificationService())
          ..registerSingleton<UserActivityService>(UserActivityService())
          ..registerSingleton<TimeService>(timeService)
          ..registerSingleton<NavService>(navService);
      },
    );

    when(() => cache.getCategoryById(any())).thenReturn(null);
    for (final category in _allCategories) {
      when(() => cache.getCategoryById(category.id)).thenReturn(category);
    }
    when(() => cache.sortedCategories).thenReturn(_allCategories);
    when(() => cache.getDashboardById(any())).thenReturn(null);
    when(
      () => cache.getDashboardById(_colonyOperations.id),
    ).thenReturn(_colonyOperations);
    when(() => cache.getDataTypeById(any())).thenReturn(null);
    for (final measurable in _allMeasurables) {
      when(
        () => cache.getDataTypeById(measurable.id),
      ).thenReturn(measurable);
    }
    when(timeService.getStream).thenAnswer(
      (_) => const Stream<JournalEntity>.empty(),
    );

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
    when(aiConfigRepo.watchProfiles).thenAnswer(
      (_) => Stream.value(manualDemoAiProfiles),
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
    when(
      () => mocks.journalDb.getMeasurementsByType(
        type: any(named: 'type'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((invocation) async {
      return _dashboardMeasurements(
        type: invocation.namedArguments[#type] as String,
        rangeStart: invocation.namedArguments[#rangeStart] as DateTime,
        rangeEnd: invocation.namedArguments[#rangeEnd] as DateTime,
      );
    });
    when(
      () => mocks.journalDb.getSurveyCompletionsByType(
        type: any(named: 'type'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => []);

    // Row taps and back affordances route through the top-level
    // `beamToNamed`; no NavService is registered here.
    beamToNamedOverride = (_) {};
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await navService.dispose();
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
    aiConfigRepositoryProvider.overrideWithValue(aiConfigRepo),
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
        expect(
          find.text(_t('Penguin Operations', 'Pinguinbetrieb')),
          findsOneWidget,
        );
        expect(
          find.text(_t('Mission Control', 'Missionskontrolle')),
          findsOneWidget,
        );
        expect(find.text(_t('37 tasks', '37 Aufgaben')), findsOneWidget);
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
        expect(
          find.text(_t('Edit category', 'Kategorie bearbeiten')),
          findsOneWidget,
        );
        expect(
          find.text(_t('Penguin Operations', 'Pinguinbetrieb')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller
              ?.text,
          _t('Penguin Operations', 'Pinguinbetrieb'),
        );
        await captureScreenshot(
          tester,
          'categories_detail_${viewport}_$theme',
          subdir: _subdir,
        );

        await tester.scrollUntilVisible(
          find.text(
            _t(
              'Checklist correction examples',
              'Checklisten-Korrekturbeispiele',
            ),
          ),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await settleFrames(tester);
        expect(
          find.text(_t('Speech recognition', 'Spracherkennung')),
          findsOneWidget,
        );
        expect(find.textContaining('Project Waddle'), findsWidgets);
        await captureScreenshot(
          tester,
          'categories_automation_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport category AI profile picker — $theme', (
        tester,
      ) async {
        await _pumpScreen(
          tester,
          device: device,
          brightness: brightness,
          overrides: categoriesDetailOverrides(),
          home: CategoryDetailsPage(categoryId: _penguinOperations.id),
        );

        final selectedProfile = find.text(
          _t('Project Waddle Command', 'Project-Waddle-Kommando'),
        );
        if (device.isPhone) {
          await tester.scrollUntilVisible(
            selectedProfile,
            300,
            scrollable: find.byType(Scrollable).first,
          );
        } else {
          _alignInOuterScrollView(tester, selectedProfile, top: 160);
        }
        await settleFrames(tester);
        await tester.tap(selectedProfile);
        await settleFrames(tester, 6);

        expect(
          find.text(
            _t('Choose an inference profile', 'Inferenzprofil auswählen'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(_t('Project Waddle Command', 'Project-Waddle-Kommando')),
          findsWidgets,
        );
        expect(
          find.text(_t('Fish Diplomacy', 'Fischdiplomatie')),
          findsOneWidget,
        );
        if (!device.isPhone) {
          expect(
            find.text(_t('Habitat Local-First', 'Habitat zuerst lokal')),
            findsOneWidget,
          );
        }
        await captureScreenshot(
          tester,
          'ai_profile_picker_${viewport}_$theme',
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
    expect(
      find.text(_t('Create category', 'Kategorie erstellen')),
      findsOneWidget,
    );
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
    expect(
      find.text(_t('No categories yet', 'Noch keine Kategorien')),
      findsOneWidget,
    );
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
        expect(
          find.text(_t('Habitat critical', 'Habitatkritisch')),
          findsOneWidget,
        );
        expect(find.text(_t('14 tasks', '14 Aufgaben')), findsOneWidget);
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
        expect(
          find.text(_t('Edit label', 'Label bearbeiten')),
          findsOneWidget,
        );
        expect(find.text('Project Waddle'), findsOneWidget);
        // Demonstrate the armed action state while preserving the story.
        await tester.enterText(
          find.byType(TextField).first,
          _t('Project Waddle — launch', 'Project Waddle — Start'),
        );
        await settleFrames(tester, 4);
        expect(
          find.text(_t('Project Waddle — launch', 'Project Waddle — Start')),
          findsOneWidget,
        );
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
    expect(
      find.text(_t('Edit label', 'Label bearbeiten')),
      findsOneWidget,
    );
    await captureScreenshot(
      tester,
      'mini_labels_detail_dark_2x',
      subdir: _subdir,
    );
  });

  // -------------------------------------------------------------------------
  // Habits.
  // -------------------------------------------------------------------------

  for (final device in [miniDevice, desktopDevice]) {
    final viewport = device.isPhone ? 'mobile' : 'desktop';
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;

      testWidgets('$viewport habits settings list — $theme', (tester) async {
        await _pumpScreen(
          tester,
          device: device,
          brightness: brightness,
          overrides: [
            habitDefinitionsStreamProvider.overrideWith(
              (ref) => Stream.value(_allHabits),
            ),
          ],
          home: const HabitsPage(),
        );
        expect(
          find.text(
            _t('Emperor penguin roll call', 'Kaiserpinguine durchzählen'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(_t('Walk the habitat seals', 'Habitatdichtungen ablaufen')),
          findsOneWidget,
        );
        expect(
          find.text(_t('Review sardine forecast', 'Sardinenprognose prüfen')),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'habits_settings_list_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport habits settings detail — $theme', (tester) async {
        await _pumpScreen(
          tester,
          device: device,
          brightness: brightness,
          home: EditHabitPage(habitId: _rollCall.id),
        );
        expect(
          find.text(_t('Edit habit', 'Gewohnheit bearbeiten')),
          findsOneWidget,
        );
        expect(
          find.text(
            _t('Emperor penguin roll call', 'Kaiserpinguine durchzählen'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(_t('Penguin Operations', 'Pinguinbetrieb')),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'habits_settings_detail_${viewport}_$theme',
          subdir: _subdir,
        );

        await tester.scrollUntilVisible(
          find.text(_t('Schedule', 'Zeitplan')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await settleFrames(tester);
        expect(find.text(_t('Start date', 'Startdatum')), findsOneWidget);
        expect(find.text(_t('Show from', 'Anzeigen ab')), findsOneWidget);
        expect(
          find.text(_t('Show alert at', 'Alarm anzeigen um')),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'habits_schedule_${viewport}_$theme',
          subdir: _subdir,
        );
      });
    }
  }

  // -------------------------------------------------------------------------
  // Measurables.
  // -------------------------------------------------------------------------

  for (final device in [miniDevice, desktopDevice]) {
    final viewport = device.isPhone ? 'mobile' : 'desktop';
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;

      testWidgets('$viewport measurables settings list — $theme', (
        tester,
      ) async {
        await _pumpScreen(
          tester,
          device: device,
          brightness: brightness,
          overrides: [
            measurableDataTypesStreamProvider.overrideWith(
              (ref) => Stream.value(_allMeasurables),
            ),
          ],
          home: const MeasurablesPage(),
        );
        expect(
          find.text(_t('Habitat pressure', 'Habitatdruck')),
          findsOneWidget,
        );
        expect(
          find.text(_t('Sardines consumed', 'Verzehrte Sardinen')),
          findsOneWidget,
        );
        expect(
          find.text(_t('Penguins accounted for', 'Gezählte Pinguine')),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'measurables_settings_list_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport measurables settings detail — $theme', (
        tester,
      ) async {
        await _pumpScreen(
          tester,
          device: device,
          brightness: brightness,
          home: MeasurableDetailsPage(dataType: _habitatPressure),
        );
        expect(
          find.text(_t('Edit measurable', 'Messgröße bearbeiten')),
          findsOneWidget,
        );
        expect(
          find.text(_t('Habitat pressure', 'Habitatdruck')),
          findsOneWidget,
        );
        expect(find.text('kPa'), findsOneWidget);
        expect(
          find.text(_t('Daily average', 'Tagesdurchschnitt')),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'measurables_settings_detail_${viewport}_$theme',
          subdir: _subdir,
        );
      });
    }
  }

  // -------------------------------------------------------------------------
  // Dashboards.
  // -------------------------------------------------------------------------

  for (final device in [miniDevice, desktopDevice]) {
    final viewport = device.isPhone ? 'mobile' : 'desktop';
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;

      testWidgets('$viewport dashboards settings list — $theme', (
        tester,
      ) async {
        await _pumpScreen(
          tester,
          device: device,
          brightness: brightness,
          overrides: [
            allDashboardsStreamProvider.overrideWith(
              (ref) => Stream.value(_allDashboards),
            ),
          ],
          home: const DashboardSettingsPage(),
        );
        expect(
          find.text(_t('Colony operations', 'Koloniebetrieb')),
          findsOneWidget,
        );
        expect(
          find.text(_t('Mission readiness', 'Missionsbereitschaft')),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'dashboards_settings_list_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport dashboards settings detail — $theme', (
        tester,
      ) async {
        await _pumpScreen(
          tester,
          device: device,
          brightness: brightness,
          home: DashboardDefinitionPage(dashboard: _colonyOperations),
        );
        final messages = AppLocalizations.of(
          tester.element(find.byType(DashboardDefinitionPage)),
        )!;
        expect(
          find.text(messages.settingsDashboardDetailsLabel),
          findsOneWidget,
        );
        expect(
          find.text(_t('Colony operations', 'Koloniebetrieb')),
          findsOneWidget,
        );
        // The reorderable charts list renders one dismissible card per item.
        expect(find.byType(Dismissible), findsNWidgets(4));
        await captureScreenshot(
          tester,
          'dashboards_settings_detail_${viewport}_$theme',
          subdir: _subdir,
        );

        _alignInOuterScrollView(
          tester,
          find.text(messages.dashboardCurrentChartsTitle),
        );
        await settleFrames(tester);
        expect(
          find.text(
            _t(
              'Habitat pressure — Daily average',
              'Habitatdruck — Tagesdurchschnitt',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _t(
              'Sardines consumed — Daily sum',
              'Verzehrte Sardinen — Tagessumme',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _t(
              'Penguins accounted for — Daily sum',
              'Gezählte Pinguine — Tagessumme',
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('PANAS'), findsOneWidget);
        await captureScreenshot(
          tester,
          'dashboards_charts_${viewport}_$theme',
          subdir: _subdir,
        );

        _alignInOuterScrollView(
          tester,
          find.text(
            _t('Add charts by type', 'Diagramme nach Typ hinzufügen'),
          ),
        );
        await settleFrames(tester);
        expect(find.text(_t('Habits', 'Gewohnheiten')), findsOneWidget);
        expect(find.text(_t('Measurements', 'Messungen')), findsOneWidget);
        expect(find.text(_t('Health', 'Gesundheit')), findsOneWidget);
        await captureScreenshot(
          tester,
          'dashboards_sources_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport dashboards route list — $theme', (tester) async {
        navService
          ..isDesktopMode = !device.isPhone
          // Desktop is a master/detail surface, so keep the coherent Colony
          // operations example selected instead of publishing an empty detail
          // pane beside the populated list. Mobile remains the list-only
          // route and opens a dashboard on navigation.
          ..desktopSelectedDashboardId.value = device.isPhone
              ? null
              : _colonyOperations.id;
        await withClock(Clock.fixed(manualDemoNow), () async {
          await _pumpScreen(
            tester,
            device: device,
            brightness: brightness,
            overrides: [
              dashboardsProvider.overrideWith(
                (ref) => Stream.value(_allDashboards),
              ),
              dashboardCategoriesProvider.overrideWith(
                (ref) => Stream.value(_allCategories),
              ),
            ],
            home: const DashboardsListPage(),
          );
        });
        expect(
          find.text(_t('Colony operations', 'Koloniebetrieb')),
          device.isPhone ? findsOneWidget : findsNWidgets(2),
        );
        expect(
          find.text(_t('Mission readiness', 'Missionsbereitschaft')),
          findsOneWidget,
        );
        if (!device.isPhone) {
          expect(
            find.text(_t('Habitat pressure', 'Habitatdruck')),
            findsOneWidget,
          );
          expect(
            find.text(_t('Sardines consumed', 'Verzehrte Sardinen')),
            findsOneWidget,
          );
        }
        await captureScreenshot(
          tester,
          'dashboard_list_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport dashboard route view — $theme', (tester) async {
        navService
          ..isDesktopMode = !device.isPhone
          ..desktopSelectedDashboardId.value = _colonyOperations.id;
        await withClock(Clock.fixed(manualDemoNow), () async {
          await _pumpScreen(
            tester,
            device: device,
            brightness: brightness,
            overrides: [
              dashboardsProvider.overrideWith(
                (ref) => Stream.value(_allDashboards),
              ),
              dashboardCategoriesProvider.overrideWith(
                (ref) => Stream.value(_allCategories),
              ),
            ],
            home: device.isPhone
                ? const DashboardPage(dashboardId: 'dash-colony-operations')
                : const DashboardsListPage(),
          );
          await settleFrames(tester, 12);
        });
        expect(
          find.text(_t('Colony operations', 'Koloniebetrieb')),
          findsWidgets,
        );
        expect(
          find.text(_t('Habitat pressure', 'Habitatdruck')),
          findsOneWidget,
        );
        expect(
          find.text(_t('Sardines consumed', 'Verzehrte Sardinen')),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'dashboard_view_${viewport}_$theme',
          subdir: _subdir,
        );

        await tester.scrollUntilVisible(
          find.text(_t('Penguins accounted for', 'Gezählte Pinguine')),
          350,
          scrollable: find.byType(Scrollable).last,
        );
        await settleFrames(tester, 8);
        expect(
          find.text(_t('Penguins accounted for', 'Gezählte Pinguine')),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'dashboard_view_crew_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport PANAS survey — $theme', (tester) async {
        navService
          ..isDesktopMode = !device.isPhone
          ..desktopSelectedDashboardId.value = _colonyOperations.id;
        await withClock(Clock.fixed(manualDemoNow), () async {
          await _pumpScreen(
            tester,
            device: device,
            brightness: brightness,
            overrides: [
              dashboardsProvider.overrideWith(
                (ref) => Stream.value(_allDashboards),
              ),
              dashboardCategoriesProvider.overrideWith(
                (ref) => Stream.value(_allCategories),
              ),
            ],
            home: device.isPhone
                ? const DashboardPage(dashboardId: 'dash-colony-operations')
                : const DashboardsListPage(),
          );
          await settleFrames(tester, 12);
        });

        await tester.scrollUntilVisible(
          find.text('PANAS'),
          350,
          scrollable: find.byType(Scrollable).last,
        );
        await settleFrames(tester, 6);
        final surveyChart = find.byType(DashboardSurveyChart);
        expect(surveyChart, findsOneWidget);
        await tester.tap(
          find.descendant(
            of: surveyChart,
            matching: find.byIcon(Icons.add_rounded),
          ),
        );
        await settleFrames(tester, 8);

        final task = tester.widget<RPUITask>(find.byType(RPUITask));
        final messages = AppLocalizations.of(
          tester.element(find.byType(RPUITask)),
        )!;
        expect(task.task.identifier, 'panasSurveyTask');
        expect(find.text(messages.panasInstructionText), findsOneWidget);
        expect(find.text(messages.surveyNextButton), findsOneWidget);
        await captureScreenshot(
          tester,
          'survey_panas_intro_${viewport}_$theme',
          subdir: _subdir,
        );

        await tester.tap(find.text(messages.surveyNextButton));
        await settleFrames(tester, 8);
        expect(find.text(messages.panasEmotionInterested), findsOneWidget);
        expect(
          find.text(messages.panasScaleVerySlightlyOrNotAtAll),
          findsOneWidget,
        );
        expect(find.text(messages.panasScaleExtremely), findsOneWidget);
        await captureScreenshot(
          tester,
          'survey_panas_question_${viewport}_$theme',
          subdir: _subdir,
        );
      });
    }
  }
}
