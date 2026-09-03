import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/facade_widget.dart';

import '../../../widget_test_utils.dart';

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

Widget _host(PlazaTask task, {bool interactive = false}) {
  return makeTestableWidget2(
    Center(
      child: SizedBox(
        width: 500,
        height: 700,
        child: FacadeWidget(task: task, interactive: interactive),
      ),
    ),
  );
}

void main() {
  testWidgets('shows title, state label, due date and link count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _task(
          state: PlazaTaskState.inProgress,
          due: DateTime.utc(2026, 7, 17),
          links: ['a', 'b'],
        ),
      ),
    );
    expect(find.text('Negotiate sardine futures'), findsOneWidget);
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('due Jul 17'), findsOneWidget);
    expect(find.text('links 2'), findsOneWidget);
  });

  testWidgets('checklist progress renders as facade fill and counter', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _task(
          state: PlazaTaskState.inProgress,
          checklistItems: 4,
          progress: 0.5,
          openItems: ['Check bay two', 'Ask the dock crew'],
        ),
      ),
    );
    final fill = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fill.heightFactor, 0.5);
    expect(find.text('2/4'), findsOneWidget);
    expect(find.text('Check bay two'), findsOneWidget);
    expect(find.text('Ask the dock crew'), findsOneWidget);
  });

  testWidgets('near tier ticks a checklist item live; ticking strikes it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _task(
          state: PlazaTaskState.inProgress,
          checklistItems: 2,
          openItems: ['Check bay two'],
        ),
        interactive: true,
      ),
    );
    expect(
      tester.widget<Checkbox>(find.byType(Checkbox)).onChanged,
      isNotNull,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    final struck = tester.widget<Text>(find.text('Check bay two'));
    expect(struck.style?.decoration, TextDecoration.lineThrough);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    final unstruck = tester.widget<Text>(find.text('Check bay two'));
    expect(unstruck.style?.decoration, isNull);
  });

  testWidgets('static tier renders checkboxes disabled', (tester) async {
    await tester.pumpWidget(
      _host(
        _task(
          // ignore: avoid_redundant_argument_values
          state: PlazaTaskState.open,
          checklistItems: 1,
          openItems: ['Check bay two'],
        ),
      ),
    );
    expect(
      tester.widget<Checkbox>(find.byType(Checkbox)).onChanged,
      isNull,
    );
  });

  testWidgets('done tasks go green and quiet: dim title, muted chip', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_task(state: PlazaTaskState.done)));
    expect(find.text('DONE'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Negotiate sardine futures'));
    expect(title.style?.color, FacadeStyle.textDim);
    final material = tester.widget<Material>(find.byType(Material).first);
    expect(material.color, FacadeStyle.backgroundDone);
  });

  testWidgets('a cover URL renders the image slot; broken loads collapse', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_task(coverUrl: 'https://demo.invalid/cover.webp')),
    );
    // The 16:9 frame exists; the test HTTP client fails the fetch and the
    // errorBuilder collapses it without throwing into the test harness.
    expect(find.byType(AspectRatio), findsOneWidget);
    await tester.pump();
    expect(tester.takeException(), isNull);
    // The failed load renders no image pixels — the slot collapsed to the
    // errorBuilder's empty box instead of showing a broken image.
    expect(find.byType(RawImage), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AspectRatio),
        matching: find.byType(SizedBox),
      ),
      findsOneWidget,
    );
  });

  test('state colors and labels cover every state', () {
    for (final state in PlazaTaskState.values) {
      expect(FacadeStyle.stateLabel(state), isNotEmpty);
      expect(FacadeStyle.stateColor(state).a, greaterThan(0));
    }
  });
}
