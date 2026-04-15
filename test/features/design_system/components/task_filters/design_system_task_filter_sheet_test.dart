import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemTaskFilterOption', () {
    test('serializes and deserializes glyph values', () {
      const option = DesignSystemTaskFilterOption(
        id: 'p1',
        label: 'P1',
        glyph: DesignSystemTaskFilterGlyph.priorityP1,
      );

      final roundTrip = DesignSystemTaskFilterOption.fromJson(option.toJson());
      final defaultGlyphOption = DesignSystemTaskFilterOption.fromJson(const {
        'id': 'all',
        'label': 'All',
      });

      expect(roundTrip.id, option.id);
      expect(roundTrip.label, option.label);
      expect(roundTrip.glyph, DesignSystemTaskFilterGlyph.priorityP1);
      expect(defaultGlyphOption.glyph, DesignSystemTaskFilterGlyph.none);
    });
  });

  group('DesignSystemTaskFilterFieldState', () {
    test(
      'tracks selected options in option order and keeps no-op updates stable',
      () {
        final fieldState = _buildFieldState(
          label: 'Labels',
          options: const [
            DesignSystemTaskFilterOption(id: 'ai-coding', label: 'AI Coding'),
            DesignSystemTaskFilterOption(id: 'agents', label: 'Agents'),
            DesignSystemTaskFilterOption(id: 'ux', label: 'UX'),
          ],
          selectedIds: const {'agents', 'ai-coding'},
        );

        expect(
          fieldState.selectedOptions.map((option) => option.id),
          ['ai-coding', 'agents'],
        );
        expect(fieldState.removeSelection('missing'), same(fieldState));

        final removed = fieldState.removeSelection('ai-coding');
        final copied = removed.copyWith(label: 'Updated labels');
        final cleared = removed.clear();
        final roundTrip = DesignSystemTaskFilterFieldState.fromJson(
          fieldState.toJson(),
        );

        expect(removed.selectedIds, {'agents'});
        expect(copied.label, 'Updated labels');
        expect(cleared.selectedIds, isEmpty);
        expect(cleared.clear(), same(cleared));
        expect(roundTrip.label, fieldState.label);
        expect(
          roundTrip.options.map((option) => option.id),
          ['ai-coding', 'agents', 'ux'],
        );
        expect(roundTrip.selectedIds, {'ai-coding', 'agents'});
      },
    );
  });

  group('DesignSystemTaskFilterState', () {
    test('round trips through json and updates each selection bucket', () {
      final state = _buildState();

      final roundTrip = DesignSystemTaskFilterState.fromJson(state.toJson());
      final copied = state.copyWith(
        title: 'Updated title',
      );
      final sorted = state.selectSort('priority');
      final prioritized = state.selectPriority(
        DesignSystemTaskFilterState.allPriorityId,
      );
      final statusRemoved = state.removeSelection(
        DesignSystemTaskFilterSection.status,
        'open',
      );
      final categoryRemoved = state.removeSelection(
        DesignSystemTaskFilterSection.category,
        'learn',
      );
      final labelRemoved = state.removeSelection(
        DesignSystemTaskFilterSection.label,
        'ai-coding',
      );

      expect(roundTrip.selectedSortId, state.selectedSortId);
      expect(roundTrip.selectedPriorityId, state.selectedPriorityId);
      expect(
        roundTrip.statusField!.selectedIds,
        state.statusField!.selectedIds,
      );
      expect(
        roundTrip.categoryField!.selectedIds,
        state.categoryField!.selectedIds,
      );
      expect(roundTrip.labelField!.selectedIds, state.labelField!.selectedIds);
      expect(state.selectSort('due-date'), same(state));
      expect(state.selectPriority('p2'), same(state));
      expect(copied.title, 'Updated title');
      expect(sorted.selectedSortId, 'priority');
      expect(
        prioritized.selectedPriorityId,
        DesignSystemTaskFilterState.allPriorityId,
      );
      expect(prioritized.appliedCount, 6);
      expect(statusRemoved.statusField!.selectedIds, {'in-progress'});
      expect(categoryRemoved.categoryField!.selectedIds, {'study'});
      expect(labelRemoved.labelField!.selectedIds, {'agents'});
    });

    test('removes project selection and counts project in appliedCount', () {
      final state = _buildState().copyWith(
        projectField: _buildFieldState(
          label: 'Project',
          options: const [
            DesignSystemTaskFilterOption(id: 'p1', label: 'Alpha'),
            DesignSystemTaskFilterOption(id: 'p2', label: 'Beta'),
          ],
          selectedIds: const {'p1', 'p2'},
        ),
      );

      // appliedCount includes project selections
      // 2 status + 1 priority + 2 category + 2 label + 2 project = 9
      expect(state.appliedCount, 9);

      final projectRemoved = state.removeSelection(
        DesignSystemTaskFilterSection.project,
        'p1',
      );
      expect(projectRemoved.projectField!.selectedIds, {'p2'});

      // clearAll clears project field too
      final cleared = state.clearAll();
      expect(cleared.projectField!.selectedIds, isEmpty);
    });

    test('derives applied count and clears selected filters', () {
      final state = _buildState();

      expect(state.appliedCount, 7);

      final cleared = state.clearAll();

      expect(cleared.selectedSortId, 'due-date');
      expect(cleared.statusField!.selectedIds, isEmpty);
      expect(
        cleared.selectedPriorityId,
        DesignSystemTaskFilterState.allPriorityId,
      );
      expect(cleared.categoryField!.selectedIds, isEmpty);
      expect(cleared.labelField!.selectedIds, isEmpty);
      expect(cleared.appliedCount, 0);
    });

    test(
      'supports project-style sheets with only status and category fields',
      () {
        final state = DesignSystemTaskFilterState(
          title: 'Apply filter',
          clearAllLabel: 'Clear all',
          applyLabel: 'Apply',
          statusField: _buildFieldState(
            label: 'Status',
            options: const [
              DesignSystemTaskFilterOption(id: 'active', label: 'Active'),
              DesignSystemTaskFilterOption(id: 'completed', label: 'Completed'),
            ],
            selectedIds: const {'completed'},
          ),
          categoryField: _buildFieldState(
            label: 'Category',
            options: const [
              DesignSystemTaskFilterOption(id: 'work', label: 'Work'),
              DesignSystemTaskFilterOption(id: 'study', label: 'Study'),
            ],
            selectedIds: const {'work'},
          ),
        );

        expect(state.hasSortSection, isFalse);
        expect(state.hasPrioritySection, isFalse);
        expect(state.hasLabelField, isFalse);
        expect(state.appliedCount, 2);

        final cleared = state.clearAll();

        expect(cleared.statusField!.selectedIds, isEmpty);
        expect(cleared.categoryField!.selectedIds, isEmpty);
        expect(cleared.appliedCount, 0);
      },
    );
  });

  group('DesignSystemTaskFilterSheet', () {
    testWidgets(
      'supports sort changes, field taps, chip removal, and apply callbacks',
      (tester) async {
        final tappedSections = <DesignSystemTaskFilterSection>[];
        DesignSystemTaskFilterState? appliedState;

        final state = await _pumpTaskFilterSheet(
          tester,
          initialState: _buildState(),
          onFieldPressed: tappedSections.add,
          onApplyPressed: (nextState) => appliedState = nextState,
        );

        expect(find.text('Apply'), findsOneWidget);
        expect(find.byIcon(Icons.new_releases), findsOneWidget);
        expect(find.text('7'), findsOneWidget);

        await tester.tap(
          find.byKey(
            const ValueKey('design-system-task-filter-sort-priority'),
          ),
        );
        await tester.pump();

        expect(state.value.selectedSortId, 'priority');

        final statusField = find.byKey(
          const ValueKey('design-system-task-filter-field-status'),
        );
        final categoryField = find.byKey(
          const ValueKey('design-system-task-filter-field-category'),
        );
        final labelField = find.byKey(
          const ValueKey('design-system-task-filter-field-label'),
        );

        await tester.ensureVisible(statusField);
        await tester.pumpAndSettle();
        await tester.tap(
          statusField,
        );
        await tester.ensureVisible(categoryField);
        await tester.pumpAndSettle();
        await tester.tap(
          categoryField,
        );
        await tester.ensureVisible(labelField);
        await tester.pumpAndSettle();
        await tester.tap(
          labelField,
        );

        expect(
          tappedSections,
          [
            DesignSystemTaskFilterSection.status,
            DesignSystemTaskFilterSection.category,
            DesignSystemTaskFilterSection.label,
          ],
        );

        await tester.tap(
          find.byKey(
            const ValueKey('design-system-task-filter-remove-status-open'),
          ),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(
            const ValueKey('design-system-task-filter-remove-category-learn'),
          ),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(
            const ValueKey('design-system-task-filter-remove-label-ai-coding'),
          ),
        );
        await tester.pump();

        expect(state.value.statusField!.selectedIds, {'in-progress'});
        expect(state.value.categoryField!.selectedIds, {'study'});
        expect(state.value.labelField!.selectedIds, {'agents'});
        expect(state.value.appliedCount, 4);
        expect(find.text('4'), findsOneWidget);

        final applyButton = find.byKey(
          const ValueKey('design-system-task-filter-apply'),
        );
        await tester.ensureVisible(applyButton);
        await tester.tap(applyButton);
        await tester.pump();

        expect(appliedState, same(state.value));
      },
    );

    testWidgets(
      'renders empty selections in light theme and clears callback state',
      (tester) async {
        DesignSystemTaskFilterState? clearedState;

        final state = await _pumpTaskFilterSheet(
          tester,
          initialState: _buildState(
            selectedPriorityId: DesignSystemTaskFilterState.allPriorityId,
            statusSelectedIds: const <String>{},
            categorySelectedIds: const <String>{},
            labelSelectedIds: const <String>{},
          ),
          theme: DesignSystemTheme.light(),
          onClearAllPressed: (nextState) => clearedState = nextState,
        );

        expect(find.text('0'), findsOneWidget);
        expect(
          find.byKey(
            const ValueKey('design-system-task-filter-remove-status-open'),
          ),
          findsNothing,
        );
        expect(find.byIcon(Icons.new_releases), findsOneWidget);

        await tester.tap(
          find.byKey(
            const ValueKey('design-system-task-filter-priority-p0'),
          ),
        );
        await tester.pump();

        expect(state.value.selectedPriorityId, 'p0');
        expect(find.text('1'), findsOneWidget);

        final clearButton = find.byKey(
          const ValueKey('design-system-task-filter-clear'),
        );
        await tester.ensureVisible(clearButton);
        await tester.tap(clearButton);
        await tester.pump();

        expect(clearedState, isNotNull);
        expect(clearedState!.appliedCount, 0);
        expect(
          state.value.selectedPriorityId,
          DesignSystemTaskFilterState.allPriorityId,
        );
        expect(find.text('0'), findsOneWidget);
      },
    );

    testWidgets('hides omitted sort, priority, and label sections', (
      tester,
    ) async {
      await _pumpTaskFilterSheet(
        tester,
        initialState: DesignSystemTaskFilterState(
          title: 'Apply filter',
          clearAllLabel: 'Clear all',
          applyLabel: 'Apply',
          statusField: _buildFieldState(
            label: 'Status',
            options: const [
              DesignSystemTaskFilterOption(id: 'active', label: 'Active'),
            ],
            selectedIds: const {'active'},
          ),
          categoryField: _buildFieldState(
            label: 'Category',
            options: const [
              DesignSystemTaskFilterOption(id: 'work', label: 'Work'),
            ],
            selectedIds: const {'work'},
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('design-system-task-filter-field-status')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('design-system-task-filter-field-category')),
        findsOneWidget,
      );
      expect(find.text('Sort by'), findsNothing);
      expect(find.text('Priority'), findsNothing);
      expect(
        find.byKey(const ValueKey('design-system-task-filter-field-label')),
        findsNothing,
      );
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('DesignSystemTaskFilterSheet toggle rows', () {
    testWidgets('renders toggle rows with correct state', (tester) async {
      DesignSystemTaskFilterState? lastChanged;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: DesignSystemTaskFilterSheet(
              state: DesignSystemTaskFilterState(
                title: 'Filters',
                clearAllLabel: 'Clear',
                applyLabel: 'Apply',
                toggles: const [
                  DesignSystemTaskFilterToggle(
                    id: 'showDate',
                    label: 'Show date',
                    value: false,
                  ),
                  DesignSystemTaskFilterToggle(
                    id: 'showDue',
                    label: 'Show due date',
                    value: true,
                  ),
                ],
              ),
              onChanged: (s) => lastChanged = s,
            ),
          ),
        ),
      );

      expect(find.text('Show date'), findsOneWidget);
      expect(find.text('Show due date'), findsOneWidget);

      await tester.tap(find.text('Show date'));
      await tester.pump();

      expect(lastChanged, isNotNull);
      expect(lastChanged!.toggles[0].value, isTrue);
      expect(lastChanged!.toggles[1].value, isTrue);
    });

    testWidgets('renders agent filter pills', (tester) async {
      DesignSystemTaskFilterState? lastChanged;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: DesignSystemTaskFilterSheet(
              state: DesignSystemTaskFilterState(
                title: 'Filters',
                clearAllLabel: 'Clear',
                applyLabel: 'Apply',
                agentFilterLabel: 'Agent',
                agentFilterOptions: const [
                  DesignSystemTaskFilterOption(id: 'all', label: 'All'),
                  DesignSystemTaskFilterOption(
                    id: 'hasAgent',
                    label: 'Has agent',
                  ),
                ],
                selectedAgentFilterId: 'all',
              ),
              onChanged: (s) => lastChanged = s,
            ),
          ),
        ),
      );

      expect(find.text('Agent'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Has agent'), findsOneWidget);

      await tester.tap(find.text('Has agent'));
      await tester.pump();

      expect(lastChanged!.selectedAgentFilterId, 'hasAgent');
    });

    testWidgets('renders search mode pills', (tester) async {
      DesignSystemTaskFilterState? lastChanged;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: DesignSystemTaskFilterSheet(
              state: DesignSystemTaskFilterState(
                title: 'Filters',
                clearAllLabel: 'Clear',
                applyLabel: 'Apply',
                searchModeLabel: 'Search mode',
                searchModeOptions: const [
                  DesignSystemTaskFilterOption(
                    id: 'fullText',
                    label: 'Full text',
                  ),
                  DesignSystemTaskFilterOption(
                    id: 'vector',
                    label: 'Vector',
                  ),
                ],
                selectedSearchModeId: 'fullText',
              ),
              onChanged: (s) => lastChanged = s,
            ),
          ),
        ),
      );

      expect(find.text('Search mode'), findsOneWidget);

      await tester.tap(find.text('Vector'));
      await tester.pump();

      expect(lastChanged!.selectedSearchModeId, 'vector');
    });

    testWidgets('renders project field section', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: DesignSystemTaskFilterSheet(
              state: DesignSystemTaskFilterState(
                title: 'Filters',
                clearAllLabel: 'Clear',
                applyLabel: 'Apply',
                projectField: const DesignSystemTaskFilterFieldState(
                  label: 'Project',
                  options: [
                    DesignSystemTaskFilterOption(id: 'p1', label: 'Alpha'),
                    DesignSystemTaskFilterOption(id: 'p2', label: 'Beta'),
                  ],
                  selectedIds: {'p1'},
                ),
              ),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Project'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
    });

    testWidgets('project field supports chip removal and tap callback', (
      tester,
    ) async {
      DesignSystemTaskFilterState? lastChanged;
      final tappedSections = <DesignSystemTaskFilterSection>[];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: DesignSystemTaskFilterSheet(
              state: DesignSystemTaskFilterState(
                title: 'Filters',
                clearAllLabel: 'Clear',
                applyLabel: 'Apply',
                projectField: const DesignSystemTaskFilterFieldState(
                  label: 'Project',
                  options: [
                    DesignSystemTaskFilterOption(id: 'p1', label: 'Alpha'),
                    DesignSystemTaskFilterOption(id: 'p2', label: 'Beta'),
                  ],
                  selectedIds: {'p1', 'p2'},
                ),
              ),
              onChanged: (s) => lastChanged = s,
              onFieldPressed: tappedSections.add,
            ),
          ),
        ),
      );

      // Tap the project field to trigger onFieldPressed
      await tester.tap(
        find.byKey(
          const ValueKey('design-system-task-filter-field-project'),
        ),
      );
      await tester.pump();

      expect(tappedSections, [DesignSystemTaskFilterSection.project]);

      // Remove a project chip
      await tester.tap(
        find.byKey(
          const ValueKey('design-system-task-filter-remove-project-p1'),
        ),
      );
      await tester.pump();

      expect(lastChanged!.projectField!.selectedIds, {'p2'});
    });
  });
}

