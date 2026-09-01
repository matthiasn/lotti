import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_view_side_panel.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';
import '../../../lockdown/lockdown_test_utils.dart';

const _work = DayAgentCategory(
  id: 'cat_work',
  name: 'Work',
  colorHex: '5ED4B7',
);

/// The panel always renders the current local day, so fixtures anchor to the
/// ambient clock's date rather than a hard-coded one.
DateTime get _today {
  final now = clock.now();
  return DateTime(now.year, now.month, now.day);
}

DraftPlan _planForToday() {
  final day = _today;
  DateTime at(int h, int m) => day.add(Duration(hours: h, minutes: m));
  return DraftPlan(
    dayDate: day,
    blocks: [
      TimeBlock(
        id: 'b_focus',
        title: 'Planned focus',
        start: at(9, 0),
        end: at(10, 30),
        type: TimeBlockType.ai,
        state: TimeBlockState.drafted,
        category: _work,
      ),
    ],
    bands: const [],
    capacityMinutes: 480,
    scheduledMinutes: 90,
  );
}

List<TimeBlock> _actualForToday() {
  final day = _today;
  return [
    TimeBlock(
      id: 'actual:session',
      title: 'Recorded session',
      start: day.add(const Duration(hours: 9, minutes: 5)),
      end: day.add(const Duration(hours: 9, minutes: 45)),
      type: TimeBlockType.manual,
      state: TimeBlockState.completed,
      category: _work,
    ),
  ];
}

class _SeededPreferencesController extends DailyOsPreferencesController {
  _SeededPreferencesController({this.gesturesLearned = false});

  final bool gesturesLearned;
  int markCalls = 0;

  @override
  DailyOsPreferences build() =>
      DailyOsPreferences(timelineGesturesLearned: gesturesLearned);

  @override
  void markTimelineGesturesLearned() => markCalls++;
}

