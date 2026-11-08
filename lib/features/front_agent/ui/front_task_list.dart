import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
import 'package:material_ui/material_ui.dart';

/// Stable keys for her lists of tasks.
@visibleForTesting
abstract final class FrontTaskListKeys {
  static const Key card = Key('front-task-list');
  static Key row(String id) => Key('front-task-row-$id');
}

/// The tasks — and projects — she names in a list, as one card of rows
/// rather than a run of links. [onOpen] is given the mention to open.
class FrontTaskList extends StatelessWidget {
  const FrontTaskList({required this.tasks, required this.onOpen, super.key});

  final List<FrontTaskMention> tasks;
  final ValueChanged<FrontTaskMention> onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      key: FrontTaskListKeys.card,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tasks.length; i++) ...[
            if (i > 0) const DesignSystemDivider(),
            if (tasks[i].kind == FrontDestinationKind.project)
              _FrontProjectRow(
                key: FrontTaskListKeys.row(tasks[i].id),
                mention: tasks[i],
                onOpen: () => onOpen(tasks[i]),
              )
            else
              FrontTaskRow(
                key: FrontTaskListKeys.row(tasks[i].id),
                mention: tasks[i],
                onOpen: () => onOpen(tasks[i]),
              ),
          ],
        ],
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
        // Its priority and when it is due, only while it is still to do.
        if (!settled) ...[
          const TextSpan(text: '   '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: TaskShowcasePriorityGlyph(
              priority: task.data.priority,
              size: IconSizes.xs,
            ),
          ),
          TextSpan(text: ' ${task.data.priority.short}'),
        ],
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
      trailingExtra: chevron,
    );
  }

  /// The name of [task]'s category, when it has one the app knows.
  static String? _categoryName(WidgetRef ref, Task task) {
    final id = task.meta.categoryId;
    if (id == null) return null;
    return ref.watch(entitiesCacheServiceProvider)?.getCategoryById(id)?.name;
  }
}
