import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/state/linked_tasks_controller.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/edit_link_type_modal.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_task_modal.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_relationship_sections.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/logic/persistence_logic.dart';

/// Linked tasks card on the task detail view.
///
/// Renders a section card with a header (title, count badge, link action,
/// expand chevron, overflow menu), the typed-relationship sections
/// ([TaskRelationshipSections], one per relationship direction that has
/// entries), and the flat plain-link list. The header always renders — even
/// with no links at all — so the link action stays reachable.
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

    final hasLinks = linkGroups.totalCount > 0;

    final flatRows = linkGroups.flat
        .map((entry) => LinkedTaskRowData(task: entry.task))
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
                hasLinkedTasks: hasLinks,
                manageMode: uiState.manageMode,
                onToggleExpanded: hasLinks
                    ? () => setState(() => _expanded = !_expanded)
                    : null,
              ),
              if (!hasLinks)
                _LinkedTasksEmptyAction(
                  onTap: () => _showLinkTaskModal(context, ref, taskId),
                ),
              if (_expanded && hasLinks) ...[
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
                // Headed only when there is something to be "other" than —
                // and headed with the picker's own word for a plain link, so
                // the card reads back the phrase the user picked.
                if (flatRows.isNotEmpty && linkGroups.typed.isNotEmpty)
                  LinkedTaskSectionHeader(
                    title: context.messages.linkPhraseBasic,
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
                    onEdit: () => EditLinkTypeModal.show(
                      context: context,
                      linkId: linkGroups.flat[i].linkId,
                      currentType: EntryLinkType.basic,
                      currentDirection: linkGroups.flat[i].direction,
                    ),
                    onUnlink: () {
                      final entry = linkGroups.flat[i];
                      final isOutgoing =
                          entry.direction == TaskLinkDirection.outgoing;
                      return ref
                          .read(journalRepositoryProvider)
                          .removeTypedLink(
                            fromId: isOutgoing ? taskId : entry.task.meta.id,
                            toId: isOutgoing ? entry.task.meta.id : taskId,
                            linkType: 'BasicLink',
                          );
                    },
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

/// The card's body when the task holds no links: a worded, full-width action
/// with a one-line explanation. An icon-only affordance in an otherwise empty
/// bordered box read as a card that had failed to load.
class _LinkedTasksEmptyAction extends StatelessWidget {
  const _LinkedTasksEmptyAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemListItem(
      onTap: onTap,
      title: context.messages.linkedTasksEmptyAction,
      subtitle: context.messages.linkedTasksEmptyHint,
      subtitleMaxLines: 2,
      size: DesignSystemListItemSize.small,
      leading: Icon(
        Icons.add_link,
        size: tokens.spacing.step5,
        color: tokens.colors.interactive.enabled,
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

  /// Null when there is nothing to expand — the card still renders its header
  /// so the link action stays reachable on a task with no links yet.
  final VoidCallback? onToggleExpanded;

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
            if (hasLinkedTasks) ...[
              SizedBox(width: tokens.spacing.step3),
              _CountBadge(count: count),
            ],
            const Spacer(),
            // Manage mode is otherwise invisible except for two icons
            // appearing per row, and the only way out used to be the same
            // unlabelled overflow menu it was entered from. While it is on,
            // the header says so and offers the exit inline.
            if (manageMode)
              TextButton(
                onPressed: notifier.toggleManageMode,
                child: Text(context.messages.doneButton),
              ),
            // The link action is worded in the empty state's own row, so the
            // header only carries it once there is a list to add to.
            if (hasLinkedTasks && !manageMode) ...[
              IconButton(
                tooltip: context.messages.linkExistingTask,
                onPressed: () => _showLinkTaskModal(context, ref, taskId),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.add_link,
                  size: tokens.spacing.step5,
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
              Icon(
                expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                // Least important control, so not the heaviest mark.
                size: tokens.spacing.step5,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ],
            SizedBox(width: tokens.spacing.step3),
            Theme(
              data: Theme.of(context).copyWith(
                // Tokens rather than Material scheme colours and raw radii,
                // so the menu belongs to the same surface family as the card
                // it opens from instead of being a themed island inside it.
                popupMenuTheme: PopupMenuThemeData(
                  color: tokens.colors.background.level03,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radii.m),
                    side: BorderSide(color: tokens.colors.decorative.level01),
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
                    case 'create_new':
                      await _createNewLinkedTask(context, ref, taskId);
                    case 'manage':
                      notifier.toggleManageMode();
                  }
                },
                itemBuilder: (context) => [
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
                  // Only offered as a way *in*: manage mode now carries its
                  // own inline exit in the header, so a second "Done" here
                  // would be two controls for one state.
                  if (hasLinkedTasks && !manageMode)
                    PopupMenuItem(
                      value: 'manage',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: tokens.spacing.step5),
                          SizedBox(width: tokens.spacing.step3),
                          Flexible(child: Text(context.messages.manageLinks)),
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
}

/// Opens the link picker for [taskId], seeding it with the relationships that
/// task already holds so the candidate list can exclude only true duplicates.
Future<void> _showLinkTaskModal(
  BuildContext context,
  WidgetRef ref,
  String taskId,
) async {
  final linkGroups = ref.read(taskLinkGroupsControllerProvider(taskId)).value;
  final existingRelations = {
    for (final entry in [
      ...?linkGroups?.flat,
      ...?linkGroups?.typed,
    ])
      ExistingRelation(
        taskId: entry.task.meta.id,
        relation: DirectedRelation(
          entryLinkTypeForTaskLinkKind(entry.kind),
          inverse: entry.direction == TaskLinkDirection.incoming,
        ),
      ),
  };

  await LinkTaskModal.show(
    context: context,
    currentTaskId: taskId,
    existingRelations: existingRelations,
  );
}

Future<void> _createNewLinkedTask(
  BuildContext context,
  WidgetRef ref,
  String taskId,
) async {
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
    //
    // Create first, then remove — and only if the create succeeded.
    // createLink returns false when the cycle guard rejects the edge, so
    // removing first would leave the freshly created task with no link back
    // to its parent at all.
    final swap = selection.inverse;
    final created = await getIt<PersistenceLogic>().createLink(
      fromId: swap ? newTask.meta.id : taskId,
      toId: swap ? taskId : newTask.meta.id,
      linkType: selection.type,
    );
    if (created) {
      await ref
          .read(journalRepositoryProvider)
          .removeTypedLink(
            fromId: taskId,
            toId: newTask.meta.id,
            linkType: 'BasicLink',
          );
    } else if (context.mounted) {
      // The plain link createTask made is still there, so the new task is
      // reachable; say why it didn't get the relationship that was asked for.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.messages.linkBlocksCycleErrorMessage)),
      );
    }
  }

  if (newTask != null && context.mounted) {
    unawaited(autoAssignCategoryAgent(ref, newTask));
    tasksBeamerDelegate.beamToNamed('/tasks/${newTask.meta.id}');
  }
}

/// Prompts for the relationship the new task will have to the current one,
/// or null if cancelled. Defaults to today's plain-link direction (current
/// task → new task); picking an inverse phrase swaps it.
Future<DirectedRelation?> _pickRelationshipType(BuildContext context) async {
  return showDialog<DirectedRelation>(
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
  DirectedRelation _relation = const DirectedRelation(EntryLinkType.basic);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.messages.createNewLinkedTask),
      content: RelationshipTypeSelector(
        selected: _relation,
        onChanged: (relation) => setState(() => _relation = relation),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.messages.cancelButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_relation),
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
    // Neutral, not alert.info: blue is already the In-Progress status colour
    // on this same card, and a count is not a status. Keeping it quiet also
    // stops the badge out-shouting the section headers below it.
    return Container(
      width: tokens.spacing.step6,
      height: tokens.spacing.step6,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.colors.background.level03,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.mediumEmphasis,
          height: 1,
        ),
      ),
    );
  }
}
