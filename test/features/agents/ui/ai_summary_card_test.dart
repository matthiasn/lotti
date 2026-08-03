import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/assign_agent_cta_part.dart';

import '../../../test_helper.dart';
import 'ai_summary_card/test_bench.dart';

/// Root-shell routing of [AiSummaryCard]: the four `taskAgentProvider`
/// branches (loading, error, data-null, data-with-identity). The shell's
/// inner behavior is covered by the part-file mirrors under
/// `ai_summary_card/`.
void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required Future<AgentDomainEntity?> Function() taskAgent,
    // The CTA is gated on the feature being usable at all: with no task-agent
    // template installed, the picker it opens dead-ends on a warning toast,
    // so the offer is withheld.
    bool templatesExist = true,
    bool showAssignCta = true,
  }) async {
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: [
          taskAgentProvider.overrideWith((ref, id) => taskAgent()),
          taskAgentTemplatesExistProvider.overrideWith(
            (ref) async => templatesExist,
          ),
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
    'no task-agent template installed: no CTA — the picker it opens would '
    'dead-end on a warning toast',
    (tester) async {
      await pumpCard(
        tester,
        taskAgent: () async => null,
        templatesExist: false,
      );
      await tester.pump();

      expect(find.text('Assign Agent'), findsNothing);
      expect(find.text('AI summary'), findsNothing);
    },
  );

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
}
