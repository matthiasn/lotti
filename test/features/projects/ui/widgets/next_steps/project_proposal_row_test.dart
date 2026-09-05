import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_widgets_part.dart';
import 'package:lotti/features/projects/ui/widgets/next_steps/project_proposal_row.dart';

import '../../../../../widget_test_utils.dart';
import '../../../../agents/test_data/change_set_factories.dart';

void main() {
  final changeSet = makeTestChangeSet(
    id: 'set-1',
    taskId: 'project-1',
    items: const [
      ChangeItem(
        toolName: 'create_task',
        args: {'title': 'Pack fish'},
        humanSummary: 'Create task',
      ),
      ChangeItem(
        toolName: 'update_project_status',
        args: {'status': 'monitoring'},
        humanSummary: 'Set status',
        status: ChangeItemStatus.confirmed,
      ),
      ChangeItem(
        toolName: 'update_project_status',
        args: {'status': 'on_hold'},
        humanSummary: 'Set status',
        status: ChangeItemStatus.rejected,
      ),
    ],
  );

  Widget subject(ProjectProposalRow row) => makeTestableWidget2(
    Align(alignment: Alignment.topLeft, child: row),
    mediaQueryData: const MediaQueryData(size: Size(600, 400)),
  );

  testWidgets('a pending proposal reads its localized summary and decides '
      'through the shared rail', (tester) async {
    var confirmed = 0;
    var rejected = 0;
    await tester.pumpWidget(
      subject(
        ProjectProposalRow(
          changeSet: changeSet,
          itemIndex: 0,
          busy: false,
          onConfirm: () async => confirmed++,
          onReject: () async => rejected++,
        ),
      ),
    );

    expect(find.text('Create task: Pack fish'), findsOneWidget);
    expect(find.byType(RowActions), findsOneWidget);
    await tester.tap(find.byTooltip('Confirm'));
    await tester.tap(find.byTooltip('Reject'));
    expect(confirmed, 1);
    expect(rejected, 1);
    expect(find.byType(ResolvedTag), findsNothing);
  });

  testWidgets('a disabled proposal keeps its rail inert', (tester) async {
    var decided = 0;
    await tester.pumpWidget(
      subject(
        ProjectProposalRow(
          changeSet: changeSet,
          itemIndex: 0,
          busy: false,
          enabled: false,
          onConfirm: () async => decided++,
          onReject: () async => decided++,
        ),
      ),
    );

    expect(tester.widget<RowActions>(find.byType(RowActions)).enabled, isFalse);
    await tester.tap(find.byTooltip('Confirm'));
    await tester.tap(find.byTooltip('Reject'));
    expect(decided, 0);
  });

  testWidgets('an unknown tool falls back to the persisted summary', (
    tester,
  ) async {
    final exotic = makeTestChangeSet(
      id: 'set-2',
      taskId: 'project-1',
      items: const [
        ChangeItem(
          toolName: 'rename_project',
          args: {'title': 'Waddle II'},
          humanSummary: 'Rename the project to Waddle II',
        ),
      ],
    );
    await tester.pumpWidget(
      subject(
        ProjectProposalRow(
          changeSet: exotic,
          itemIndex: 0,
          busy: false,
          onConfirm: () async {},
          onReject: () async {},
        ),
      ),
    );

    expect(find.text('Rename the project to Waddle II'), findsOneWidget);
  });

  testWidgets('a busy proposal shows the rail spinner instead of buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        ProjectProposalRow(
          changeSet: changeSet,
          itemIndex: 0,
          busy: true,
          onConfirm: () async {},
          onReject: () async {},
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Confirm'), findsNothing);
  });

  testWidgets('a decided proposal keeps its place with the resolved tag', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        ProjectProposalRow(
          changeSet: changeSet,
          itemIndex: 1,
          busy: false,
          onConfirm: () async {},
          onReject: () async {},
        ),
      ),
    );
    expect(find.text('Update project status to Monitoring'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.byType(RowActions), findsNothing);

    await tester.pumpWidget(
      subject(
        ProjectProposalRow(
          changeSet: changeSet,
          itemIndex: 2,
          busy: false,
          onConfirm: () async {},
          onReject: () async {},
        ),
      ),
    );
    expect(find.text('Dismissed'), findsOneWidget);
    expect(find.byType(RowActions), findsNothing);
  });
}
