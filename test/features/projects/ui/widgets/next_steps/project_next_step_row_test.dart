import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/projects/ui/widgets/next_steps/project_next_step_row.dart';

import '../../../../../widget_test_utils.dart';
import '../../../../agents/test_data/change_set_factories.dart';

void main() {
  const title = 'Recalibrate the zero-gravity fish feeder';
  const rationale = 'It is the only launch blocker.';
  final step = makeTestProjectRecommendation(
    id: 'step-1',
    title: title,
    rationale: rationale,
  );

  Widget subject(
    ProjectNextStepRow row, {
    double width = 340,
  }) => makeTestableWidget2(
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: row),
    ),
    mediaQueryData: const MediaQueryData(size: Size(1000, 900)),
  );

  testWidgets('a pending step offers labelled Add task and Dismiss', (
    tester,
  ) async {
    var added = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      subject(
        ProjectNextStepRow(
          step: step,
          state: ProjectNextStepRowState.pending,
          onAddTask: () => added++,
          onDismiss: () => dismissed++,
        ),
      ),
    );

    expect(find.text(title), findsOneWidget);
    expect(find.text(rationale), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    await tester.tap(find.text('Add task'));
    await tester.tap(find.text('Dismiss'));
    expect(added, 1);
    expect(dismissed, 1);
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Creating task…'), findsNothing);
  });

  testWidgets('a pending step decides by swipe and stays in place', (
    tester,
  ) async {
    var added = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      subject(
        ProjectNextStepRow(
          step: step,
          state: ProjectNextStepRowState.pending,
          onAddTask: () => added++,
          onDismiss: () => dismissed++,
        ),
      ),
    );
    final swipe = find.byKey(const ValueKey('project-next-step-swipe-step-1'));
    expect(swipe, findsOneWidget);

    await tester.drag(swipe, const Offset(400, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(added, 1);
    expect(dismissed, 0);
    expect(find.text(title), findsOneWidget, reason: 'snaps back');

    await tester.drag(swipe, const Offset(-400, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(dismissed, 1);
    expect(added, 1);
    expect(find.text(title), findsOneWidget);
  });

  testWidgets('only a pending, enabled step with an action swipes', (
    tester,
  ) async {
    Widget row({
      ProjectNextStepRowState state = ProjectNextStepRowState.pending,
      bool enabled = true,
      VoidCallback? onAddTask,
      VoidCallback? onDismiss,
    }) => subject(
      ProjectNextStepRow(
        step: step,
        state: state,
        enabled: enabled,
        onAddTask: onAddTask,
        onDismiss: onDismiss,
      ),
    );
    void noop() {}

    await tester.pumpWidget(row(state: ProjectNextStepRowState.added));
    expect(find.byType(Dismissible), findsNothing);

    await tester.pumpWidget(row(enabled: false, onAddTask: noop));
    expect(find.byType(Dismissible), findsNothing);

    await tester.pumpWidget(row());
    expect(find.byType(Dismissible), findsNothing, reason: 'no action wired');

    await tester.pumpWidget(row(onDismiss: noop));
    expect(
      tester.widget<Dismissible>(find.byType(Dismissible)).direction,
      DismissDirection.endToStart,
      reason: 'only Dismiss is wired',
    );

    await tester.pumpWidget(row(onAddTask: noop));
    expect(
      tester.widget<Dismissible>(find.byType(Dismissible)).direction,
      DismissDirection.startToEnd,
    );

    await tester.pumpWidget(row(onAddTask: noop, onDismiss: noop));
    expect(
      tester.widget<Dismissible>(find.byType(Dismissible)).direction,
      DismissDirection.horizontal,
    );
  });

  testWidgets('a disabled row keeps its controls visible but inert', (
    tester,
  ) async {
    var added = 0;
    await tester.pumpWidget(
      subject(
        ProjectNextStepRow(
          step: step,
          state: ProjectNextStepRowState.pending,
          enabled: false,
          onAddTask: () => added++,
          onDismiss: () => added++,
        ),
      ),
    );

    expect(
      tester
          .widget<DesignSystemButton>(find.byType(DesignSystemButton))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<DesignSystemInlineAction>(
            find.byType(DesignSystemInlineAction),
          )
          .onTap,
      isNull,
    );
    await tester.tap(find.text('Add task'), warnIfMissed: false);
    await tester.tap(find.text('Dismiss'), warnIfMissed: false);
    expect(added, 0);
  });

  testWidgets('a busy row says it is creating the task and hides the buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        ProjectNextStepRow(step: step, state: ProjectNextStepRowState.busy),
      ),
    );

    expect(find.text('Creating task…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Add task'), findsNothing);
    expect(find.text('Dismiss'), findsNothing);
  });

  testWidgets('an added step links to its task and offers Undo while allowed', (
    tester,
  ) async {
    var opened = 0;
    var undone = 0;
    await tester.pumpWidget(
      subject(
        ProjectNextStepRow(
          step: step,
          state: ProjectNextStepRowState.added,
          canUndo: true,
          onOpenTask: () => opened++,
          onUndo: () => undone++,
        ),
      ),
    );

    expect(find.text('Added'), findsOneWidget);
    await tester.tap(find.text('Open task'));
    await tester.tap(find.text('Undo'));
    expect(opened, 1);
    expect(undone, 1);
    expect(find.text('Add task'), findsNothing);

    await tester.pumpWidget(
      subject(
        ProjectNextStepRow(step: step, state: ProjectNextStepRowState.added),
      ),
    );
    expect(find.text('Undo'), findsNothing, reason: 'The undo window closed.');
    expect(find.text('Added'), findsOneWidget);
  });

  testWidgets('a done step shows its tag without a task link', (tester) async {
    await tester.pumpWidget(
      subject(
        ProjectNextStepRow(
          step: step,
          state: ProjectNextStepRowState.done,
          canUndo: true,
          onUndo: () {},
        ),
      ),
    );

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Open task'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('a dismissed step strikes its title and offers Undo', (
    tester,
  ) async {
    var undone = 0;
    await tester.pumpWidget(
      subject(
        ProjectNextStepRow(
          step: step,
          state: ProjectNextStepRowState.dismissed,
          canUndo: true,
          onUndo: () => undone++,
        ),
      ),
    );

    final titleStyle = tester.widget<Text>(find.text(title)).style;
    expect(titleStyle?.decoration, TextDecoration.lineThrough);
    expect(find.text('Dismissed'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    expect(undone, 1);
  });

  testWidgets('a failed attempt explains itself and offers Retry', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      subject(
        ProjectNextStepRow(
          step: step,
          state: ProjectNextStepRowState.failed,
          onAddTask: () => retried++,
          onDismiss: () {},
        ),
      ),
    );

    expect(
      find.text(
        "Couldn't create the task. Update now to load the current list, "
        'or retry.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
    expect(find.text('Dismiss'), findsOneWidget);

    await tester.pumpWidget(
      subject(
        ProjectNextStepRow(
          step: step,
          state: ProjectNextStepRowState.failed,
          failureMessage: 'Project lookup failed',
          onDismiss: () {},
        ),
      ),
    );
    expect(find.text('Project lookup failed'), findsOneWidget);
    expect(
      find.text('Retry'),
      findsNothing,
      reason: 'A final failure offers no Retry, only Dismiss.',
    );
    expect(find.text('Dismiss'), findsOneWidget);
  });

  testWidgets('priority reads the way the created task would carry it', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        ProjectNextStepRow(
          step: makeTestProjectRecommendation(
            id: 'no-priority',
            title: 'Untriaged',
            rationale: null,
            priority: null,
          ),
          state: ProjectNextStepRowState.pending,
        ),
      ),
    );
    expect(
      find.text('Medium'),
      findsOneWidget,
      reason: 'A step without a priority creates a medium task.',
    );

    await tester.pumpWidget(
      subject(
        ProjectNextStepRow(
          step: makeTestProjectRecommendation(
            id: 'odd-priority',
            title: 'Untriaged',
            priority: 'WHENEVER',
          ),
          state: ProjectNextStepRowState.pending,
        ),
      ),
    );
    for (final label in ['Urgent', 'High', 'Medium', 'Low']) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('the action strip sits beside the text only when wide', (
    tester,
  ) async {
    ProjectNextStepRow row() => ProjectNextStepRow(
      step: step,
      state: ProjectNextStepRowState.pending,
      onAddTask: () {},
      onDismiss: () {},
    );

    await tester.pumpWidget(subject(row()));
    expect(
      tester.getTopLeft(find.text('Add task')).dy,
      greaterThan(tester.getBottomLeft(find.text(rationale)).dy),
      reason: 'On a phone the strip stacks under the text.',
    );

    await tester.pumpWidget(subject(row(), width: 900));
    expect(
      tester.getTopLeft(find.text('Add task')).dy,
      lessThan(tester.getBottomLeft(find.text(rationale)).dy),
      reason: 'On a wide row the strip shares the line with the text.',
    );
    expect(
      tester.getTopLeft(find.text('Add task')).dx,
      greaterThan(tester.getTopRight(find.text(title)).dx),
    );
  });
}
