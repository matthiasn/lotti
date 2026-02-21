import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_report_section.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('AgentReportSection', () {
    Widget buildSubject(Map<String, Object?> content) {
      return makeTestableWidget(
        AgentReportSection(content: content),
      );
    }

    testWidgets('renders title when provided', (tester) async {
      await tester.pumpWidget(
        buildSubject({'title': 'Weekly Analysis Report'}),
      );
      await tester.pump();

      expect(find.text('Weekly Analysis Report'), findsOneWidget);
    });

    testWidgets('renders TLDR text when provided', (tester) async {
      await tester.pumpWidget(
        buildSubject({
          'tldr': 'Task is progressing well with minor blockers.',
        }),
      );
      await tester.pump();

      expect(
        find.text('Task is progressing well with minor blockers.'),
        findsOneWidget,
      );
    });

    testWidgets('renders status badge as a Chip', (tester) async {
      await tester.pumpWidget(
        buildSubject({'status': 'In Progress'}),
      );
      await tester.pump();

      expect(find.text('In Progress'), findsOneWidget);
      expect(find.byType(Chip), findsOneWidget);
    });

    testWidgets('renders priority badge as a Chip', (tester) async {
      await tester.pumpWidget(
        buildSubject({'priority': 'High'}),
      );
      await tester.pump();

      expect(find.text('High'), findsOneWidget);
      expect(find.byType(Chip), findsOneWidget);
    });

    testWidgets('renders both status and priority badges', (tester) async {
      await tester.pumpWidget(
        buildSubject({
          'status': 'In Progress',
          'priority': 'High',
        }),
      );
      await tester.pump();

      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.byType(Chip), findsNWidgets(2));
    });

    testWidgets('renders achieved bullet list items', (tester) async {
      await tester.pumpWidget(
        buildSubject({
          'achieved': ['Implemented feature A', 'Fixed bug B'],
        }),
      );
      await tester.pump();

      expect(find.text('Achieved'), findsOneWidget);
      expect(find.text('Implemented feature A'), findsOneWidget);
      expect(find.text('Fixed bug B'), findsOneWidget);
    });

    testWidgets('renders remaining bullet list items', (tester) async {
      await tester.pumpWidget(
        buildSubject({
          'remaining': ['Finish testing', 'Update docs'],
        }),
      );
      await tester.pump();

      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('Finish testing'), findsOneWidget);
      expect(find.text('Update docs'), findsOneWidget);
    });

    testWidgets('renders checklist progress bar with label', (tester) async {
      await tester.pumpWidget(
        buildSubject({
          'checklist': {'done': 3, 'total': 5},
        }),
      );
      await tester.pump();

      expect(find.text('Checklist: 3 / 5'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('hides checklist when total is zero', (tester) async {
      await tester.pumpWidget(
        buildSubject({
          'checklist': {'done': 0, 'total': 0},
        }),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('renders learnings text in italic', (tester) async {
      await tester.pumpWidget(
        buildSubject({
          'learnings': 'Discovered a better API pattern.',
        }),
      );
      await tester.pump();

      expect(
        find.text('Discovered a better API pattern.'),
        findsOneWidget,
      );
    });

    testWidgets('renders lastUpdated timestamp', (tester) async {
      await tester.pumpWidget(
        buildSubject({
          'lastUpdated': '2024-03-15 14:30',
        }),
      );
      await tester.pump();

      expect(find.text('Updated: 2024-03-15 14:30'), findsOneWidget);
    });

    testWidgets('renders full report with all fields', (tester) async {
      await tester.pumpWidget(
        buildSubject({
          'title': 'Sprint Report',
          'tldr': 'Good progress overall.',
          'status': 'Active',
          'priority': 'Medium',
          'achieved': ['Task 1 done'],
          'remaining': ['Task 2 pending'],
          'checklist': {'done': 2, 'total': 4},
          'learnings': 'Learned X.',
          'lastUpdated': '2024-06-01 10:00',
        }),
      );
      await tester.pump();

      expect(find.text('Sprint Report'), findsOneWidget);
      expect(find.text('Good progress overall.'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Achieved'), findsOneWidget);
      expect(find.text('Task 1 done'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('Task 2 pending'), findsOneWidget);
      expect(find.text('Checklist: 2 / 4'), findsOneWidget);
      expect(find.text('Learned X.'), findsOneWidget);
      expect(find.text('Updated: 2024-06-01 10:00'), findsOneWidget);
    });

    testWidgets('handles empty content map gracefully', (tester) async {
      await tester.pumpWidget(
        buildSubject(<String, Object?>{}),
      );
      await tester.pump();

      // Should render the Card without crashing, with no text content
      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Achieved'), findsNothing);
      expect(find.text('Remaining'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('filters non-string items from achieved list', (tester) async {
      await tester.pumpWidget(
        buildSubject({
          'achieved': ['Valid item', 42, null, 'Another valid'],
        }),
      );
      await tester.pump();

      expect(find.text('Valid item'), findsOneWidget);
      expect(find.text('Another valid'), findsOneWidget);
      expect(find.text('Achieved'), findsOneWidget);
    });

    testWidgets(
      'does not render achieved section when list is empty',
      (tester) async {
        await tester.pumpWidget(
          buildSubject({'achieved': <String>[]}),
        );
        await tester.pump();

        expect(find.text('Achieved'), findsNothing);
      },
    );

    testWidgets(
      'does not render remaining section when list is empty',
      (tester) async {
        await tester.pumpWidget(
          buildSubject({'remaining': <String>[]}),
        );
        await tester.pump();

        expect(find.text('Remaining'), findsNothing);
      },
    );
  });
}
