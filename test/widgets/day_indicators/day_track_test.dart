import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/day_indicators/day_mark_cell.dart';
import 'package:lotti/widgets/day_indicators/day_track.dart';
import 'package:lotti/widgets/misc/linked_scroll_group.dart';

import '../../widget_test_utils.dart';

void main() {
  testWidgets('DayTrack centers each child in a slot one pitch wide', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Align(
          alignment: Alignment.topLeft,
          child: DayTrack(
            height: 20,
            pitch: 30,
            children: [
              for (var i = 0; i < 3; i++)
                SizedBox(key: ValueKey('slot-$i'), width: 10, height: 10),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DayTrack)), const Size(90, 20));
    for (var i = 0; i < 3; i++) {
      expect(tester.getCenter(find.byKey(ValueKey('slot-$i'))).dx, 30 * i + 15);
    }
  });

  testWidgets('an empty DayTrack takes no space', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Align(
          alignment: Alignment.topLeft,
          child: DayTrack(height: 20, pitch: 30, children: []),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DayTrack)), Size.zero);
  });

  testWidgets('metrics are one square and step2 of air, with one-letter '
      'captions, at every span', (tester) async {
    late DayTrackMetrics metrics;
    late DsTokens tokens;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) {
            tokens = context.designTokens;
            metrics = dayTrackMetrics(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(metrics.pitch, kDaySquareSize + tokens.spacing.step2);
    expect(metrics.narrowLabels, isTrue, reason: '"Mon" does not fit 16px');
    expect(metrics.labelHeight, greaterThanOrEqualTo(IconSizes.s));
  });

  testWidgets('a desktop window keys the pitch to the larger square', (
    tester,
  ) async {
    late DayTrackMetrics metrics;
    late DsTokens tokens;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) {
            tokens = context.designTokens;
            metrics = dayTrackMetrics(context);
            return const SizedBox.shrink();
          },
        ),
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
      ),
    );
    expect(
      metrics.pitch,
      kDaySquareSize + tokens.spacing.step1 + tokens.spacing.step2,
    );
  });

  testWidgets('a raised text scale widens the pitch to hold the caption', (
    tester,
  ) async {
    late DayTrackMetrics scaled;
    late DayTrackMetrics normal;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) {
            normal = dayTrackMetrics(context);
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.5)),
              child: Builder(
                builder: (context) {
                  scaled = dayTrackMetrics(context);
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(scaled.pitch, greaterThan(normal.pitch));
  });

  testWidgets('fitOrScrollDayTrack wraps only content wider than its measure, '
      'in a trailing-anchored scroller joined to the group', (tester) async {
    final group = LinkedScrollGroup();
    addTearDown(group.dispose);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 200,
              child: fitOrScrollDayTrack(
                contentWidth: 100,
                availableWidth: 200,
                group: group,
                child: const SizedBox(
                  key: ValueKey('fits'),
                  width: 100,
                  height: 10,
                ),
              ),
            ),
            SizedBox(
              width: 200,
              child: fitOrScrollDayTrack(
                contentWidth: 400,
                availableWidth: 200,
                group: group,
                child: const SizedBox(
                  key: ValueKey('pans'),
                  width: 400,
                  height: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    expect(find.byType(LinkedDayTrackScroller), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('fits')),
        matching: find.byType(LinkedDayTrackScroller),
      ),
      findsNothing,
    );
    final scroller = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scroller.reverse, isTrue);
    expect(scroller.controller, isNotNull);
    // Opens on today: the trailing edge of the content is on screen.
    expect(tester.getTopRight(find.byKey(const ValueKey('pans'))).dx, 200);
  });

  testWidgets(
    'a scroller re-attaches when its group changes and detaches on dispose',
    (tester) async {
      final first = LinkedScrollGroup();
      final second = LinkedScrollGroup();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      Widget build(LinkedScrollGroup group) => makeTestableWidgetNoScroll(
        SizedBox(
          width: 100,
          child: LinkedDayTrackScroller(
            group: group,
            child: const SizedBox(width: 300, height: 10),
          ),
        ),
      );
      await tester.pumpWidget(build(first));
      final firstController = tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .controller;
      await tester.pumpWidget(build(second));
      final secondController = tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .controller;
      expect(secondController, isNot(same(firstController)));
      // Detaching disposes the controller, so it refuses new listeners.
      expect(
        () => firstController!.addListener(() {}),
        throwsFlutterError,
        reason: 'detached from the old group',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(() => secondController!.addListener(() {}), throwsFlutterError);
    },
  );
}
