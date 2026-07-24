import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/state/linked_tasks_controller.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_task_modal.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_relationship_sections.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/theme.dart';

/// Linked tasks card on the task detail view.
///
/// Renders a single section card with a header (title, count badge, expand
/// chevron, overflow menu), the 6 typed-relationship sections
/// ([TaskRelationshipSections] — Blocked by, Blocks, Follow-ups, Duplicates,
/// Fixes, Supersedes, each shown only when non-empty), and the flat
/// plain-link list (today's original "Linked Tasks" rows, unchanged). Hidden
/// entirely when there are no links of any kind.
class LinkedTasksWidget extends ConsumerStatefulWidget {
  const LinkedTasksWidget({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  ConsumerState<LinkedTasksWidget> createState() => _LinkedTasksWidgetState();
}

class _LinkedTasksWidgetState extends ConsumerState<LinkedTasksWidget> {
  bool _expanded = true;

  @override
  void didUpdateWidget(LinkedTasksWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskId = widget.taskId;
    final uiState = ref.watch(linkedTasksControllerProvider(taskId));
    final linkGroups =
        ref.watch(taskLinkGroupsControllerProvider(taskId)).value ??
        TaskLinkGroups.empty;

    if (linkGroups.totalCount == 0) {
      return const SizedBox.shrink();
    }

    final flatRows = linkGroups.flat
        .map(
          (entry) => LinkedTaskRowData(
            task: entry.task,
            direction: entry.direction == TaskLinkDirection.outgoing
                ? LinkDirection.outgoing
                : LinkDirection.incoming,
            caption: entry.direction == TaskLinkDirection.outgoing
                ? context.messages.linkedToCaption
                : context.messages.linkedFromCaption,
          ),
        )
        .toList();

    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.l);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level02,
          borderRadius: radius,
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LinkedTasksHeader(
                taskId: taskId,
                count: linkGroups.totalCount,
                expanded: _expanded,
                hasLinkedTasks: true,
                manageMode: uiState.manageMode,
                onToggleExpanded: () => setState(() => _expanded = !_expanded),
              ),
              if (_expanded) ...[
                if (linkGroups.typed.isNotEmpty)
                  TaskRelationshipSections(
                    taskId: taskId,
                    manageMode: uiState.manageMode,
                  ),
                if (linkGroups.typed.isNotEmpty && flatRows.isNotEmpty)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: tokens.colors.decorative.level01,
                  ),
                for (var i = 0; i < flatRows.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: tokens.colors.decorative.level01,
                    ),
                  LinkedTaskRow(
                    taskId: taskId,
                    data: flatRows[i],
                    manageMode: uiState.manageMode,
                    onUnlink: () => ref
                        .read(journalRepositoryProvider)
                        .removeTypedLink(
                          fromId:
                              flatRows[i].direction == LinkDirection.outgoing
                              ? taskId
                              : flatRows[i].task.meta.id,
                          toId: flatRows[i].direction == LinkDirection.outgoing
                              ? flatRows[i].task.meta.id
                              : taskId,
                          linkType: 'BasicLink',
                        ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkedTasksHeader extends ConsumerWidget {
  const _LinkedTasksHeader({
    required this.taskId,
    required this.count,
    required this.expanded,
    required this.hasLinkedTasks,
    required this.manageMode,
    required this.onToggleExpanded,
  });

  final String taskId;
  final int count;
  final bool expanded;
  final bool hasLinkedTasks;
  final bool manageMode;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final notifier = ref.read(
      linkedTasksControllerProvider(taskId).notifier,
    );

    return InkWell(
      onTap: onToggleExpanded,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.step5,
          tokens.spacing.step3,
          tokens.spacing.step3,
          tokens.spacing.step3,
        ),
        child: Row(
          children: [
            Text(
              context.messages.linkedTasksTitle,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            _CountBadge(count: count),
            const Spacer(),
            Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
              size: 24,
              color: tokens.colors.text.highEmphasis,
            ),
            SizedBox(width: tokens.spacing.step3),
            Theme(
              data: Theme.of(context).copyWith(
                popupMenuTheme: PopupMenuThemeData(
                  color: context.colorScheme.surfaceContainerHighest,
                  elevation: 8,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: context.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                      width: 0.8,
                    ),
                  ),
                ),
              ),
              child: PopupMenuButton<String>(
                tooltip: context.messages.linkedTasksMenuTooltip,
                icon: Icon(
                  Icons.more_vert,
                  color: tokens.colors.text.highEmphasis,
                  size: 20,
                ),
                position: PopupMenuPosition.under,
                onSelected: (value) async {
                  switch (value) {
                    case 'link_existing':
                      await _showLinkTaskModal(context, ref);
                    case 'create_new':
                      await _createNewLinkedTask(context, ref);
                    case 'manage':
                      notifier.toggleManageMode();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'link_existing',
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(context.messages.linkExistingTask),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'create_new',
                    child: Row(
                      children: [
                        const Icon(Icons.add, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(context.messages.createNewLinkedTask),
                        ),
                      ],
                    ),
                  ),
                  if (hasLinkedTasks)
                    PopupMenuItem(
                      value: 'manage',
                      child: Row(
                        children: [
                          Icon(
                            manageMode
                                ? Icons.check_rounded
                                : Icons.edit_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              manageMode
                                  ? context.messages.doneButton
                                  : context.messages.manageLinks,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLinkTaskModal(BuildContext context, WidgetRef ref) async {
    final linkGroups = ref.read(taskLinkGroupsControllerProvider(taskId)).value;
    final existingLinkedIds = <String>{
      ...?linkGroups?.flat.map((e) => e.task.meta.id),
      ...?linkGroups?.typed.map((e) => e.task.meta.id),
    };

    await LinkTaskModal.show(
      context: context,
      currentTaskId: taskId,
      existingLinkedIds: existingLinkedIds,
    );
  }

  Future<void> _createNewLinkedTask(BuildContext context, WidgetRef ref) async {
    final selection = await _pickRelationshipType(context);
    if (selection == null || !context.mounted) return;

    final entryState = ref.read(entryControllerProvider(taskId)).value;
    final categoryId = entryState?.entry?.meta.categoryId;

    final newTask = await createTask(
      linkedId: taskId,
      categoryId: categoryId,
    );

    if (newTask != null && selection.type != EntryLinkType.basic) {
      // createTask always makes a BasicLink; swap it for the chosen
      // relationship rather than leaving a redundant plain link alongside it.
      await ref
          .read(journalRepositoryProvider)
          .removeTypedLink(
            fromId: taskId,
            toId: newTask.meta.id,
            linkType: 'BasicLink',
          );
      final swap = selection.inverse;
      await getIt<PersistenceLogic>().createLink(
        fromId: swap ? newTask.meta.id : taskId,
        toId: swap ? taskId : newTask.meta.id,
        linkType: selection.type,
      );
    }

    if (newTask != null && context.mounted) {
      unawaited(autoAssignCategoryAgent(ref, newTask));
      tasksBeamerDelegate.beamToNamed('/tasks/${newTask.meta.id}');
    }
  }
}

/// Relationship type + direction chosen for a newly-created linked task.
class _RelationshipSelection {
  const _RelationshipSelection({required this.type, required this.inverse});
  final EntryLinkType type;
  final bool inverse;
}

/// Prompts for the relationship the new task will have to the current one,
/// or null if cancelled. The new task always defaults to today's plain-link
/// direction (current task → new task); the inverse toggle swaps it.
Future<_RelationshipSelection?> _pickRelationshipType(
  BuildContext context,
) async {
  return showDialog<_RelationshipSelection>(
    context: context,
    builder: (context) => const _RelationshipPickerDialog(),
  );
}

class _RelationshipPickerDialog extends StatefulWidget {
  const _RelationshipPickerDialog();

  @override
  State<_RelationshipPickerDialog> createState() =>
      _RelationshipPickerDialogState();
}

class _RelationshipPickerDialogState extends State<_RelationshipPickerDialog> {
  EntryLinkType _selectedType = EntryLinkType.basic;
  bool _inverse = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.messages.createNewLinkedTask),
      content: RelationshipTypeSelector(
        selectedType: _selectedType,
        inverse: _inverse,
        onTypeChanged: (type) => setState(() {
          _selectedType = type;
          _inverse = false;
        }),
        onInverseChanged: (value) => setState(() => _inverse = value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.messages.cancelButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _RelationshipSelection(type: _selectedType, inverse: _inverse),
          ),
          child: Text(context.messages.createButton),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.colors.alert.info.defaultColor,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.onInteractiveAlert,
          height: 1,
        ),
      ),
    );
  }
}
