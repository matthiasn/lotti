import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart'
    show StatusGlyph;
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/color.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for her list of closed tasks.
@visibleForTesting
abstract final class FrontTaskListKeys {
  static const Key closedCard = Key('front-closed-task-list');
  static Key closedRow(String id) => Key('front-closed-task-row-$id');
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
