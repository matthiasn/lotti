import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/tasks_corpus_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/tasks_corpus_page.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
  MediaQueryData mediaQueryData = const MediaQueryData(size: Size(900, 1000)),
}) {
  return ProviderScope(
    overrides: overrides,
    child: makeTestableWidget2(
      child,
      mediaQueryData: mediaQueryData,
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

    testWidgets('renders desktop row layout on wide windows', (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final agent = _fastAgent();
      await tester.pumpWidget(
        _wrap(
          const TasksCorpusPage(),
          mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Desktop row uses Row + Flexible meta text (single line); mobile uses
      // a Column + Wrap. Verify the desktop layout's row-level title still
      // shows the corpus item and is constrained to maxLines: 2.
      final title = tester.widget<Text>(
        find.text('Deck review — Q2 leadership update'),
      );
      expect(title.maxLines, 2);
    });

    testWidgets('shows empty state when the corpus has no items', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(900, 1000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          const TasksCorpusPage(),
          overrides: [
            tasksCorpusItemsProvider.overrideWith(
              (ref) async => const <TaskCorpusItem>[],
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final context = tester.element(find.byType(TasksCorpusPage));
      expect(
        find.text(AppLocalizations.of(context)!.dailyOsNextTasksEmpty),
        findsOneWidget,
      );
    });

    testWidgets('shows the loader while the corpus is pending', (tester) async {
      tester.view
        ..physicalSize = const Size(900, 1000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          const TasksCorpusPage(),
          overrides: [
            tasksCorpusItemsProvider.overrideWith(
              (ref) => Completer<List<TaskCorpusItem>>().future,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders the error message when the corpus fails', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(900, 1000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          const TasksCorpusPage(),
          overrides: [
            tasksCorpusItemsProvider.overrideWith(
              (ref) async {
                throw StateError('boom');
              },
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets('tapping a category pill narrows the list to that category', (
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

      // Mock corpus uses Work / Health / Meals / Study categories.
      final healthPill = find.text('Health').first;
      await tester.ensureVisible(healthPill);
      await tester.tap(healthPill);
      await tester.pump(const Duration(milliseconds: 200));

      // Work-only items disappear; Morning run (Health) remains.
      expect(find.text('Morning run · 5km'), findsOneWidget);
      expect(
        find.text('Deck review — Q2 leadership update'),
        findsNothing,
      );

      // Tapping the "All" category pill restores the full list.
      final context = tester.element(find.byType(TasksCorpusPage));
      final allLabel = AppLocalizations.of(
        context,
      )!.dailyOsNextCategoryFilterAll;
      await tester.tap(find.text(allLabel).first);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('Deck review — Q2 leadership update'),
        findsOneWidget,
      );
    });

    testWidgets('back button invokes maybePop without errors', (tester) async {
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

      // The page is the root route, so maybePop returns false. The point is
      // that the button is wired to the navigator without throwing.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(TasksCorpusPage), findsOneWidget);
    });

    testWidgets('lets task titles wrap on phone widths', (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final agent = _fastAgent();
      await tester.pumpWidget(
        _wrap(
          const TasksCorpusPage(),
          mediaQueryData: const MediaQueryData(size: Size(390, 844)),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final title = tester.widget<Text>(
        find.text('Deck review — Q2 leadership update'),
      );
      expect(title.maxLines, greaterThan(1));
      expect(title.overflow, TextOverflow.fade);
    });
  });
}