void main() {
  Widget wrap(
    Widget child, {
    required Size size,
    DraftPlan? plan,
    List<TimeBlock> actualBlocks = const [],
    DailyOsPreferencesController Function()? preferences,
  }) {
    return ProviderScope(
      overrides: [
        currentDraftPlanProvider.overrideWith((ref, date) async => plan),
        dailyOsActualTimeBlocksProvider.overrideWith(
          (ref, date) async => actualBlocks,
        ),
        dailyOsPreferencesControllerProvider.overrideWith(
          preferences ?? _SeededPreferencesController.new,
        ),
      ],
      child: makeTestableWidget2(
        SizedBox(width: size.width, height: size.height, child: child),
        mediaQueryData: MediaQueryData(size: size),
      ),
    );
  }

  void setView(WidgetTester tester, Size size) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('DayViewSidePanel', () {
    testWidgets(
      "renders today's planned and recorded time through the Daily OS "
      'timeline',
      (tester) async {
        const size = Size(700, 900);
        setView(tester, size);

        await tester.pumpWidget(
          wrap(
            DayViewSidePanel(onToggleHidden: () {}),
            size: size,
            plan: _planForToday(),
            actualBlocks: _actualForToday(),
          ),
        );
        // Two pumps: one for the FutureProvider overrides to resolve, one
        // for the dependent rebuild.
        await tester.pump();
        await tester.pump();

        // Both lanes exist — 700 is above the panel's lowered comparison
        // breakpoint, so planned and actual render side by side.
        expect(
          find.byKey(const Key('daily_os_timeline_plan_pane')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('daily_os_timeline_actual_pane')),
          findsOneWidget,
        );
        expect(find.text('Planned focus'), findsOneWidget);
        expect(find.text('Recorded session'), findsOneWidget);

        // Header: the Today title plus the hide affordance.
        final messages = tester.element(find.byType(DayViewSidePanel)).messages;
        expect(find.text(messages.dailyOsTodayButton), findsOneWidget);
        expect(
          find.byKey(const Key('day_view_panel_hide_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows recorded time even when no plan exists for today', (
      tester,
    ) async {
      const size = Size(700, 900);
      setView(tester, size);

      await tester.pumpWidget(
        wrap(
          DayViewSidePanel(onToggleHidden: () {}),
          size: size,
          actualBlocks: _actualForToday(),
        ),
      );
      await tester.pump();
      await tester.pump();

      // No plan → the timeline still renders (via DraftPlan.emptyForDay)
      // with the recorded session visible on the actual lane.
      expect(
        find.byKey(const Key('daily_os_timeline_actual_pane')),
        findsOneWidget,
      );
      expect(find.text('Recorded session'), findsOneWidget);
    });

    testWidgets('narrow panel keeps the swipeable paged timeline', (
      tester,
    ) async {
      const size = Size(340, 900);
      setView(tester, size);

      await tester.pumpWidget(
        wrap(
          DayViewSidePanel(onToggleHidden: () {}),
          size: size,
          plan: _planForToday(),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Below kDayViewSidePanelComparisonBreakpoint the timeline falls back
      // to its PageView, i.e. swipe left/right moves between the planned and
      // actual lanes — the same interaction as the Daily OS day surface.
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('the calendar button at the top fires the hide callback', (
      tester,
    ) async {
      const size = Size(700, 900);
      setView(tester, size);

      var toggled = 0;
      await tester.pumpWidget(
        wrap(
          DayViewSidePanel(onToggleHidden: () => toggled++),
          size: size,
          plan: _planForToday(),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('day_view_panel_hide_button')));
      expect(toggled, 1);
    });

    testWidgets('forwards gesture learning to the Daily OS preferences', (
      tester,
    ) async {
      const size = Size(700, 900);
      setView(tester, size);

      final prefs = _SeededPreferencesController();
      await tester.pumpWidget(
        wrap(
          DayViewSidePanel(onToggleHidden: () {}),
          size: size,
          plan: _planForToday(),
          preferences: () => prefs,
        ),
      );
      await tester.pump();
      await tester.pump();

      // The timeline's lane-mode toggle is one of the gestures that retires
      // the coaching hint; it must route to the same persisted preference
      // the Daily OS day surface uses. At 700 wide the lanes render side by
      // side, so the toggle offers the paged view.
      final timeline = tester.element(find.byType(DayViewSidePanel));
      final toggleTooltip = timeline.messages.dailyOsNextTimelineShowPaged;
      await tester.tap(find.byTooltip(toggleTooltip));
      await tester.pump();
      expect(prefs.markCalls, 1);
    });
  });

  group('DayViewSidePanelRail', () {
    testWidgets('shows the calendar button and fires the show callback', (
      tester,
    ) async {
      const size = Size(64, 900);
      setView(tester, size);

      var toggled = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: makeTestableWidget2(
            SizedBox(
              width: size.width,
              height: size.height,
              child: DayViewSidePanelRail(onToggleHidden: () => toggled++),
            ),
            mediaQueryData: const MediaQueryData(size: size),
          ),
        ),
      );
      await tester.pump();

      final showButton = find.byKey(const Key('day_view_panel_show_button'));
      expect(showButton, findsOneWidget);
      await tester.tap(showButton);
      expect(toggled, 1);
    });
  });

  group('DayViewSidePanel under lockdown', () {
    testWidgets('blocks outside the locked category stay on the day but are '
        'redacted; the locked category renders normally', (tester) async {
      const size = Size(700, 900);
      setView(tester, size);
      const health = DayAgentCategory(
        id: 'cat_health',
        name: 'Health',
        colorHex: 'FF0000',
      );
      final day = _today;
      final secret = TimeBlock(
        id: 'actual:secret',
        title: 'Secret run',
        start: day.add(const Duration(hours: 7)),
        end: day.add(const Duration(hours: 8)),
        type: TimeBlockType.manual,
        state: TimeBlockState.completed,
        category: health,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentDraftPlanProvider.overrideWith(
              (ref, date) async => _planForToday(),
            ),
            dailyOsActualTimeBlocksProvider.overrideWith(
              (ref, date) async => [..._actualForToday(), secret],
            ),
            dailyOsPreferencesControllerProvider.overrideWith(
              _SeededPreferencesController.new,
            ),
            lockdownOverride(const {'cat_work'}),
          ],
          child: makeTestableWidget2(
            SizedBox(
              width: size.width,
              height: size.height,
              child: DayViewSidePanel(onToggleHidden: () {}),
            ),
            mediaQueryData: const MediaQueryData(size: size),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Planned focus'), findsOneWidget);
      expect(find.text('Recorded session'), findsOneWidget);
      // The other category's block is still on the timeline, textless.
      expect(
        find.byKey(const Key('daily_os_day_block_actual:secret')),
        findsOneWidget,
      );
      expect(find.text('Secret run'), findsNothing);
    });
  });
}
