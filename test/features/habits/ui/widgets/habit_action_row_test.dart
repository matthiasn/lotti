import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/colors.dart';
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
        ).thenAnswer((_) async => testHabitCompletionEntry);

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
    bool reduceMotion = false,
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
        mediaQueryData: reduceMotion
            ? phoneMediaQueryData.copyWith(disableAnimations: true)
            : null,
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

  group('streak chain', () {
    Finder greenBoxes() => find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color == successColor,
    );

    testWidgets('shows one green box per kept day, plus the flame + count', (
      tester,
    ) async {
      await pumpRow(tester, currentStreak: 3);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(greenBoxes(), findsNWidgets(3));
    });

    testWidgets('shows nothing when there is no current streak', (
      tester,
    ) async {
      await pumpRow(tester);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
      expect(greenBoxes(), findsNothing);
    });

    testWidgets('a long streak keeps the true count but caps the chain', (
      tester,
    ) async {
      await pumpRow(tester, currentStreak: 41);
      // The flame count is always the real length...
      expect(find.text('41'), findsOneWidget);
      // ...but the chain is capped (and never exceeds 30 boxes).
      final boxes = greenBoxes().evaluate().length;
      expect(boxes, greaterThan(0));
      expect(boxes, lessThanOrEqualTo(30));
    });

    testWidgets('extends with a new box when the streak grows', (tester) async {
      await pumpRow(tester, currentStreak: 5);
      expect(greenBoxes(), findsNWidgets(5));

      // Grow in place → the chain gains a box (which pops in); let it settle.
      await pumpRow(tester, currentStreak: 6);
      await tester.pump(const Duration(milliseconds: 500));
      expect(greenBoxes(), findsNWidgets(6));
      expect(find.text('6'), findsOneWidget);
    });
  });

  group('completion flash', () {
    final flash = find.byKey(const ValueKey('habit-completion-flash'));

    testWidgets('glow is staged in — fires after the check, then fades out', (
      tester,
    ) async {
      await pumpRow(tester);
      expect(flash, findsNothing);

      // Flip to done in place → the celebration timeline starts, but the glow
      // is windowed to begin ~76ms in (the check pops first), so it is not yet
      // visible at 40ms.
      await pumpRow(tester, completedToday: true);
      await tester.pump(const Duration(milliseconds: 40));
      expect(flash, findsNothing);

      // Into the glow's window now.
      await tester.pump(const Duration(milliseconds: 180));
      expect(flash, findsOneWidget);

      // Past the end of the timeline → gone.
      await tester.pump(const Duration(milliseconds: 900));
      expect(flash, findsNothing);
    });

    testWidgets('a row already done on first build does not flash', (
      tester,
    ) async {
      await pumpRow(tester, completedToday: true);
      await tester.pump(const Duration(milliseconds: 40));
      expect(flash, findsNothing);
    });

    testWidgets('spark burst origin tracks card width to stay on the button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<double> burstOriginX(double width) async {
        Widget rowAt({required bool done}) => makeTestableWidgetWithScaffold(
          SizedBox(
            width: width,
            child: HabitActionRow(
              habitId: habitFlossing.id,
              completedToday: done,
            ),
          ),
        );

        await tester.pumpWidget(rowAt(done: false));
        await tester.pump();
        await tester.pumpWidget(rowAt(done: true)); // flip → celebration starts
        await tester.pump(const Duration(milliseconds: 220)); // burst window
        final burst = tester.widget<CompletionBurst>(
          find.byType(CompletionBurst),
        );
        expect(burst.origin.y, 0);
        await tester.pump(const Duration(milliseconds: 1400)); // settle
        return burst.origin.x;
      }

      final narrow = await burstOriginX(500);
      final wide = await burstOriginX(1000);

      // A wider card pushes the trailing button toward the edge, so the burst
      // origin shifts right to stay on it — never past the edge, and clearly
      // rightward of the old fixed 0.82 on a wide card.
      expect(wide, greaterThan(narrow));
      expect(wide, lessThanOrEqualTo(1.0));
      expect(wide, greaterThan(0.9));
    });

    testWidgets('reduced motion: static glow, but no spark burst', (
      tester,
    ) async {
      await pumpRow(tester, reduceMotion: true);
      await pumpRow(tester, completedToday: true, reduceMotion: true);

      // The spark burst never renders under reduced motion...
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(CompletionBurst), findsNothing);
      // ...but the glow still acknowledges the completion (opacity-only).
      expect(flash, findsOneWidget);

      // Settles to the done state with the glow gone.
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
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

    testWidgets(
      'tapping complete fires the celebration before the data flips',
      (
        tester,
      ) async {
        await pumpRow(tester); // not done
        expect(find.byType(CompletionBurst), findsNothing);

        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pump(); // establish the animation start
        // Into the burst window while completedToday is STILL false — the
        // celebration is optimistic (driven by the tap), not gated on the
        // provider catching up after the persist + recompute.
        await tester.pump(const Duration(milliseconds: 220));
        expect(find.byType(CompletionBurst), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1400)); // settle
      },
    );

    testWidgets('a failed persist clears the flag so a later one celebrates', (
      tester,
    ) async {
      // PersistenceLogic returns null when the write doesn't commit (it logs the
      // cause itself), so the `completedToday` flip that would consume the
      // optimistic flag never arrives — the row must clear it on its own.
      when(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: any(named: 'habitDefinition'),
        ),
      ).thenAnswer((_) async => null);

      await pumpRow(tester); // not done
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump(); // haptic + the (failing) persist resolve
      await tester.pump(const Duration(milliseconds: 1400)); // settle the burst

      // A failed write records nothing, so no success SnackBar is shown.
      expect(find.byType(SnackBar), findsNothing);

      // The flag was cleared, so a later real completion (from the dialog / a
      // sync) must still celebrate — it isn't suppressed.
      await pumpRow(tester, completedToday: true);
      await tester.pump(); // establish
      await tester.pump(const Duration(milliseconds: 220)); // burst window
      expect(find.byType(CompletionBurst), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1400)); // settle
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

  group('long-press the + button', () {
    testWidgets('opens the dialog (to log another day), not a quick-complete', (
      tester,
    ) async {
      await pumpRow(tester);
      await tester.longPress(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Opens the date-picker dialog rather than silently logging today.
      verifyNever(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: any(named: 'habitDefinition'),
        ),
      );
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
