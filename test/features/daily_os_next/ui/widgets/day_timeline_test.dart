import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/why_chip.dart';

import '../../../../widget_test_utils.dart';

DraftPlan _draft() {
  final day = DateTime(2026, 5, 25);
  DateTime at(int h, int m) => day.add(Duration(hours: h, minutes: m));
  const work = DayAgentCategory(
    id: 'cat_work',
    name: 'Work',
    colorHex: '5ED4B7',
  );
  const buffer = DayAgentCategory(
    id: 'cat_buffer',
    name: 'Buffer',
    colorHex: '8E8E8E',
  );
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
        category: work,
        reason: 'Your highest-focus window.',
      ),
      TimeBlock(
        id: 'b_buffer',
        title: 'Buffer',
        start: at(10, 0),
        end: at(10, 30),
        type: TimeBlockType.buffer,
        state: TimeBlockState.drafted,
        category: buffer,
      ),
      TimeBlock(
        id: 'b_cal',
        title: 'Team sync',
        start: at(13, 0),
        end: at(13, 30),
        type: TimeBlockType.cal,
        state: TimeBlockState.committed,
        category: work,
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
    capacityMinutes: 480,
    scheduledMinutes: 120,
  );
}

Widget _wrap(Widget child) {
  return makeTestableWidget2(
    child,
    mediaQueryData: const MediaQueryData(size: Size(1280, 1200)),
  );
}

void main() {
  group('DayTimeline', () {
    testWidgets('renders each block from the draft and an energy band label', (
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
      // Energy band overline.
      expect(find.text('HIGH ENERGY'), findsOneWidget);
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

      // Hour-rail label badge at 9:15.
      expect(find.text('9:15'), findsOneWidget);
    });
  });
}
