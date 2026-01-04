import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_wrapper.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/checklists/drag_utils.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Body of a checklist card containing items list and add input.
class ChecklistCardBody extends StatelessWidget {
  const ChecklistCardBody({
    required this.itemIds,
    required this.checklistId,
    required this.taskId,
    required this.filter,
    required this.completionRate,
    required this.focusNode,
    required this.isCreatingItem,
    required this.onCreateItem,
    required this.onReorder,
    super.key,
  });

  final List<String> itemIds;
  final String checklistId;
  final String taskId;
  final ChecklistFilter filter;
  final double completionRate;
  final FocusNode focusNode;
  final bool isCreatingItem;
  final Future<void> Function(String?) onCreateItem;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final hideChecked = filter == ChecklistFilter.openOnly;
    final allDone = hideChecked && completionRate == 1 && itemIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Items list (with horizontal padding)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.cardPadding),
          child: itemIds.isEmpty
              ? const ChecklistEmptyState()
              : allDone
                  ? const ChecklistAllDoneState()
                  : ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // Disable Flutter's default handles - we use custom left-side
                      // handles. Cross-checklist drag uses super_drag_and_drop
                      // (long-press anywhere on item).
                      buildDefaultDragHandles: false,
                      proxyDecorator: (child, index, animation) =>
                          buildDragDecorator(context, child),
                      onReorder: onReorder,
                      children: List.generate(
                        itemIds.length,
                        (int index) {
                          final itemId = itemIds.elementAt(index);
                          return ChecklistItemWrapper(
                            itemId,
                            taskId: taskId,
                            checklistId: checklistId,
                            hideIfChecked: hideChecked,
                            index: index,
                            key:
                                ValueKey('checklist-item-$checklistId-$itemId'),
                          );
                        },
                      ),
                    ),
        ),

        // Divider 3: Between items and add input (no horizontal padding)
        Divider(
          height: 1,
          thickness: 1,
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),

        // Add input at BOTTOM (with horizontal padding)
        // Top padding from divider, bottom padding combines with card's padding
        Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.cardPadding,
            right: AppTheme.cardPadding,
            top: 12,
            bottom: 4, // Card adds cardPaddingHalf (8) below this
          ),
          child: FocusTraversalGroup(
            child: FocusScope(
              child: TitleTextField(
                key: ValueKey('add-input-$checklistId'),
                focusNode: focusNode,
                onSave: onCreateItem,
                clearOnSave: true,
                keepFocusOnSave: true,
                autofocus: itemIds.isEmpty,
                semanticsLabel: 'Add item to checklist',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Empty state shown when a checklist has no items.
class ChecklistEmptyState extends StatelessWidget {
  const ChecklistEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Only vertical padding - horizontal is handled by parent
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Text(
          'No items yet',
          style: context.textTheme.titleSmall?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

/// State shown when all checklist items are complete and filter is "Open only".
class ChecklistAllDoneState extends StatelessWidget {
  const ChecklistAllDoneState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Only vertical padding - horizontal is handled by parent
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        context.messages.checklistAllDone,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.outline,
        ),
      ),
    );
  }
}
