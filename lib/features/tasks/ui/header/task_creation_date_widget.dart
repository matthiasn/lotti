import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_multipage_modal.dart';
import 'package:lotti/themes/theme.dart';

/// Widget to display task creation date without time.
/// Uses a user-friendly format like "Dec 24, 2025".
class TaskCreationDateWidget extends ConsumerWidget {
  const TaskCreationDateWidget({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;

    if (entry == null || entry is! Task) {
      return const SizedBox.shrink();
    }

    final style = context.textTheme.titleSmall?.copyWith(
      color: context.colorScheme.outline,
      fontWeight: FontWeight.w600,
    );

    return GestureDetector(
      onTap: () =>
          EntryDateTimeMultiPageModal.show(entry: entry, context: context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: AppTheme.statusIndicatorIconSizeCompact,
            color: context.colorScheme.outline,
          ),
          const SizedBox(width: 6),
          Text(
            DateFormat.yMMMd().format(entry.meta.dateFrom),
            style: style,
          ),
        ],
      ),
    );
  }
}
