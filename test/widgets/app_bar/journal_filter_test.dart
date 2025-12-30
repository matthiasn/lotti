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

  JournalPageState createState({
    Set<DisplayFilter> filters = const {},
  }) {
    return JournalPageState(
      tagIds: <String>{},
      filters: filters,
      fullTextMatches: {},
      taskStatuses: const ['OPEN', 'GROOMED', 'IN PROGRESS'],
      selectedTaskStatuses: {'OPEN'},
      selectedCategoryIds: {},
    );
  }

  Widget buildSubject(JournalPageState state) {
    fakeController = FakeJournalPageController(state);

    return WidgetTestBench(
      child: ProviderScope(
        overrides: [
          journalPageScopeProvider.overrideWithValue(false),
          journalPageControllerProvider(false)
              .overrideWith(() => fakeController),
        ],
        child: const Scaffold(
          body: JournalFilter(),
        ),
      ),
    );
  }

  group('JournalFilter', () {
    testWidgets('renders SegmentedButton with three segments', (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      expect(find.byType(JournalFilter), findsOneWidget);
      expect(find.byType(SegmentedButton<DisplayFilter>), findsOneWidget);

      // Verify three filter icons are present (starred, flagged, private)
      expect(find.byIcon(Icons.star_outline), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('shows filled icons when filters are active', (tester) async {
      await tester.pumpWidget(buildSubject(createState(
        filters: {
          DisplayFilter.starredEntriesOnly,
          DisplayFilter.flaggedEntriesOnly,
          DisplayFilter.privateEntriesOnly,
        },
      )));
      await tester.pumpAndSettle();

      // Active filters show filled icons
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.flag), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);

      // Outlined icons should not be present
      expect(find.byIcon(Icons.star_outline), findsNothing);
      expect(find.byIcon(Icons.flag_outlined), findsNothing);
      expect(find.byIcon(Icons.shield_outlined), findsNothing);
    });

    testWidgets('tapping starred filter calls setFilters', (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      // Tap on the starred filter icon
      await tester.tap(find.byIcon(Icons.star_outline));
      await tester.pump();

      expect(fakeController.filtersCalls, isNotEmpty);
      expect(
        fakeController.filtersCalls.last,
        contains(DisplayFilter.starredEntriesOnly),
      );
    });

    testWidgets('tapping flagged filter calls setFilters', (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      // Tap on the flagged filter icon
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pump();

      expect(fakeController.filtersCalls, isNotEmpty);
      expect(
        fakeController.filtersCalls.last,
        contains(DisplayFilter.flaggedEntriesOnly),
      );
    });

    testWidgets('tapping private filter calls setFilters', (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      // Tap on the private filter icon
      await tester.tap(find.byIcon(Icons.shield_outlined));
      await tester.pump();

      expect(fakeController.filtersCalls, isNotEmpty);
      expect(
        fakeController.filtersCalls.last,
        contains(DisplayFilter.privateEntriesOnly),
      );
    });

    testWidgets('multi-selection is enabled', (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      final segmentedButton = tester.widget<SegmentedButton<DisplayFilter>>(
        find.byType(SegmentedButton<DisplayFilter>),
      );

      expect(segmentedButton.multiSelectionEnabled, isTrue);
      expect(segmentedButton.emptySelectionAllowed, isTrue);
    });

    testWidgets('deselecting active filter removes it', (tester) async {
      await tester.pumpWidget(buildSubject(createState(
        filters: {DisplayFilter.starredEntriesOnly},
      )));
      await tester.pumpAndSettle();

      // Tap on the active starred filter to deselect
      await tester.tap(find.byIcon(Icons.star));
      await tester.pump();

      expect(fakeController.filtersCalls, isNotEmpty);
      expect(
        fakeController.filtersCalls.last,
        isNot(contains(DisplayFilter.starredEntriesOnly)),
      );
    });
  });
}
