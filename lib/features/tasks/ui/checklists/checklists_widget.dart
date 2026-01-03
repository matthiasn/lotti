import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklists_sorting_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_wrapper.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

/// Container widget for all checklists within a task.
///
/// Features:
/// - Global section header with title, add button, and menu
/// - Reorderable list of checklist cards
/// - Global sorting mode that collapses all cards for reordering
class ChecklistsWidget extends ConsumerStatefulWidget {
  const ChecklistsWidget({
    required this.entryId,
    required this.task,
    super.key,
  });

  final String entryId;
  final Task task;

  @override
  ConsumerState<ChecklistsWidget> createState() => _ChecklistsWidgetState();
}

class _ChecklistsWidgetState extends ConsumerState<ChecklistsWidget> {
  List<String>? _checklistIds;

  /// Track expansion states for each checklist (used for sorting mode).
  final Map<String, bool> _expansionStates = {};

  void _onExpansionChanged(String checklistId, bool isExpanded) {
    _expansionStates[checklistId] = isExpanded;
  }

  void _enterSortingMode() {
    ref
        .read(checklistsSortingControllerProvider(widget.task.id).notifier)
        .enterSortingMode(Map<String, bool>.from(_expansionStates));
  }

  void _exitSortingMode() {
    ref
        .read(checklistsSortingControllerProvider(widget.task.id).notifier)
        .exitSortingMode();
  }

  @override
  Widget build(BuildContext context) {
    final provider = entryControllerProvider(id: widget.entryId);
    final item = ref.watch(provider).value?.entry;
    final notifier = ref.read(provider.notifier);

    // Watch sorting state
    final sortingState = ref.watch(
      checklistsSortingControllerProvider(widget.task.id),
    );
    final isSorting = sortingState.isSorting;

    if (item == null || item is! Task) {
      return const SizedBox.shrink();
    }

    final checklistIds = _checklistIds ?? item.data.checklistIds ?? [];
    final color = context.colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // GLOBAL SECTION HEADER
        _ChecklistsSectionHeader(
          onAdd: () => createChecklist(task: widget.task, ref: ref),
          onSortChecklists: checklistIds.length > 1 ? _enterSortingMode : null,
          checklistCount: checklistIds.length,
          color: color,
        ),

        // CHECKLIST CARDS
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false, // We use custom drag handles
          onReorder: (int oldIndex, int newIndex) {
            final itemIds = [...checklistIds];
            final movedItem = itemIds.removeAt(oldIndex);
            final insertionIndex =
                newIndex > oldIndex ? newIndex - 1 : newIndex;
            itemIds.insert(insertionIndex, movedItem);
            setState(() {
              _checklistIds = itemIds;
            });

            notifier.updateChecklistOrder(itemIds);
          },
          children: List.generate(
            checklistIds.length,
            (int index) {
              final checklistId = checklistIds.elementAt(index);
              // Wrap in Consumer to filter out deleted/stale checklists
              return Consumer(
                key: Key('$checklistId${widget.entryId}$index'),
                builder: (context, ref, _) {
                  final checklist = ref
                      .watch(
                        checklistControllerProvider((
                          id: checklistId,
                          taskId: widget.task.id,
                        )),
                      )
                      .value;
                  // Don't render card for deleted or stale checklists
                  if (checklist == null) {
                    return const SizedBox.shrink();
                  }

                  // Determine initial expansion state for restoration
                  final initiallyExpanded = isSorting
                      ? false // Force collapsed during sorting
                      : sortingState.preExpansionStates[checklistId];

                  return ModernBaseCard(
                    margin: const EdgeInsets.only(
                      bottom: AppTheme.cardSpacing,
                    ),
                    // Only vertical padding - horizontal padding is handled
                    // inside ChecklistWidget to allow dividers to extend edge-to-edge
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.cardPaddingHalf,
                    ),
                    child: ChecklistWrapper(
                      entryId: checklistId,
                      categoryId: item.categoryId,
                      taskId: widget.task.id,
                      isSortingMode: isSorting,
                      initiallyExpanded: initiallyExpanded,
                      onExpansionChanged: _onExpansionChanged,
                      reorderIndex: index,
                    ),
                  );
                },
              );
            },
          ),
        ),

        // DONE BUTTON (shown during sorting mode)
        if (isSorting)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _exitSortingMode,
                child: Text(context.messages.doneButton),
              ),
            ),
          ),
      ],
    );
  }
}

/// Section header with title, add button, and menu.
class _ChecklistsSectionHeader extends StatelessWidget {
  const _ChecklistsSectionHeader({
    required this.onAdd,
    required this.checklistCount,
    required this.color,
    this.onSortChecklists,
  });

  final VoidCallback onAdd;
  final VoidCallback? onSortChecklists;
  final int checklistCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          context.messages.checklistsTitle,
          style: context.textTheme.titleSmall?.copyWith(color: color),
        ),
        IconButton(
          tooltip: context.messages.addActionAddChecklist,
          onPressed: onAdd,
          icon: Icon(Icons.add_rounded, color: color),
        ),
        // Only show menu if there are actions available
        if (checklistCount > 1)
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                color: context.colorScheme.surfaceContainerHighest,
                elevation: 8,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: context.colorScheme.outlineVariant
                        .withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
              ),
            ),
            child: PopupMenuButton<String>(
              tooltip: 'More',
              icon: Icon(Icons.more_vert, color: color, size: 20),
              position: PopupMenuPosition.under,
              onSelected: (value) {
                if (value == 'sort') {
                  onSortChecklists?.call();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'sort',
                  child: Row(
                    children: [
                      const Icon(Icons.sort, size: 18),
                      const SizedBox(width: 8),
                      Text(context.messages.checklistsReorder),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
