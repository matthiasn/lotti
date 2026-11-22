import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/tasks/ui/widgets/task_list_states.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('TaskListEmptyState', () {
    Future<(List<String>, List<String>)> pump(
      WidgetTester tester, {
      String query = '',
      bool filtersActive = false,
      bool pullRequestSearch = false,
    }) async {
      final cleared = <String>[];
      final reset = <String>[];
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TaskListEmptyState(
            query: query,
            filtersActive: filtersActive,
            pullRequestSearch: pullRequestSearch,
            onClearSearch: () async => cleared.add('search'),
            onClearFilters: () async => reset.add('filters'),
          ),
        ),
      );
      await tester.pump();
      return (cleared, reset);
    }

    String title(WidgetTester tester) => tester
        .widget<DesignSystemEmptyState>(find.byType(DesignSystemEmptyState))
        .title!;

    testWidgets('a search miss names the trimmed search and clears it', (
      tester,
    ) async {
      final (cleared, reset) = await pump(
        tester,
        query: '  krill ',
        filtersActive: true,
      );

      // The search outranks the filters: it is what was just typed.
      expect(title(tester), 'Nothing matches “krill”');
      await tester.tap(find.text('Clear search'));
      expect(cleared, ['search']);
      expect(reset, isEmpty);
    });

    testWidgets('a pull request search says no task is linked to it', (
      tester,
    ) async {
      await pump(
        tester,
        query: 'https://github.com/o/r/pull/1',
        pullRequestSearch: true,
      );

      expect(title(tester), 'No linked tasks found for this pull request.');
    });

    testWidgets('a filter miss resets the filters', (tester) async {
      final (cleared, reset) = await pump(tester, filtersActive: true);

      expect(title(tester), 'No tasks match these filters');
      await tester.tap(find.text('Clear filters'));
      expect(reset, ['filters']);
      expect(cleared, isEmpty);
    });

    testWidgets('nothing narrowing: no tasks yet, no clear action', (
      tester,
    ) async {
      await pump(tester);

      expect(title(tester), 'No tasks yet');
      expect(find.text('Clear filters'), findsNothing);
      expect(find.text('Clear search'), findsNothing);
    });
  });

  testWidgets('TaskListErrorState says the load failed and retries', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        TaskListErrorState(onRetry: () => retries++),
      ),
    );

    expect(find.text("Couldn't load your tasks"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('TaskListSpinner is the design-system spinner, closer inline', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const Column(
          children: [TaskListSpinner(), TaskListSpinner(inline: true)],
        ),
      ),
    );

    expect(find.byType(DesignSystemSpinner), findsNWidgets(2));
    final paddings = tester
        .widgetList<Padding>(
          find.ancestor(
            of: find.byType(Center),
            matching: find.byType(Padding),
          ),
        )
        .map((p) => p.padding.resolve(TextDirection.ltr))
        .toList();
    // Full-page load: room above only. Next page: even room around.
    expect(paddings.first.bottom, 0);
    expect(paddings.last.top, paddings.last.bottom);
  });
}
