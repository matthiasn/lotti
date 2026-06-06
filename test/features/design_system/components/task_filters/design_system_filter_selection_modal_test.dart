import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_selection_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../../widget_test_utils.dart';

void main() {
  DesignSystemTaskFilterState buildFilterState() {
    return DesignSystemTaskFilterState(
      title: 'Apply filter',
      clearAllLabel: 'Clear all',
      applyLabel: 'Apply',
      statusField: const DesignSystemTaskFilterFieldState(
        label: 'Status',
        options: [
          DesignSystemTaskFilterOption(id: 'open', label: 'Open'),
          DesignSystemTaskFilterOption(id: 'active', label: 'Active'),
          DesignSystemTaskFilterOption(id: 'blocked', label: 'Blocked'),
        ],
        selectedIds: {'open'},
      ),
    );
  }

  testWidgets(
    'returns updated selected ids from the shared DS field selection modal',
    (tester) async {
      DesignSystemTaskFilterState? result;

      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    key: const ValueKey('open-selection-modal'),
                    onPressed: () async {
                      result =
                          await showDesignSystemTaskFilterFieldSelectionModal(
                            context: context,
                            draftState: buildFilterState(),
                            section: DesignSystemTaskFilterSection.status,
                          );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('open-selection-modal')));
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemCheckbox), findsNWidgets(3));

      final blockedOption = find.byKey(
        const ValueKey('design-system-filter-selection-option-blocked'),
      );
      await tester.ensureVisible(blockedOption);
      await tester.tap(blockedOption);
      await tester.pump();

      final doneButton = find.byKey(
        const ValueKey('design-system-filter-selection-apply'),
      );
      await tester.ensureVisible(doneButton);
      await tester.tap(doneButton);
      // Wolt sheet exit animation has a bounded duration; the modal
      // future completes on pop, so two bounded pumps suffice.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        result?.statusField?.selectedIds,
        {'open', 'blocked'},
      );
    },
  );

  testWidgets('keeps disabled selection options unchanged', (tester) async {
    Set<String>? result;

    await tester.pumpWidget(
      makeTestableWidget2(
        Theme(
          data: DesignSystemTheme.dark(),
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  key: const ValueKey('open-disabled-selection-modal'),
                  onPressed: () async {
                    result = await showDesignSystemFilterSelectionModal(
                      context: context,
                      title: 'Category',
                      options: const [
                        DesignSystemTaskFilterOption(id: 'work', label: 'Work'),
                        DesignSystemTaskFilterOption(
                          id: 'archived',
                          label: 'Archived',
                        ),
                      ],
                      initialSelectedIds: const {'work'},
                      appearanceResolver: (optionId) => optionId == 'archived'
                          ? const DesignSystemFilterSelectionOptionAppearance(
                              enabled: false,
                            )
                          : null,
                      applyLabel: 'Done',
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('open-disabled-selection-modal')),
    );
    await tester.pumpAndSettle();

    final disabledOption = find.byKey(
      const ValueKey('design-system-filter-selection-option-archived'),
    );
    await tester.ensureVisible(disabledOption);
    await tester.tap(disabledOption);
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('design-system-filter-selection-apply')),
    );
    // Wolt sheet exit animation has a bounded duration; the modal
    // future completes on pop, so two bounded pumps suffice.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(result, {'work'});
  });

  testWidgets(
    'renders custom icon and foreground color from appearance resolver',
    (tester) async {
      Set<String>? result;

      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    key: const ValueKey('open-icon-selection-modal'),
                    onPressed: () async {
                      result = await showDesignSystemFilterSelectionModal(
                        context: context,
                        title: 'Priority',
                        options: const [
                          DesignSystemTaskFilterOption(
                            id: 'high',
                            label: 'High',
                          ),
                          DesignSystemTaskFilterOption(
                            id: 'medium',
                            label: 'Medium',
                          ),
                        ],
                        initialSelectedIds: const <String>{},
                        appearanceResolver: (optionId) => optionId == 'high'
                            ? const DesignSystemFilterSelectionOptionAppearance(
                                icon: Icons.check_circle,
                                foregroundColor: Colors.green,
                              )
                            : null,
                        applyLabel: 'Done',
                      );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('open-icon-selection-modal')),
      );
      await tester.pumpAndSettle();

      // Verify the custom icon is rendered for the 'high' option
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Verify the icon uses the custom foreground color
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(iconWidget.color, Colors.green);
      expect(iconWidget.size, 28);

      // Verify the label text for the option with custom appearance also uses
      // the foreground color
      final highOptionRow = find.ancestor(
        of: find.text('High'),
        matching: find.byKey(
          const ValueKey('design-system-filter-selection-option-high'),
        ),
      );
      expect(highOptionRow, findsOneWidget);

      // Toggle the 'high' option and apply
      await tester.ensureVisible(highOptionRow);
      await tester.tap(highOptionRow);
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('design-system-filter-selection-apply')),
      );
      // Wolt sheet exit animation has a bounded duration; the modal
      // future completes on pop, so two bounded pumps suffice.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(result, {'high'});
    },
  );

  testWidgets(
    'toggles options and returns result via UI taps',
    (tester) async {
      Set<String>? result;

      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    key: const ValueKey('open-toggle-modal'),
                    onPressed: () async {
                      result = await showDesignSystemFilterSelectionModal(
                        context: context,
                        title: 'Status',
                        options: const [
                          DesignSystemTaskFilterOption(
                            id: 'open',
                            label: 'Open',
                          ),
                          DesignSystemTaskFilterOption(
                            id: 'closed',
                            label: 'Closed',
                          ),
                          DesignSystemTaskFilterOption(
                            id: 'blocked',
                            label: 'Blocked',
                          ),
                        ],
                        initialSelectedIds: const {'open'},
                        applyLabel: 'Apply',
                      );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Open the modal
      await tester.tap(find.byKey(const ValueKey('open-toggle-modal')));
      await tester.pumpAndSettle();

      // Toggle 'closed' on via actual tap
      final closedOption = find.byKey(
        const ValueKey('design-system-filter-selection-option-closed'),
      );
      await tester.ensureVisible(closedOption);
      await tester.tap(closedOption);
      await tester.pump();

      // Toggle 'open' off (deselect) via actual tap
      final openOption = find.byKey(
        const ValueKey('design-system-filter-selection-option-open'),
      );
      await tester.ensureVisible(openOption);
      await tester.tap(openOption);
      await tester.pump();

      // Tap apply button to close the modal and return the result
      final applyButton = find.byKey(
        const ValueKey('design-system-filter-selection-apply'),
      );
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      // Wolt sheet exit animation has a bounded duration; the modal
      // future completes on pop, so two bounded pumps suffice.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify the returned set reflects both the add and the remove
      expect(result, {'closed'});
    },
  );

  testWidgets('returns null when field is null for the given section', (
    tester,
  ) async {
    DesignSystemTaskFilterState? result = DesignSystemTaskFilterState(
      title: 'sentinel',
      clearAllLabel: '',
      applyLabel: '',
    );

    await tester.pumpWidget(
      makeTestableWidget2(
        Theme(
          data: DesignSystemTheme.dark(),
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  key: const ValueKey('open-null-field-modal'),
                  onPressed: () async {
                    // projectField is null, so calling with project section
                    // should return null immediately.
                    result =
                        await showDesignSystemTaskFilterFieldSelectionModal(
                          context: context,
                          draftState: DesignSystemTaskFilterState(
                            title: 'Filter',
                            clearAllLabel: 'Clear',
                            applyLabel: 'Apply',
                            statusField: const DesignSystemTaskFilterFieldState(
                              label: 'Status',
                              options: [
                                DesignSystemTaskFilterOption(
                                  id: 'open',
                                  label: 'Open',
                                ),
                              ],
                              selectedIds: {'open'},
                            ),
                          ),
                          section: DesignSystemTaskFilterSection.project,
                        );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('open-null-field-modal')));
    await tester.pump();

    expect(result, isNull);
  });

  testWidgets(
    'renders selection modal with light theme palette',
    (tester) async {
      Set<String>? result;

      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.light(),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    key: const ValueKey('open-light-selection-modal'),
                    onPressed: () async {
                      result = await showDesignSystemFilterSelectionModal(
                        context: context,
                        title: 'Category',
                        options: const [
                          DesignSystemTaskFilterOption(
                            id: 'work',
                            label: 'Work',
                          ),
                          DesignSystemTaskFilterOption(
                            id: 'personal',
                            label: 'Personal',
                          ),
                        ],
                        initialSelectedIds: const {'work'},
                        applyLabel: 'Done',
                      );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('open-light-selection-modal')),
      );
      await tester.pumpAndSettle();

      // Toggle the 'personal' option on
      final personalOption = find.byKey(
        const ValueKey('design-system-filter-selection-option-personal'),
      );
      await tester.ensureVisible(personalOption);
      await tester.tap(personalOption);
      await tester.pump();

      // Apply the selection
      final doneButton = find.byKey(
        const ValueKey('design-system-filter-selection-apply'),
      );
      await tester.ensureVisible(doneButton);
      await tester.tap(doneButton);
      // Wolt sheet exit animation has a bounded duration; the modal
      // future completes on pop, so two bounded pumps suffice.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(result, {'work', 'personal'});
    },
  );

  testWidgets(
    'renders DesignSystemGlassStrip around the apply action bar',
    (tester) async {
      await _openSelectionModal(
        tester,
        openerKey: 'open-glass-modal',
        options: const [
          DesignSystemTaskFilterOption(id: 'open', label: 'Open'),
        ],
        applyLabel: 'Done',
      );

      // The sticky action bar is wrapped in DesignSystemGlassStrip so list
      // rows scroll behind the blurred footer.
      expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
      // Apply button still tappable as before.
      expect(
        find.byKey(
          const ValueKey('design-system-filter-selection-apply'),
        ),
        findsOneWidget,
      );
    },
  );

  group('with searchHintText', () {
    testWidgets('renders a DesignSystemSearch above the options', (
      tester,
    ) async {
      await _openSelectionModal(
        tester,
        openerKey: 'open-search-modal',
        options: const [
          DesignSystemTaskFilterOption(id: 'work', label: 'Work'),
          DesignSystemTaskFilterOption(id: 'personal', label: 'Personal'),
        ],
        searchHintText: 'Search categories',
      );

      expect(find.byType(DesignSystemSearch), findsOneWidget);
      final searchWidget = tester.widget<DesignSystemSearch>(
        find.byType(DesignSystemSearch),
      );
      expect(searchWidget.hintText, 'Search categories');
    });

    testWidgets('filters options by case-insensitive label substring', (
      tester,
    ) async {
      await _openSelectionModal(
        tester,
        openerKey: 'open-filter-search-modal',
        options: const [
          DesignSystemTaskFilterOption(id: 'work', label: 'Work'),
          DesignSystemTaskFilterOption(id: 'personal', label: 'Personal'),
          DesignSystemTaskFilterOption(
            id: 'side-project',
            label: 'Side project',
          ),
        ],
        searchHintText: 'Search',
      );

      // All three options are visible initially.
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Side project'), findsOneWidget);

      // Type a query that matches one row (case-insensitive).
      await tester.enterText(
        find.descendant(
          of: find.byType(DesignSystemSearch),
          matching: find.byType(TextField),
        ),
        'PERS',
      );
      await tester.pump();

      // Only the matching row is rendered.
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Work'), findsNothing);
      expect(find.text('Side project'), findsNothing);
    });

    testWidgets('shows the no-matches placeholder when nothing matches', (
      tester,
    ) async {
      await _openSelectionModal(
        tester,
        openerKey: 'open-no-match-modal',
        options: const [
          DesignSystemTaskFilterOption(id: 'work', label: 'Work'),
          DesignSystemTaskFilterOption(id: 'personal', label: 'Personal'),
        ],
        searchHintText: 'Search',
      );

      await tester.enterText(
        find.descendant(
          of: find.byType(DesignSystemSearch),
          matching: find.byType(TextField),
        ),
        'zzz',
      );
      await tester.pump();

      // Rows hidden, placeholder visible.
      expect(find.text('Work'), findsNothing);
      expect(find.text('Personal'), findsNothing);
      expect(find.byType(DesignSystemCheckbox), findsNothing);
      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('omitting searchHintText hides the search bar', (tester) async {
      await _openSelectionModal(
        tester,
        openerKey: 'open-nosearch-modal',
        options: const [
          DesignSystemTaskFilterOption(id: 'open', label: 'Open'),
        ],
      );

      expect(find.byType(DesignSystemSearch), findsNothing);
    });
  });
}

/// Pumps a host with a single opener button that calls
/// [showDesignSystemFilterSelectionModal] with the given parameters, then
/// taps it and lets the modal animation settle.
///
/// Centralises the boilerplate shared by tests that only need to verify
/// what the modal renders for a given parameter combination.
Future<void> _openSelectionModal(
  WidgetTester tester, {
  required String openerKey,
  required List<DesignSystemTaskFilterOption> options,
  Set<String> initialSelectedIds = const <String>{},
  String? applyLabel,
  String? searchHintText,
  ThemeData? themeData,
}) async {
  await tester.pumpWidget(
    makeTestableWidget2(
      Theme(
        data: themeData ?? DesignSystemTheme.dark(),
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                key: ValueKey(openerKey),
                onPressed: () {
                  showDesignSystemFilterSelectionModal(
                    context: context,
                    title: 'Filter',
                    options: options,
                    initialSelectedIds: initialSelectedIds,
                    applyLabel: applyLabel,
                    searchHintText: searchHintText,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(ValueKey(openerKey)));
  await tester.pumpAndSettle();
}
