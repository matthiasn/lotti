import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_attribution_summary.dart';

import '../../../test_helper.dart';
import '../../ai_consumption/test_utils.dart';
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
  }) async {
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: [
          taskAgentProvider.overrideWith((ref, id) => taskAgent()),
        ],
        child: const AiSummaryCard(taskId: 'task-001'),
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

  testWidgets('data with identity: shows the summary shell', (tester) async {
    await tester.pumpWidget(AgentTestBench().build());
    await tester.pump();
    await tester.pump();

    expect(find.text('AI summary'), findsOneWidget);
    expect(find.text('Assign Agent'), findsNothing);
  });

  testWidgets('report carrier surfaces its compact AI attribution summary', (
    tester,
  ) async {
    final envelope = makeAiTerminalEnvelope();
    final report = makeTestReport().copyWith(
      provenance: {
        aiAttributionProvenanceKey: jsonDecode(
          jsonEncode(envelope.toJson()),
        ),
      },
    );

    await tester.pumpWidget(AgentTestBench(report: report).build());
    await tester.pump();
    await tester.pump();

    expect(find.byType(AiAttributionSummary), findsOneWidget);
    expect(find.textContaining('Ada · Manual · Completed'), findsOneWidget);
  });
}
