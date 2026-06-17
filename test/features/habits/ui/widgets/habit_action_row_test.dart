import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late MockEntitiesCacheService mockCacheService;
  late MockPersistenceLogic mockPersistenceLogic;

  setUpAll(() {
    registerFallbackValue(FakeHabitCompletionData());
  });

  setUp(() async {
    // Quick-complete and swipe paths await HapticFeedback.lightImpact(); without
    // a platform-channel handler that future never resolves and the persistence
    // call that follows it is never reached.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (methodCall) async => null,
        );
    await setUpTestGetIt(
      additionalSetup: () {
        mockCacheService = MockEntitiesCacheService();
        mockPersistenceLogic = MockPersistenceLogic();

        when(
          () => mockCacheService.getHabitById(habitFlossing.id),
        ).thenReturn(habitFlossing);
        when(() => mockCacheService.getCategoryById(any())).thenReturn(null);

        when(
          () => mockPersistenceLogic.createHabitCompletionEntry(
            data: any(named: 'data'),
            comment: any(named: 'comment'),
            habitDefinition: any(named: 'habitDefinition'),
          ),
        ).thenAnswer((_) async => null);

        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(
            mockJournalDbWithHabits([habitFlossing]),
          )
          ..registerSingleton<EntitiesCacheService>(mockCacheService)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await tearDownTestGetIt();
  });

  Future<void> pumpRow(
    WidgetTester tester, {
    HabitDefinition? habit,
    bool completedToday = false,
    int currentStreak = 0,
    Widget? history,
    bool showLinkedDashboard = true,
    List<Override> extraOverrides = const [],
  }) async {
    final definition = habit ?? habitFlossing;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        HabitActionRow(
          habitId: definition.id,
          completedToday: completedToday,
          currentStreak: currentStreak,
          history: history,
          showLinkedDashboard: showLinkedDashboard,
        ),
        overrides: extraOverrides,
      ),
    );
    await tester.pump();
  }

  HabitCompletionData captureCompletionData() {
    return verify(
          () => mockPersistenceLogic.createHabitCompletionEntry(
            data: captureAny(named: 'data'),
            comment: any(named: 'comment'),
            habitDefinition: any(named: 'habitDefinition'),
          ),
        ).captured.single
        as HabitCompletionData;
  }

  group('missing habit', () {
    testWidgets('renders nothing when the habit is unknown', (tester) async {
      when(() => mockCacheService.getHabitById('unknown')).thenReturn(null);
      await pumpRow(tester, habit: habitFlossing.copyWith(id: 'unknown'));
      expect(find.byType(Dismissible), findsNothing);
      expect(find.text(habitFlossing.name), findsNothing);
    });
  });

  group('name and priority', () {
    testWidgets('renders the habit name', (tester) async {
      await pumpRow(tester);
      expect(find.text(habitFlossing.name), findsOneWidget);
    });

    for (final priority in [true, false]) {
      testWidgets('priority star ${priority ? 'shown' : 'hidden'}', (
        tester,
      ) async {
        final habit = habitFlossing.copyWith(
          id: 'priority-$priority',
          priority: priority,
        );
        when(() => mockCacheService.getHabitById(habit.id)).thenReturn(habit);
        await pumpRow(tester, habit: habit);
        expect(
          find.byIcon(Icons.star_rounded),
          priority ? findsOneWidget : findsNothing,
        );
      });
    }
  });

  group('history slot', () {
    testWidgets('renders the history widget when provided', (tester) async {
      await pumpRow(
        tester,
        history: const SizedBox(key: Key('history-slot')),
      );
      expect(find.byKey(const Key('history-slot')), findsOneWidget);
    });

    testWidgets('omits history when none is supplied', (tester) async {
      await pumpRow(tester);
      expect(find.byKey(const Key('history-slot')), findsNothing);
      // The body still renders without a history slot.
      expect(find.text(habitFlossing.name), findsOneWidget);
    });
  });

  group('streak chip', () {
    testWidgets('shows a flame + count for a streak of 2 or more', (
      tester,
    ) async {
      await pumpRow(tester, currentStreak: 12);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('hides the chip for a streak below 2', (tester) async {
      await pumpRow(tester, currentStreak: 1);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
    });

    testWidgets('counts up rather than snapping when the chain grows', (
      tester,
    ) async {
      await pumpRow(tester, currentStreak: 22);
      expect(find.text('22'), findsOneWidget);

      await pumpRow(tester, currentStreak: 23);
      await tester.pump(const Duration(milliseconds: 40));
      // Still counting toward 23, not snapped.
      expect(find.text('23'), findsNothing);

      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('23'), findsOneWidget);
    });
  });

  group('completion flash', () {
    final flash = find.byKey(const ValueKey('habit-completion-flash'));

    testWidgets('flashes an accent glow on completion, then fades out', (
      tester,
    ) async {
      await pumpRow(tester);
      expect(flash, findsNothing);

      // Flip to done in place → the one-shot glow fires.
      await pumpRow(tester, completedToday: true);
      await tester.pump(const Duration(milliseconds: 40));
      expect(flash, findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      expect(flash, findsNothing);
    });

    testWidgets('a row already done on first build does not flash', (
      tester,
    ) async {
      await pumpRow(tester, completedToday: true);
      await tester.pump(const Duration(milliseconds: 40));
      expect(flash, findsNothing);
    });
  });

  group('trailing complete button', () {
    testWidgets('not done → hollow "+" ring that records a success', (
      tester,
    ) async {
      await pumpRow(tester);
      // Hollow add ring, never the completed check-circle.
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.pump();

      final data = captureCompletionData();
      expect(data.completionType, HabitCompletionType.success);
      expect(data.habitId, habitFlossing.id);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(habitFlossing.name),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the icon swap is driven through an AnimatedSwitcher (pop)', (
      tester,
    ) async {
      await pumpRow(tester);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsWidgets);

      // Rebuild in place with the habit now done → the check settles in and the
      // "+" is gone once the ~320ms switch completes.
      await pumpRow(tester, completedToday: true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
    });

    testWidgets('done → circle check that opens the dialog, no duplicate', (
      tester,
    ) async {
      await pumpRow(tester, completedToday: true);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verifyNever(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: any(named: 'habitDefinition'),
        ),
      );
      expect(find.byType(HabitDialog), findsOneWidget);
    });
  });

  group('row body tap', () {
    testWidgets('opens the HabitDialog for the habit', (tester) async {
      await pumpRow(tester);
      await tester.tap(find.text(habitFlossing.name));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final dialog = tester.widget<HabitDialog>(find.byType(HabitDialog));
      expect(dialog.habitId, habitFlossing.id);
    });
  });

  group('swipe gestures', () {
    final swipeRow = find.byKey(
      ValueKey<String>('habit-swipe-${habitFlossing.id}'),
    );

    testWidgets('swipe right records a success', (tester) async {
      await pumpRow(tester);
      await tester.drag(swipeRow, const Offset(600, 0));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        captureCompletionData().completionType,
        HabitCompletionType.success,
      );
      expect(swipeRow, findsOneWidget); // snaps back, never removed
    });

    testWidgets('swipe left records a miss', (tester) async {
      await pumpRow(tester);
      await tester.drag(swipeRow, const Offset(-600, 0));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(captureCompletionData().completionType, HabitCompletionType.fail);
      expect(swipeRow, findsOneWidget);
    });
  });

  group('linked dashboard', () {
    testWidgets('passes showLinkedDashboard through to the dialog', (
      tester,
    ) async {
      final dashboardHabit = habitFlossing.copyWith(dashboardId: 'dash-1');
      when(
        () => mockCacheService.getHabitById(dashboardHabit.id),
      ).thenReturn(dashboardHabit);
      when(
        () => mockCacheService.getDashboardById('dash-1'),
      ).thenReturn(null);

      await pumpRow(
        tester,
        habit: dashboardHabit,
        extraOverrides: [
          dashboardByIdProvider('dash-1').overrideWithValue(null),
        ],
      );

      await tester.tap(find.text(dashboardHabit.name));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final dialog = tester.widget<HabitDialog>(find.byType(HabitDialog));
      expect(dialog.habitId, dashboardHabit.id);
      expect(dialog.showLinkedDashboard, isTrue);
    });
  });
}
