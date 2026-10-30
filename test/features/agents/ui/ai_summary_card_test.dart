import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_automation_row.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';

import '../../../test_helper.dart';
import '../test_data/entity_factories.dart';
import 'ai_summary_card/test_bench.dart';

/// Root-shell routing of [AiSummaryCard]: the four `taskAgentProvider`
/// branches (loading, error, data-null, data-with-identity). The shell's
/// inner behavior is covered by the part-file mirrors under
/// `ai_summary_card/`.
void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required Future<AgentDomainEntity?> Function() taskAgent,
    bool showAssignCta = true,
  }) async {
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: [
          taskAgentProvider.overrideWith((ref, id) => taskAgent()),
        ],
        child: AiSummaryCard(
          taskId: 'task-001',
          showAssignCta: showAssignCta,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('loading: collapses to nothing (no CTA, no shell)', (
    tester,
  ) async {
    final never = Completer<AgentDomainEntity?>();
    await pumpCard(tester, taskAgent: () => never.future);

    expect(find.text('Assign Agent'), findsNothing);
    expect(find.text('AI summary'), findsNothing);
  });

  testWidgets('error: collapses to nothing (no CTA, no shell)', (
    tester,
  ) async {
    await pumpCard(
      tester,
      taskAgent: () async => throw StateError('agent lookup failed'),
    );
    await tester.pump();

    expect(find.text('Assign Agent'), findsNothing);
    expect(find.text('AI summary'), findsNothing);
  });

  testWidgets('data with no agent: shows the Assign Agent CTA', (
    tester,
  ) async {
    await pumpCard(tester, taskAgent: () async => null);
    await tester.pump();

    expect(find.text('Assign Agent'), findsOneWidget);
    expect(find.text('AI summary'), findsNothing);
  });

  testWidgets(
    'showAssignCta: false suppresses the CTA — the task page folds the same '
    'offer into its first-run block, and two on one screen is one too many',
    (tester) async {
      await pumpCard(
        tester,
        taskAgent: () async => null,
        showAssignCta: false,
      );
      await tester.pump();

      expect(find.text('Assign Agent'), findsNothing);
    },
  );

  testWidgets('data with identity: shows the summary shell', (tester) async {
    await tester.pumpWidget(AgentTestBench().build());
    await tester.pump();
    await tester.pump();

    expect(find.text('AI summary'), findsOneWidget);
    expect(find.text('Assign Agent'), findsNothing);
  });

  testWidgets('the status row follows the disclosure links with no gap of '
      'its own: their tap target already leaves the air the prose above them '
      'has', (tester) async {
    await tester.pumpWidget(
      AgentTestBench(
        report: makeTestReport(tldr: 'Summary line.', content: 'Full report.'),
      ).build(),
    );
    await tester.pump();
    await tester.pump();

    final body = tester.getRect(find.byType(TldrBody));
    final status = tester.getRect(find.byType(AgentAutomationRow));
    expect(status.top, body.bottom);
  });
}
