import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/switch_icon_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/save_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';

class TaskDateRow extends ConsumerWidget {
  const TaskDateRow({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;
    final task = entryState?.entry;

    if (task == null || task is! Task) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            EntryDatetimeWidget(
              entryId: taskId,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 10),
            if (task.meta.starred ?? false)
              SwitchIconWidget(
                tooltip: context.messages.journalFavoriteTooltip,
                onPressed: notifier.toggleStarred,
                value: task.meta.starred ?? false,
                icon: Icons.star_outline_rounded,
                activeIcon: Icons.star_rounded,
                activeColor: starredGold,
              ),
            if (task.meta.flag == EntryFlag.import)
              SwitchIconWidget(
                tooltip: context.messages.journalFlaggedTooltip,
                onPressed: notifier.toggleFlagged,
                value: task.meta.flag == EntryFlag.import,
                icon: Icons.flag_outlined,
                activeIcon: Icons.flag,
                activeColor: context.colorScheme.error,
              ),
            const Spacer(),
            SaveButton(entryId: taskId),
          ],
        ),
      ],
    );
  }
}
