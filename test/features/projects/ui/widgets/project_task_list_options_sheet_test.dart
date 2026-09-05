import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/projects/ui/model/project_task_list_options.dart';
import 'package:lotti/features/projects/ui/widgets/project_task_list_options_sheet.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget subject(
    ProjectTaskListOptions options,
    ValueChanged<ProjectTaskListOptions> onChanged,
  ) => makeTestableWidget2(
    Scaffold(
      body: ProjectTaskListOptionsSheetContent(
        options: options,
        onChanged: onChanged,
      ),
    ),
    mediaQueryData: const MediaQueryData(size: Size(400, 1400)),
  );

  bool selected(WidgetTester tester, String title) => tester
      .widget<DesignSystemSelectionRow>(
        find.widgetWithText(DesignSystemSelectionRow, title),
      )
      .selected;

  testWidgets('shows both sections with the current choices selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        const ProjectTaskListOptions(
          groupBy: ProjectTaskGroupBy.priority,
          sortBy: ProjectTaskSortBy.dueDate,
          keepDoneInGroups: true,
        ),
        (_) {},
      ),
    );

    expect(find.text('Group by'), findsOneWidget);
    expect(find.text('Sort by'), findsOneWidget);
    expect(find.text('Creation month'), findsOneWidget);
    expect(find.text('Recently updated'), findsOneWidget);
    expect(selected(tester, 'Creation month'), isFalse);
    expect(selected(tester, 'Due date'), isTrue);
    expect(find.text('Keep done tasks in their groups'), findsOneWidget);
    // "Priority" appears once per section; the group-by one is selected.
    final priorityRows = tester
        .widgetList<DesignSystemSelectionRow>(
          find.widgetWithText(DesignSystemSelectionRow, 'Priority'),
        )
        .map((row) => row.selected)
        .toList();
    expect(priorityRows, [true, false]);
  });

  testWidgets('each choice applies immediately and only when it changes', (
    tester,
  ) async {
    final applied = <ProjectTaskListOptions>[];
    await tester.pumpWidget(
      subject(ProjectTaskListOptions.defaults, applied.add),
    );

    Future<void> pick(String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pump();
    }

    await pick('Status');
    await pick('Title');
    await pick('Keep done tasks in their groups');
    await pick('Title');

    expect(applied, [
      const ProjectTaskListOptions(groupBy: ProjectTaskGroupBy.status),
      const ProjectTaskListOptions(
        groupBy: ProjectTaskGroupBy.status,
        sortBy: ProjectTaskSortBy.title,
      ),
      const ProjectTaskListOptions(
        groupBy: ProjectTaskGroupBy.status,
        sortBy: ProjectTaskSortBy.title,
        keepDoneInGroups: true,
      ),
    ]);
    expect(selected(tester, 'Status'), isTrue);
    expect(selected(tester, 'Creation month'), isFalse);
  });

  testWidgets('the sheet opens with its title from the shared modal', (
    tester,
  ) async {
    ProjectTaskListOptions? changed;
    await tester.pumpWidget(
      makeTestableWidget2(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showProjectTaskListOptionsSheet(
                context: context,
                options: ProjectTaskListOptions.defaults,
                onChanged: (value) => changed = value,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Sort and group'), findsOneWidget);
    expect(find.text('Group by'), findsOneWidget);
    await tester.tap(find.text('Due window'));
    await tester.pump();
    expect(changed?.groupBy, ProjectTaskGroupBy.dueWindow);
  });

  test('labels cover every grouping and ordering', () async {
    final messages = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      ProjectTaskGroupBy.values.map(
        (g) => projectTaskGroupByLabel(messages, g),
      ),
      ['Creation month', 'Status', 'Priority', 'Due window', 'None'],
    );
    expect(
      ProjectTaskSortBy.values.map((s) => projectTaskSortByLabel(messages, s)),
      [
        'Actionability',
        'Created',
        'Due date',
        'Estimate',
        'Priority',
        'Recently updated',
        'Title',
      ],
    );
  });
}
