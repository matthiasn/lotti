import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/icon_tokens.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_reply_parts.dart';
import 'package:lotti/features/front_agent/ui/front_task_list.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/features/tasks/ui/due_date_text.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  final at = DateTime(2026, 11, 7, 9);
  final colony = CategoryDefinition(
    id: 'colony',
    name: 'Colony',
    color: '#4CAF93',
    createdAt: at,
    updatedAt: at,
    vectorClock: null,
    private: false,
    active: true,
  );

  Task task(
    String id,
    String title,
    TaskStatus status, {
    DateTime? due,
    String? categoryId = 'colony',
  }) => testTask.copyWith(
    data: testTask.data.copyWith(title: title, status: status, due: due),
    meta: testTask.meta.copyWith(id: id, categoryId: categoryId),
  );

  final counting = task(
    't1',
    'Count the hatchlings',
    TaskStatus.inProgress(id: 's1', createdAt: at, utcOffset: 60),
    due: at,
  );
  final done = task(
    't2',
    'Check the nest cameras',
    TaskStatus.done(id: 's2', createdAt: at, utcOffset: 60),
    due: at,
    categoryId: null,
  );

  const mentions = [
    FrontTaskMention(id: 't1', title: 'Count the hatchlings (as she said)'),
    FrontTaskMention(id: 't2', title: 'Check the nest cameras'),
    FrontTaskMention(id: 'gone', title: 'Feed the chicks'),
    FrontTaskMention(
      id: 'p1',
      title: 'Colony census',
      kind: FrontDestinationKind.project,
    ),
  ];
  const countingOneLiner = 'Halfway through the north beach';

  late List<String> opened;
  late List<FrontDestinationKind> openedKinds;

  Future<void> pump(
    WidgetTester tester, {
    Future<Task?> Function(String id)? load,
  }) async {
    opened = [];
    openedKinds = [];
    final cache = MockEntitiesCacheService();
    when(() => cache.getCategoryById(any())).thenReturn(null);
    when(() => cache.getCategoryById('colony')).thenReturn(colony);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: SingleChildScrollView(
            child: FrontTaskList(
              tasks: mentions,
              onOpen: (m) {
                opened.add(m.id);
                openedKinds.add(m.kind);
              },
            ),
          ),
        ),
        overrides: [
          entitiesCacheServiceProvider.overrideWithValue(cache),
          taskPreviewProvider.overrideWith((ref, id) async {
            final task =
                await (load?.call(id) ??
                    Future.value({'t1': counting, 't2': done}[id]));
            if (task == null) return null;
            return TaskPreview(
              task: task,
              oneLiner: id == 't1' ? countingOneLiner : null,
              tldr: 'Not shown in the row',
            );
          }),
        ],
      ),
    );
    await tester.pump();
  }

  Finder inRow(String id, Finder finder) => find.descendant(
    of: find.byKey(FrontTaskListKeys.row(id)),
    matching: finder,
  );

  testWidgets('one card, one row per task, in her order', (tester) async {
    await pump(tester);

    expect(find.byKey(FrontTaskListKeys.card), findsOne);
    final tops = [
      for (final m in mentions)
        tester.getTopLeft(find.byKey(FrontTaskListKeys.row(m.id))).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets('a task shows as it is now: its own title, its status glyph, '
      'its status and category, and when it is due', (tester) async {
    await pump(tester);

    expect(inRow('t1', find.text('Count the hatchlings')), findsOne);
    expect(
      tester.widget<StatusGlyph>(inRow('t1', find.byType(StatusGlyph))).status,
      counting.data.status,
    );
    expect(
      inRow(
        't1',
        find.textContaining('In Progress · Colony', findRichText: true),
      ),
      findsOne,
    );
    expect(
      tester.widget<DueDateText>(inRow('t1', find.byType(DueDateText))).dueDate,
      at,
    );
  });

  testWidgets('a settled task says no due date, and a task with no category '
      'shows its status alone', (tester) async {
    await pump(tester);

    expect(inRow('t2', find.byType(DueDateText)), findsNothing);
    expect(
      inRow('t2', find.textContaining('Done', findRichText: true)),
      findsOne,
    );
    expect(
      inRow('t2', find.textContaining('·', findRichText: true)),
      findsNothing,
    );
  });

  testWidgets('a task that is gone, or not loaded yet, keeps the title she '
      'gave it, and still opens', (tester) async {
    final pending = Completer<Task?>();
    await pump(
      tester,
      load: (id) => id == 't1' ? pending.future : Future.value(),
    );

    expect(inRow('gone', find.text('Feed the chicks')), findsOne);
    expect(
      inRow('t1', find.text('Count the hatchlings (as she said)')),
      findsOne,
    );
    expect(inRow('gone', find.byType(StatusGlyph)), findsNothing);

    await tester.tap(find.byKey(FrontTaskListKeys.row('gone')));
    expect(opened, ['gone']);
  });

  testWidgets('a tap on a row opens its task', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(FrontTaskListKeys.row('t2')));
    await tester.tap(find.byKey(FrontTaskListKeys.row('t1')));

    expect(opened, ['t2', 't1']);
  });

  testWidgets("a task's one-liner shows in its row, above its status; its "
      'TL;DR does not, it is a tap away', (tester) async {
    await pump(tester);

    final subtitle = inRow(
      't1',
      find.textContaining(countingOneLiner, findRichText: true),
    );
    expect(subtitle, findsOne);
    expect(
      tester.widget<RichText>(subtitle).text.toPlainText(),
      startsWith('$countingOneLiner\nIn Progress · Colony'),
    );
    expect(find.textContaining('Not shown in the row'), findsNothing);
  });

  testWidgets('a project in the list is a row of its own that opens the '
      'project', (tester) async {
    await pump(tester);

    expect(inRow('p1', find.text('Colony census')), findsOne);
    expect(inRow('p1', find.byIcon(LottiIcons.folder)), findsOne);

    await tester.tap(find.byKey(FrontTaskListKeys.row('p1')));
    expect(opened, ['p1']);
    expect(openedKinds, [FrontDestinationKind.project]);
  });
}
