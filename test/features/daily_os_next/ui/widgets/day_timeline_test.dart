import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/why_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

const _work = DayAgentCategory(
  id: 'cat_work',
  name: 'Work',
  colorHex: '5ED4B7',
);

const _buffer = DayAgentCategory(
  id: 'cat_buffer',
  name: 'Buffer',
  colorHex: '8E8E8E',
);

DraftPlan _draft() {
  final day = DateTime(2026, 5, 25);
  DateTime at(int h, int m) => day.add(Duration(hours: h, minutes: m));
  return DraftPlan(
    dayDate: day,
    blocks: [
      TimeBlock(
        id: 'b_ai',
        title: 'Deep work',
        start: at(8, 30),
        end: at(10, 0),
        type: TimeBlockType.ai,
        state: TimeBlockState.drafted,
        category: _work,
        reason: 'Your highest-focus window.',
      ),
      TimeBlock(
        id: 'b_buffer',
        title: 'Buffer',
        start: at(10, 0),
        end: at(10, 30),
        type: TimeBlockType.buffer,
        state: TimeBlockState.drafted,
        category: _buffer,
      ),
      TimeBlock(
        id: 'b_cal',
        title: 'Team sync',
        start: at(13, 0),
        end: at(13, 30),
        type: TimeBlockType.cal,
        state: TimeBlockState.committed,
        category: _work,
      ),
    ],
    bands: [
      EnergyBand(
        start: at(7, 0),
        end: at(10, 30),
        level: EnergyLevel.high,
        label: 'HIGH ENERGY',
      ),
    ],
    actualBlocks: [
      TimeBlock(
        id: 'a_ai',
        title: 'Deep work actual',
        start: at(8, 45),
        end: at(9, 30),
        type: TimeBlockType.ai,
        state: TimeBlockState.completed,
        category: _work,
      ),
    ],
    capacityMinutes: 480,
    scheduledMinutes: 120,
  );
}

DraftPlan _draftWithBlocks({
  required List<TimeBlock> blocks,
  List<TimeBlock> actualBlocks = const [],
}) {
  return DraftPlan(
    dayDate: DateTime(2026, 5, 25),
    blocks: blocks,
    bands: const [],
    actualBlocks: actualBlocks,
    capacityMinutes: 480,
    scheduledMinutes: 120,
  );
}

TimeBlock _timeBlock({
  required String id,
  required String title,
  required int startHour,
  required int endHour,
  TimeBlockState state = TimeBlockState.drafted,
}) {
  final day = DateTime(2026, 5, 25);
  return TimeBlock(
    id: id,
    title: title,
    start: day.add(Duration(hours: startHour)),
    end: day.add(Duration(hours: endHour)),
    type: TimeBlockType.ai,
    state: state,
    category: _work,
    reason: 'Window selected for focused work.',
  );
}

Widget _wrap(
  Widget child, {
  Size size = const Size(1280, 1200),
}) {
  return makeTestableWidget2(
    child,
    mediaQueryData: MediaQueryData(size: size),
  );
}

