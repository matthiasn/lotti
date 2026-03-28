import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_selection_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemTaskFilterWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Task filter modal',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _TaskFilterOverviewPage(),
      ),
    ],
  );
}

class _TaskFilterOverviewPage extends StatefulWidget {
  const _TaskFilterOverviewPage();

  @override
  State<_TaskFilterOverviewPage> createState() =>
      _TaskFilterOverviewPageState();
}

class _TaskFilterOverviewPageState extends State<_TaskFilterOverviewPage> {
  DesignSystemTaskFilterState? _state;
  AppLocalizations? _lastMessages;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final messages = context.messages;
    if (_lastMessages != messages) {
      _lastMessages = messages;
      final previous = _state;
      final fresh = _buildSampleState(messages);
      _state = previous == null
          ? fresh
          : fresh.copyWith(
              selectedSortId: previous.selectedSortId,
              selectedPriorityId: previous.selectedPriorityId,
              statusField: fresh.statusField?.copyWith(
                selectedIds: previous.statusField?.selectedIds ?? const {},
              ),
              categoryField: fresh.categoryField?.copyWith(
                selectedIds: previous.categoryField?.selectedIds ?? const {},
              ),
              labelField: fresh.labelField?.copyWith(
                selectedIds: previous.labelField?.selectedIds ?? const {},
              ),
            );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          WidgetbookSection(
            title: 'Mobile Preview',
            child: WidgetbookViewport(
              width: 402,
              child: DesignSystemTaskFilterSheet(
                state: state,
                onChanged: (nextState) {
                  setState(() => _state = nextState);
                },
                onFieldPressed: (section) async {
                  final nextState =
                      await showDesignSystemTaskFilterFieldSelectionModal(
                        context: context,
                        draftState: state,
                        section: section,
                        presentation: DesignSystemFilterPresentation.mobile,
                      );
                  if (!mounted || nextState == null) {
                    return;
                  }

                  setState(() => _state = nextState);
                },
                onApplyPressed: (nextState) {
                  setState(() => _state = nextState);
                },
                onClearAllPressed: (nextState) {
                  setState(() => _state = nextState);
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
          const _TaskFilterStatePanelTitle(),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(state.toJson()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'Inconsolata',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskFilterStatePanelTitle extends StatelessWidget {
  const _TaskFilterStatePanelTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Serialized state',
      style: Theme.of(context).textTheme.headlineSmall,
    );
  }
}

DesignSystemTaskFilterState _buildSampleState(AppLocalizations messages) {
  return DesignSystemTaskFilterState(
    title: messages.tasksFilterApplyTitle,
    clearAllLabel: messages.tasksFilterClearAll,
    applyLabel: messages.tasksLabelsSheetApply,
    sortLabel: messages.tasksSortByLabel,
    sortOptions: [
      DesignSystemTaskFilterOption(
        id: 'due-date',
        label: messages.tasksSortByDueDate,
      ),
      DesignSystemTaskFilterOption(
        id: 'created-date',
        label: messages.tasksSortByCreationDate,
      ),
      DesignSystemTaskFilterOption(
        id: 'priority',
        label: messages.tasksSortByPriority,
      ),
    ],
    selectedSortId: 'due-date',
    statusField: DesignSystemTaskFilterFieldState(
      label: stripTrailingColon(messages.taskStatusLabel),
      options: [
        DesignSystemTaskFilterOption(
          id: 'open',
          label: messages.taskStatusOpen,
        ),
        DesignSystemTaskFilterOption(
          id: 'in-progress',
          label: messages.taskStatusInProgress,
        ),
        DesignSystemTaskFilterOption(
          id: 'blocked',
          label: messages.taskStatusBlocked,
        ),
      ],
      selectedIds: const {'open', 'in-progress'},
    ),
    priorityLabel: messages.tasksPriorityFilterTitle,
    priorityOptions: [
      const DesignSystemTaskFilterOption(
        id: 'p0',
        label: 'P0',
        glyph: DesignSystemTaskFilterGlyph.priorityP0,
      ),
      const DesignSystemTaskFilterOption(
        id: 'p1',
        label: 'P1',
        glyph: DesignSystemTaskFilterGlyph.priorityP1,
      ),
      const DesignSystemTaskFilterOption(
        id: 'p2',
        label: 'P2',
        glyph: DesignSystemTaskFilterGlyph.priorityP2,
      ),
      const DesignSystemTaskFilterOption(
        id: 'p3',
        label: 'P3',
        glyph: DesignSystemTaskFilterGlyph.priorityP3,
      ),
      DesignSystemTaskFilterOption(
        id: DesignSystemTaskFilterState.allPriorityId,
        label: messages.tasksPriorityFilterAll,
      ),
    ],
    selectedPriorityId: 'p2',
    categoryField: DesignSystemTaskFilterFieldState(
      label: stripTrailingColon(messages.taskCategoryLabel),
      options: const [
        DesignSystemTaskFilterOption(id: 'learn', label: 'Learn'),
        DesignSystemTaskFilterOption(id: 'study', label: 'Study'),
        DesignSystemTaskFilterOption(id: 'ship', label: 'Ship'),
      ],
      selectedIds: const {'learn', 'study'},
    ),
    labelField: DesignSystemTaskFilterFieldState(
      label: messages.tasksLabelFilterTitle,
      options: const [
        DesignSystemTaskFilterOption(id: 'ai-coding', label: 'AI Coding'),
        DesignSystemTaskFilterOption(id: 'agents', label: 'Agents'),
        DesignSystemTaskFilterOption(id: 'ux', label: 'UX'),
      ],
      selectedIds: const {'ai-coding', 'agents'},
    ),
  );
}
