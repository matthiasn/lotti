import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_reply_parts.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/features/tasks/ui/due_date_text.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart'
    show StatusGlyph;
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_chips.dart'
    show TaskShowcasePriorityGlyph;
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/color.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for her lists of tasks.
@visibleForTesting
abstract final class FrontTaskListKeys {
  static const Key card = Key('front-task-list');
  static Key row(String id) => Key('front-task-row-$id');
  static const Key closedCard = Key('front-closed-task-list');
  static Key closedRow(String id) => Key('front-closed-task-row-$id');
}

/// The tasks — and projects — she names in a list, as one card of rows
/// rather than a run of links. [onOpen] is given the mention to open.
class FrontTaskList extends StatelessWidget {
  const FrontTaskList({required this.tasks, required this.onOpen, super.key});

  final List<FrontTaskMention> tasks;
  final ValueChanged<FrontTaskMention> onOpen;

  @override
  Widget build(BuildContext context) => _FrontRowsCard(
    key: FrontTaskListKeys.card,
    rows: [
      for (final task in tasks)
        if (task.kind == FrontDestinationKind.project)
          _FrontProjectRow(
            key: FrontTaskListKeys.row(task.id),
            mention: task,
            onOpen: () => onOpen(task),
          )
        else
          FrontTaskRow(
            key: FrontTaskListKeys.row(task.id),
            mention: task,
            onOpen: () => onOpen(task),
          ),
    ],
  );
}

/// The tasks a `list_closed_tasks` found, as one card of rows under her
/// words: every one of them, each saying how it closed. [onOpen] is given
/// the id of the task to open.
class FrontClosedTaskList extends StatelessWidget {
  const FrontClosedTaskList({
    required this.tasks,
    required this.onOpen,
    super.key,
  });

  final List<FrontClosedTaskCard> tasks;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => _FrontRowsCard(
    key: FrontTaskListKeys.closedCard,
    rows: [
      for (final task in tasks)
        FrontClosedTaskRow(
          key: FrontTaskListKeys.closedRow(task.id),
          task: task,
          onOpen: () => onOpen(task.id),
        ),
    ],
  );
}

/// [rows] on one rounded card, a divider between each two.
class _FrontRowsCard extends StatelessWidget {
  const _FrontRowsCard({required this.rows, super.key});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const DesignSystemDivider(),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// One task of a closed-task answer: how it closed — the Done or Rejected
/// glyph and label — and the day, then its category's colour and name. A
/// task reopened since shows what it is now after an arrow. A tap opens it.
class FrontClosedTaskRow extends ConsumerWidget {
  const FrontClosedTaskRow({
    required this.task,
    required this.onOpen,
    super.key,
  });

  final FrontClosedTaskCard task;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final closedStatus = task.rejected
        ? TaskStatus.rejected(
            id: task.id,
            createdAt: task.closedAt,
            utcOffset: 0,
          )
        : TaskStatus.done(id: task.id, createdAt: task.closedAt, utcOffset: 0);
    final closedLabel = taskLabelFromStatusString(
      closedStatus.toDbString,
      context,
    );
    // Only a reopened task needs its status now; the rest closed as shown.
    final now = task.reopened
        ? ref.watch(taskPreviewProvider(task.id)).value?.task.data.status
        : null;
    final how = now == null
        ? closedLabel
        : '$closedLabel → ${taskLabelFromStatusString(now.toDbString, context)}';
    final day = DateFormat.MMMEd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(task.closedAt.toLocal());
    final category = ref
        .watch(entitiesCacheServiceProvider)
        ?.getCategoryById(task.categoryId);
    return DesignSystemListItem(
      title: task.title,
      titleMaxLines: 2,
      size: DesignSystemListItemSize.small,
      onTap: onOpen,
      semanticsLabel: [task.title, how, day, ?category?.name].join(', '),
      leading: StatusGlyph(status: closedStatus, tooltip: closedLabel),
      subtitleSpans: [
        TextSpan(text: '$how · $day'),
        if (category != null) ...[
          const TextSpan(text: '   '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ColorIcon(
              colorFromCssHex(category.color),
              size: IconSizes.xs,
            ),
          ),
          TextSpan(text: ' ${category.name}'),
        ],
      ],
      subtitleEmphasis: tokens.colors.text.lowEmphasis,
      trailingExtra: Icon(
        LottiIcons.chevronRight,
        size: IconSizes.s,
        color: tokens.colors.text.lowEmphasis,
      ),
    );
  }
}

