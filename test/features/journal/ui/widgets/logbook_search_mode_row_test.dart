import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/ui/widgets/logbook_search_mode_row.dart';

import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late FakeJournalPageController fakeController;

  /// Pumps the row with the page controller pinned to [state] for the
  /// journal (non-tasks) scope.
  Widget buildSubject(JournalPageState state) {
    fakeController = FakeJournalPageController(state);
    return makeTestableWidgetWithScaffold(
      LogbookSearchModeRow(state: state),
      overrides: [
        journalPageScopeProvider.overrideWithValue(false),
        journalPageControllerProvider(
          false,
        ).overrideWith(() => fakeController),
      ],
    );
  }

  group('LogbookSearchModeRow', () {
    testWidgets('renders both segments with the current mode selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(const JournalPageState(enableVectorSearch: true)),
      );
      await tester.pump();

      final segmented = tester.widget<SegmentedButton<SearchMode>>(
        find.byType(SegmentedButton<SearchMode>),
      );
      expect(segmented.selected, {SearchMode.fullText});
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
      expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
      expect(find.text('Full Text'), findsOneWidget);
      expect(find.text('Vector'), findsOneWidget);
    });

    testWidgets('tapping the vector segment calls setSearchMode', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(const JournalPageState(enableVectorSearch: true)),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.hub_outlined));
      await tester.pump();

      expect(fakeController.searchModeCalls, [SearchMode.vector]);
    });

    testWidgets('shows loading indicator while a vector search is in flight', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          const JournalPageState(
            enableVectorSearch: true,
            searchMode: SearchMode.vector,
            vectorSearchInFlight: true,
            vectorSearchElapsed: Duration(milliseconds: 324),
            vectorSearchResultCount: 8,
          ),
        ),
      );
      await tester.pump();

      // The in-flight spinner wins over the timing readout of the previous
      // query.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('324'), findsNothing);
    });

    testWidgets('shows timing readout after a vector search completes', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          const JournalPageState(
            enableVectorSearch: true,
            searchMode: SearchMode.vector,
            vectorSearchElapsed: Duration(milliseconds: 324),
            vectorSearchResultCount: 8,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('324ms, 8 results'), findsOneWidget);
    });

    testWidgets(
      'shows neither spinner nor readout in full-text mode',
      (tester) async {
        // Even with elapsed data from an earlier vector query, the readout is
        // suppressed once the mode is back on full-text.
        await tester.pumpWidget(
          buildSubject(
            const JournalPageState(
              enableVectorSearch: true,
              vectorSearchElapsed: Duration(milliseconds: 324),
              vectorSearchResultCount: 8,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining('324'), findsNothing);
      },
    );
  });
}
