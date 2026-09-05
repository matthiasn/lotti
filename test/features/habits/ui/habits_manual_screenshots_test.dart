/// Deterministic manual screenshots for the habits dashboard and completion
/// form. Generated PNGs are external staging inputs, not golden files.
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/habits/model/habit_completion_record.dart';
import 'package:lotti/features/habits/state/habit_editor_providers.dart';
import 'package:lotti/features/habits/state/habit_signal_status_controller.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_controller.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_data.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';
import 'package:lotti/features/habits/ui/pages/habit_editor_page.dart';
import 'package:lotti/features/habits/ui/sheets/habit_completion_sheet.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_signal_card.dart';
import 'package:lotti/features/habits/ui/widgets/habit_signal_row.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/signals/habit_rule_evaluator.dart';
import 'package:lotti/logic/signals/signal_window.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:material_ui/material_ui.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../daily_os_next/screenshot_harness.dart';
import '../test_utils.dart';

final _today = DateTime(2026, 7, 17);
String _t(String en, String de) => manualScreenshotText(en: en, de: de);

AppLocalizations _messages(WidgetTester tester) {
  final habitsPage = find.byType(HabitsTabPage);
  final editor = find.byType(HabitEditorPage);
  final context = habitsPage.evaluate().isNotEmpty
      ? tester.element(habitsPage)
      : editor.evaluate().isNotEmpty
      ? tester.element(editor)
      : tester.element(find.byType(HabitCompletionSheet));
  return AppLocalizations.of(context)!;
}

final _penguinOps = CategoryDefinition(
  id: 'penguin-ops',
  name: _t('Penguin Ops', 'Pinguinbetrieb'),
  color: '#34A889',
  createdAt: _today,
  updatedAt: _today,
  vectorClock: null,
  active: true,
  private: false,
);

HabitDefinition _habit({
  required String id,
  required String name,
  required String description,
}) => HabitDefinition(
  id: id,
  name: name,
  description: description,
  createdAt: DateTime(2026),
  updatedAt: _today,
  vectorClock: null,
  habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  active: true,
  private: false,
  activeFrom: DateTime(2026),
  categoryId: _penguinOps.id,
);

final _krillRations = MeasurableDataType(
  id: 'krill-rations',
  displayName: _t('Krill rations', 'Krillrationen'),
  description: '',
  unitName: 'kg',
  version: 1,
  createdAt: DateTime(2026),
  updatedAt: _today,
  vectorClock: null,
  aggregationType: AggregationType.dailySum,
);

final _hydrationCheck = MeasurableDataType(
  id: 'hydration-check',
  displayName: _t('Hydration check', 'Hydrationscheck'),
  description: '',
  unitName: '',
  version: 1,
  createdAt: DateTime(2026),
  updatedAt: _today,
  vectorClock: null,
  valueKind: MeasurableValueKind.choice,
  choices: [
    MeasurableChoice(id: 'hyd-clear', title: _t('Clear', 'Klar')),
    MeasurableChoice(id: 'hyd-pale', title: _t('Pale yellow', 'Hellgelb')),
    MeasurableChoice(id: 'hyd-dark', title: _t('Dark yellow', 'Dunkelgelb')),
  ],
);

final HabitDefinition _inspectHabitatSeals =
    _habit(
      id: 'inspect-habitat-seals',
      name: _t('Inspect habitat seals', 'Habitatdichtungen inspizieren'),
      description: _t(
        'Check the pressure seals before the colony wakes.',
        'Prüfe die Druckdichtungen, bevor die Kolonie aufwacht.',
      ),
    ).copyWith(
      autoCompleteRule: AutoCompleteRule.and(
        rules: [
          AutoCompleteRule.measurable(dataTypeId: _krillRations.id, minimum: 3),
          AutoCompleteRule.measurable(dataTypeId: _hydrationCheck.id),
          const AutoCompleteRule.health(
            dataType: 'cumulative_step_count',
            minimum: 6000,
          ),
        ],
      ),
    );

/// The instant every capture is taken at, so dates and times in the sheet
/// are the same on every run.
final _captureNow = DateTime(2026, 7, 17, 8, 12);
final _todayKey = DateTime.utc(2026, 7, 17);

/// A fixed two-week window for the seals habit: krill logged most days, steps
/// short of the target today.
class _FixedSignalStatus extends HabitSignalStatusController {
  _FixedSignalStatus(super.habitId);

