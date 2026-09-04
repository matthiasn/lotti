import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/billboard_widget.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';

import '../../../widget_test_utils.dart';

final _now = DateTime.utc(2026, 7, 15);

PlazaTask _task({
  PlazaTaskState state = PlazaTaskState.open,
  DateTime? due,
  String? cover,
}) => PlazaTask(
  id: 'bb',
  createdAt: DateTime.utc(2026, 7),
  title: 'Fuel the shuttle',
  state: state,
  progress: 0,
  checklistItems: 0,
  linkedTaskIds: const [],
  categoryColor: 0xFF4AB6E8,
  due: due,
  coverImageUrl: cover,
);

Widget _host(
  PlazaTask task, {
  double pulseSeconds = 3,
  double heightMeters = 8.5,
}) => makeTestableWidget2(
  Center(
    child: SizedBox(
      width: 600,
      height: heightMeters * 40,
      child: BillboardWidget(
        attention: attentionFor(task, _now),
        widthMeters: 15,
        heightMeters: heightMeters,
        pxPerMeter: 40,
        pulseSeconds: pulseSeconds,
      ),
    ),
  ),
);

void main() {
  testWidgets('a blocked task: title, reason, chip, fly-there, red frame', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_task(state: PlazaTaskState.blocked)));
    expect(find.text('Fuel the shuttle'), findsOneWidget);
    expect(find.text('blocked — needs a decision'), findsOneWidget);
    expect(find.text('✕  BLOCKED'), findsOneWidget);
    expect(find.text('fly there ›'), findsOneWidget);
    final framed = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border != null);
    expect(
      framed.border!.top.color.withValues(alpha: 1),
      PlazaStyle.lantern(LanternState.blocked),
    );
  });

  testWidgets('an anomaly breathes: the frame alpha changes over 1.5 s', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_task(state: PlazaTaskState.blocked)));
    double alpha() => tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border != null)
        .border!
        .top
        .color
        .a;
    final start = alpha();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(alpha(), isNot(closeTo(start, 0.05)));
  });

  testWidgets('a due-soon task does not pulse and shows its date', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_task(due: _now)));
    expect(find.text('due Jul 15'), findsOneWidget);
    double alpha() => tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border != null)
        .border!
        .top
        .color
        .a;
    expect(alpha(), 1);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(alpha(), 1);
  });

  testWidgets('cover art gets the middle of the panel', (tester) async {
    await tester.pumpWidget(
      _host(
        _task(state: PlazaTaskState.blocked, cover: 'https://x.invalid/c.webp'),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a shorter pulse is more agitated', (tester) async {
    double alphaOf(WidgetTester t) => t
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border != null)
        .border!
        .top
        .color
        .a;
    await tester.pumpWidget(
      _host(_task(state: PlazaTaskState.blocked), pulseSeconds: 1.2),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final fast = alphaOf(tester);
    await tester.pumpWidget(_host(_task(state: PlazaTaskState.blocked)));
    await tester.pump(const Duration(milliseconds: 600));
    final slow = alphaOf(tester);
    // After 0.6 s the 1.2 s cycle is at its peak; the 3 s cycle is not.
    expect(fast, greaterThan(slow));
  });

  testWidgets('a squat roof panel keeps the cover, then drops the reason', (
    tester,
  ) async {
    final task = _task(
      state: PlazaTaskState.blocked,
      cover: 'https://x.invalid/c.webp',
    );
    await tester.pumpWidget(_host(task, heightMeters: 6));
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('blocked — needs a decision'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_host(task, heightMeters: 4));
    expect(find.text('blocked — needs a decision'), findsNothing);
    expect(tester.widget<Text>(find.text('Fuel the shuttle')).maxLines, 1);
    expect(tester.takeException(), isNull);
  });
}
