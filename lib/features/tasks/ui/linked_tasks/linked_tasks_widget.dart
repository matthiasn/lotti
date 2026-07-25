import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/state/linked_tasks_controller.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/edit_link_type_modal.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_created_feedback.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_task_modal.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_relationship_sections.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';

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
    final groupsAsync = ref.watch(taskLinkGroupsControllerProvider(taskId));
    final linkGroups = groupsAsync.value ?? TaskLinkGroups.empty;

    // Two DB round trips resolve before this provider has a value, and until
    // it does an unloaded task is indistinguishable from a task with no
    // links. Treating "no value yet" as "no links" showed a definitive "you
    // have no links" CTA on the first open of every task that has some.
    final resolved = groupsAsync.hasValue || groupsAsync.hasError;
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
              // Only once the answer is actually known. While it is loading
              // the header alone stands in — no empty CTA, no spinner
              // flashing in and out for two fast local queries.
              if (!hasLinks && resolved)
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
                  const DesignSystemDivider(),
                // Headed only when there is something to be "other" than —
                // and headed with the picker's own word for a plain link, so
                // the card reads back the phrase the user picked.
                if (flatRows.isNotEmpty && linkGroups.typed.isNotEmpty)
                  LinkedTaskSectionHeader(
                    title: context.messages.linkPhraseBasic,
                  ),
                for (var i = 0; i < flatRows.length; i++) ...[
                  if (i > 0) const DesignSystemDivider(),
                  LinkedTaskRow(
                    taskId: taskId,
                    data: flatRows[i],
                    manageMode: uiState.manageMode,
                    onEdit: () => EditLinkTypeModal.show(
                      context: context,
                      linkId: linkGroups.flat[i].linkId,
                      currentType: EntryLinkType.basic,
                      currentDirection: linkGroups.flat[i].direction,
                      linkedTaskTitle: linkGroups.flat[i].task.data.title,
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
      // Three lines, and quieter than the action it explains: at two lines
      // the longer locales ellipsized away the examples that teach what
      // "link" means here, and at medium ink the explanation tied with the
      // action on the one screen shown before the feature has done anything.
      subtitleMaxLines: 3,
      subtitleEmphasis: tokens.colors.text.lowEmphasis,
      size: DesignSystemListItemSize.small,
      leading: Icon(
        Icons.add_link,
        size: tokens.spacing.step5,
        // The interactive accent the populated card's Link button carries.
        // Emphasis should be highest where the user has nothing yet, and one
        // glyph meaning one thing must not change colour with the card state.
        color: tokens.colors.interactive.enabled,
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: tokens.spacing.step4,
        color: tokens.colors.text.lowEmphasis,
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
            // Leads the title it discloses. Trailing the Link button, it read
            // as that button's dropdown caret, so a tap aimed at a relation
            // menu collapsed the card instead — and it vanished in manage
            // mode while the collapse gesture stayed live.
            if (hasLinkedTasks) ...[
              Icon(
                expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                size: tokens.spacing.step5,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step2),
            ],
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
              DesignSystemButton(
                label: context.messages.doneButton,
                variant: DesignSystemButtonVariant.tertiary,
                onPressed: notifier.toggleManageMode,
              ),
            // Worded, in the same slot manage mode's Done occupies. As an
            // icon alone it was the card's only creative action and its least
            // legible control, and a bare glyph gives a screen-magnifier or
            // low-vision user nothing to read.
            if (hasLinkedTasks && !manageMode) ...[
              DesignSystemButton(
                label: context.messages.linkTaskButton,
                variant: DesignSystemButtonVariant.tertiary,
                leadingIcon: Icons.add_link,
                onPressed: () => _showLinkTaskModal(context, ref, taskId),
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
                  // The overflow is the least important control in the header;
                  // it was also the heaviest mark in it.
                  color: tokens.colors.text.mediumEmphasis,
                  size: tokens.spacing.step5,
                ),
                position: PopupMenuPosition.under,
                onSelected: (value) async {
                  switch (value) {
                    case 'link_existing':
                      await _showLinkTaskModal(context, ref, taskId);
                    case 'create_new':
                      await _createNewLinkedTask(context, ref, taskId);
                    case 'manage':
                      notifier.toggleManageMode();
                  }
                },
                itemBuilder: (context) => [
                  // Manage mode replaces the header's Link button with Done,
                  // which left no way to add a link while curating them —
                  // the one state where the user is most likely to want one.
                  if (manageMode)
                    PopupMenuItem(
                      value: 'link_existing',
                      child: Row(
                        children: [
                          Icon(Icons.add_link, size: tokens.spacing.step5),
                          SizedBox(width: tokens.spacing.step3),
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
                        Icon(Icons.add, size: tokens.spacing.step5),
                        SizedBox(width: tokens.spacing.step3),
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
      // Only a blocking link can fail the cycle guard, so anything else has
      // to say so plainly rather than blame a cycle that cannot exist.
      showLinkFailureMessage(
        tokens: context.designTokens,
        messenger: ScaffoldMessenger.of(context),
        message: selection.type == EntryLinkType.blocks
            ? context.messages.linkBlocksCycleErrorMessage
            : context.messages.linkCreateFailedMessage,
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
///
/// On the shared modal, not showDialog: this was the last surface in the
/// feature rendering raw Material defaults inside an otherwise tokenised flow,
/// and it sits between two modals that already use it.
Future<DirectedRelation?> _pickRelationshipType(BuildContext context) async {
  final relation = ValueNotifier<DirectedRelation>(
    const DirectedRelation(EntryLinkType.basic),
  );
  try {
    return await ModalUtils.showSinglePageModal<DirectedRelation>(
      context: context,
      title: context.messages.createNewLinkedTaskTitle,
      padding: EdgeInsets.zero,
      stickyActionBarBuilder: (BuildContext modalContext) =>
          buildPickerApplyFooter(
            context: modalContext,
            label: modalContext.messages.createButton,
            onTap: () => Navigator.of(modalContext).pop(relation.value),
          ),
      builder: (_) => _RelationshipPickerBody(relation: relation),
    );
  } finally {
    relation.dispose();
  }
}

class _RelationshipPickerBody extends StatelessWidget {
  const _RelationshipPickerBody({required this.relation});

  final ValueNotifier<DirectedRelation> relation;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // The Create footer is a sticky overlay rather than a sibling, so its
    // height has to be reserved or the selector renders underneath it.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step5,
        DesignSystemGlassActionFooter.reservedHeightFor(context),
      ),
      child: ValueListenableBuilder<DirectedRelation>(
        valueListenable: relation,
        builder: (context, value, _) => RelationshipTypeSelector(
          selected: value,
          onChanged: (next) => relation.value = next,
        ),
      ),
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