  @override
  Future<HabitSignalStatus?> build() async {
    final rule = _inspectHabitatSeals.autoCompleteRule!;
    final krill = <DateTime, num>{};
    final hydration = <DateTime, num>{};
    final steps = <DateTime, num>{};
    const krillByOffset = [2, 4, 3, null, 5, 3, 4, 2, null, 4, 3, 5, 4, 2];
    const stepsByOffset = [
      5200,
      7100,
      6400,
      3900,
      8200,
      6900,
      7400,
      4100,
      6600,
      7800,
      5900,
      6100,
      9100,
      4120,
    ];
    for (var i = 0; i < 14; i++) {
      final day = _todayKey.subtract(Duration(days: 13 - i));
      if (krillByOffset[i] != null) krill[day] = krillByOffset[i]!;
      // Checked most mornings, not yet today.
      if (i % 5 != 2 && i != 13) hydration[day] = 1;
      steps[day] = stepsByOffset[i];
    }
    final window = SignalWindow(
      start: _todayKey.subtract(const Duration(days: 13)),
      end: _todayKey,
      measurableTotalsByDay: {
        _krillRations.id: krill,
        _hydrationCheck.id: hydration,
      },
      quantitativeByDay: {'cumulative_step_count': steps},
    );
    return HabitSignalStatus(
      rule: rule,
      window: window,
      verdict: const HabitRuleEvaluator().evaluate(
        rule: rule,
        window: window,
        day: _todayKey,
      ),
      today: _todayKey,
    );
  }
}

class _FixedSuggestions extends MeasurableSuggestionsController {
  _FixedSuggestions() : super('krill-rations');

  @override
  Future<List<num>?> build() async => [3, 5, 8];
}

final HabitDefinition _penguinRollCall = _habit(
  id: 'penguin-roll-call',
  name: _t('Log penguin roll call', 'Pinguin-Zählappell protokollieren'),
  description: _t(
    'Confirm all 37 emperor penguins are aboard.',
    'Bestätige, dass alle 37 Kaiserpinguine an Bord sind.',
  ),
);
final HabitDefinition _recalibrateFishFeeder = _habit(
  id: 'recalibrate-fish-feeder',
  name: _t('Recalibrate fish feeder', 'Futterautomaten neu kalibrieren'),
  description: _t(
    'Tune the zero-gravity feeder after the midday delivery.',
    'Stimme den Schwerelos-Futterautomaten nach der Mittagslieferung ab.',
  ),
);
final HabitDefinition _reviewSardineInventory = _habit(
  id: 'review-sardine-inventory',
  name: _t('Review sardine inventory', 'Sardinenbestand prüfen'),
  description: _t(
    'Reconcile consumed crates with the orbital manifest.',
    'Gleiche verbrauchte Kisten mit dem Orbitalmanifest ab.',
  ),
);
final List<HabitDefinition> _habits = [
  _inspectHabitatSeals,
  _penguinRollCall,
  _recalibrateFishFeeder,
  _reviewSardineInventory,
];

class _FixedHeatmapController extends HabitHeatmapController {
  _FixedHeatmapController(this.data);

  final HabitHeatmapData data;

  @override
  HabitHeatmapData build() => data;
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'habits manual screenshot harness (opt-in)',
      () {},
      skip: 'Set LOTTI_SCREENSHOT_DIR to capture manual screenshots.',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  setUp(() async {
    final mocks = await setUpTestGetIt();
    final cache =
        EntitiesCacheService(
            journalDb: mocks.journalDb,
            updateNotifications: mocks.updateNotifications,
          )
          ..categoriesById[_penguinOps.id] = _penguinOps
          ..dataTypesById[_krillRations.id] = _krillRations
          ..dataTypesById[_hydrationCheck.id] = _hydrationCheck
          ..habitsById.addEntries(
            _habits.map((habit) => MapEntry(habit.id, habit)),
          );
    getIt
      ..registerSingleton<EntitiesCacheService>(cache)
      ..registerSingleton<UserActivityService>(UserActivityService())
      ..registerSingleton<PersistenceLogic>(MockPersistenceLogic());
  });

  tearDown(tearDownTestGetIt);

