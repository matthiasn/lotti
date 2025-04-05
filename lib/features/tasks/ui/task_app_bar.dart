import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/journal_card_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/save_button.dart';
import 'package:lotti/features/tasks/ui/linked_duration.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

class TaskSliverAppBar extends ConsumerWidget {
  const TaskSliverAppBar({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = journalCardControllerProvider(id: taskId);
    final item = ref.watch(provider).value;

    if (item == null || item is! Task) {
      return SliverAppBar(
        leadingWidth: 100,
        leading: const BackWidget(),
        pinned: true,
        actions: [
          SaveButton(entryId: item?.meta.id ?? ''),
        ],
        automaticallyImplyLeading: false,
      );
    }

    return SliverAppBar(
      leadingWidth: 100,
      titleSpacing: 0,
      scrolledUnderElevation: 0,
      elevation: 10,
      title: LinkedDuration(taskId: item.id),
      leading: const BackWidget(),
      actions: [
        SaveButton(entryId: taskId),
      ],
      pinned: true,
      automaticallyImplyLeading: false,
    );
  }
}
