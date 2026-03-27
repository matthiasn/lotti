import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

void main() {
  DesignSystemTaskFilterState buildMinimalState() {
    return DesignSystemTaskFilterState(
      title: 'Filter',
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
        ],
        selectedIds: {'open'},
      ),
      priorityLabel: 'Priority',
      priorityOptions: const [
        DesignSystemTaskFilterOption(id: 'all', label: 'All'),
      ],
    );
  }

  /// Opens the modal and completes the entry animation so the sheet is
  /// fully visible before returning.
  Future<void> openModal(
    WidgetTester tester, {
    required DesignSystemFilterPresentation presentation,
    required ValueChanged<DesignSystemTaskFilterState> onApplied,
    DesignSystemTaskFilterState? state,
    DesignSystemFilterFieldHandler? onFieldPressed,
  }) async {
    final filterState = state ?? buildMinimalState();

    const size = Size(900, 900);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: DesignSystemTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                key: const ValueKey('trigger'),
                onPressed: () {
                  showDesignSystemFilterModal(
                    context: context,
                    initialState: filterState,
                    onApplied: onApplied,
                    presentation: presentation,
                    onFieldPressed: onFieldPressed,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Tap the trigger button to open the modal
    await tester.tap(find.byKey(const ValueKey('trigger')));

    // Pump long enough to complete the modal entry animation (dialog
    // uses 150ms, bottom sheet uses ~250ms).
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Retrieves the [DesignSystemTaskFilterSheet] widget currently in the
  /// tree. Useful for invoking callbacks directly when the widget is
  /// rendered inside a modal bottom sheet (where hit-testing can fail
  /// because the overlay positions content outside the render surface).
  DesignSystemTaskFilterSheet findSheet(WidgetTester tester) {
    return tester.widget<DesignSystemTaskFilterSheet>(
      find.byType(DesignSystemTaskFilterSheet),
    );
  }

  group('showDesignSystemFilterModal', () {
    group('desktop presentation', () {
      testWidgets(
        'opens a Dialog and renders filter sheet with showDragHandle false',
        (tester) async {
          await openModal(
            tester,
            presentation: DesignSystemFilterPresentation.desktop,
            onApplied: (_) {},
          );

          expect(find.byType(Dialog), findsOneWidget);
          expect(find.byType(DesignSystemTaskFilterSheet), findsOneWidget);
          expect(find.text('Filter'), findsOneWidget);
          expect(find.text('Sort by'), findsOneWidget);
          expect(find.text('Due date'), findsOneWidget);
          expect(find.text('Apply'), findsOneWidget);

          // Desktop presentation sets showDragHandle to false
          final sheet = findSheet(tester);
          expect(sheet.state.showDragHandle, isFalse);
        },
      );
    });

    group('mobile presentation', () {
      testWidgets(
        'opens a ModalBottomSheet and renders filter sheet with '
        'showDragHandle true',
        (tester) async {
          await openModal(
            tester,
            presentation: DesignSystemFilterPresentation.mobile,
            onApplied: (_) {},
          );

          expect(find.byType(BottomSheet), findsOneWidget);
          expect(find.byType(DesignSystemTaskFilterSheet), findsOneWidget);
          expect(find.text('Filter'), findsOneWidget);

          // Mobile presentation sets showDragHandle to true
          final sheet = findSheet(tester);
          expect(sheet.state.showDragHandle, isTrue);
        },
      );
    });

    group('onApplyPressed', () {
      testWidgets(
        'calls onApplied and closes dialog for desktop',
        (tester) async {
          DesignSystemTaskFilterState? appliedState;

          await openModal(
            tester,
            presentation: DesignSystemFilterPresentation.desktop,
            onApplied: (nextState) => appliedState = nextState,
          );

          final applyButton = find.byKey(
            const ValueKey('design-system-task-filter-apply'),
          );
          await tester.ensureVisible(applyButton);
          await tester.pump();
          await tester.tap(applyButton);
          await tester.pump();

          expect(appliedState, isNotNull);
          expect(appliedState!.statusField!.selectedIds, {'open'});
          expect(appliedState!.showDragHandle, isFalse);

          // The dialog should be closed after apply
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(DesignSystemTaskFilterSheet), findsNothing);
        },
      );

      testWidgets(
        'calls onApplied and closes bottom sheet for mobile',
        (tester) async {
          DesignSystemTaskFilterState? appliedState;

          await openModal(
            tester,
            presentation: DesignSystemFilterPresentation.mobile,
            onApplied: (nextState) => appliedState = nextState,
          );

          // In mobile, the bottom sheet overlay renders content outside the
          // surface bounds, so we invoke the apply callback directly.
          final sheet = findSheet(tester);
          sheet.onApplyPressed?.call(sheet.state);
          await tester.pump();

          expect(appliedState, isNotNull);
          expect(appliedState!.statusField!.selectedIds, {'open'});
          expect(appliedState!.showDragHandle, isTrue);

          // The bottom sheet should be closed after apply
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(DesignSystemTaskFilterSheet), findsNothing);
        },
      );
    });

    group('onClearAllPressed', () {
      testWidgets(
        'clears draft state filters for desktop',
        (tester) async {
          await openModal(
            tester,
            presentation: DesignSystemFilterPresentation.desktop,
            onApplied: (_) {},
          );

          expect(
            find.byKey(
              const ValueKey('design-system-task-filter-remove-status-open'),
            ),
            findsOneWidget,
          );

          final clearButton = find.byKey(
            const ValueKey('design-system-task-filter-clear'),
          );
          await tester.ensureVisible(clearButton);
          await tester.pump();
          await tester.tap(clearButton);
          await tester.pump();

          expect(
            find.byKey(
              const ValueKey('design-system-task-filter-remove-status-open'),
            ),
            findsNothing,
          );

          expect(find.byType(DesignSystemTaskFilterSheet), findsOneWidget);
        },
      );

      testWidgets(
        'clears draft state filters for mobile',
        (tester) async {
          await openModal(
            tester,
            presentation: DesignSystemFilterPresentation.mobile,
            onApplied: (_) {},
          );

          // Verify the sheet has a status selection before clearing
          var sheet = findSheet(tester);
          expect(sheet.state.statusField!.selectedIds, {'open'});

          // Invoke the clear-all callback directly because the bottom sheet
          // overlay renders outside the surface bounds in tests.
          final clearedState = sheet.state.clearAll();
          sheet.onChanged(clearedState);
          sheet.onClearAllPressed?.call(clearedState);
          await tester.pump();

          sheet = findSheet(tester);
          expect(sheet.state.statusField!.selectedIds, isEmpty);

          // Modal should still be open
          expect(find.byType(DesignSystemTaskFilterSheet), findsOneWidget);
        },
      );
    });

    group('onFieldPressed', () {
      testWidgets(
        'forwards field press to handler for desktop',
        (tester) async {
          final tappedSections = <DesignSystemTaskFilterSection>[];

          await openModal(
            tester,
            presentation: DesignSystemFilterPresentation.desktop,
            onApplied: (_) {},
            onFieldPressed: (context, draftState, section) async {
              tappedSections.add(section);
              return draftState.copyWith(
                statusField: draftState.statusField?.clear(),
              );
            },
          );

          final statusField = find.byKey(
            const ValueKey('design-system-task-filter-field-status'),
          );
          await tester.ensureVisible(statusField);
          await tester.pump();
          await tester.tap(statusField);
          await tester.pump();

          expect(tappedSections, [DesignSystemTaskFilterSection.status]);

          expect(
            find.byKey(
              const ValueKey('design-system-task-filter-remove-status-open'),
            ),
            findsNothing,
          );
        },
      );

      testWidgets(
        'forwards field press to handler for mobile',
        (tester) async {
          final tappedSections = <DesignSystemTaskFilterSection>[];

          await openModal(
            tester,
            presentation: DesignSystemFilterPresentation.mobile,
            onApplied: (_) {},
            onFieldPressed: (context, draftState, section) async {
              tappedSections.add(section);
              return draftState.copyWith(
                statusField: draftState.statusField?.clear(),
              );
            },
          );

          // Invoke the field press callback directly because the bottom sheet
          // overlay renders outside the surface bounds in tests.
          final sheet = findSheet(tester);
          sheet.onFieldPressed?.call(DesignSystemTaskFilterSection.status);
          await tester.pump();

          expect(tappedSections, [DesignSystemTaskFilterSection.status]);

          // After the handler clears status, the draft should be updated
          final updatedSheet = findSheet(tester);
          expect(updatedSheet.state.statusField!.selectedIds, isEmpty);
        },
      );

      testWidgets(
        'does not render field tap target when onFieldPressed is null',
        (tester) async {
          await openModal(
            tester,
            presentation: DesignSystemFilterPresentation.desktop,
            onApplied: (_) {},
          );

          final statusField = find.byKey(
            const ValueKey('design-system-task-filter-field-status'),
          );
          expect(statusField, findsOneWidget);

          // The sheet should have null onFieldPressed
          final sheet = findSheet(tester);
          expect(sheet.onFieldPressed, isNull);

          // Tap the field; since onFieldPressed is null, the InkWell's onTap
          // is null so nothing should happen (no crash)
          await tester.ensureVisible(statusField);
          await tester.pump();
          await tester.tap(statusField);
          await tester.pump();

          expect(find.byType(DesignSystemTaskFilterSheet), findsOneWidget);
        },
      );

      testWidgets(
        'does not update draft when onFieldPressed returns null',
        (tester) async {
          await openModal(
            tester,
            presentation: DesignSystemFilterPresentation.desktop,
            onApplied: (_) {},
            onFieldPressed: (context, draftState, section) async {
              return null;
            },
          );

          expect(
            find.byKey(
              const ValueKey('design-system-task-filter-remove-status-open'),
            ),
            findsOneWidget,
          );

          final statusField = find.byKey(
            const ValueKey('design-system-task-filter-field-status'),
          );
          await tester.ensureVisible(statusField);
          await tester.pump();
          await tester.tap(statusField);
          await tester.pump();

          // Since handler returned null, draft should remain unchanged
          expect(
            find.byKey(
              const ValueKey('design-system-task-filter-remove-status-open'),
            ),
            findsOneWidget,
          );
        },
      );
    });
  });
}