  for (final device in [proDevice, desktopDevice]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final viewport = device.isPhone ? 'mobile' : 'desktop';
      final theme = brightness.name;

      testWidgets('$viewport habits today — $theme', (tester) async {
        await _pumpHabitsDashboard(
          tester,
          device: device,
          brightness: brightness,
        );

        expect(
          find.text(_messages(tester).settingsHabitsTitle),
          findsOneWidget,
        );
        expect(
          find.text(
            _t('Inspect habitat seals', 'Habitatdichtungen inspizieren'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(_t('Review sardine inventory', 'Sardinenbestand prüfen')),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'habits_today_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport habit editor step 1 — $theme', (tester) async {
        await _pumpHabitEditor(tester, device: device, brightness: brightness);
        expect(
          find.text(_messages(tester).habitEditorNameHeading),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'habit_editor_step1_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport habit editor step 2 — $theme', (tester) async {
        await _pumpHabitEditor(
          tester,
          device: device,
          brightness: brightness,
          signalsStep: true,
        );
        expect(
          find.text(_messages(tester).habitEditorSignalsHeading),
          findsOneWidget,
        );
        expect(find.byType(HabitSignalCard), findsOneWidget);
        await captureScreenshot(
          tester,
          'habit_editor_step2_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport habit completion — $theme', (tester) async {
        await _pumpHabitCompletion(
          tester,
          device: device,
          brightness: brightness,
        );

        expect(
          find.text(
            _t('Inspect habitat seals', 'Habitatdichtungen inspizieren'),
          ),
          findsOneWidget,
        );
        final messages = _messages(tester);
        expect(
          find.text(messages.completeHabitSuccessButton),
          findsNWidgets(2),
        );
        expect(
          find.text(messages.completeHabitSkipButton),
          findsNWidgets(2),
        );
        expect(
          find.text(messages.completeHabitFailButton),
          findsNWidgets(2),
        );
        expect(find.byKey(const Key('habit_save')), findsOneWidget);
        expect(find.byType(HabitSignalRow), findsNWidgets(3));
        await captureScreenshot(
          tester,
          'habits_record_${viewport}_$theme',
          subdir: 'manual',
        );
      });
    }
  }
}

Future<void> _pumpHabitsDashboard(
  WidgetTester tester, {
  required ScreenshotDevice device,
  required Brightness brightness,
}) => withClock(Clock.fixed(_captureNow), () async {
  applyScreenshotDevice(tester, device);
  final state = _habitsState();
  final controller = FakeHabitsController(state);
  final theme = _theme(brightness);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitsControllerProvider.overrideWith(() => controller),
        habitHeatmapControllerProvider.overrideWith(
          () => _FixedHeatmapController(_heatmapData()),
        ),
        firstDayOfWeekIndexProvider.overrideWith((ref) => DateTime.monday),
        celebrationPreferencesProvider.overrideWithValue(
          const CelebrationPreferences.allEnabled().copyWith(enabled: false),
        ),
      ],
      child: MaterialApp(
        builder: LegacyMaterialBridge.builder,
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: manualScreenshotLocale,
        home: const RepaintBoundary(
          key: screenshotBoundaryKey,
          child: HabitsTabPage(),
        ),
      ),
    ),
  );
  await settleFrames(tester, 8);
});

Future<void> _pumpHabitCompletion(
  WidgetTester tester, {
  required ScreenshotDevice device,
  required Brightness brightness,
}) => withClock(Clock.fixed(_captureNow), () async {
  applyScreenshotDevice(tester, device);
  final originalIsMobile = platform.isMobile;
  final originalIsDesktop = platform.isDesktop;
  platform.isMobile = device.isPhone;
  platform.isDesktop = !device.isPhone;
  addTearDown(() {
    platform.isMobile = originalIsMobile;
    platform.isDesktop = originalIsDesktop;
  });
  final theme = _theme(brightness);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitSignalStatusProvider(
          _inspectHabitatSeals.id,
        ).overrideWith(() => _FixedSignalStatus(_inspectHabitatSeals.id)),
        measurableSuggestionsControllerProvider(
          _krillRations.id,
        ).overrideWith(_FixedSuggestions.new),
      ],
      child: MaterialApp(
        builder: LegacyMaterialBridge.builder,
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: manualScreenshotLocale,
        home: RepaintBoundary(
          key: screenshotBoundaryKey,
          child: Scaffold(
            body: HabitCompletionSheet(
              habitId: _inspectHabitatSeals.id,
              themeData: theme,
              // "Today" under the fixed capture clock, so the signal rows
              // show and the date field is deterministic.
              dateString: '2026-07-17',
            ),
          ),
        ),
      ),
    ),
  );
  await settleFrames(tester, 6);
});

ThemeData _theme(Brightness brightness) => brightness == Brightness.dark
    ? DesignSystemTheme.dark()
    : DesignSystemTheme.light();

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  AppLocalizations.delegate,
  FormBuilderLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

HabitsState _habitsState() {
  final days = [
    for (var offset = 13; offset >= 0; offset--)
      _ymd(_today.subtract(Duration(days: offset))),
  ];
  final allIds = _habits.map((habit) => habit.id).toSet();
  final successes = <String, Set<String>>{
    for (var index = 0; index < days.length; index++)
      days[index]: index.isEven
          ? {
              _inspectHabitatSeals.id,
              _reviewSardineInventory.id,
              _penguinRollCall.id,
            }
          : {_inspectHabitatSeals.id, _penguinRollCall.id},
  };

  return HabitsState.initial().copyWith(
    habitDefinitions: _habits,
    openHabits: [
      _inspectHabitatSeals,
      _penguinRollCall,
      _recalibrateFishFeeder,
    ],
    openNow: [_inspectHabitatSeals, _penguinRollCall],
    pendingLater: [_recalibrateFishFeeder],
    completed: [_reviewSardineInventory],
    completedToday: {_reviewSardineInventory.id},
    successfulToday: {_reviewSardineInventory.id},
    autoCompletedToday: {_reviewSardineInventory.id: 'Steps · 7412'},
    habitCompletions: [
      HabitCompletionRecord(
        habitId: _reviewSardineInventory.id,
        dateFrom: DateTime(2026, 7, 17, 7, 58),
        completionType: HabitCompletionType.success,
        source: HabitCompletionSource.auto,
        autoCompleteReason: 'Steps · 7412',
      ),
    ],
    days: days,
    successfulByDay: successes,
    skippedByDay: {
      days[3]: {_recalibrateFishFeeder.id},
    },
    failedByDay: {
      days[9]: {_reviewSardineInventory.id},
      days[10]: {_recalibrateFishFeeder.id},
    },
    allByDay: {for (final day in days) day: allIds},
    shortStreakCount: 2,
    longStreakCount: 1,
    displayFilter: HabitDisplayFilter.all,
    minY: 25,
  );
}

HabitHeatmapData _heatmapData() {
  final days = [
    for (var offset = 83; offset >= 0; offset--)
      HeatmapDay(
        ymd: _ymd(_today.subtract(Duration(days: offset))),
        successCount: offset % 9 == 0 ? 2 : 3,
        activeCount: 4,
        isToday: offset == 0,
      ),
  ];
  return HabitHeatmapData(
    days: days,
    hasHabits: true,
    isLoading: false,
    streaksByHabit: {
      _inspectHabitatSeals.id: 6,
      _penguinRollCall.id: 4,
      _recalibrateFishFeeder.id: 0,
      _reviewSardineInventory.id: 9,
    },
  );
}

String _ymd(DateTime date) => date.toIso8601String().substring(0, 10);

/// The create wizard under the fixed clock: step 1 as it opens, or step 2
/// after the "6,000 steps" example filled the name and pre-checked Steps.
Future<void> _pumpHabitEditor(
  WidgetTester tester, {
  required ScreenshotDevice device,
  required Brightness brightness,
  bool signalsStep = false,
}) => withClock(Clock.fixed(_captureNow), () async {
  applyScreenshotDevice(tester, device);
  final theme = _theme(brightness);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        measurableDataTypesStreamProvider.overrideWith(
          (ref) => Stream.value([_krillRations, _hydrationCheck]),
        ),
        workoutTypesProvider.overrideWith(
          (ref) async => ['functionalStrengthTraining', 'running'],
        ),
      ],
      child: MaterialApp(
        builder: LegacyMaterialBridge.builder,
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: manualScreenshotLocale,
        home: const RepaintBoundary(
          key: screenshotBoundaryKey,
          child: AppCommandHost(
            handlers: {},
            child: HabitEditorPage(),
          ),
        ),
      ),
    ),
  );
  await settleFrames(tester, 6);
  if (!signalsStep) return;
  await tester.tap(find.byKey(const ValueKey('habit-editor-example-1')));
  await settleFrames(tester, 2);
  await tester.tap(find.byKey(const ValueKey('habit-editor-primary')));
  await settleFrames(tester, 4);
});
