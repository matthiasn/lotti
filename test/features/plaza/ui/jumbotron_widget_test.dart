import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/jumbotron_widget.dart';

import '../../../widget_test_utils.dart';

PlazaTask _task(String id, String title) => PlazaTask(
  id: id,
  createdAt: DateTime.utc(2026, 7),
  title: title,
  state: PlazaTaskState.blocked,
  progress: 0,
  checklistItems: 0,
  linkedTaskIds: const [],
  categoryColor: 0,
);

/// The harness clock the widget reads; each test starts it at zero.
final clock = ValueNotifier<double>(0);

void main() {
  setUp(() => clock.value = 0);

  final now = DateTime.utc(2026, 7, 15);
  final headlines = [
    for (var i = 0; i < 4; i++) attentionFor(_task('$i', 'Headline $i'), now),
  ];

  Widget host({
    List<String> covers = const [],
    ValueNotifier<bool>? pin,
  }) => makeTestableWidget2(
    Center(
      child: SizedBox(
        width: 900,
        height: 480,
        child: JumbotronWidget(
          clock: clock,
          projectLabel: 'Project Waddle',
          taskCount: 28,
          attentionCount: 7,
          headlines: headlines,
          covers: covers,
          widthMeters: 30,
          pxPerMeter: 30,
          pinProjectCard: pin,
        ),
      ),
    ),
  );

  testWidgets('pinned, the screen holds the project card through the cycle', (
    tester,
  ) async {
    final pin = ValueNotifier<bool>(true);
    addTearDown(pin.dispose);
    await tester.pumpWidget(host(pin: pin));
    expect(find.text('28 tasks · 7 need attention'), findsOneWidget);
    clock.value += 5;
    await tester.pump();
    clock.value += 5;
    await tester.pump();
    // Still the card, where an unpinned screen would show a headline.
    expect(find.text('28 tasks · 7 need attention'), findsOneWidget);
    expect(find.textContaining('Headline'), findsNothing);
    // Release: the headlines come back on the next frame.
    pin.value = false;
    await tester.pump();
    expect(find.textContaining('Headline'), findsOneWidget);
  });

  testWidgets('a two-line headline with its reason fits the panel', (
    tester,
  ) async {
    final long = [
      attentionFor(
        _task('long', 'Trace the humidity spike in Bay C before the audit'),
        now,
      ),
    ];
    // The real 30 × 16 m panel, then a squatter one the slide must scale
    // down into.
    for (final height in [480.0, 330.0]) {
      // Every height starts the screen's cycle afresh.
      clock.value = 0;
      await tester.pumpWidget(
        makeTestableWidget2(
          Center(
            child: SizedBox(
              width: 900,
              height: height,
              child: JumbotronWidget(
                clock: clock,
                key: ValueKey(height),
                projectLabel: 'Project Waddle',
                taskCount: 28,
                attentionCount: 7,
                headlines: long,
                covers: const [],
                widthMeters: 30,
                pxPerMeter: 30,
              ),
            ),
          ),
        ),
      );
      clock.value += 5;
      await tester.pump();
      expect(find.text('blocked — needs a decision'), findsOneWidget);
      expect(find.text('fly there ›'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'height $height');
    }
  });

  testWidgets('one message at a time: the project card, then each headline', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    expect(find.text('Project Waddle'), findsOneWidget);
    expect(find.text('28 tasks · 7 need attention'), findsOneWidget);
    expect(find.textContaining('Headline'), findsNothing);
    expect(find.byType(Image), findsNothing);
    for (var i = 0; i < 3; i++) {
      clock.value += 5;
      await tester.pump();
      expect(find.text('Headline $i'), findsOneWidget);
      expect(find.text('Project Waddle'), findsNothing);
      expect(find.textContaining('BLOCKED'), findsOneWidget);
      expect(find.text('blocked — needs a decision'), findsOneWidget);
    }
    // Only the top three, then back to the card.
    clock.value += 5;
    await tester.pump();
    expect(find.text('Project Waddle'), findsOneWidget);
    expect(find.textContaining('Headline 3'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cycles the hero covers every few seconds', (tester) async {
    await tester.pumpWidget(
      host(covers: ['https://x.invalid/a.webp', 'https://x.invalid/b.webp']),
    );
    Image image() => tester.widget<Image>(find.byType(Image));
    expect((image().image as NetworkImage).url, endsWith('a.webp'));
    clock.value += 5;
    await tester.pump();
    expect((image().image as NetworkImage).url, endsWith('b.webp'));
    clock.value += 5;
    await tester.pump();
    expect((image().image as NetworkImage).url, endsWith('a.webp'));
  });
}