Future<ValueNotifier<DesignSystemTaskFilterState>> _pumpTaskFilterSheet(
  WidgetTester tester, {
  required DesignSystemTaskFilterState initialState,
  ThemeData? theme,
  ValueChanged<DesignSystemTaskFilterSection>? onFieldPressed,
  ValueChanged<DesignSystemTaskFilterState>? onApplyPressed,
  ValueChanged<DesignSystemTaskFilterState>? onClearAllPressed,
}) async {
  final state = ValueNotifier(initialState);
  addTearDown(state.dispose);
  await tester.binding.setSurfaceSize(const Size(900, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    makeTestableWidget2(
      StatefulBuilder(
        builder: (context, setState) {
          return Theme(
            data: theme ?? DesignSystemTheme.dark(),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 430,
                  height: 760,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        DesignSystemTaskFilterSheet(
                          state: state.value,
                          onChanged: (nextState) {
                            state.value = nextState;
                            setState(() {});
                          },
                          onFieldPressed: onFieldPressed,
                        ),
                        DesignSystemTaskFilterActionBar(
                          state: state.value,
                          onChanged: (nextState) {
                            state.value = nextState;
                            setState(() {});
                          },
                          onApplyPressed: onApplyPressed,
                          onClearAllPressed: onClearAllPressed,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      mediaQueryData: const MediaQueryData(size: Size(900, 1000)),
    ),
  );
  await tester.pump();

  return state;
}

DesignSystemTaskFilterState _buildState({
  String selectedSortId = 'due-date',
  String selectedPriorityId = 'p2',
  Set<String> statusSelectedIds = const {'open', 'in-progress'},
  Set<String> categorySelectedIds = const {'learn', 'study'},
  Set<String> labelSelectedIds = const {'ai-coding', 'agents'},
}) {
  return DesignSystemTaskFilterState(
    title: 'Apply filter',
    clearAllLabel: 'Clear all',
    applyLabel: 'Apply',
    sortLabel: 'Sort by',
    sortOptions: const [
      DesignSystemTaskFilterOption(id: 'due-date', label: 'Due date'),
      DesignSystemTaskFilterOption(id: 'created-date', label: 'Created'),
      DesignSystemTaskFilterOption(id: 'priority', label: 'Priority'),
    ],
    selectedSortId: selectedSortId,
    statusField: _buildFieldState(
      label: 'Status',
      options: const [
        DesignSystemTaskFilterOption(id: 'open', label: 'Open'),
        DesignSystemTaskFilterOption(id: 'in-progress', label: 'In progress'),
        DesignSystemTaskFilterOption(id: 'blocked', label: 'Blocked'),
      ],
      selectedIds: statusSelectedIds,
    ),
    priorityLabel: 'Priority',
    priorityOptions: const [
      DesignSystemTaskFilterOption(
        id: 'p0',
        label: 'P0',
        glyph: DesignSystemTaskFilterGlyph.priorityP0,
      ),
      DesignSystemTaskFilterOption(
        id: 'p1',
        label: 'P1',
        glyph: DesignSystemTaskFilterGlyph.priorityP1,
      ),
      DesignSystemTaskFilterOption(
        id: 'p2',
        label: 'P2',
        glyph: DesignSystemTaskFilterGlyph.priorityP2,
      ),
      DesignSystemTaskFilterOption(
        id: 'p3',
        label: 'P3',
        glyph: DesignSystemTaskFilterGlyph.priorityP3,
      ),
      DesignSystemTaskFilterOption(
        id: DesignSystemTaskFilterState.allPriorityId,
        label: 'All',
      ),
    ],
    selectedPriorityId: selectedPriorityId,
    categoryField: _buildFieldState(
      label: 'Category',
      options: const [
        DesignSystemTaskFilterOption(id: 'learn', label: 'Learn'),
        DesignSystemTaskFilterOption(id: 'study', label: 'Study'),
        DesignSystemTaskFilterOption(id: 'ship', label: 'Ship'),
      ],
      selectedIds: categorySelectedIds,
    ),
    labelField: _buildFieldState(
      label: 'Labels',
      options: const [
        DesignSystemTaskFilterOption(id: 'ai-coding', label: 'AI Coding'),
        DesignSystemTaskFilterOption(id: 'agents', label: 'Agents'),
        DesignSystemTaskFilterOption(id: 'ux', label: 'UX'),
      ],
      selectedIds: labelSelectedIds,
    ),
  );
}

DesignSystemTaskFilterFieldState _buildFieldState({
  required String label,
  required List<DesignSystemTaskFilterOption> options,
  required Set<String> selectedIds,
}) {
  return DesignSystemTaskFilterFieldState(
    label: label,
    options: options,
    selectedIds: selectedIds,
  );
}
