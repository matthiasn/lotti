import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_activity_log.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  const testAgentId = kTestAgentId;

  group('AgentReportHistoryLog', () {
    Widget buildReportHistory({
      required AsyncValue<List<AgentDomainEntity>> reportsValue,
    }) {
      return makeTestableWidgetWithScaffold(
        const AgentReportHistoryLog(agentId: testAgentId),
        overrides: [
          agentReportHistoryProvider.overrideWith(
            (ref, agentId) => reportsValue.when(
              data: (data) async => data,
              loading: () => Completer<List<AgentDomainEntity>>().future,
              error: Future<List<AgentDomainEntity>>.error,
            ),
          ),
        ],
      );
    }

    testWidgets('shows loading indicator', (tester) async {
      await tester.pumpWidget(
        buildReportHistory(
          reportsValue: const AsyncValue<List<AgentDomainEntity>>.loading(),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message', (tester) async {
      await tester.pumpWidget(
        buildReportHistory(
          reportsValue: AsyncValue<List<AgentDomainEntity>>.error(
            Exception('DB error'),
            StackTrace.current,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('error occurred'),
        findsOneWidget,
      );
    });

    testWidgets('shows empty state when no reports', (tester) async {
      await tester.pumpWidget(
        buildReportHistory(
          reportsValue: const AsyncValue.data([]),
        ),
      );
      await tester.pump();

      expect(find.text('No report snapshots yet.'), findsOneWidget);
    });

    testWidgets('shows report cards with timestamps', (tester) async {
      final reports = <AgentDomainEntity>[
        makeTestReport(
          id: 'report-1',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          content: '# First Report',
        ),
        makeTestReport(
          id: 'report-2',
          createdAt: DateTime(2024, 3, 15, 14),
          content: '# Second Report',
        ),
      ];

      await tester.pumpWidget(
        buildReportHistory(reportsValue: AsyncValue.data(reports)),
      );
      await tester.pump();

      // Both cards should have the "Report" badge.
      expect(find.text('Report'), findsNWidgets(2));
      // Timestamps should be shown (formatAgentDateTime uses HH:mm, no seconds).
      expect(find.text('2024-03-15 10:30'), findsOneWidget);
      expect(find.text('2024-03-15 14:00'), findsOneWidget);
    });

    testWidgets('first report is expanded by default', (tester) async {
      final reports = <AgentDomainEntity>[
        makeTestReport(
          id: 'report-1',
          createdAt: DateTime(2024, 3, 15, 10),
          content: 'Report content here',
        ),
        makeTestReport(
          id: 'report-2',
          createdAt: DateTime(2024, 3, 15, 14),
          content: 'Second report content',
        ),
      ];

      await tester.pumpWidget(
        buildReportHistory(reportsValue: AsyncValue.data(reports)),
      );
      await tester.pumpAndSettle();

      // First report expanded — GptMarkdown renders content.
      // The second report should be collapsed.
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('tapping a collapsed report expands it', (tester) async {
      final reports = <AgentDomainEntity>[
        makeTestReport(
          id: 'report-1',
          createdAt: DateTime(2024, 3, 15, 10),
          content: 'Only report',
        ),
      ];

      await tester.pumpWidget(
        buildReportHistory(reportsValue: AsyncValue.data(reports)),
      );
      await tester.pumpAndSettle();

      // Initially expanded (index 0).
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      // Tap to collapse.
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Tap to expand again.
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('collapsed report shows only TLDR section', (tester) async {
      final reports = <AgentDomainEntity>[
        makeTestReport(
          id: 'report-first',
          createdAt: DateTime(2024, 3, 15, 10),
          content:
              '## 📋 TLDR\n'
              'Summary of the work.\n\n'
              '## ✅ Achieved\n'
              '- Built a spaceship\n',
        ),
        makeTestReport(
          id: 'report-second',
          createdAt: DateTime(2024, 3, 15, 9),
          content:
              '## 📋 TLDR\n'
              'Earlier summary.\n\n'
              '## ✅ Achieved\n'
              '- Prepared launch pad\n',
        ),
      ];

      await tester.pumpWidget(
        buildReportHistory(reportsValue: AsyncValue.data(reports)),
      );
      await tester.pumpAndSettle();

      // Second report is collapsed — its GptMarkdown should render
      // only the TLDR section, not the Achieved section.
      final markdowns = tester
          .widgetList<GptMarkdown>(find.byType(GptMarkdown))
          .toList();
      // First report expanded (full content), second collapsed (TLDR only)
      expect(markdowns.length, 2);
      // The collapsed one should NOT contain "Achieved" content
      expect(markdowns.last.data, contains('TLDR'));
      expect(markdowns.last.data, isNot(contains('Achieved')));
    });

    testWidgets('collapsed report uses first paragraph as TLDR fallback', (
      tester,
    ) async {
      final reports = <AgentDomainEntity>[
        makeTestReport(
          id: 'report-fallback',
          createdAt: DateTime(2024, 3, 15, 10),
          content:
              'This has no TLDR heading.\n\n'
              'Second paragraph with details.',
        ),
      ];

      await tester.pumpWidget(
        buildReportHistory(reportsValue: AsyncValue.data(reports)),
      );
      await tester.pumpAndSettle();

      // Collapse the first (auto-expanded) report
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      // The collapsed content should be just the first paragraph
      final markdowns = tester
          .widgetList<GptMarkdown>(find.byType(GptMarkdown))
          .toList();
      expect(markdowns.length, 1);
      expect(markdowns.first.data, contains('no TLDR heading'));
      expect(markdowns.first.data, isNot(contains('Second paragraph')));
    });

    testWidgets(
      'collapsed report shows TLDR-only section when it is the last section',
      (tester) async {
        final reports = <AgentDomainEntity>[
          makeTestReport(
            id: 'report-tldr-only',
            createdAt: DateTime(2024, 3, 15, 10),
            content:
                '## 📋 TLDR\n'
                'This is the entire report.',
          ),
        ];

        await tester.pumpWidget(
          buildReportHistory(reportsValue: AsyncValue.data(reports)),
        );
        await tester.pumpAndSettle();

        // Collapse the report
        await tester.tap(find.byType(InkWell));
        await tester.pump();

        final markdowns = tester
            .widgetList<GptMarkdown>(find.byType(GptMarkdown))
            .toList();
        expect(markdowns.length, 1);
        expect(markdowns.first.data, contains('TLDR'));
        expect(markdowns.first.data, contains('entire report'));
      },
    );

    testWidgets('ignores non-report entities in the list', (tester) async {
      final mixed = <AgentDomainEntity>[
        makeTestReport(
          id: 'report-1',
          createdAt: DateTime(2024, 3, 15, 10),
          content: 'A report',
        ),
        // Include a non-report entity.
        makeTestMessage(
          id: 'msg-1',
          createdAt: DateTime(2024, 3, 15, 11),
        ),
      ];

      await tester.pumpWidget(
        buildReportHistory(reportsValue: AsyncValue.data(mixed)),
      );
      await tester.pump();

      // Only the report card should render.
      expect(find.text('Report'), findsOneWidget);
    });
  });
}