/// A project of her list: the title she gave it, opening its page.
class _FrontProjectRow extends StatelessWidget {
  const _FrontProjectRow({
    required this.mention,
    required this.onOpen,
    super.key,
  });

  final FrontTaskMention mention;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemListItem(
      title: mention.title,
      titleMaxLines: 2,
      size: DesignSystemListItemSize.small,
      onTap: onOpen,
      leading: Icon(
        LottiIcons.folder,
        size: IconSizes.s,
        color: tokens.colors.text.mediumEmphasis,
      ),
      trailingExtra: Icon(
        LottiIcons.chevronRight,
        size: IconSizes.s,
        color: tokens.colors.text.lowEmphasis,
      ),
    );
  }
}

/// One task of her list, as it is now: its status glyph, title, its agent's
/// one-liner, its status and category, and its due date in the tasks list's
/// own colours — kept current as it changes. A tap opens it ([onOpen]),
/// where its TL;DR is. Until it has loaded, or if it is gone, the title she
/// gave it stands alone, and still opens it.
class FrontTaskRow extends ConsumerWidget {
  const FrontTaskRow({required this.mention, required this.onOpen, super.key});

  final FrontTaskMention mention;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final chevron = Icon(
      LottiIcons.chevronRight,
      size: IconSizes.s,
      color: tokens.colors.text.lowEmphasis,
    );
    // `.value`: a reload keeps the row as it was until the new one lands.
    final preview = ref.watch(taskPreviewProvider(mention.id)).value;
    if (preview == null) {
      return DesignSystemListItem(
        title: mention.title,
        titleMaxLines: 2,
        size: DesignSystemListItemSize.small,
        onTap: onOpen,
        trailingExtra: chevron,
      );
    }
    final task = preview.task;
    final status = task.data.status;
    final statusLabel = taskLabelFromStatusString(status.toDbString, context);
    final category = _categoryName(ref, task);
    final due = task.data.due;
    final settled = status is TaskDone || status is TaskRejected;
    final oneLiner = preview.oneLiner;
    return DesignSystemListItem(
      title: task.data.title,
      titleMaxLines: 2,
      size: DesignSystemListItemSize.small,
      onTap: onOpen,
      semanticsLabel: [
        task.data.title,
        ?oneLiner,
        statusLabel,
        ?category,
        if (!settled) task.data.priority.short,
      ].join(', '),
      leading: StatusGlyph(status: status, tooltip: statusLabel),
      // The one-liner, then status and category and when it is due —
      // under the title, so the title keeps the row's width on a phone.
      subtitleSpans: [
        // In the AI ink the tasks list gives a one-liner.
        if (oneLiner != null)
          TextSpan(
            text: '$oneLiner\n',
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.aiCard.accent,
            ),
          ),
        TextSpan(
          text: category == null ? statusLabel : '$statusLabel · $category',
        ),
        // When it is due, only while it is still to do.
        if (due != null && !settled) ...[
          const TextSpan(text: '   '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: DueDateText(dueDate: due),
          ),
        ],
      ],
      subtitleMaxLines: oneLiner == null ? 2 : 3,
      subtitleEmphasis: tokens.colors.text.lowEmphasis,
      // Its priority, only while it is still to do, beside the chevron: out
      // of the subtitle, so however long the one-liner, truncation never
      // takes it.
      trailingExtra: settled
          ? chevron
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TaskShowcasePriorityGlyph(
                  priority: task.data.priority,
                  size: IconSizes.xs,
                ),
                SizedBox(width: tokens.spacing.step1),
                Text(
                  task.data.priority.short,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
                SizedBox(width: tokens.spacing.step2),
                chevron,
              ],
            ),
    );
  }

  /// The name of [task]'s category, when it has one the app knows.
  static String? _categoryName(WidgetRef ref, Task task) {
    final id = task.meta.categoryId;
    if (id == null) return null;
    return ref.watch(entitiesCacheServiceProvider)?.getCategoryById(id)?.name;
  }
}
