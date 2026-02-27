import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/task_agent_report_section.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    required String taskId,
    AgentDomainEntity? agent,
    AgentDomainEntity? report,
  }) {
    return makeTestableWidget(
      TaskAgentReportSection(taskId: taskId),
      overrides: [
        taskAgentProvider.overrideWith(
          (ref, id) async => agent,
        ),
        agentReportProvider.overrideWith(
          (ref, agentId) async => report,
        ),
      ],
    );
  }

  group('TaskAgentReportSection', () {
    testWidgets('renders nothing when no agent exists for task',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(taskId: 'task-no-agent'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GptMarkdown), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders nothing when agent has no report', (tester) async {
      final agent = makeTestIdentity(
        id: 'agent-1',
        agentId: 'agent-1',
      );

      await tester.pumpWidget(
        buildSubject(taskId: 'task-1', agent: agent),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GptMarkdown), findsNothing);
    });

    testWidgets('renders report content when agent has report', (tester) async {
      final agent = makeTestIdentity(
        id: 'agent-1',
        agentId: 'agent-1',
      );
      final report = makeTestReport(
        agentId: 'agent-1',
        content: '## 📋 TLDR\nGood progress on task.\n\n'
            '## ✅ Achieved\n- Item A\n',
      );

      await tester.pumpWidget(
        buildSubject(taskId: 'task-1', agent: agent, report: report),
      );
      await tester.pumpAndSettle();

      // TLDR section visible
      final markdowns =
          tester.widgetList<GptMarkdown>(find.byType(GptMarkdown)).toList();
      expect(markdowns, isNotEmpty);
      expect(markdowns.first.data, contains('TLDR'));
      expect(markdowns.first.data, contains('Good progress'));
    });

    testWidgets('renders nothing when report content is empty', (tester) async {
      final agent = makeTestIdentity(
        id: 'agent-1',
        agentId: 'agent-1',
      );
      final report = makeTestReport(
        agentId: 'agent-1',
        content: '',
      );

      await tester.pumpWidget(
        buildSubject(taskId: 'task-1', agent: agent, report: report),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GptMarkdown), findsNothing);
    });
  });
}
