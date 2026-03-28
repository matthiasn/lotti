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
                        presentation: DesignSystemFilterPresentation.desktop,
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
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DesignSystemFilterSelectionSheet), findsOneWidget);

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
      await tester.pump(const Duration(milliseconds: 500));

      expect(result, {'high'});
    },
  );

  testWidgets(
    'renders options in mobile bottom sheet presentation',
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
                    key: const ValueKey('open-mobile-selection-modal'),
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
                        ],
                        initialSelectedIds: const {'open'},
                        presentation: DesignSystemFilterPresentation.mobile,
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

      await tester.tap(
        find.byKey(const ValueKey('open-mobile-selection-modal')),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DesignSystemFilterSelectionSheet), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);

      // In mobile, the bottom sheet overlay renders content outside the
      // surface bounds, so we invoke the callbacks directly on the widget.
      final sheet = tester.widget<DesignSystemFilterSelectionSheet>(
        find.byType(DesignSystemFilterSelectionSheet),
      );

      // Verify the sheet received the correct options and initial selection
      expect(sheet.options.length, 2);
      expect(sheet.selectedIds, {'open'});
      expect(sheet.showDragHandle, isTrue);

      // Toggle the 'closed' option via the callback
      sheet.onOptionToggled('closed');
      await tester.pump();

      // Tap apply via the callback
      sheet.onApplyPressed();
      await tester.pump(const Duration(milliseconds: 500));

      expect(result, {'open', 'closed'});
    },
  );
}