void main() {
  group('DayTimeline', () {
    testWidgets('renders each block from the draft without band label text', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 1200)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
        ),
      );
      await tester.pump();

      // One title per block on the timeline.
      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('Buffer'), findsOneWidget);
      expect(find.text('Team sync'), findsOneWidget);
      expect(find.text('HIGH ENERGY'), findsNothing);
    });

    testWidgets('AI blocks render a WhyChip; cal and buffer blocks do not', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 1200)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
        ),
      );
      await tester.pump();

      // The mock draft has exactly one ai block; only that one gets a chip.
      expect(find.byType(WhyChip), findsOneWidget);
    });

    testWidgets('now-line renders inside the visible window', (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 1200)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
        ),
      );
      await tester.pump();

      // Hour-rail label badge at 09:15.
      expect(find.text('09:15'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders actual timeline labels and time spent summary', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 1200)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
        ),
      );
      await tester.pump();

      final messages = tester.element(find.byType(DayTimeline)).messages;
      expect(find.text(messages.dailyOsNextTimelinePlanned), findsOneWidget);
      expect(find.text(messages.dailyOsNextTimelineActual), findsOneWidget);
      expect(find.text(messages.dailyOsNextTimeSpentTitle), findsOneWidget);
      expect(
        find.text(messages.dailyOsNextTimeSpentSummary('45m', 1)),
        findsOneWidget,
      );
    });

    testWidgets('wide layouts show plan and actual together by default', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
          size: const Size(1280, 900),
        ),
      );
      await tester.pump();

      final messages = tester.element(find.byType(DayTimeline)).messages;
      expect(find.text(messages.dailyOsNextTimelinePlanned), findsOneWidget);
      expect(find.text(messages.dailyOsNextTimelineActual), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
      expect(
        find.byTooltip(messages.dailyOsNextTimelineShowPaged),
        findsOneWidget,
      );
    });

    testWidgets('compact layouts keep the swipeable plan-first view', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(430, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
          size: const Size(430, 900),
        ),
      );
      await tester.pump();

      final messages = tester.element(find.byType(DayTimeline)).messages;
      expect(find.byType(PageView), findsOneWidget);
      expect(
        find.byTooltip(messages.dailyOsNextTimelineShowBoth),
        findsOneWidget,
      );
    });

    testWidgets('folds a long gap caused by planned blocks', (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draftWithBlocks(
              blocks: [
                _timeBlock(
                  id: 'morning',
                  title: 'Morning plan',
                  startHour: 8,
                  endHour: 9,
                ),
                _timeBlock(
                  id: 'late',
                  title: 'Late plan',
                  startHour: 16,
                  endHour: 17,
                ),
              ],
            ),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
          size: const Size(1280, 900),
        ),
      );
      await tester.pump();

      final foldedGap = find.byKey(
        const Key('daily_os_timeline_fold_9_16'),
      );
      expect(foldedGap, findsOneWidget);
      expect(find.text('09:00-16:00'), findsOneWidget);
      expect(find.text('12:00'), findsNothing);

      await tester.tap(foldedGap.first);
      await tester.pump();

      expect(find.text('09:00-16:00'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
    });

    testWidgets('uses one sticky time rail for plan and actual', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
          size: const Size(1280, 900),
        ),
      );
      await tester.pump();

      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('Deep work actual'), findsOneWidget);

      final tokens = tester.element(find.byType(DayTimeline)).designTokens;
      final hourLabel = tester.widget<Text>(find.text('09:00'));
      expect(
        hourLabel.style?.fontSize,
        tokens.typography.styles.others.caption.fontSize,
      );
      expect(
        hourLabel.style?.fontWeight,
        tokens.typography.styles.others.caption.fontWeight,
      );
    });

    testWidgets('folded timelines still span midnight to midnight', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draftWithBlocks(
              blocks: [
                _timeBlock(
                  id: 'morning',
                  title: 'Morning plan',
                  startHour: 8,
                  endHour: 9,
                ),
              ],
            ),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
          size: const Size(1280, 900),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('daily_os_timeline_fold_0_8')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('daily_os_timeline_fold_9_24')),
        findsOneWidget,
      );
      expect(find.text('00:00-08:00'), findsOneWidget);
      expect(find.text('09:00-24:00'), findsOneWidget);
    });

    testWidgets('folds a long gap caused by actual blocks', (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draftWithBlocks(blocks: const []),
            actualBlocks: [
              _timeBlock(
                id: 'actual-morning',
                title: 'Actual morning',
                startHour: 8,
                endHour: 9,
                state: TimeBlockState.completed,
              ),
              _timeBlock(
                id: 'actual-late',
                title: 'Actual late',
                startHour: 16,
                endHour: 17,
                state: TimeBlockState.completed,
              ),
            ],
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
          size: const Size(1280, 900),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('daily_os_timeline_fold_9_16')),
        findsOneWidget,
      );
      expect(find.text('09:00-16:00'), findsOneWidget);
      expect(find.text('Actual morning'), findsOneWidget);
      expect(find.text('Actual late'), findsOneWidget);
    });

    testWidgets('two-finger vertical pinch zooms into the timeline', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 1200)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
        ),
      );
      await tester.pump();

      final tenAm = find.text('10:00').first;
      final before = tester.getTopLeft(tenAm).dy;
      final center = tester.getCenter(find.byType(DayTimeline));
      final firstFinger = await tester.createGesture(pointer: 101);
      final secondFinger = await tester.createGesture(pointer: 102);

      await firstFinger.down(center.translate(0, -40));
      await secondFinger.down(center.translate(0, 40));
      await tester.pump();

      await firstFinger.moveTo(center.translate(0, -120));
      await secondFinger.moveTo(center.translate(0, 120));
      await tester.pump();

      await firstFinger.up();
      await secondFinger.up();
      await tester.pump();

      expect(tester.getTopLeft(tenAm).dy, greaterThan(before));
    });

    testWidgets('trackpad pinch zooms into the timeline', (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 1200)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
        ),
      );
      await tester.pump();

      final tenAm = find.text('10:00').first;
      final before = tester.getTopLeft(tenAm).dy;
      final center = tester.getCenter(find.byType(DayTimeline));

      tester.binding.handlePointerEvent(
        PointerPanZoomStartEvent(position: center),
      );
      tester.binding.handlePointerEvent(
        PointerPanZoomUpdateEvent(position: center, scale: 1.6),
      );
      tester.binding.handlePointerEvent(
        PointerPanZoomEndEvent(position: center),
      );
      await tester.pump();

      expect(tester.getTopLeft(tenAm).dy, greaterThan(before));
    });

    testWidgets('plan and actual share one vertical scroll view', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 720)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
          size: const Size(1280, 720),
        ),
      );
      await tester.pump();

      final timelineScroll = find.byKey(const Key('daily_os_timeline_scroll'));
      final planPane = find.byKey(const Key('daily_os_timeline_plan_pane'));
      final actualPane = find.byKey(const Key('daily_os_timeline_actual_pane'));
      final singleChildScrollViews = tester.widgetList<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );

      expect(timelineScroll, findsOneWidget);
      expect(planPane, findsOneWidget);
      expect(actualPane, findsOneWidget);
      expect(singleChildScrollViews, hasLength(1));

      final controller = tester
          .widget<SingleChildScrollView>(timelineScroll)
          .controller!;
      final planBefore = tester.getTopLeft(find.text('Deep work')).dy;
      final actualBefore = tester.getTopLeft(find.text('Deep work actual')).dy;

      controller.jumpTo(120);
      await tester.pump();

      expect(controller.position.pixels, 120);
      expect(
        tester.getTopLeft(find.text('Deep work')).dy,
        lessThan(planBefore),
      );
      expect(
        tester.getTopLeft(find.text('Deep work actual')).dy,
        lessThan(actualBefore),
      );
    });

    testWidgets('pinch zoom scales the shared scroll offset', (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 420)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
          size: const Size(1280, 420),
        ),
      );
      await tester.pump();

      final scrollable = find.byKey(const Key('daily_os_timeline_scroll'));
      final controller = tester
          .widget<SingleChildScrollView>(scrollable)
          .controller!;
      final beforeOffset = controller.position.maxScrollExtent / 2;
      controller.jumpTo(beforeOffset);
      await tester.pump();

      final center = tester.getCenter(find.byType(DayTimeline));
      tester.binding.handlePointerEvent(
        PointerPanZoomStartEvent(position: center),
      );
      tester.binding.handlePointerEvent(
        PointerPanZoomUpdateEvent(position: center, scale: 1.6),
      );
      tester.binding.handlePointerEvent(
        PointerPanZoomEndEvent(position: center),
      );
      await tester.pump();

      expect(controller.position.pixels, greaterThan(beforeOffset));
    });
  });
}
