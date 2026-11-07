import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_reply_parts.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/features/tasks/ui/due_date_text.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart'
    show StatusGlyph;
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for her lists of tasks.
@visibleForTesting
abstract final class FrontTaskListKeys {
  static const Key card = Key('front-task-list');
  static Key row(String taskId) => Key('front-task-row-$taskId');
}

/// The tasks she names in a list, as one card of task rows rather than a
/// run of links: each with its status, its category, when it is due, and a
/// tap that opens it ([onOpen], given the task's id).
class FrontTaskList extends StatelessWidget {
  const FrontTaskList({required this.tasks, required this.onOpen, super.key});

  final List<FrontTaskMention> tasks;
  final ValueChanged<String> onOpen;

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
            FrontTaskRow(
              key: FrontTaskListKeys.row(tasks[i].id),
              mention: tasks[i],
              onOpen: () => onOpen(tasks[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

/// One task of her list: the task as it is now — its status glyph, title,
/// status and category, and its due date in the tasks list's own colours —
/// kept current as it changes. Until it has loaded, or if it is gone, the
/// title she gave it stands alone, and still opens it.
class FrontTaskRow extends ConsumerWidget {
  const FrontTaskRow({required this.mention, required this.onOpen, super.key});

  final FrontTaskMention mention;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    // `.value`: a reload keeps the row as it was until the new one lands.
    final task = ref.watch(taskLiveDataProvider(mention.id)).value;
    final chevron = Icon(
      LottiIcons.chevronRight,
      size: IconSizes.s,
      color: tokens.colors.text.lowEmphasis,
    );
    if (task == null) {
      return DesignSystemListItem(
        title: mention.title,
        titleMaxLines: 2,
        size: DesignSystemListItemSize.small,
        onTap: onOpen,
        trailingExtra: chevron,
      );
    }
    final status = task.data.status;
    final statusLabel = taskLabelFromStatusString(status.toDbString, context);
    final category = _categoryName(task);
    final due = task.data.due;
    final settled = status is TaskDone || status is TaskRejected;
    return DesignSystemListItem(
      title: task.data.title,
      titleMaxLines: 2,
      size: DesignSystemListItemSize.small,
      onTap: onOpen,
      semanticsLabel: [task.data.title, statusLabel, ?category].join(', '),
      leading: StatusGlyph(status: status, tooltip: statusLabel),
      // Status and category, then when it is due — on the line under the
      // title, so the title keeps the row's width on a phone.
      subtitleSpans: [
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
      subtitleMaxLines: 2,
      subtitleEmphasis: tokens.colors.text.lowEmphasis,
      trailingExtra: chevron,
    );
  }

  /// The name of [task]'s category, when it has one the app knows.
  static String? _categoryName(Task task) {
    final id = task.meta.categoryId;
    if (id == null) return null;
    return getIt<EntitiesCacheService>().getCategoryById(id)?.name;
  }
}
