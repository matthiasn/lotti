import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/plaza_search_sheet.dart';

import '../../../widget_test_utils.dart';

final _now = DateTime.utc(2026, 7, 15);

PlazaTask _task(String id, String title, {bool deleted = false}) => PlazaTask(
  id: id,
  createdAt: DateTime.utc(2026, 7),
  title: title,
  state: PlazaTaskState.open,
  progress: 0,
  checklistItems: 0,
  linkedTaskIds: const [],
  categoryColor: 0,
  deleted: deleted,
);

final List<PlazaTask> _tasks = [
  _task('1', 'Fuel the shuttle'),
  _task('2', 'Seal the hatch gaskets'),
  _task('3', 'Load the sardine cargo pods'),
  _task('4', 'Stock the sardine cold ring'),
  _task('5', 'Deleted sardine task', deleted: true),
  for (var i = 6; i < 14; i++) _task('$i', 'Filler task $i'),
];

void main() {
  group('searchPlazaTasks', () {
    test('matches titles case-insensitively, skips deleted, caps at six', () {
      expect(
        searchPlazaTasks(_tasks, 'SARDINE').map((t) => t.id),
        ['3', '4'],
      );
      expect(searchPlazaTasks(_tasks, ''), hasLength(6));
      expect(searchPlazaTasks(_tasks, 'nothing here'), isEmpty);
    });
  });

  group('PlazaSearchSheet', () {
    late List<PlazaTask> picked;
    late int closed;

    setUp(() {
      picked = [];
      closed = 0;
    });

    Widget host() => makeTestableWidget2(
      Scaffold(
        body: PlazaSearchSheet(
          tasks: _tasks,
          attentionOf: (t) => attentionFor(t, _now),
          weekOf: (t) => 'W1',
          onPick: picked.add,
          onClose: () => closed++,
        ),
      ),
      mediaQueryData: const MediaQueryData(size: Size(1200, 800)),
    );

    testWidgets('typing filters, arrows move the selection, enter flies', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(find.text('↵ fly'), findsNWidgets(6));
      await tester.enterText(find.byType(TextField), 'sardine');
      await tester.pump();
      expect(find.text('Load the sardine cargo pods'), findsOneWidget);
      expect(find.text('Stock the sardine cold ring'), findsOneWidget);
      expect(find.text('Deleted sardine task'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(picked.map((t) => t.id), ['4']);
    });

    testWidgets('arrows and enter are no-ops when nothing matches', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.enterText(find.byType(TextField), 'zzz nothing');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(picked, isEmpty);
    });

    testWidgets('clicking a result picks it; escape closes', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('Seal the hatch gaskets'));
      expect(picked.map((t) => t.id), ['2']);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closed, 1);
    });
  });
}
