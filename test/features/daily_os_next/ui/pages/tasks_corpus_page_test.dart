import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/tasks_corpus_page.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: makeTestableWidget2(
      child,
      mediaQueryData: const MediaQueryData(size: Size(900, 1000)),
    ),
  );
}

MockDayAgent _fastAgent() => MockDayAgent(
  parseLatency: Duration.zero,
  pendingLatency: Duration.zero,
  triageLatency: Duration.zero,
  draftLatency: Duration.zero,
  summarizeLatency: Duration.zero,
  clock: () => DateTime(2026, 5, 25, 9),
);

void main() {
  group('TasksCorpusPage', () {
    testWidgets('renders the corpus with default All filter', (tester) async {
      tester.view
        ..physicalSize = const Size(900, 1000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final agent = _fastAgent();
      await tester.pumpWidget(
        _wrap(
          const TasksCorpusPage(),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Mock returns 7 corpus items at default filter.
      expect(find.text('Reschedule dentist'), findsOneWidget);
      expect(find.text('Read 30 pages'), findsOneWidget);
      // Filter pills row present.
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Overdue'), findsWidgets);
    });

    testWidgets('tapping a state pill narrows the list', (tester) async {
      tester.view
        ..physicalSize = const Size(900, 1000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final agent = _fastAgent();
      await tester.pumpWidget(
        _wrap(
          const TasksCorpusPage(),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Tap the Overdue filter pill. There are multiple "Overdue"
      // strings — the pill is the first one in the filter row.
      final overduePill = find.text('Overdue').first;
      await tester.ensureVisible(overduePill);
      await tester.tap(overduePill);
      await tester.pump(const Duration(milliseconds: 200));

      // Only the overdue row remains visible (Reschedule dentist).
      expect(find.text('Reschedule dentist'), findsOneWidget);
      // Items in other states are filtered out.
      expect(find.text('Read 30 pages'), findsNothing);
      expect(find.text('Morning run · 5km'), findsNothing);
    });

    testWidgets('typing into the search field filters by title substring', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(900, 1000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final agent = _fastAgent();
      await tester.pumpWidget(
        _wrap(
          const TasksCorpusPage(),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(find.byType(TextField), 'deck');
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text('Deck review — Q2 leadership update'),
        findsOneWidget,
      );
      expect(find.text('Reschedule dentist'), findsNothing);
    });
  });
}
