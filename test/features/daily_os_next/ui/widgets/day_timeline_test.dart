import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/editable_title.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';

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
  TimeBlockType type = TimeBlockType.ai,
  String? taskId,
}) {
  final day = DateTime(2026, 5, 25);
  return TimeBlock(
    id: id,
    title: title,
    start: day.add(Duration(hours: startHour)),
    end: day.add(Duration(hours: endHour)),
    type: type,
    state: state,
    category: _work,
    reason: 'Window selected for focused work.',
    taskId: taskId,
  );
}

/// Sizes the physical test surface and registers the reset teardown —
/// shared by every test in this file.
void _setView(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _wrap(
  Widget child, {
  Size size = const Size(1280, 1200),
  ProviderContainer? container,
}) {
  // The timeline's blocks are ConsumerWidgets (they publish task-focus
  // intents on tap), so every render needs a ProviderScope. When a test
  // wants to read the published intent it passes its own [container].
  final app = makeTestableWidget2(
    child,
    mediaQueryData: MediaQueryData(size: size),
  );
  if (container != null) {
    return UncontrolledProviderScope(container: container, child: app);
  }
  return ProviderScope(child: app);
}

void main() {
  tearDown(() => beamToNamedOverride = null);

  group('DayTimeline', () {
    testWidgets('renders each block from the draft without band label text', (
      tester,
    ) async {
      _setView(tester, const Size(1280, 1200));

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

    testWidgets('opens task-backed timeline blocks through app navigation', (
      tester,
    ) async {
      _setView(tester, const Size(1280, 1200));

      String? openedPath;
      beamToNamedOverride = (path) => openedPath = path;

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draftWithBlocks(
              blocks: [
                _timeBlock(
                  id: 'plan-task',
                  title: 'Openable plan block',
                  startHour: 8,
                  endHour: 9,
                  taskId: 'task-1',
                ),
              ],
            ),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
        ),
      );
      await tester.pump();

      final block = find.byKey(const Key('daily_os_day_block_plan-task'));
      expect(
        find.descendant(of: block, matching: find.byType(Ink)),
        findsOneWidget,
      );

      await tester.tap(block);
      await tester.pump();

      expect(openedPath, '/tasks/task-1');
    });

    testWidgets('leaves timeline blocks without task ids inert', (
      tester,
    ) async {
      _setView(tester, const Size(1280, 1200));

      String? openedPath;
      beamToNamedOverride = (path) => openedPath = path;

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draftWithBlocks(
              blocks: [
                _timeBlock(
                  id: 'standalone',
                  title: 'Standalone block',
                  startHour: 8,
                  endHour: 9,
                  type: TimeBlockType.cal,
                ),
              ],
            ),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
        ),
      );
      await tester.pump();

      final standaloneBlock = find.byKey(
        const Key('daily_os_day_block_standalone'),
      );
      final blockRect = tester.getRect(standaloneBlock);
      expect(blockRect.top, greaterThanOrEqualTo(0));
      expect(
        blockRect.bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );

      await tester.tapAt(blockRect.center);
      await tester.pump();

      expect(openedPath, isNull);
    });

    testWidgets(
      'tracked blocks publish a scroll-to-entry focus intent before navigating',
      (tester) async {
        _setView(tester, const Size(1280, 1200));

        String? openedPath;
        beamToNamedOverride = (path) => openedPath = path;
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _wrap(
            container: container,
            DayTimeline(
              draft: _draftWithBlocks(
                blocks: const [],
                actualBlocks: [
                  _timeBlock(
                    id: '${actualTimeBlockIdPrefix}entry-7',
                    title: 'Recorded session',
                    startHour: 8,
                    endHour: 9,
                    type: TimeBlockType.manual,
                    state: TimeBlockState.completed,
                    taskId: 'task-9',
                  ),
                ],
              ),
              clock: () => DateTime(2026, 5, 25, 9, 15),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(
          find.byKey(
            const Key('daily_os_day_block_${actualTimeBlockIdPrefix}entry-7'),
          ),
        );
        await tester.pump();

        // Navigates to the backing task...
        expect(openedPath, '/tasks/task-9');

        // ...and first publishes the intent that makes the task page scroll
        // to (and highlight) the tapped recording, using the decoded entry id.
        final intent = container.read(
          taskFocusControllerProvider(id: 'task-9'),
        );
        expect(intent, isNotNull);
        expect(intent!.target, TaskFocusTarget.entry);
        expect(intent.entryId, 'entry-7');
        expect(intent.alignment, kDefaultScrollAlignment);
      },
    );

    testWidgets(
      'drafted task-linked blocks navigate without a focus intent',
      (tester) async {
        _setView(tester, const Size(1280, 1200));

        beamToNamedOverride = (_) {};
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _wrap(
            container: container,
            DayTimeline(
              draft: _draftWithBlocks(
                blocks: [
                  _timeBlock(
                    id: 'plan-task',
                    title: 'Planned block',
                    startHour: 8,
                    endHour: 9,
                    taskId: 'task-1',
                  ),
                ],
              ),
              clock: () => DateTime(2026, 5, 25, 9, 15),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('daily_os_day_block_plan-task')));
        await tester.pump();

        // No backing recording → no scroll target published.
        expect(
          container.read(taskFocusControllerProvider(id: 'task-1')),
          isNull,
        );
      },
    );

    testWidgets('timeline blocks never render a why affordance', (
      tester,
    ) async {
      _setView(tester, const Size(1280, 1200));

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
        ),
      );
      await tester.pump();

      // Placement reasons surface on the agenda's sparkle tooltip; the
      // duration-sized timeline boxes stay text-light.
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
    });

    testWidgets('now-line renders inside the visible window', (tester) async {
      _setView(tester, const Size(1280, 1200));

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

    testWidgets('renders plan and actual pane labels', (
      tester,
    ) async {
      _setView(tester, const Size(1280, 1200));

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
    });

    testWidgets('wide layouts show plan and actual together by default', (
      tester,
    ) async {
      _setView(tester, const Size(1280, 900));

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
      _setView(tester, const Size(430, 900));

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
      _setView(tester, const Size(1280, 900));

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
      _setView(tester, const Size(1280, 900));

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            // Mid-hour so the now-chip doesn't (correctly) suppress the
            // adjacent hour labels this test asserts on.
            clock: () => DateTime(2026, 5, 25, 9, 35),
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

    testWidgets('now-chip suppresses the hour label it would occlude', (
      tester,
    ) async {
      _setView(tester, const Size(1280, 900));

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            // :55 — the chip's rect overlaps the 10:00 gutter label.
            clock: () => DateTime(2026, 5, 25, 9, 55),
          ),
          size: const Size(1280, 900),
        ),
      );
      await tester.pump();

      expect(find.text('09:55'), findsAtLeastNWidgets(1));
      expect(find.text('10:00'), findsNothing);
      expect(find.text('09:00'), findsOneWidget);
    });

    testWidgets('folded timelines still span midnight to midnight', (
      tester,
    ) async {
      _setView(tester, const Size(1280, 900));

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
      _setView(tester, const Size(1280, 900));

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
      _setView(tester, const Size(1280, 1200));

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
      _setView(tester, const Size(1280, 1200));

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
      _setView(tester, const Size(1280, 720));

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
      _setView(tester, const Size(1280, 420));

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

    testWidgets('toolbar toggle button switches comparison mode paged→both', (
      tester,
    ) async {
      _setView(tester, const Size(430, 900));

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

      // Compact screen starts in paged mode → button tooltip says "show both".
      expect(
        find.byTooltip(messages.dailyOsNextTimelineShowBoth),
        findsOneWidget,
      );
      expect(find.byType(PageView), findsOneWidget);

      // Tap toggles to "both" side-by-side mode.
      await tester.tap(
        find.byTooltip(messages.dailyOsNextTimelineShowBoth),
      );
      await tester.pump();

      expect(find.byType(PageView), findsNothing);
      expect(
        find.byTooltip(messages.dailyOsNextTimelineShowPaged),
        findsOneWidget,
      );

      // Tap again goes back to paged.
      await tester.tap(
        find.byTooltip(messages.dailyOsNextTimelineShowPaged),
      );
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets(
      'horizontal pinch gesture on compact layout switches comparison mode',
      (tester) async {
        _setView(tester, const Size(430, 900));

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

        // Start in paged mode.
        expect(find.byType(PageView), findsOneWidget);

        final center = tester.getCenter(find.byType(DayTimeline));
        // Spread fingers horizontally (pinch-out) → should switch to paged
        // (i.e. the horizontal pinch-in to < 0.82 switches to "both").
        final firstFinger = await tester.createGesture(pointer: 201);
        final secondFinger = await tester.createGesture(pointer: 202);

        // Start with fingers close together.
        await firstFinger.down(center.translate(-20, 0));
        await secondFinger.down(center.translate(20, 0));
        await tester.pump();

        // Move far apart horizontally (scale > 1.08 → paged stays or changes).
        // Move inward so scale < 0.82 → switches to "both".
        await firstFinger.moveTo(center.translate(-8, 0));
        await secondFinger.moveTo(center.translate(8, 0));
        await tester.pump();

        await firstFinger.up();
        await secondFinger.up();
        await tester.pump();

        // After inward horizontal pinch (scale < 0.82) → comparison mode = both.
        expect(find.byType(PageView), findsNothing);
      },
    );

    testWidgets('didUpdateWidget propagates new pxPerMinute to state', (
      tester,
    ) async {
      _setView(tester, const Size(1280, 900));

      // Start with default pxPerMinute = 1.0.
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

      final tenAmBefore = tester.getTopLeft(find.text('10:00').first).dy;

      // Rebuild with a larger pxPerMinute → blocks spread further apart.
      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: _draft(),
            pxPerMinute: 2,
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
          size: const Size(1280, 900),
        ),
      );
      await tester.pump();

      final tenAmAfter = tester.getTopLeft(find.text('10:00').first).dy;
      expect(tenAmAfter, greaterThan(tenAmBefore));
    });

    testWidgets(
      'tracked blocks are the alive treatment: full category stripe and '
      'fill, green check when done, mono time range, no why affordance',
      (tester) async {
        _setView(tester, const Size(1280, 900));

        final day = DateTime(2026, 5, 25);
        await tester.pumpWidget(
          _wrap(
            DayTimeline(
              draft: _draftWithBlocks(blocks: const []),
              actualBlocks: [
                TimeBlock(
                  id: 'tracked-1',
                  title: 'Recorded session',
                  start: day.add(const Duration(hours: 9)),
                  end: day.add(const Duration(hours: 10, minutes: 30)),
                  type: TimeBlockType.manual,
                  state: TimeBlockState.completed,
                  category: _work,
                  reason: 'should never surface a why affordance',
                ),
              ],
              clock: () => DateTime(2026, 5, 25, 9, 15),
            ),
            size: const Size(1280, 900),
          ),
        );
        await tester.pump();

        // Recorded sessions carry the color: an 18% category tint
        // composited opaquely over the canvas (paint-by-numbers — doing
        // fills the block in; gridlines never bleed through).
        final ink = tester.widget<Ink>(
          find.descendant(
            of: find.byKey(const Key('daily_os_day_block_tracked-1')),
            matching: find.byType(Ink),
          ),
        );
        final fill = (ink.decoration! as BoxDecoration).color!;
        final tokens = tester.element(find.byType(DayTimeline)).designTokens;
        final isLight =
            Theme.of(tester.element(find.byType(DayTimeline))).brightness ==
            Brightness.light;
        final expected = Color.alphaBlend(
          categoryColorFromHex(
            _work.colorHex,
          ).withValues(alpha: isLight ? 0.30 : 0.18),
          tokens.colors.background.level01,
        );
        expect(fill, expected);
        expect(fill.a, 1.0);
        // Done sessions get the green check.
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        // Tracked blocks never surface agent reasoning.
        expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
        // The mono time range carries the recorded voice (no suffix —
        // the lane header already says Actual).
        final subtitle = tester.widget<Text>(find.text('09:00\u201310:30'));
        expect(subtitle.style?.fontFamily, 'Inconsolata');
      },
    );

    testWidgets(
      'drafted plan blocks read provisional via a dashed outline; '
      'committed blocks render solid',
      (tester) async {
        _setView(tester, const Size(1280, 900));

        await tester.pumpWidget(
          _wrap(
            DayTimeline(
              draft: _draftWithBlocks(
                blocks: [
                  _timeBlock(
                    id: 'drafted',
                    title: 'Drafted block',
                    startHour: 8,
                    endHour: 9,
                  ),
                  TimeBlock(
                    id: 'committed',
                    title: 'Committed block',
                    start: DateTime(2026, 5, 25, 10),
                    end: DateTime(2026, 5, 25, 11),
                    type: TimeBlockType.ai,
                    state: TimeBlockState.committed,
                    category: _work,
                    reason: 'Window selected for focused work.',
                  ),
                ],
              ),
              clock: () => DateTime(2026, 5, 25, 9, 15),
            ),
            size: const Size(1280, 900),
          ),
        );
        await tester.pump();

        // Exactly one block (the drafted one) carries the dashed border.
        expect(
          find.ancestor(
            of: find.text('Drafted block'),
            matching: find.byType(DsDashedBorder),
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.text('Committed block'),
            matching: find.byType(DsDashedBorder),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'task-linked plan blocks show a link icon; standalone blocks are '
      'inline-renamable when the timeline provides a rename callback',
      (tester) async {
        _setView(tester, const Size(1280, 900));

        final renames = <(String, String)>[];
        await tester.pumpWidget(
          _wrap(
            DayTimeline(
              draft: _draftWithBlocks(
                blocks: [
                  TimeBlock(
                    id: 'linked',
                    title: 'Linked block',
                    start: DateTime(2026, 5, 25, 8),
                    end: DateTime(2026, 5, 25, 9, 30),
                    type: TimeBlockType.ai,
                    state: TimeBlockState.drafted,
                    category: _work,
                    taskId: 'task-1',
                    reason: 'Backed by a task.',
                  ),
                  TimeBlock(
                    id: 'standalone',
                    title: 'Standalone block',
                    start: DateTime(2026, 5, 25, 10),
                    end: DateTime(2026, 5, 25, 11, 30),
                    type: TimeBlockType.manual,
                    state: TimeBlockState.drafted,
                    category: _work,
                  ),
                ],
              ),
              onRenameBlock: (block, title) => renames.add((block.id, title)),
              clock: () => DateTime(2026, 5, 25, 9, 15),
            ),
            size: const Size(1280, 900),
          ),
        );
        await tester.pump();

        // Task-linked block carries the small info link icon.
        expect(find.byIcon(Icons.link_rounded), findsOneWidget);

        // The standalone title is click-to-edit: tap, type, submit.
        expect(find.byType(EditableTitle), findsOneWidget);
        await tester.tap(find.text('Standalone block'));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('daily_os_editable_title_field')),
          'Renamed block',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(renames, [('standalone', 'Renamed block')]);
      },
    );

    testWidgets('EnergyBand low and secondWind levels render', (tester) async {
      _setView(tester, const Size(1280, 900));

      final day = DateTime(2026, 5, 25);
      DateTime at(int h, int m) => day.add(Duration(hours: h, minutes: m));

      final draft = DraftPlan(
        dayDate: day,
        blocks: [
          _timeBlock(
            id: 'b1',
            title: 'Anchor block',
            startHour: 8,
            endHour: 9,
          ),
        ],
        bands: [
          EnergyBand(
            start: at(6, 0),
            end: at(8, 0),
            level: EnergyLevel.low,
            label: 'LOW ENERGY',
          ),
          EnergyBand(
            start: at(14, 0),
            end: at(16, 0),
            level: EnergyLevel.secondWind,
            label: 'SECOND WIND',
          ),
        ],
        capacityMinutes: 480,
        scheduledMinutes: 60,
      );

      await tester.pumpWidget(
        _wrap(
          DayTimeline(
            draft: draft,
            clock: () => DateTime(2026, 5, 25, 9, 15),
          ),
          size: const Size(1280, 900),
        ),
      );
      await tester.pump();

      // Both bands are rendered as Semantics labels (IgnorePointer with Semantics).
      expect(find.bySemanticsLabel('LOW ENERGY'), findsOneWidget);
      expect(find.bySemanticsLabel('SECOND WIND'), findsOneWidget);
    });

    testWidgets(
      'block subtitle shows session index and location when present',
      (tester) async {
        _setView(tester, const Size(1280, 900));

        final day = DateTime(2026, 5, 25);
        final block = TimeBlock(
          id: 'session-block',
          title: 'Session work',
          start: day.add(const Duration(hours: 9)),
          end: day.add(const Duration(hours: 10, minutes: 30)),
          type: TimeBlockType.ai,
          state: TimeBlockState.drafted,
          category: _work,
          sessionIndex: 2,
          sessionTotal: 3,
          location: 'Office',
        );

        await tester.pumpWidget(
          _wrap(
            DayTimeline(
              draft: _draftWithBlocks(blocks: [block]),
              clock: () => DateTime(2026, 5, 25, 9, 15),
            ),
            size: const Size(1280, 900),
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(DayTimeline)).messages;
        final sessionLabel = messages.dailyOsNextTimelineSessionOf(2, 3);
        // The subtitle combines time range, session label and location.
        expect(
          find.textContaining(sessionLabel),
          findsOneWidget,
        );
        expect(find.textContaining('Office'), findsOneWidget);
      },
    );

    testWidgets(
      'block subtitle covers the bare-range and session-only branches',
      (tester) async {
        _setView(tester, const Size(1280, 900));

        final day = DateTime(2026, 5, 25);
        final bare = TimeBlock(
          id: 'bare-block',
          title: 'Bare work',
          start: day.add(const Duration(hours: 9)),
          end: day.add(const Duration(hours: 10, minutes: 30)),
          type: TimeBlockType.ai,
          state: TimeBlockState.drafted,
          category: _work,
        );
        final sessionOnly = TimeBlock(
          id: 'session-only-block',
          title: 'Session-only work',
          start: day.add(const Duration(hours: 12)),
          end: day.add(const Duration(hours: 13)),
          type: TimeBlockType.ai,
          state: TimeBlockState.drafted,
          category: _work,
          sessionIndex: 1,
          sessionTotal: 2,
        );

        await tester.pumpWidget(
          _wrap(
            DayTimeline(
              draft: _draftWithBlocks(blocks: [bare, sessionOnly]),
              clock: () => DateTime(2026, 5, 25, 9, 15),
            ),
            size: const Size(1280, 900),
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(DayTimeline)).messages;
        final sessionLabel = messages.dailyOsNextTimelineSessionOf(1, 2);

        // No session, no location: the subtitle is exactly the time range.
        expect(find.text('09:00\u201310:30'), findsOneWidget);
        // Session but no location: range + session label, nothing more.
        expect(
          find.text('12:00\u201313:00 \u00b7 $sessionLabel'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'clusters near the start/end of the day are merged into visible regions '
      'to avoid tiny gaps',
      (tester) async {
        _setView(tester, const Size(1280, 900));

        // A block starting at hour 1 (< gapThreshold=4 from hour 0) means the
        // leading cluster should be extended back to hour 0.
        // Similarly a block ending at hour 22 (< 4 from hour 24) merges end.
        await tester.pumpWidget(
          _wrap(
            DayTimeline(
              draft: _draftWithBlocks(
                blocks: [
                  _timeBlock(
                    id: 'early',
                    title: 'Early block',
                    startHour: 1,
                    endHour: 2,
                  ),
                  _timeBlock(
                    id: 'late',
                    title: 'Late block',
                    startHour: 22,
                    endHour: 23,
                  ),
                ],
              ),
              clock: () => DateTime(2026, 5, 25, 9, 15),
            ),
            size: const Size(1280, 900),
          ),
        );
        await tester.pump();

        // When the gap between start(0) and cluster.startHour(1) is < 4,
        // the cluster is extended back to 0, so "00:00" should be visible.
        expect(find.text('00:00'), findsOneWidget);
        // When the gap between cluster.endHour(23) and end(24) is < 4,
        // the cluster is extended to 24, so "24:00" should appear.
        expect(find.text('24:00'), findsOneWidget);
      },
    );

    testWidgets(
      'without an injected clock the now-line tracks the real clock and the '
      'per-minute timer keeps it mounted across a tick',
      (tester) async {
        _setView(tester, const Size(1280, 1200));

        // Deliberate exception to the deterministic-dates rule: this test
        // covers the no-injected-clock FALLBACK branch, so touching the real
        // clock is the point. The widget's fallback reads the raw wall clock
        // (`DateTime.now`), so we use `clock.now()` here — which is the same
        // wall clock outside a `withClock` zone — to satisfy the no-bare-
        // `DateTime.now()` test rule while still placing the draft on the real
        // calendar day so the now-line falls inside the window. Assertions read
        // the rendered badge back from the tree so a minute rollover mid-test
        // cannot flake.
        final wallNow = clock.now();
        final today = DateTime(wallNow.year, wallNow.month, wallNow.day);
        final draft = DraftPlan(
          dayDate: today,
          blocks: [
            TimeBlock(
              id: 'anchor',
              title: 'Anchor block',
              start: today.add(const Duration(hours: 8)),
              end: today.add(const Duration(hours: 9)),
              type: TimeBlockType.ai,
              state: TimeBlockState.drafted,
              category: _work,
              reason: 'Window selected for focused work.',
            ),
          ],
          bands: const [],
          capacityMinutes: 480,
          scheduledMinutes: 60,
        );

        await tester.pumpWidget(_wrap(DayTimeline(draft: draft)));
        await tester.pump();

        // The red now-badge (bold, error colour) carries the live HH:mm. Read
        // it back from the tree instead of recomputing, so a minute rollover
        // mid-test cannot make the assertion flaky.
        final tokens = tester.element(find.byType(DayTimeline)).designTokens;
        final errorColor = tokens.colors.alert.error.defaultColor;
        Finder nowBadge() => find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.style?.color == errorColor &&
              w.style?.fontWeight == tokens.typography.weight.bold,
        );

        expect(nowBadge(), findsOneWidget);
        final labelBefore = tester.widget<Text>(nowBadge()).data;
        expect(labelBefore, isNotNull);
        // Looks like a clock value, e.g. 14:07.
        expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(labelBefore!), isTrue);

        // Advance fake time past a full minute so the scheduled Timer fires.
        // The callback re-reads DateTime.now(), calls setState, and reschedules
        // (lines covering the timer body). The widget must stay mounted and the
        // now-line must survive the rebuild.
        await tester.pump(const Duration(minutes: 1));

        expect(nowBadge(), findsOneWidget);
        expect(find.text('Anchor block'), findsOneWidget);

        // Dispose cancels the live (rescheduled) timer; a leaked timer would
        // fail the test, proving the reschedule produced a cancellable timer.
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'wide layout horizontal pinch-out switches both → paged comparison mode',
      (tester) async {
        _setView(tester, const Size(1280, 900));

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

        // Wide screen (>= desktop breakpoint) defaults to side-by-side "both".
        expect(find.byType(PageView), findsNothing);

        final center = tester.getCenter(find.byType(DayTimeline));
        final firstFinger = await tester.createGesture(pointer: 301);
        final secondFinger = await tester.createGesture(pointer: 302);

        // Fingers start close, then spread far apart horizontally so
        // horizontalScale > 1.08 (pinch-out) and the horizontal axis dominates.
        await firstFinger.down(center.translate(-10, 0));
        await secondFinger.down(center.translate(10, 0));
        await tester.pump();

        await firstFinger.moveTo(center.translate(-200, 0));
        await secondFinger.moveTo(center.translate(200, 0));
        await tester.pump();

        await firstFinger.up();
        await secondFinger.up();
        await tester.pump();

        // Pinch-out collapses the side-by-side view back to the paged carousel.
        expect(find.byType(PageView), findsOneWidget);
        final messages = tester.element(find.byType(DayTimeline)).messages;
        expect(
          find.byTooltip(messages.dailyOsNextTimelineShowBoth),
          findsOneWidget,
        );
      },
    );
  });

  group('formatTimelineHourLabel', () {
    test('renders the exclusive end-of-day marker as 24:00, not 00:00', () {
      // The 24 special case is the whole reason the formatter is not a plain
      // `hour % 24` — fold ranges and the rail label use 24 to mean
      // "end of day". Regressing this would collapse 24:00 to 00:00.
      expect(formatTimelineHourLabel(24), '24:00');
      expect(formatTimelineHourLabel(0), '00:00');
      expect(formatTimelineHourLabel(9), '09:00');
      expect(formatTimelineHourLabel(13), '13:00');
    });

    glados.Glados<int>(
      glados.any.intInRange(0, 25),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'always formats as HH:00 with a zero-padded hour in [00, 24]',
      (hour) {
        final label = formatTimelineHourLabel(hour);

        // Shape: exactly two digits, a colon, then the literal minutes 00.
        expect(RegExp(r'^\d{2}:00$').hasMatch(label), isTrue);

        final displayHour = int.parse(label.substring(0, 2));
        // 24 stays 24 (end-of-day); every other value is on a 24-hour clock.
        final expected = hour == 24 ? 24 : hour % 24;
        expect(displayHour, expected);
        expect(displayHour, inInclusiveRange(0, 24));
      },
      tags: 'glados',
    );
  });

  group('DayBlock height tiers', () {
    TimeBlock incident({int minutes = 22}) => TimeBlock(
      id: 'tier-probe',
      title: 'Production incident triage',
      start: DateTime(2026, 5, 25, 10, 40),
      end: DateTime(2026, 5, 25, 10, 40 + minutes),
      type: TimeBlockType.manual,
      state: TimeBlockState.completed,
      category: _work,
    );

    Widget tierHarness({required double height, double textScale = 1.0}) =>
        _wrap(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(1280, 1200),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Center(
              child: SizedBox(
                height: height,
                width: 240,
                child: DayBlock(block: incident(), tracked: true),
              ),
            ),
          ),
        );

    testWidgets(
      'a 22px block at default text scale keeps a FITTED title — the '
      'canonical short incident stays information, not just color',
      (tester) async {
        _setView(tester, const Size(1280, 1200));
        await tester.pumpWidget(tierHarness(height: 22));
        await tester.pump();

        final title = find.text('Production incident triage');
        expect(title, findsOneWidget);
        // Content area = 22 − 2×step2 vertical padding = 14px; the fitted
        // scaler shrinks the caption line to fit — never shears it.
        expect(tester.getSize(title).height, lessThanOrEqualTo(14.01));
      },
    );

    testWidgets('a micro block renders fill + stripe only (no text)', (
      tester,
    ) async {
      _setView(tester, const Size(1280, 1200));
      await tester.pumpWidget(tierHarness(height: 16));
      await tester.pump();

      // 16 − 8 padding = 8px content < 3/4 caption line → no glyphs; the
      // DayBlock Semantics label still carries the title.
      expect(find.text('Production incident triage'), findsNothing);
    });

    testWidgets(
      'at 2.0x text the sliver line still fits its box (no shearing)',
      (tester) async {
        _setView(tester, const Size(1280, 1200));
        await tester.pumpWidget(tierHarness(height: 36, textScale: 2));
        await tester.pump();

        final title = find.text('Production incident triage');
        expect(title, findsOneWidget);
        // Content area = 36 − 8 = 28px; the fitted line must not exceed it.
        expect(tester.getSize(title).height, lessThanOrEqualTo(28.01));
      },
    );
  });
}
