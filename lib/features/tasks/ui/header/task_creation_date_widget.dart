import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_multipage_modal.dart';
import 'package:lotti/widgets/cards/subtle_action_chip.dart';

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

    if (entry is! Task) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () =>
          EntryDateTimeMultiPageModal.show(entry: entry, context: context),
      child: SubtleActionChip(
        label: DateFormat.yMMMd().format(entry.meta.dateFrom),
        icon: Icons.calendar_today_rounded,
      ),
    );
  }
}
