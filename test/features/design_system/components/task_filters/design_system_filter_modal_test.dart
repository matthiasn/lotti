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
    DesignSystemFilterCreateHandler? onCreateSavedFilter,
    DesignSystemFilterUpdateHandler? onUpdateSavedFilter,
    DesignSystemFilterSavePredicate? canCreateSavedFilter,
    DesignSystemFilterSavePredicate? canUpdateSavedFilter,
    String? existingSavedFilterName,
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
                  onCreateSavedFilter: onCreateSavedFilter,
                  onUpdateSavedFilter: onUpdateSavedFilter,
                  canCreateSavedFilter: canCreateSavedFilter,
                  canUpdateSavedFilter: canUpdateSavedFilter,
                  existingSavedFilterName: existingSavedFilterName,
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

  testWidgets(
    'create stays in the modal, requires a name, then persists before Apply',
    (tester) async {
      final creates = <String>[];
      DesignSystemTaskFilterState? applied;
      await openModal(
        tester,
        onApplied: (state) => applied = state,
        onCreateSavedFilter: (name, _) => creates.add(name),
        canCreateSavedFilter: (_) => true,
      );
      final barrierCount = find.byType(ModalBarrier).evaluate().length;

      await tester.tap(
        find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
      );
      await tester.pump(const Duration(milliseconds: 900));

      expect(
        find.byKey(DesignSystemFilterSavePageKeys.namePage),
        findsOneWidget,
      );
      expect(find.byType(ModalBarrier), findsNWidgets(barrierCount));
      expect(find.byType(MenuAnchor), findsNothing);
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(DesignSystemFilterSavePageKeys.commit),
            )
            .onPressed,
        isNull,
      );

      final nameField = find.descendant(
        of: find.byKey(DesignSystemFilterSavePageKeys.nameField),
        matching: find.byType(TextField),
      );
      await tester.enterText(nameField, '  Blocked work  ');
      await tester.pump();
      final commit = find.byKey(DesignSystemFilterSavePageKeys.commit);
      await tester.ensureVisible(commit);
      await tester.pump();
      tester.widget<DesignSystemButton>(commit).onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      expect(creates, ['Blocked work']);
      expect(applied, isNotNull);
      expect(find.byType(DesignSystemTaskFilterSheet), findsNothing);
    },
  );

  testWidgets(
    'an existing filter exposes explicit update and save-as-new paths',
    (tester) async {
      var updateCalls = 0;
      await openModal(
        tester,
        onApplied: (_) {},
        onCreateSavedFilter: (_, _) {},
        onUpdateSavedFilter: (_) => updateCalls++,
        canCreateSavedFilter: (_) => true,
        canUpdateSavedFilter: (_) => true,
        existingSavedFilterName: 'Urgent work',
      );
      final barrierCount = find.byType(ModalBarrier).evaluate().length;

      await tester.tap(
        find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
      );
      await tester.pump(const Duration(milliseconds: 900));

      expect(
        find.byKey(DesignSystemFilterSavePageKeys.choicePage),
        findsOneWidget,
      );
      expect(find.text('Urgent work'), findsOneWidget);
      expect(
        find.byKey(DesignSystemFilterSavePageKeys.update),
        findsOneWidget,
      );
      expect(
        find.byKey(DesignSystemFilterSavePageKeys.saveAsNew),
        findsOneWidget,
      );
      expect(find.byType(ModalBarrier), findsNWidgets(barrierCount));

      final saveAsNew = find.byKey(
        DesignSystemFilterSavePageKeys.saveAsNew,
      );
      await tester.ensureVisible(saveAsNew);
      await tester.pump();
      tester.widget<DesignSystemButton>(saveAsNew).onPressed!();
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        find.byKey(DesignSystemFilterSavePageKeys.namePage),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        find.byKey(DesignSystemFilterSavePageKeys.choicePage),
        findsOneWidget,
      );

      final update = find.byKey(DesignSystemFilterSavePageKeys.update);
      await tester.ensureVisible(update);
      await tester.pump();
      tester.widget<DesignSystemButton>(update).onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(updateCalls, 1);
      expect(find.byType(DesignSystemTaskFilterSheet), findsNothing);
    },
  );

  testWidgets('save availability follows the route-scoped draft', (
    tester,
  ) async {
    await openModal(
      tester,
      onApplied: (_) {},
      onCreateSavedFilter: (_, _) {},
      canCreateSavedFilter: (state) =>
          state.statusField!.selectedIds.contains('blocked'),
    );
    final saveButton = find.byKey(
      DesignSystemTaskFilterActionBar.saveButtonKey,
    );
    expect(tester.widget<DesignSystemButton>(saveButton).onPressed, isNull);

    tester.widget<DesignSystemSelectionRow>(statusRow()).onTap!();
    await tester.pump(const Duration(milliseconds: 900));
    tester.widget<DesignSystemSelectionRow>(option('blocked')).onTap!();
    await tester.pump();
    tester
        .widget<DesignSystemButton>(
          find.byKey(const ValueKey('design-system-filter-selection-apply')),
        )
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 900));

    expect(
      tester.widget<DesignSystemButton>(saveButton).onPressed,
      isNotNull,
    );
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
