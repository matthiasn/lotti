import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline_fold_surface.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline_folding.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_utils/material_ui_finders.dart';
import '../../../../widget_test_utils.dart';

/// A phone lane's width once the hour rail and the gutters are taken: the
/// width the fold pill actually gets on an iPhone SE.
const double _narrowLane = 174;

TimelineFoldingState _stateWithFold({
  required bool expanded,
  int startHour = 8,
  int endHour = 18,
}) => TimelineFoldingState(
  startHour: 0,
  endHour: 24,
  segments: [
    TimelineVisibleRegion(startHour: 0, endHour: startHour),
    TimelineFoldRegion(
      startHour: startHour,
      endHour: endHour,
      isExpanded: expanded,
      collapsedHourHeight: 6,
    ),
    if (endHour < 24) TimelineVisibleRegion(startHour: endHour, endHour: 24),
  ],
);

Widget _layer({
  required TimelineFoldingState state,
  required ValueChanged<int> onToggle,
  double width = _narrowLane,
  double textScale = 1,
}) => makeTestableWidget2(
  Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      height: state.totalHeight(1),
      child: FoldRegionLayer(
        foldingState: state,
        pxPerMinute: 1,
        onToggleFoldRegion: onToggle,
      ),
    ),
  ),
  mediaQueryData: phoneMediaQueryData.copyWith(
    textScaler: TextScaler.linear(textScale),
  ),
);

void main() {
  group('FoldRegionLayer', () {
    // The pill used to shrink-wrap an icon and a rigid caption; at 2× text in
    // a narrow lane the caption alone outgrew the region and the row
    // overflowed — a striped error box on the default Day view of a small
    // phone with large text.
    for (final expanded in [false, true]) {
      testWidgets(
        '${expanded ? 'an expanded' : 'a compressed'} fold pill stays inside '
        'a narrow lane at large text',
        (tester) async {
          final state = _stateWithFold(expanded: expanded);
          await tester.pumpWidget(
            _layer(state: state, onToggle: (_) {}, textScale: 2),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          final label = find.text('08:00-18:00');
          expect(label, findsOneWidget);
          // What the ellipsis takes at this size is still one long-press
          // away.
          expect(findMaterialTooltip('08:00-18:00'), findsOneWidget);
          final region = find.byKey(const Key('daily_os_timeline_fold_8_18'));
          final regionRect = tester.getRect(region);
          final labelRect = tester.getRect(label);
          expect(labelRect.right, lessThanOrEqualTo(regionRect.right));
          expect(labelRect.left, greaterThanOrEqualTo(regionRect.left));
          expect(regionRect.width, _narrowLane);
        },
      );
    }

    testWidgets('at regular text the label is not clipped', (tester) async {
      await tester.pumpWidget(
        _layer(state: _stateWithFold(expanded: false), onToggle: (_) {}),
      );
      await tester.pump();

      final text = tester.widget<Text>(find.text('08:00-18:00'));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('08:00-18:00'),
      );
      expect(text.overflow, TextOverflow.ellipsis);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a fold region reports its start hour, in either '
        'state', (tester) async {
      for (final expanded in [false, true]) {
        final toggled = <int>[];
        // A short fold: expanded it is 4 h × 60 px, so its centre stays
        // inside the test view either way.
        await tester.pumpWidget(
          _layer(
            state: _stateWithFold(expanded: expanded, startHour: 1, endHour: 5),
            onToggle: toggled.add,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('daily_os_timeline_fold_1_5')));
        await tester.pump();

        expect(toggled, [1], reason: 'expanded: $expanded');
      }
    });

    testWidgets('a fold that runs to midnight is labelled 24:00', (
      tester,
    ) async {
      await tester.pumpWidget(
        _layer(
          state: _stateWithFold(expanded: false, startHour: 18, endHour: 24),
          onToggle: (_) {},
        ),
      );
      await tester.pump();

      expect(find.text('18:00-24:00'), findsOneWidget);
    });
  });
}
