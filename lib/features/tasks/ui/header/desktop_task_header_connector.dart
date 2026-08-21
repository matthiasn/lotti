import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/tasks/state/task_blockers_controller.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_column.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_flyout.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_pickers.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/features/tasks/ui/widgets/task_ai_cost_indicator.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_back_leading.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/features/tasks/util/task_navigation.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Connects [DesktopTaskHeader] to the Riverpod task state: title saves, the
/// breadcrumb's category/project pickers ([TaskMetaPickers]), and the
/// metadata fly-out ([TaskMetaFlyout]) where every other attribute is edited
/// — unless a [TaskMetaColumn] already carries those rows beside the task, in
/// which case the header's Details affordance stands down.
///
/// The presentational widget stays framework-free; all repository /
/// `EntryController` interaction is concentrated here so widgetbook and tests
/// can target the inner `DesktopTaskHeader` directly.
class DesktopTaskHeaderConnector extends ConsumerWidget {
  const DesktopTaskHeaderConnector({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild when label definitions change (names, colours, visibility).
    ref.watch(labelsStreamProvider);

    final entryState = ref.watch(entryControllerProvider(taskId)).value;
    final task = entryState?.entry;
    if (task is! Task) {
      return const SizedBox.shrink();
    }

    final projectAsync = ref.watch(projectForTaskProvider(taskId));
    final project = projectAsync.asData?.value;
    // `.value` preserves the established tagline while a background refresh
    // reloads the provider, avoiding a one-line header reflow.
    final oneLiner = ref.watch(taskOneLinerProvider(taskId)).value;

    // With the details column mounted beside the task, its metadata is
    // already on screen: the header keeps its read-outs but stops offering a
    // fly-out over a panel showing the same eight rows.
    final hasMetaColumn = TaskMetaColumnScope.isVisible(context);

    final data = _buildData(context, task, project, oneLiner);
    final controller = ref.read(entryControllerProvider(taskId).notifier);
    final categoryId = task.meta.categoryId;

    return DesktopTaskHeader(
      key: ValueKey('task-header-$taskId'),
      data: data,
      // A task with no title yet opens straight into the title editor, cursor
      // in the field. Naming the task is the one thing every new task needs
      // and the one thing the page could not previously offer — the title was
      // a read-only label whose only affordance was a hover cursor. Keyed by
      // task id so the decision is re-made per task rather than inherited from
      // whichever task the header last rendered.
      initialEditing: data.title.trim().isEmpty,
      // The desktop split's list-pane toggle, above the breadcrumb and on the
      // same rail as its category dot. It used to sit next to the task list's
      // own title, where selecting a task made the control appear and shoved
      // that title sideways.
      leadingSlot: const TaskDetailHideListButton(),
      blockedBySlot: _TaskBlockedByChip(taskId: task.meta.id),
      // The cost rides in the summary lane with the other facts, so it is
      // readable at the same glance as the status rather than one panel away.
      // Read-only where the details column already shows the full breakdown;
      // otherwise a tap opens the fly-out that holds it.
      aiCostSlot: hasMetaColumn
          ? TaskAiCostIndicator.readOnly(taskId: task.meta.id)
          : TaskAiCostIndicator(taskId: task.meta.id),
      onTitleSaved: (newTitle) {
        controller.save(title: newTitle);
      },
      onOpenDetails: hasMetaColumn
          ? null
          : () => TaskMetaFlyout.show(context, taskId: taskId),
      // Projects are scoped to a category, so without one there is nothing to
      // pick from. The header drops the project crumb entirely in that state;
      // passing `null` keeps the two in agreement rather than leaving a
      // tappable-looking target that does nothing.
      onProjectTap: categoryId == null
          ? null
          : () => TaskMetaPickers.showProjectPicker(
              context,
              ref,
              taskId: taskId,
              categoryId: categoryId,
              current: project,
            ),
      onCategoryTap: () => TaskMetaPickers.showCategoryPicker(
        context,
        ref,
        task,
      ),
    );
  }

  DesktopTaskHeaderData _buildData(
    BuildContext context,
    Task task,
    ProjectEntry? project,
    String? oneLiner,
  ) {
    final cache = getIt<EntitiesCacheService>();
    final categoryId = task.meta.categoryId;
    final categoryDef = cache.getCategoryById(categoryId);
    final category = categoryDef == null
        ? null
        : DesktopTaskHeaderCategory(
            label: categoryDef.name,
            color: colorFromCssHex(
              categoryDef.color,
              substitute: Theme.of(context).colorScheme.primary,
            ),
          );

    final due = task.data.due;
    final dueDate = due == null
        ? null
        : DesktopTaskHeaderDueDate(
            label: context.messages.taskDueDateWithDate(
              DateFormat.yMMMd(
                Localizations.localeOf(context).toLanguageTag(),
              ).format(due),
            ),
            urgency: _dueUrgency(task.data),
          );

    final showPrivate = cache.showPrivateEntries;
    final labels = <LabelDefinition>[];
    for (final id in task.meta.labelIds ?? const <String>[]) {
      final def = cache.getLabelById(id);
      if (def == null) continue;
      if (!showPrivate && (def.private ?? false)) continue;
      labels.add(def);
    }
    labels.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return DesktopTaskHeaderData(
      title: task.data.title,
      priority: task.data.priority,
      status: task.data.status,
      project: project == null
          ? null
          : DesktopTaskHeaderProject(
              label: project.data.title,
            ),
      category: category,
      dueDate: dueDate,
      oneLiner: oneLiner,
      labels: labels,
    );
  }

  DesktopTaskHeaderDueUrgency _dueUrgency(TaskData data) {
    if (data.due == null) return DesktopTaskHeaderDueUrgency.normal;
    // Completed / rejected tasks are no longer "urgent" — they're done.
    if (data.status is TaskDone || data.status is TaskRejected) {
      return DesktopTaskHeaderDueUrgency.normal;
    }
    final status = getDueDateStatus(
      dueDate: data.due,
      referenceDate: clock.now(),
    );
    switch (status.urgency) {
      case DueDateUrgency.overdue:
        return DesktopTaskHeaderDueUrgency.overdue;
      case DueDateUrgency.dueToday:
        return DesktopTaskHeaderDueUrgency.today;
      case DueDateUrgency.normal:
        return DesktopTaskHeaderDueUrgency.normal;
    }
  }
}

/// "Blocked by" chip in the header's summary lane — a derived, read-time
/// fact (ADR 0042 §4) independent of the task's own [TaskStatus]: a task can
/// carry a live `blocks` link while its stored status is still `open`, and
/// that's exactly the state this chip must surface. Renders nothing when the
/// task isn't blocked.
class _TaskBlockedByChip extends ConsumerWidget {
  const _TaskBlockedByChip({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(taskBlockersControllerProvider(taskId)).value;
    if (result == null || !result.isBlocked) {
      return const SizedBox.shrink();
    }

    // warning, not error: the overdue due-date chip already owns error red —
    // a simultaneously-blocked-and-overdue task must not show two identical
    // alarms (design-review-panel round 1, color-contrast finding).
    final accent = TaskShowcasePalette.warning(context);
    final blockers = result.openBlockers;

    if (blockers.isEmpty) {
      // Blocked purely by a link whose blocker id didn't resolve to any
      // entity (conservative default, ADR 0042 §4) — nothing to name or
      // navigate to, so render a bare label with no tap affordance.
      return DsPill(
        variant: DsPillVariant.outline,
        shape: DsPillShape.tag,
        color: accent,
        labelColor: context.designTokens.colors.text.highEmphasis,
        leading: Icon(
          LottiIcons.block,
          size: context.designTokens.spacing.step4,
          color: accent,
        ),
        label: context.messages.taskBlockedByUnresolvedLabel,
      );
    }

    final single = blockers.length == 1;
    final tokens = context.designTokens;

    return Tooltip(
      message: context.messages.taskBlockedByChipTooltip(
        blockers.length,
        single ? blockers.first.data.title : '',
      ),
      child: DsPill(
        // Outline, not tinted: the status read-out is the summary's alarm,
        // and this chip explains it. Two filled alert-coloured shells side by
        // side stated one fact at two severities and competed for the same
        // glance.
        variant: DsPillVariant.outline,
        color: accent,
        // Amber marks the border and the glyph; the label itself reads as
        // ordinary text. An explanatory chip should not out-shout the status
        // read-out it explains.
        labelColor: tokens.colors.text.highEmphasis,
        leading: Icon(
          LottiIcons.block,
          size: tokens.spacing.step4,
          color: accent,
        ),
        // Count only, no blocker title. Embedding the title made the chip
        // grow with it — on a long title it spanned the header and out-shouted
        // the status read-out beside it. That the task is waiting is the
        // header's job; which task it waits on is one glance away in the
        // Linked Tasks card, and the tooltip still names it.
        label: context.messages.taskBlockedByChipLabel(blockers.length),
        // Matches LinkedTaskRow's own browse-mode chevron so a chip that
        // navigates reads as tappable, not just as a status readout. Neutral,
        // not amber: "go here" is not part of the blocked semantic, and a third
        // amber mark is what made the chip compete with the status pill.
        trailing: Icon(
          LottiIcons.chevronRight,
          size: tokens.spacing.step4,
          color: tokens.colors.text.lowEmphasis,
        ),
        onTap: () => single
            ? openLinkedTaskDetail(context: context, taskId: blockers.first.id)
            : _showBlockersSheet(context, blockers),
      ),
    );
  }

  Future<void> _showBlockersSheet(
    BuildContext context,
    List<Task> blockers,
  ) async {
    // Picked here, navigated to after the sheet closes: opening a task from
    // inside the sheet would route behind its own barrier, leaving the user
    // looking at an unchanged sheet over a page that had already moved on.
    String? picked;
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.linkedTasksBlockedBySectionTitle,
      // LinkedTaskRow brings its own step5 horizontal padding, same as every
      // sibling picker in this feature — without this the rows get inset twice.
      padding: EdgeInsets.zero,
      builder: (modalContext) => ListView(
        shrinkWrap: true,
        children: [
          for (final blocker in blockers)
            LinkedTaskRow(
              data: LinkedTaskRowData(task: blocker),
              manageMode: false,
              onOpen: () {
                picked = blocker.id;
                Navigator.of(modalContext).pop();
              },
            ),
        ],
      ),
    );

    if (picked != null && context.mounted) {
      openLinkedTaskDetail(context: context, taskId: picked!);
    }
  }
}
