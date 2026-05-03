import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';

import 'test_bench.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiSummaryCard – Activity footer', () {
    testWidgets('hides the See activity pill when there are no entries', (
      tester,
    ) async {
      await tester.pumpWidget(AgentTestBench().build());
      await tester.pumpAndSettle();

      expect(find.text('See activity'), findsNothing);
    });

    testWidgets(
      'See activity expands to RECENT ACTIVITY list, capped at 6 entries',
      (tester) async {
        final entries = [
          for (var i = 0; i < 8; i++)
            makeLedgerEntry(
              id: 'a$i',
              status: ChangeItemStatus.confirmed,
              humanSummary: 'Activity row $i',
            ),
        ];
        final bench = AgentTestBench(
          suggestions: UnifiedSuggestionList(open: const [], activity: entries),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        expect(find.text('See activity'), findsOneWidget);
        expect(find.textContaining('8 recent actions'), findsOneWidget);

        await tester.tap(find.text('See activity'));
        await tester.pumpAndSettle();

        expect(find.text('Hide activity'), findsOneWidget);
        expect(find.text('RECENT ACTIVITY'), findsOneWidget);
        for (var i = 0; i < 6; i++) {
          expect(find.text('Activity row $i'), findsOneWidget);
        }
        expect(find.text('Activity row 6'), findsNothing);
        expect(find.text('Activity row 7'), findsNothing);

        await tester.tap(find.text('Hide activity'));
        await tester.pumpAndSettle();
        expect(find.text('RECENT ACTIVITY'), findsNothing);
      },
    );
  });

  group('AiSummaryCard – Activity rendering by kind', () {
    testWidgets('activity row renders distinct icons per proposal kind', (
      tester,
    ) async {
      final entries = [
        makeLedgerEntry(
          id: 'add',
          status: ChangeItemStatus.confirmed,
          toolName: 'add_multiple_checklist_items',
          humanSummary: 'Add: "Item"',
        ),
        makeLedgerEntry(
          id: 'status',
          status: ChangeItemStatus.confirmed,
        ),
        makeLedgerEntry(
          id: 'label',
          status: ChangeItemStatus.confirmed,
          toolName: 'assign_task_labels',
          humanSummary: 'Assign label: "macOS"',
        ),
        makeLedgerEntry(
          id: 'priority',
          status: ChangeItemStatus.confirmed,
          toolName: 'update_task_priority',
          humanSummary: 'Raise priority to P1',
        ),
        makeLedgerEntry(
          id: 'estimate',
          status: ChangeItemStatus.confirmed,
          toolName: 'update_task_estimate',
          humanSummary: 'Estimate 3h',
        ),
        makeLedgerEntry(
          id: 'due',
          status: ChangeItemStatus.confirmed,
          toolName: 'update_task_due_date',
          humanSummary: 'Move due date to Apr 3',
        ),
      ];
      final bench = AgentTestBench(
        suggestions: UnifiedSuggestionList(open: const [], activity: entries),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('See activity'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.label_outline), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    });

    testWidgets('unknown tool names fall through to the update kind icon', (
      tester,
    ) async {
      final entries = [
        makeLedgerEntry(
          id: 'unknown',
          status: ChangeItemStatus.confirmed,
          toolName: 'set_task_title',
          humanSummary: 'Renamed task',
        ),
      ];
      final bench = AgentTestBench(
        suggestions: UnifiedSuggestionList(open: const [], activity: entries),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('See activity'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets(
      'relative-time formatting covers minutes / hours / days / weeks',
      (tester) async {
        await withClock(Clock.fixed(DateTime(2026, 5, 4, 12)), () async {
          final entries = [
            makeLedgerEntry(
              id: 'now',
              status: ChangeItemStatus.confirmed,
              humanSummary: 'Just now',
              resolvedAt: DateTime(2026, 5, 4, 12),
            ),
            makeLedgerEntry(
              id: 'min',
              status: ChangeItemStatus.confirmed,
              humanSummary: 'Minutes ago',
              resolvedAt: DateTime(2026, 5, 4, 11, 55),
            ),
            makeLedgerEntry(
              id: 'hr',
              status: ChangeItemStatus.confirmed,
              humanSummary: 'Hours ago',
              resolvedAt: DateTime(2026, 5, 4, 8),
            ),
            makeLedgerEntry(
              id: 'day',
              status: ChangeItemStatus.confirmed,
              humanSummary: 'Days ago',
              resolvedAt: DateTime(2026, 5, 1, 12),
            ),
            makeLedgerEntry(
              id: 'wk',
              status: ChangeItemStatus.confirmed,
              humanSummary: 'Weeks ago',
              resolvedAt: DateTime(2026, 4, 10, 12),
            ),
          ];
          final bench = AgentTestBench(
            suggestions: UnifiedSuggestionList(
              open: const [],
              activity: entries,
            ),
          );

          await tester.pumpWidget(bench.build());
          await tester.pumpAndSettle();

          await tester.tap(find.text('See activity'));
          await tester.pumpAndSettle();

          expect(find.textContaining('now · Test Agent'), findsOneWidget);
          expect(find.textContaining('5m ago · Test Agent'), findsOneWidget);
          expect(find.textContaining('4h ago · Test Agent'), findsOneWidget);
          expect(find.textContaining('3d ago · Test Agent'), findsOneWidget);
          expect(find.textContaining('3w ago · Test Agent'), findsOneWidget);
        });
      },
    );
  });
}
