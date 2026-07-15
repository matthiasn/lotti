import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_selection_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
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
      toggles: const [
        DesignSystemTaskFilterToggle(
          id: 'show-creation-date',
          label: 'Show creation date',
          value: false,
        ),
        DesignSystemTaskFilterToggle(
          id: 'show-flagged',
          label: 'Show flagged items',
          value: true,
        ),
      ],
    );
  }

  Future<void> openModal(
    WidgetTester tester, {
    required ValueChanged<DesignSystemTaskFilterState> onApplied,
    Size size = const Size(900, 900),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      makeTestableWidget(
        SizedBox(
          height: size.height,
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
        mediaQueryData: MediaQueryData(size: size, textScaler: textScaler),
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
    expect(
      tester.widget<DesignSystemSelectionRow>(statusRow()).focusNode!.hasFocus,
      isTrue,
    );
  });

  for (final navigation in ['Escape', 'system back']) {
    testWidgets(
      '$navigation returns to the overview and restores field focus',
      (tester) async {
        await openModal(tester, onApplied: (_) {});
        final barrierCount = find.byType(ModalBarrier).evaluate().length;
        tester.widget<DesignSystemSelectionRow>(statusRow()).onTap!();
        await tester.pump(const Duration(milliseconds: 900));

        if (navigation == 'Escape') {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pump(const Duration(milliseconds: 900));

        expect(find.byType(ModalBarrier), findsNWidgets(barrierCount));
        expect(find.byType(DesignSystemTaskFilterSheet), findsOneWidget);
        expect(
          tester
              .widget<DesignSystemSelectionRow>(statusRow())
              .focusNode!
              .hasFocus,
          isTrue,
        );
      },
    );
  }

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

  for (final textScale in [1.0, 2.0]) {
    testWidgets(
      'mobile footer leaves the final toggle unobscured at ${textScale}x text',
      (tester) async {
        await openModal(
          tester,
          onApplied: (_) {},
          size: const Size(390, 844),
          textScaler: TextScaler.linear(textScale),
        );

        final finalToggle = find.ancestor(
          of: find.text('Show flagged items'),
          matching: find.byType(DesignSystemFilterToggleRow),
        );
        await tester.ensureVisible(finalToggle);
        await tester.pump(const Duration(milliseconds: 500));

        final actionBar = find.byType(DesignSystemTaskFilterActionBar);
        expect(
          tester.getBottomLeft(finalToggle).dy,
          lessThanOrEqualTo(tester.getTopLeft(actionBar).dy),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
