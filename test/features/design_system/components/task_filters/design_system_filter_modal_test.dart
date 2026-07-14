import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_selection_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';

import '../../../../widget_test_utils.dart';

void main() {
  DesignSystemTaskFilterState buildState() {
    return DesignSystemTaskFilterState(
      title: 'Filter tasks',
      clearAllLabel: 'Clear all',
      applyLabel: 'Apply',
      sortLabel: 'Sort by',
      sortOptions: const [
        DesignSystemTaskFilterOption(id: 'due-date', label: 'Due date'),
      ],
      selectedSortId: 'due-date',
      statusField: const DesignSystemTaskFilterFieldState(
        label: 'Status',
        options: [
          DesignSystemTaskFilterOption(id: 'open', label: 'Open'),
          DesignSystemTaskFilterOption(id: 'blocked', label: 'Blocked'),
        ],
        selectedIds: {'open'},
      ),
    );
  }

  Future<void> openModal(
    WidgetTester tester, {
    required ValueChanged<DesignSystemTaskFilterState> onApplied,
  }) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      makeTestableWidget(
        SizedBox(
          height: 900,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('trigger'),
                onPressed: () => showDesignSystemFilterModal(
                  context: context,
                  initialState: buildState(),
                  onApplied: onApplied,
                  fieldPageConfigs: const {
                    DesignSystemTaskFilterSection.status:
                        DesignSystemFilterFieldPageConfig(
                          searchHintText: 'Search status',
                        ),
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(900, 900)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Finder statusField() => find.byKey(
    const ValueKey('design-system-task-filter-field-status'),
  );
  Finder statusRow() => find.descendant(
    of: statusField(),
    matching: find.byType(DesignSystemSelectionRow),
  );
  Finder option(String id) => find.byKey(
    ValueKey('design-system-filter-selection-option-$id'),
  );

  testWidgets('renders the supplied title, overview, and standard action bar', (
    tester,
  ) async {
    await openModal(tester, onApplied: (_) {});

    expect(find.text('Filter tasks'), findsOneWidget);
    expect(find.byType(DesignSystemTaskFilterSheet), findsOneWidget);
    expect(find.byType(DesignSystemTaskFilterActionBar), findsOneWidget);
    expect(find.text('Due date'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('selection pages stay in one route and persist into Apply', (
    tester,
  ) async {
    DesignSystemTaskFilterState? applied;
    await openModal(tester, onApplied: (state) => applied = state);
    final routeBarrierCount = find.byType(ModalBarrier).evaluate().length;

    tester.widget<DesignSystemSelectionRow>(statusRow()).onTap!();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Search status'), findsWidgets);
    expect(option('open'), findsOneWidget);
    expect(find.byType(ModalBarrier), findsNWidgets(routeBarrierCount));

    tester.widget<DesignSystemSelectionRow>(option('blocked')).onTap!();
    await tester.pump();
    tester
        .widget<DesignSystemButton>(
          find.byKey(const ValueKey('design-system-filter-selection-apply')),
        )
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Open, Blocked'), findsOneWidget);
    tester
        .widget<DesignSystemButton>(
          find.byKey(const ValueKey('design-system-task-filter-apply')),
        )
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 900));

    expect(applied!.statusField!.selectedIds, {'open', 'blocked'});
  });

  testWidgets('Back returns from a child page without closing the flow', (
    tester,
  ) async {
    await openModal(tester, onApplied: (_) {});
    final barrierCount = find.byType(ModalBarrier).evaluate().length;
    tester.widget<DesignSystemSelectionRow>(statusRow()).onTap!();
    await tester.pump(const Duration(milliseconds: 900));

    final backButton = find.ancestor(
      of: find.byIcon(Icons.arrow_back_rounded),
      matching: find.byType(IconButton),
    );
    tester.widget<IconButton>(backButton).onPressed!();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(ModalBarrier), findsNWidgets(barrierCount));
    expect(
      tester.widget<DesignSystemSelectionRow>(statusRow()).subtitle,
      'Open',
    );
  });

  testWidgets('Clear resets the draft and disables itself', (tester) async {
    await openModal(tester, onApplied: (_) {});
    final clearFinder = find.byKey(
      const ValueKey('design-system-task-filter-clear'),
    );
    await tester.tap(clearFinder);
    await tester.pump();

    expect(find.text('All'), findsOneWidget);
    expect(tester.widget<DesignSystemButton>(clearFinder).onPressed, isNull);
  });

  testWidgets('closing a changed child page never calls Apply', (tester) async {
    var applyCalls = 0;
    await openModal(tester, onApplied: (_) => applyCalls++);
    await tester.ensureVisible(statusField());
    await tester.tap(statusField());
    await tester.pump(const Duration(milliseconds: 900));
    tester.widget<DesignSystemSelectionRow>(option('blocked')).onTap!();
    await tester.pump();

    Navigator.of(tester.element(option('blocked'))).pop();
    await tester.pump(const Duration(milliseconds: 900));

    expect(applyCalls, 0);
    expect(find.byType(DesignSystemTaskFilterSheet), findsNothing);
  });
}
