import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
import 'package:lotti/features/plaza/ui/facade_widget.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';

import '../../../widget_test_utils.dart';

final _now = DateTime.utc(2026, 7, 15);

PlazaTask _task({
  PlazaTaskState state = PlazaTaskState.open,
  double progress = 0,
  int checklistItems = 0,
  List<String> openItems = const [],
  List<String> links = const [],
  DateTime? due,
  String? coverUrl,
}) {
  return PlazaTask(
    id: 'facade-test',
    createdAt: DateTime.utc(2026, 3, 2, 9),
    title: 'Negotiate sardine futures',
    state: state,
    progress: progress,
    checklistItems: checklistItems,
    openChecklistItems: openItems,
    linkedTaskIds: links,
    categoryColor: 0xFF5C9DFF,
    due: due,
    coverImageUrl: coverUrl,
  );
}

Widget _host(
  PlazaTask task, {
  FacadeVariant variant = FacadeVariant.live,
  ChecklistTicks? ticks,
  VoidCallback? onOpen,
  bool focused = false,
}) {
  return makeTestableWidget2(
    Center(
      child: SizedBox(
        width: 540,
        height: 720,
        child: FacadeWidget(
          task: task,
          attention: attentionFor(task, _now),
          variant: variant,
          widthMeters: 12,
          pxPerMeter: 45,
          ticks: ticks,
          onOpen: onOpen,
          focused: focused,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('live facade shows title, chip, meta and progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _task(
          state: PlazaTaskState.inProgress,
          due: DateTime.utc(2026, 7, 17),
          links: ['a', 'b'],
          checklistItems: 4,
          progress: 0.5,
          openItems: ['Check bay two', 'Ask the dock crew'],
        ),
      ),
    );
    expect(find.text('Negotiate sardine futures'), findsOneWidget);
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('due Jul 17  ·  links 2'), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);
    expect(find.text('Check bay two'), findsOneWidget);
    // The light bar spans half the base.
    final bar = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(bar.widthFactor, 0.5);
  });

  testWidgets('sign facade drops everything but title, chip and bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _task(
          state: PlazaTaskState.inProgress,
          due: DateTime.utc(2026, 7, 17),
          checklistItems: 2,
          openItems: ['Check bay two'],
          coverUrl: 'https://demo.invalid/cover.webp',
        ),
        variant: FacadeVariant.sign,
      ),
    );
    expect(find.text('Negotiate sardine futures'), findsOneWidget);
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.textContaining('due Jul 17'), findsNothing);
    expect(find.text('Check bay two'), findsNothing);
    expect(find.text('OPEN'), findsNothing);
    expect(find.byType(Image), findsNothing);
    // Bigger type than the live variant for the same wall.
    final sign = tester.widget<Text>(find.text('Negotiate sardine futures'));
    await tester.pumpWidget(_host(_task()));
    final live = tester.widget<Text>(find.text('Negotiate sardine futures'));
    expect(sign.style!.fontSize!, greaterThan(live.style!.fontSize!));
  });

  testWidgets('overdue overrides the chip; an in-progress task fills 35%', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_task(due: DateTime.utc(2026, 7, 1))),
    );
    expect(find.text('OVERDUE'), findsOneWidget);
    expect(find.text('OPEN'), findsNothing);

    await tester.pumpWidget(_host(_task(state: PlazaTaskState.inProgress)));
    final bar = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(bar.widthFactor, 0.35);
  });

  testWidgets('ticking on the wall goes through the shared ticks', (
    tester,
  ) async {
    final ticks = ChecklistTicks();
    await tester.pumpWidget(
      _host(
        _task(
          state: PlazaTaskState.inProgress,
          checklistItems: 3,
          progress: 1 / 3,
          openItems: ['Check bay two', 'Ask the dock crew'],
        ),
        ticks: ticks,
      ),
    );
    expect(find.text('1/3'), findsOneWidget);
    await tester.tap(find.text('Check bay two'));
    await tester.pump();
    expect(ticks.isTicked('facade-test', 0), isTrue);
    expect(find.text('2/3'), findsOneWidget);
    final struck = tester.widget<Text>(find.text('Check bay two'));
    expect(struck.style?.decoration, TextDecoration.lineThrough);

    // A tick from elsewhere (the side panel) shows on the wall too.
    ticks.toggle('facade-test', 1);
    await tester.pump();
    expect(find.text('3/3'), findsOneWidget);
  });

  testWidgets('without ticks the items are inert; OPEN fires its callback', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      _host(
        _task(checklistItems: 1, openItems: ['Check bay two']),
        onOpen: () => opened++,
      ),
    );
    await tester.tap(find.text('Check bay two'));
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Check bay two')).style?.decoration,
      isNull,
    );
    await tester.tap(find.text('OPEN'));
    expect(opened, 1);
  });

  testWidgets('the OPEN chip and the state chip use the design colours', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_task(state: PlazaTaskState.blocked), onOpen: () {}),
    );
    expect(find.text('BLOCKED'), findsOneWidget);
    final open = tester.widget<Container>(
      find.ancestor(of: find.text('OPEN'), matching: find.byType(Container)).first,
    );
    expect((open.decoration! as BoxDecoration).color, PlazaStyle.teal);
  });

  testWidgets('focused draws the teal ring', (tester) async {
    await tester.pumpWidget(_host(_task(), focused: true));
    final ringed = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.foregroundDecoration != null);
    expect(ringed, hasLength(1));
    final border = (ringed.first.foregroundDecoration! as BoxDecoration).border!;
    expect(border.top.color, PlazaStyle.teal);
    await tester.pumpWidget(_host(_task()));
    expect(
      tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.foregroundDecoration != null),
      isEmpty,
    );
  });

  testWidgets('a broken cover collapses without throwing', (tester) async {
    await tester.pumpWidget(
      _host(_task(coverUrl: 'https://demo.invalid/cover.webp')),
    );
    expect(find.byType(Image), findsOneWidget);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(RawImage), findsNothing);
  });
}
