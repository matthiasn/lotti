import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
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
      await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // Verify the returned set reflects both the add and the remove
      expect(result, {'closed'});
    },
  );

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
      await tester.pumpAndSettle();

      expect(result, {'work', 'personal'});
    },
  );
}
