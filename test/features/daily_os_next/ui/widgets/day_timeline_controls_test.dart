import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

const _work = DayAgentCategory(id: 'w', name: 'Work', colorHex: '5ED4B7');
final _day = DateTime(2026, 5, 25);

DraftPlan _plan() => DraftPlan(
  dayDate: _day,
  blocks: [
    TimeBlock(
      id: 'b1',
      title: 'Deep work',
      start: _day.add(const Duration(hours: 9)),
      end: _day.add(const Duration(hours: 10)),
      type: TimeBlockType.ai,
      state: TimeBlockState.drafted,
      category: _work,
    ),
  ],
  bands: const [],
  capacityMinutes: 480,
  scheduledMinutes: 60,
);

final Finder _modeToggle = find.byKey(
  const Key('daily_os_timeline_mode_toggle'),
);
final Finder _arrangeToggle = find.byKey(
  const Key('daily_os_timeline_arrange_toggle'),
);

/// The controls above the timeline, as the Day page hosts them, and the
/// timeline itself. A comparison breakpoint far wider than the surface keeps
/// the lanes paged until the toggle says otherwise.
Widget _host(
  DayTimelineController controller, {
  bool timeline = true,
  bool showGestureHint = false,
  bool canArrange = true,
  Widget? toolbarLeading,
}) => makeTestableWidgetNoScroll(
  Column(
    children: [
      Row(
        children: [
          const Spacer(),
          DayTimelineControls(
            key: const Key('host_controls'),
            controller: controller,
          ),
        ],
      ),
      if (timeline)
        Expanded(
          child: DayTimeline(
            draft: _plan(),
            controller: controller,
            clock: () => _day.add(const Duration(hours: 8)),
            showGestureHint: showGestureHint,
            comparisonBreakpoint: 100000,
            toolbarLeading: toolbarLeading,
            onRescheduleBlock: canArrange
                ? (block, start, end) async => true
                : null,
          ),
        ),
    ],
  ),
  mediaQueryData: const MediaQueryData(size: Size(800, 900)),
);

Finder _inHost(Finder finder) => find.descendant(
  of: find.byKey(const Key('host_controls')),
  matching: finder,
);

