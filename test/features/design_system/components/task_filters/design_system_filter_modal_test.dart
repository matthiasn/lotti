import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/l10n/app_localizations.dart';

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
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
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

    // Pump long enough to complete the Wolt modal entry animation.
    await tester.pumpAndSettle();
  }

  group('showDesignSystemFilterModal', () {
    testWidgets(
      'opens modal and renders filter sheet and action bar',
      (tester) async {
        await openModal(
          tester,
          onApplied: (_) {},
        );

        expect(find.byType(DesignSystemTaskFilterSheet), findsOneWidget);
        expect(
          find.byType(DesignSystemTaskFilterActionBar),
          findsOneWidget,
        );
        // Title comes from localization (tasksFilterTitle)
        expect(find.text('Tasks Filter'), findsOneWidget);
        expect(find.text('Sort by'), findsOneWidget);
        expect(find.text('Due date'), findsOneWidget);
        expect(find.text('Apply'), findsOneWidget);
      },
    );

    group('onApplyPressed', () {
      testWidgets(
        'calls onApplied and closes modal',
        (tester) async {
          DesignSystemTaskFilterState? appliedState;

          await openModal(
            tester,
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

          // The modal should be closed after apply
          await tester.pumpAndSettle();
          expect(find.byType(DesignSystemTaskFilterSheet), findsNothing);
        },
      );
    });

    group('onClearAllPressed', () {
      testWidgets(
        'clears draft state filters',
        (tester) async {
          await openModal(
            tester,
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
    });

    group('onFieldPressed', () {
      testWidgets(
        'forwards field press to handler',
        (tester) async {
          final tappedSections = <DesignSystemTaskFilterSection>[];

          await openModal(
            tester,
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
        'does not render field tap target when onFieldPressed is null',
        (tester) async {
          await openModal(
            tester,
            onApplied: (_) {},
          );

          final statusField = find.byKey(
            const ValueKey('design-system-task-filter-field-status'),
          );
          expect(statusField, findsOneWidget);

          // The sheet should have null onFieldPressed
          final sheet = tester.widget<DesignSystemTaskFilterSheet>(
            find.byType(DesignSystemTaskFilterSheet),
          );
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
