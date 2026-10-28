import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/task_due_views_provider.dart';
import 'package:lotti/features/tasks/ui/widgets/task_due_views_strip.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

Future<FakeJournalPageController> _pumpStrip(
  WidgetTester tester, {
  required TaskDueViewCounts? counts,
  TaskDueFilter active = TaskDueFilter.all,
}) async {
  final page = FakeJournalPageController(JournalPageState(dueFilter: active));
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      const Scaffold(body: TaskDueViewsStrip()),
      overrides: <Override>[
        journalPageControllerProvider(true).overrideWith(() => page),
        taskDueViewCountsProvider.overrideWith(
          (ref) => counts == null
              // Never resolves: the cold-start loading state.
              ? Completer<TaskDueViewCounts>().future
              : Future.value(counts),
        ),
      ],
    ),
  );
  await tester.pump();
  return page;
}

Finder _view(TaskDueFilter view) =>
    find.byKey(TaskDueViewsStripKeys.view(view));

DsPill _pill(WidgetTester tester, TaskDueFilter view) => tester.widget<DsPill>(
  find.descendant(of: _view(view), matching: find.byType(DsPill)),
);

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  testWidgets('takes no space when nothing is overdue or due today', (
    tester,
  ) async {
    await _pumpStrip(
      tester,
      counts: const TaskDueViewCounts(overdue: 0, dueToday: 0),
    );

    expect(_view(TaskDueFilter.overdue), findsNothing);
    expect(_view(TaskDueFilter.dueToday), findsNothing);
    expect(tester.getSize(find.byKey(TaskDueViewsStripKeys.root)), Size.zero);
  });

  testWidgets('renders nothing while the first counts load', (tester) async {
    await _pumpStrip(tester, counts: null);

    expect(find.byType(DsPill), findsNothing);
  });

  testWidgets('shows only the views that have tasks, with their counts', (
    tester,
  ) async {
    await _pumpStrip(
      tester,
      counts: const TaskDueViewCounts(overdue: 0, dueToday: 2),
    );

    expect(_view(TaskDueFilter.overdue), findsNothing);
    expect(
      find.descendant(
        of: _view(TaskDueFilter.dueToday),
        matching: find.text('Due today'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _view(TaskDueFilter.dueToday),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('overdue leads, solid red; due today follows, tinted orange', (
    tester,
  ) async {
    await _pumpStrip(
      tester,
      counts: const TaskDueViewCounts(overdue: 3, dueToday: 2),
    );
    final tokens = tester.element(find.byType(TaskDueViewsStrip)).designTokens;

    expect(
      tester.getTopLeft(_view(TaskDueFilter.overdue)).dx,
      lessThan(tester.getTopLeft(_view(TaskDueFilter.dueToday)).dx),
    );
    final overdue = _pill(tester, TaskDueFilter.overdue);
    expect(overdue.variant, DsPillVariant.solid);
    expect(overdue.color, tokens.colors.alert.error.defaultColor);
    final dueToday = _pill(tester, TaskDueFilter.dueToday);
    expect(dueToday.variant, DsPillVariant.tinted);
    expect(dueToday.color, tokens.colors.alert.warning.ink);
    // Distinct glyphs, so the two never rely on hue alone.
    expect(
      find.descendant(
        of: _view(TaskDueFilter.overdue),
        matching: find.byIcon(LottiIcons.warning),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _view(TaskDueFilter.dueToday),
        matching: find.byIcon(LottiIcons.today),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a view applies it as the due clause', (tester) async {
    final page = await _pumpStrip(
      tester,
      counts: const TaskDueViewCounts(overdue: 3, dueToday: 2),
    );

    await tester.tap(_view(TaskDueFilter.overdue));
    await tester.pump();

    expect(page.dueFilterCalls, [TaskDueFilter.overdue]);
  });

  testWidgets('the active view is selected, closable, and lifts on tap', (
    tester,
  ) async {
    final page = await _pumpStrip(
      tester,
      counts: const TaskDueViewCounts(overdue: 3, dueToday: 2),
      active: TaskDueFilter.dueToday,
    );

    expect(_pill(tester, TaskDueFilter.dueToday).selected, isTrue);
    expect(_pill(tester, TaskDueFilter.overdue).selected, isFalse);
    expect(
      find.descendant(
        of: _view(TaskDueFilter.dueToday),
        matching: find.byIcon(LottiIcons.close),
      ),
      findsOneWidget,
    );

    await tester.tap(_view(TaskDueFilter.dueToday));
    await tester.pump();

    expect(page.dueFilterCalls, [TaskDueFilter.all]);
  });

  testWidgets('an emptied active view stays, so the way out stays visible', (
    tester,
  ) async {
    await _pumpStrip(
      tester,
      counts: const TaskDueViewCounts(overdue: 0, dueToday: 0),
      active: TaskDueFilter.overdue,
    );

    expect(_view(TaskDueFilter.overdue), findsOneWidget);
    expect(
      find.descendant(
        of: _view(TaskDueFilter.overdue),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(_view(TaskDueFilter.dueToday), findsNothing);
  });

  testWidgets('each view is one button speaking its name and count', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpStrip(
      tester,
      counts: const TaskDueViewCounts(overdue: 1, dueToday: 0),
    );

    expect(
      tester.getSemantics(_view(TaskDueFilter.overdue)),
      matchesSemantics(
        label: 'Overdue, 1 task',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
