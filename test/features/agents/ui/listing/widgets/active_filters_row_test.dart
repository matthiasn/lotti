import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';
import 'package:lotti/features/agents/ui/listing/widgets/active_filters_row.dart';
import 'package:lotti/features/design_system/components/chips/active_filter_chip.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';

const _axes = [
  AgentListFilterAxis(
    id: 'type',
    sectionLabel: 'Type',
    options: [
      AgentListFilterOption(id: 'taskAgent', label: 'Task agent', count: 7),
      AgentListFilterOption(id: 'dayAgent', label: 'Day agent', count: 2),
    ],
  ),
  AgentListFilterAxis(
    id: 'status',
    sectionLabel: 'Status',
    options: [
      AgentListFilterOption(id: 'active', label: 'Active', count: 5),
    ],
  ),
];

/// Pumps the row with a no-op `onChanged`. Use for render-only assertions;
/// tests that need to capture the emitted state pump inline instead.
Future<void> _pumpRow(
  WidgetTester tester,
  AgentListFilterState state, {
  List<AgentListFilterAxis> axes = _axes,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      ActiveFiltersRow(
        state: state,
        axes: axes,
        onChanged: (_) {},
      ),
      theme: DesignSystemTheme.dark(),
    ),
  );
  await tester.pump();
}

void main() {
  group('ActiveFiltersRow', () {
    testWidgets('renders one chip per selected option, ordered by axis', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        const AgentListFilterState(
          groupAxisId: 'soul',
          sortAxisId: 'recent',
          selectionsByAxis: {
            'type': {'taskAgent'},
            'status': {'active'},
          },
        ),
      );

      // Only the selected options surface as chips (Day agent is not).
      expect(find.text('Task agent'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Day agent'), findsNothing);
      expect(find.byType(ActiveFilterChip), findsNWidgets(2));

      // Chips render in axis declaration order: type before status.
      final typeDx = tester.getTopLeft(find.text('Task agent')).dx;
      final statusDx = tester.getTopLeft(find.text('Active')).dx;
      expect(typeDx, lessThan(statusDx));
    });

    testWidgets('search term renders a quoted chip', (tester) async {
      await _pumpRow(
        tester,
        const AgentListFilterState(
          groupAxisId: 'soul',
          sortAxisId: 'recent',
          search: 'laura',
        ),
      );

      // Quoted with typographic quotes, no axis chips present.
      expect(find.text('“laura”'), findsOneWidget);
      expect(find.byType(ActiveFilterChip), findsOneWidget);
    });

    testWidgets('removing an option chip toggles that option off', (
      tester,
    ) async {
      AgentListFilterState? captured;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActiveFiltersRow(
            state: const AgentListFilterState(
              groupAxisId: 'soul',
              sortAxisId: 'recent',
              selectionsByAxis: {
                'type': {'taskAgent', 'dayAgent'},
              },
            ),
            axes: _axes,
            onChanged: (next) => captured = next,
          ),
          theme: DesignSystemTheme.dark(),
        ),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(ActiveFilterChip, 'Task agent'));
      await tester.pump();

      // Tapping the Task agent chip removes only that option from the axis.
      expect(captured, isNotNull);
      expect(captured!.selectionsFor('type'), {'dayAgent'});
    });

    testWidgets('removing the search chip clears the search string', (
      tester,
    ) async {
      AgentListFilterState? captured;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActiveFiltersRow(
            state: const AgentListFilterState(
              groupAxisId: 'soul',
              sortAxisId: 'recent',
              search: 'laura',
            ),
            axes: _axes,
            onChanged: (next) => captured = next,
          ),
          theme: DesignSystemTheme.dark(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(ActiveFilterChip));
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.search, isEmpty);
    });

    testWidgets('Clear-all action emits a fully cleared state', (tester) async {
      AgentListFilterState? captured;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActiveFiltersRow(
            state: const AgentListFilterState(
              groupAxisId: 'soul',
              sortAxisId: 'recent',
              search: 'laura',
              selectionsByAxis: {
                'type': {'taskAgent'},
              },
            ),
            axes: _axes,
            onChanged: (next) => captured = next,
          ),
          theme: DesignSystemTheme.dark(),
        ),
      );
      await tester.pump();

      final ctx = tester.element(find.byType(ActiveFiltersRow));
      await tester.tap(find.text(ctx.messages.agentInstancesFilterClearAll));
      await tester.pump();

      // clearAll wipes both selections and search; group/sort axes survive.
      expect(captured, isNotNull);
      expect(captured!.isAnyFilterActive, isFalse);
      expect(captured!.search, isEmpty);
      expect(captured!.groupAxisId, 'soul');
      expect(captured!.sortAxisId, 'recent');
    });

    testWidgets(
      'with no selections and no search only the Clear-all action shows',
      (tester) async {
        await _pumpRow(
          tester,
          const AgentListFilterState(groupAxisId: 'soul', sortAxisId: 'recent'),
        );

        expect(find.byType(ActiveFilterChip), findsNothing);
        final ctx = tester.element(find.byType(ActiveFiltersRow));
        expect(
          find.text(ctx.messages.agentInstancesFilterClearAll),
          findsOneWidget,
        );
      },
    );
  });
}
