// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';

import '../../test_helper.dart';
import '../../test_utils/fake_journal_page_controller.dart';

void main() {
  late FakeJournalPageController fakeController;

  Widget buildSubject(JournalPageState state) {
    fakeController = FakeJournalPageController(state);

    return WidgetTestBench(
      child: ProviderScope(
        overrides: [
          journalPageScopeProvider.overrideWithValue(state.showTasks),
          journalPageControllerProvider(state.showTasks)
              .overrideWith(() => fakeController),
        ],
        child: const CustomScrollView(
          slivers: [JournalSliverAppBar()],
        ),
      ),
    );
  }

  group('JournalSliverAppBar search mode toggle', () {
    testWidgets('toggle is hidden when enableVectorSearch is false',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        const JournalPageState(
          showTasks: true,
          enableVectorSearch: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.byType(SegmentedButton<SearchMode>),
        findsNothing,
      );
    });

    testWidgets('toggle is visible on journal tab when flag is enabled',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        const JournalPageState(
          enableVectorSearch: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.byType(SegmentedButton<SearchMode>),
        findsOneWidget,
      );
    });

    testWidgets('toggle is visible on tasks tab when flag is enabled',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        const JournalPageState(
          showTasks: true,
          enableVectorSearch: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.byType(SegmentedButton<SearchMode>),
        findsOneWidget,
      );
      // Both segments are visible
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
      expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
    });

    testWidgets('tapping vector segment calls setSearchMode', (tester) async {
      await tester.pumpWidget(buildSubject(
        const JournalPageState(
          showTasks: true,
          enableVectorSearch: true,
          searchMode: SearchMode.fullText,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap the vector segment
      await tester.tap(find.byIcon(Icons.hub_outlined));
      await tester.pumpAndSettle();

      expect(fakeController.searchModeCalls, contains(SearchMode.vector));
    });

    testWidgets('shows loading indicator when vector search is in-flight',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        const JournalPageState(
          showTasks: true,
          enableVectorSearch: true,
          searchMode: SearchMode.vector,
          vectorSearchInFlight: true,
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows timing info after vector search completes',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        const JournalPageState(
          showTasks: true,
          enableVectorSearch: true,
          searchMode: SearchMode.vector,
          vectorSearchElapsed: Duration(milliseconds: 324),
          vectorSearchResultCount: 8,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('324'), findsOneWidget);
      expect(find.textContaining('8'), findsOneWidget);
    });
  });
}
