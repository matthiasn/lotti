import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/state/linked_from_entries_controller.dart';
import 'package:lotti/features/tasks/state/linked_tasks_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_task_modal.dart';
import 'package:lotti/features/tasks/util/task_navigation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/themes/theme.dart';

enum _LinkDirection { to, from }

class _LinkedTaskRowData {
  const _LinkedTaskRowData(this.task, this.direction);
  final Task task;
  final _LinkDirection direction;
}

/// Linked tasks card on the task detail view.
///
/// Renders a single section card with a header (title, count badge, expand
/// chevron, overflow menu) and a list of incoming ("from") and outgoing ("to")
/// task links separated by dividers. Hidden entirely when no links exist.
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
    final uiState = ref.watch(linkedTasksControllerProvider(taskId: taskId));

    final outgoingTasks = ref
        .watch(outgoingLinkedTasksProvider(taskId))
        .whereType<Task>()
        .toList();

    final incomingEntities =
        ref.watch(linkedFromEntriesControllerProvider(id: taskId)).value ?? [];
    final incomingTasks = incomingEntities.whereType<Task>().toList();

    if (incomingTasks.isEmpty && outgoingTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = <_LinkedTaskRowData>[
      ...outgoingTasks.map((t) => _LinkedTaskRowData(t, _LinkDirection.to)),
      ...incomingTasks.map((t) => _LinkedTaskRowData(t, _LinkDirection.from)),
    ];

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
                count: rows.length,
                expanded: _expanded,
                hasLinkedTasks: rows.isNotEmpty,
                manageMode: uiState.manageMode,
                onToggleExpanded: () => setState(() => _expanded = !_expanded),
              ),
              if (_expanded)
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: tokens.colors.decorative.level01,
                    ),
                  _LinkedTaskRow(
                    taskId: taskId,
                    data: rows[i],
                    manageMode: uiState.manageMode,
                  ),
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
      linkedTasksControllerProvider(taskId: taskId).notifier,
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
              expanded ? Icons.expand_less : Icons.expand_more,
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
    final outgoingLinks =
        ref.read(linkedEntriesControllerProvider(id: taskId)).value ?? [];
    final incomingEntities =
        ref.read(linkedFromEntriesControllerProvider(id: taskId)).value ?? [];

    final existingLinkedIds = <String>{
      ...outgoingLinks.map((link) => link.toId),
      ...incomingEntities.whereType<Task>().map((task) => task.meta.id),
    };

    await LinkTaskModal.show(
      context: context,
      currentTaskId: taskId,
      existingLinkedIds: existingLinkedIds,
    );
  }

  Future<void> _createNewLinkedTask(BuildContext context, WidgetRef ref) async {
    final entryState = ref.read(entryControllerProvider(id: taskId)).value;
    final categoryId = entryState?.entry?.meta.categoryId;

    final newTask = await createTask(
      linkedId: taskId,
      categoryId: categoryId,
    );

    if (newTask != null && context.mounted) {
      unawaited(autoAssignCategoryAgent(ref, newTask));
      tasksBeamerDelegate.beamToNamed('/tasks/${newTask.meta.id}');
    }
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

class _LinkedTaskRow extends ConsumerWidget {
  const _LinkedTaskRow({
    required this.taskId,
    required this.data,
    required this.manageMode,
  });

  final String taskId;
  final _LinkedTaskRowData data;
  final bool manageMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final task = data.task;
    final isOutgoing = data.direction == _LinkDirection.to;
    final directionColor = isOutgoing
        ? tokens.colors.alert.info.defaultColor
        : tokens.colors.alert.success.defaultColor;
    final glyph = isOutgoing
        ? 'assets/icons/subdirectory_arrow_right.svg'
        : 'assets/icons/subdirectory_arrow_left.svg';
    final caption = isOutgoing
        ? context.messages.linkedToCaption
        : context.messages.linkedFromCaption;
    final isCompleted =
        task.data.status is TaskDone || task.data.status is TaskRejected;

    return InkWell(
      onTap: manageMode
          ? null
          : () => openLinkedTaskDetail(context: context, taskId: task.id),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step3,
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              glyph,
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(directionColor, BlendMode.srcIn),
            ),
            SizedBox(width: tokens.spacing.step2),
            Text(
              caption,
              style: tokens.typography.styles.others.caption.copyWith(
                color: directionColor,
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            _StatusGlyph(isCompleted: isCompleted),
            SizedBox(width: tokens.spacing.step2),
            Expanded(
              child: Text(
                task.data.title,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            if (manageMode)
              IconButton(
                tooltip: context.messages.unlinkButton,
                onPressed: () => _confirmUnlink(context, ref),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: tokens.colors.text.lowEmphasis,
                ),
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: tokens.colors.text.lowEmphasis,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmUnlink(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.messages.unlinkTaskTitle),
        content: Text(ctx.messages.unlinkTaskConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.messages.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.messages.unlinkButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    if (data.direction == _LinkDirection.to) {
      await ref
          .read(linkedEntriesControllerProvider(id: taskId).notifier)
          .removeLink(toId: data.task.id);
    } else {
      await ref
          .read(journalRepositoryProvider)
          .removeLink(fromId: data.task.id, toId: taskId);
    }
  }
}

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = isCompleted
        ? tokens.colors.alert.success.defaultColor
        : tokens.colors.alert.info.defaultColor;
    return Icon(
      isCompleted ? Icons.check_circle : Icons.circle_outlined,
      size: 16,
      color: color,
    );
  }
}
