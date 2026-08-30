import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_selection.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:lotti/features/design_system/components/celebration/completion_glow.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/ui/sheets/habit_completion_sheet.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_cell.dart';
import 'package:lotti/widgets/day_indicators/day_mark_strip.dart';
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
    bool autoCompleted = false,
    String? autoCompleteReason,
    String? autoCompletedAt,
    int currentStreak = 0,
    List<DayMark> history = const [],
    bool reduceMotion = false,
    List<Override> extraOverrides = const [],
  }) async {
    final definition = habit ?? habitFlossing;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        HabitActionRow(
          habitId: definition.id,
          completedToday: completedToday,
          autoCompleted: autoCompleted,
          autoCompleteReason: autoCompleteReason,
          autoCompletedAt: autoCompletedAt,
          currentStreak: currentStreak,
          history: history,
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
          find.byIcon(LottiIcons.star),
          priority ? findsOneWidget : findsNothing,
        );
      });
    }
  });

  group('history strip', () {
    final today = DateTime(2026, 8, 11);
    List<DayMark> week(List<DayMarkState> states) => [
      for (var i = 0; i < states.length; i++)
        DayMark(
          day: today.subtract(Duration(days: states.length - 1 - i)),
          state: states[i],
        ),
    ];
    Finder squares() => find.byType(DayMarkCell);

    testWidgets('draws one dated square per history day under the name, kept '
        'days in the interactive fill', (tester) async {
      await pumpRow(
        tester,
        history: week(const [
          DayMarkState.full,
          DayMarkState.none,
          DayMarkState.missed,
          DayMarkState.skipped,
          DayMarkState.none,
          DayMarkState.full,
          DayMarkState.full,
        ]),
      );
      expect(squares(), findsNWidgets(7));
      expect(
        tester.getTopLeft(squares().first).dy,
        greaterThan(tester.getBottomLeft(find.text(habitFlossing.name)).dy),
      );
      final tokens = tester.element(find.byType(HabitActionRow)).designTokens;
      Color fillAt(int index) =>
          (tester
                      .widget<Container>(
                        find.descendant(
                          of: squares().at(index),
                          matching: find.byType(Container),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;
      expect(fillAt(0), tokens.colors.interactive.enabled);
      expect(fillAt(1), tokens.colors.background.level03);
      expect(fillAt(2), tokens.colors.background.level03);
      expect(fillAt(3), tokens.colors.background.level03);
      expect(find.byIcon(LottiIcons.streak), findsNothing);
    });

    testWidgets('a square opens the completion sheet for ITS day, and the '
        'weekday initials say which day each square is', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester, history: week(List.filled(7, DayMarkState.none)));
      // Four days back from the last square, on a strip that ends on a
      // Tuesday: the sheet must open on that Friday, not on today.
      final friday = today.subtract(const Duration(days: 4));
      expect(find.text('F'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Fri, Aug 7')), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is DayMarkCell && widget.mark.day == friday,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final sheet = tester.widget<HabitCompletionSheet>(
        find.byType(HabitCompletionSheet),
      );
      expect(sheet.habitId, habitFlossing.id);
      expect(sheet.dateString, '2026-08-07');
      expect(DateTime.parse(sheet.dateString!), friday);
      handle.dispose();
    });

    testWidgets('a square for a day after today is not a button at all', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await withClock(Clock.fixed(today), () async {
        final tomorrow = today.add(const Duration(days: 1));
        await pumpRow(
          tester,
          history: [
            DayMark(day: today, state: DayMarkState.none, isToday: true),
            DayMark(day: tomorrow, state: DayMarkState.none),
          ],
        );
        // Read-only: no activation callback, no semantic button, no ink.
        final future = find.byWidgetPredicate(
          (widget) => widget is DayMarkCell && widget.mark.day == tomorrow,
        );
        expect(tester.widget<DayMarkCell>(future).onTap, isNull);
        expect(find.bySemanticsLabel(RegExp('Wed, Aug 12')), findsNothing);
        expect(
          find.descendant(of: future, matching: find.byType(InkWell)),
          findsNothing,
        );
        await tester.tap(
          find.byWidgetPredicate(
            (widget) => widget is DayMarkCell && widget.mark.day == today,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester
              .widget<HabitCompletionSheet>(find.byType(HabitCompletionSheet))
              .dateString,
          '2026-08-11',
        );
      });
      handle.dispose();
    });

    testWidgets('the strip shows a week on a phone and two on a desktop '
        'window', (tester) async {
      late int phoneDays;
      late int desktopDays;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              phoneDays = habitHistoryDays(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              desktopDays = habitHistoryDays(context);
              return const SizedBox.shrink();
            },
          ),
          mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        ),
      );
      expect(phoneDays, 7);
      expect(desktopDays, kHabitHistoryDaysDesktop);
      expect(kHabitHistoryDaysDesktop, 14);
    });

    testWidgets('no history and no streak draws no strip', (tester) async {
      await pumpRow(tester);
      expect(find.byType(DayMarkStrip), findsNothing);
      expect(find.text(habitFlossing.name), findsOneWidget);
    });

    testWidgets('the streak rides the strip as a flame and the exact count', (
      tester,
    ) async {
      await pumpRow(
        tester,
        history: week(List.filled(7, DayMarkState.full)),
        currentStreak: 41,
      );
      expect(squares(), findsNWidgets(7));
      expect(find.byIcon(LottiIcons.streak), findsOneWidget);
      expect(find.text('41'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byIcon(LottiIcons.streak)).dx,
        greaterThan(tester.getTopRight(squares().last).dx),
      );
    });

    testWidgets('a streak with no history still shows its tail', (
      tester,
    ) async {
      await pumpRow(tester, currentStreak: 3);
      expect(squares(), findsNothing);
      expect(find.byIcon(LottiIcons.streak), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
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
      expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
      expect(flash, findsNothing);
    });
  });

  group('trailing complete button', () {
    testWidgets('not done → hollow "+" ring that records a success', (
      tester,
    ) async {
      await pumpRow(tester);
      // Hollow add ring, never the completed check-circle.
      expect(find.byIcon(LottiIcons.add), findsOneWidget);
      expect(find.byIcon(LottiIcons.confirmCircled), findsNothing);

      await tester.tap(find.byIcon(LottiIcons.add));
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

        await tester.tap(find.byIcon(LottiIcons.add));
        await tester.pump(); // establish the animation start
        // Into the burst window while completedToday is STILL false — the
        // celebration is optimistic (driven by the tap), not gated on the
        // provider catching up after the persist + recompute.
        await tester.pump(const Duration(milliseconds: 220));
        expect(find.byType(CompletionBurst), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1400)); // settle
      },
    );

    testWidgets('no celebration when habit celebrations are off', (
      tester,
    ) async {
      await pumpRow(
        tester,
        extraOverrides: [
          celebrationPreferencesProvider.overrideWithValue(
            const CelebrationPreferences.allEnabled().copyWith(habits: false),
          ),
        ],
      );
      expect(find.byType(CompletionBurst), findsNothing);

      await tester.tap(find.byIcon(LottiIcons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      // The completion still records (haptic + persist run), but neither the
      // spark burst nor the glow plays.
      expect(find.byType(CompletionBurst), findsNothing);
      expect(find.byType(CompletionGlow), findsNothing);

      await tester.pump(const Duration(milliseconds: 1400)); // settle
    });

    testWidgets('no celebration when the master switch is off (habits on)', (
      tester,
    ) async {
      await pumpRow(
        tester,
        extraOverrides: [
          celebrationPreferencesProvider.overrideWithValue(
            // Habit switch on, but the master switch is off.
            const CelebrationPreferences.allEnabled().copyWith(enabled: false),
          ),
        ],
      );

      await tester.tap(find.byIcon(LottiIcons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.byType(CompletionBurst), findsNothing);
      expect(find.byType(CompletionGlow), findsNothing);

      await tester.pump(const Duration(milliseconds: 1400)); // settle
    });

    testWidgets('flows the selected variant into burst and glow', (
      tester,
    ) async {
      await pumpRow(
        tester,
        extraOverrides: [
          celebrationPreferencesProvider.overrideWithValue(
            const CelebrationPreferences.allEnabled().copyWith(
              habitsSelection: const FixedSelection(CelebrationVariant.embers),
            ),
          ),
        ],
      );

      await tester.tap(find.byIcon(LottiIcons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      final burst = tester.widget<CompletionBurst>(
        find.byType(CompletionBurst),
      );
      expect(burst.params?.variant, CelebrationVariant.embers);
      // Embers is a warm variant, so the glow blooms warm (gold), not accent.
      final glow = tester.widget<CompletionGlow>(find.byType(CompletionGlow));
      expect(glow.color, starredGold);

      await tester.pump(const Duration(milliseconds: 1400)); // settle
    });

    testWidgets('an optimistic tap is consumed, not restarted, when the '
        'provider catches up', (tester) async {
      await pumpRow(tester); // not done
      // Tap complete → the optimistic celebration starts immediately.
      await tester.tap(find.byIcon(LottiIcons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.byType(CompletionBurst), findsOneWidget);

      // The provider catches up and the row rebuilds as done. The in-flight
      // timeline continues (the optimistic flag is consumed in didUpdateWidget)
      // rather than re-firing a second burst.
      await pumpRow(tester, completedToday: true);
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(CompletionBurst), findsOneWidget);

      // It still clears itself once the single timeline completes.
      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.byType(CompletionBurst), findsNothing);
    });

    testWidgets('a combine selection layers a distinct second variant', (
      tester,
    ) async {
      await pumpRow(
        tester,
        extraOverrides: [
          celebrationPreferencesProvider.overrideWithValue(
            const CelebrationPreferences.allEnabled().copyWith(
              habitsSelection: const CombineSelection(),
            ),
          ),
        ],
      );

      await tester.tap(find.byIcon(LottiIcons.add));
      await tester.pump();
      // Combine RE-ROLLS its pair from a process-wide seed, so this test —
      // unlike the FixedSelection ones — cannot know the resolved duration.
      // The burst only mounts between 12% and 96% of the timeline, and a pair
      // containing `bubbles` stretches the 1400ms base by 1.4x to 1960ms.
      // 220ms is 15.7% of 1400ms but only 11.2% of 1960ms, so it fell BELOW
      // the mount threshold whenever the roll produced bubbles and the lookup
      // below found no widget. Anything in
      //   [0.12 * 1960ms, 0.96 * 1400ms] = [235ms, 1344ms]
      // is inside the window for every pair; 400ms sits comfortably clear of
      // both ends.
      await tester.pump(const Duration(milliseconds: 400));

      final burst = tester.widget<CompletionBurst>(
        find.byType(CompletionBurst),
      );
      expect(burst.secondParams, isNotNull);
      expect(burst.secondParams!.variant, isNot(burst.params!.variant));

      await tester.pump(const Duration(milliseconds: 1400)); // settle
    });

    group('completion haptic honours the independent haptics switch', () {
      late List<String> haptics;

      void captureHaptics(WidgetTester tester) {
        haptics = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              haptics.add(call.arguments as String? ?? '');
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
      }

      testWidgets('a success completion buzzes when haptics are on', (
        tester,
      ) async {
        captureHaptics(tester);
        await pumpRow(tester);

        await tester.tap(find.byIcon(LottiIcons.add));
        await tester.pump();
        expect(haptics, contains('HapticFeedbackType.lightImpact'));

        await tester.pump(const Duration(milliseconds: 1400));
      });

      testWidgets('a success completion stays silent when haptics are off', (
        tester,
      ) async {
        captureHaptics(tester);
        await pumpRow(
          tester,
          extraOverrides: [
            celebrationPreferencesProvider.overrideWithValue(
              const CelebrationPreferences.allEnabled().copyWith(
                haptics: false,
              ),
            ),
          ],
        );

        await tester.tap(find.byIcon(LottiIcons.add));
        await tester.pump();
        expect(haptics, isEmpty);

        await tester.pump(const Duration(milliseconds: 1400));
      });
    });

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
      await tester.tap(find.byIcon(LottiIcons.add));
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
      expect(find.byIcon(LottiIcons.add), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsWidgets);

      // Rebuild in place with the habit now done → the check settles in and the
      // "+" is gone once the ~320ms switch completes.
      await pumpRow(tester, completedToday: true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
      expect(find.byIcon(LottiIcons.add), findsNothing);
    });

    testWidgets('done → circle check that opens the dialog, no duplicate', (
      tester,
    ) async {
      await pumpRow(tester, completedToday: true);
      expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);

      await tester.tap(find.byIcon(LottiIcons.confirmCircled));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verifyNever(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: any(named: 'habitDefinition'),
        ),
      );
      expect(find.byType(HabitCompletionSheet), findsOneWidget);
    });
  });

  group('row body tap', () {
    testWidgets('opens the HabitCompletionSheet for the habit', (tester) async {
      await pumpRow(tester);
      await tester.tap(find.text(habitFlossing.name));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final dialog = tester.widget<HabitCompletionSheet>(
        find.byType(HabitCompletionSheet),
      );
      expect(dialog.habitId, habitFlossing.id);
    });
  });

  group('long-press the + button', () {
    testWidgets('opens the dialog (to log another day), not a quick-complete', (
      tester,
    ) async {
      await pumpRow(tester);
      await tester.longPress(find.byIcon(LottiIcons.add));
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
      final dialog = tester.widget<HabitCompletionSheet>(
        find.byType(HabitCompletionSheet),
      );
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

  group('auto-completed row', () {
    testWidgets('shows the auto pill and the signal caption', (tester) async {
      await pumpRow(
        tester,
        completedToday: true,
        autoCompleted: true,
        autoCompleteReason: 'Steps · 7412',
        autoCompletedAt: '08:12',
      );
      expect(find.byKey(const ValueKey('habit-auto-pill')), findsOneWidget);
      expect(find.text('auto'), findsOneWidget);
      expect(
        find.text('Checked off from Steps · 7412 at 08:12'),
        findsOneWidget,
      );
    });

    testWidgets('a manual completion shows neither', (tester) async {
      await pumpRow(tester, completedToday: true);
      expect(find.byKey(const ValueKey('habit-auto-pill')), findsNothing);
      expect(find.byKey(const ValueKey('habit-auto-caption')), findsNothing);
    });

    testWidgets('tapping an auto-completed row still opens the sheet', (
      tester,
    ) async {
      await pumpRow(tester, completedToday: true, autoCompleted: true);
      await tester.tap(find.text(habitFlossing.name));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final sheet = tester.widget<HabitCompletionSheet>(
        find.byType(HabitCompletionSheet),
      );
      expect(sheet.habitId, habitFlossing.id);
    });

    testWidgets('an auto completion without a time shows the pill only', (
      tester,
    ) async {
      // A rebuild across midnight can keep the pill data while the time for
      // the new day is not known yet — the caption must not render with a
      // blank time.
      await pumpRow(
        tester,
        completedToday: true,
        autoCompleted: true,
        autoCompleteReason: 'Steps · 7412',
      );
      expect(find.byKey(const ValueKey('habit-auto-pill')), findsOneWidget);
      expect(find.byKey(const ValueKey('habit-auto-caption')), findsNothing);
    });
  });

  group('editing', () {
    testWidgets('press-and-hold on the body opens the editor', (tester) async {
      String? beamedTo;
      beamToNamedOverride = (path) => beamedTo = path;
      addTearDown(() => beamToNamedOverride = null);
      await pumpRow(tester);
      await tester.longPress(find.text(habitFlossing.name));
      await tester.pump();
      expect(beamedTo, '/habits/edit/${habitFlossing.id}');
      expect(find.byType(HabitCompletionSheet), findsNothing);
    });
  });
}
