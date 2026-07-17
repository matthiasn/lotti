/// Deterministic manual screenshots for the habits dashboard and completion
/// form. Generated PNGs are external staging inputs, not golden files.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_controller.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_data.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:lotti/utils/platform.dart' as platform;

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../daily_os_next/screenshot_harness.dart';
import '../test_utils.dart';

final _today = DateTime(2026, 7, 17);

final _penguinOps = CategoryDefinition(
  id: 'penguin-ops',
  name: 'Penguin Ops',
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

final HabitDefinition _inspectHabitatSeals = _habit(
  id: 'inspect-habitat-seals',
  name: 'Inspect habitat seals',
  description: 'Check the pressure seals before the colony wakes.',
);
final HabitDefinition _penguinRollCall = _habit(
  id: 'penguin-roll-call',
  name: 'Log penguin roll call',
  description: 'Confirm all 37 emperor penguins are aboard.',
);
final HabitDefinition _recalibrateFishFeeder = _habit(
  id: 'recalibrate-fish-feeder',
  name: 'Recalibrate fish feeder',
  description: 'Tune the zero-gravity feeder after the midday delivery.',
);
final HabitDefinition _reviewSardineInventory = _habit(
  id: 'review-sardine-inventory',
  name: 'Review sardine inventory',
  description: 'Reconcile consumed crates with the orbital manifest.',
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

        expect(find.text('Habits'), findsOneWidget);
        expect(find.text('Inspect habitat seals'), findsOneWidget);
        expect(find.text('Review sardine inventory'), findsOneWidget);
        await captureScreenshot(
          tester,
          'habits_today_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport habit completion — $theme', (tester) async {
        await _pumpHabitCompletion(
          tester,
          device: device,
          brightness: brightness,
        );

        expect(find.text('Inspect habitat seals'), findsOneWidget);
        expect(find.text('Success'), findsNWidgets(2));
        expect(find.text('Skip'), findsNWidgets(2));
        expect(find.text('Missed'), findsNWidgets(2));
        expect(find.byKey(const Key('habit_save')), findsOneWidget);
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
}) async {
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
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RepaintBoundary(
          key: screenshotBoundaryKey,
          child: HabitsTabPage(),
        ),
      ),
    ),
  );
  await settleFrames(tester, 8);
}

Future<void> _pumpHabitCompletion(
  WidgetTester tester, {
  required ScreenshotDevice device,
  required Brightness brightness,
}) async {
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
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      localizationsDelegates: _localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RepaintBoundary(
        key: screenshotBoundaryKey,
        child: Scaffold(
          body: HabitDialog(
            habitId: _inspectHabitatSeals.id,
            themeData: theme,
            // A past day resolves to the production form's deterministic
            // end-of-day timestamp instead of sampling the wall clock.
            dateString: '2026-07-16',
            showLinkedDashboard: false,
          ),
        ),
      ),
    ),
  );
  await settleFrames(tester, 6);
}

ThemeData _theme(Brightness brightness) => brightness == Brightness.dark
    ? DesignSystemTheme.dark()
    : DesignSystemTheme.light();

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  AppLocalizations.delegate,
  FormBuilderLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
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
    days: days,
    successfulByDay: successes,
    skippedByDay: {
      days[3]: {_recalibrateFishFeeder.id},
    },
    failedByDay: {
      days[8]: {_reviewSardineInventory.id},
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
      _recalibrateFishFeeder.id: 2,
      _reviewSardineInventory.id: 9,
    },
  );
}

String _ymd(DateTime date) => date.toIso8601String().substring(0, 10);
