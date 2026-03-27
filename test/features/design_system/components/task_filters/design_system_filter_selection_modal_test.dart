import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
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
                            presentation:
                                DesignSystemFilterPresentation.desktop,
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
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DesignSystemFilterSelectionSheet), findsOneWidget);
      expect(find.byType(DesignSystemCheckbox), findsNWidgets(3));
      expect(find.byType(CheckboxListTile), findsNothing);

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
      await tester.pump(const Duration(milliseconds: 500));

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
                      presentation: DesignSystemFilterPresentation.desktop,
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
    await tester.pump(const Duration(milliseconds: 500));

    final disabledOption = find.byKey(
      const ValueKey('design-system-filter-selection-option-archived'),
    );
    await tester.ensureVisible(disabledOption);
    await tester.tap(disabledOption);
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('design-system-filter-selection-apply')),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(result, {'work'});
  });
}