void main() {
  late DayTimelineController controller;
  setUp(() => controller = DayTimelineController());
  tearDown(() => controller.dispose());

  group('DayTimelineController', () {
    testWidgets('is detached, and its controls empty, without a timeline', (
      tester,
    ) async {
      await tester.pumpWidget(_host(controller, timeline: false));

      expect(controller.isAttached, isFalse);
      expect(_modeToggle, findsNothing);
      // Toggling a detached controller is a no-op, not a crash.
      controller
        ..toggleComparisonMode()
        ..toggleArrangeMode();
      expect(controller.showingBoth, isFalse);
    });

    testWidgets('a mounted timeline attaches and reports its state', (
      tester,
    ) async {
      await tester.pumpWidget(_host(controller));
      await tester.pump();

      expect(controller.isAttached, isTrue);
      expect(controller.showingBoth, isFalse);
      expect(controller.arrangeMode, isFalse);
      expect(controller.canArrange, isTrue);
    });

    testWidgets('a timeline that cannot arrange says so', (tester) async {
      await tester.pumpWidget(_host(controller, canArrange: false));
      await tester.pump();

      expect(controller.canArrange, isFalse);
      expect(_inHost(_arrangeToggle), findsNothing);
      expect(_inHost(_modeToggle), findsOneWidget);
    });

    testWidgets('the timeline detaches when it goes', (tester) async {
      await tester.pumpWidget(_host(controller));
      await tester.pump();

      await tester.pumpWidget(_host(controller, timeline: false));
      await tester.pump();

      expect(controller.isAttached, isFalse);
      expect(_modeToggle, findsNothing);
    });

    testWidgets('a timeline handed a new controller moves to it', (
      tester,
    ) async {
      final next = DayTimelineController();
      addTearDown(next.dispose);
      await tester.pumpWidget(_host(controller));
      await tester.pump();

      await tester.pumpWidget(_host(next));
      await tester.pump();

      expect(controller.isAttached, isFalse);
      expect(next.isAttached, isTrue);
    });

    testWidgets('one controller drives one timeline at a time', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Column(
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: DayTimeline(
                    draft: _plan(),
                    controller: controller,
                    clock: () => _day,
                  ),
                ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('listeners hear a change, and only a change', (tester) async {
      await tester.pumpWidget(_host(controller));
      await tester.pump();
      var notified = 0;
      controller.addListener(() => notified++);

      // A rebuild with nothing new is not news.
      await tester.pumpWidget(_host(controller));
      await tester.pump();
      expect(notified, 0);

      controller.toggleArrangeMode();
      await tester.pump();
      await tester.pump();
      expect(notified, 1);
      expect(controller.arrangeMode, isTrue);
    });
  });

  group('DayTimelineControls', () {
    testWidgets('the mode toggle switches the lanes side by side and back', (
      tester,
    ) async {
      await tester.pumpWidget(_host(controller));
      await tester.pump();
      expect(find.byType(PageView), findsOneWidget);

      await tester.tap(_inHost(_modeToggle));
      await tester.pump();
      await tester.pump();

      expect(controller.showingBoth, isTrue);
      expect(find.byType(PageView), findsNothing);
      expect(
        tester.widget<Icon>(_inHost(find.byType(Icon)).first).icon,
        LottiIcons.viewCarousel,
      );

      await tester.tap(_inHost(_modeToggle));
      await tester.pump();
      await tester.pump();
      expect(controller.showingBoth, isFalse);
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('the arrange toggle puts the blocks into arrange mode', (
      tester,
    ) async {
      await tester.pumpWidget(_host(controller));
      await tester.pump();
      expect(find.byKey(const Key('daily_os_move_block_b1')), findsNothing);

      await tester.tap(_inHost(_arrangeToggle));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('daily_os_move_block_b1')), findsOneWidget);
      expect(
        tester.widget<IconButton>(_inHost(_arrangeToggle)).isSelected,
        isTrue,
      );
    });
  });

  group('DayTimeline toolbar with a controller', () {
    testWidgets('leaves the buttons to the host', (tester) async {
      await tester.pumpWidget(_host(controller, showGestureHint: true));
      await tester.pump();

      expect(_modeToggle, findsOneWidget);
      expect(_inHost(_modeToggle), findsOneWidget);
      expect(_arrangeToggle, findsOneWidget);
    });

    testWidgets('keeps the coaching line where it was', (tester) async {
      await tester.pumpWidget(_host(controller, showGestureHint: true));
      await tester.pump();

      expect(find.textContaining('Swipe'), findsOneWidget);
    });

    testWidgets('takes no row with nothing left to show', (tester) async {
      await tester.pumpWidget(_host(controller));
      await tester.pump();
      final withoutRow = tester.getTopLeft(find.byType(PageView)).dy;

      await tester.pumpWidget(_host(controller, showGestureHint: true));
      await tester.pump();
      final withRow = tester.getTopLeft(find.byType(PageView)).dy;

      expect(withRow, greaterThan(withoutRow));
    });

    testWidgets("keeps a row for the host's own leading control", (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(controller, toolbarLeading: const Text('host date')),
      );
      await tester.pump();

      expect(find.text('host date'), findsOneWidget);
      expect(_modeToggle, findsOneWidget);
    });
  });

  group('DayTimeline toolbar without a controller', () {
    testWidgets('keeps its own buttons', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          DayTimeline(
            draft: _plan(),
            clock: () => _day,
            showGestureHint: false,
            onRescheduleBlock: (block, start, end) async => true,
          ),
        ),
      );
      await tester.pump();

      expect(_modeToggle, findsOneWidget);
      expect(_arrangeToggle, findsOneWidget);
    });
  });
}
