import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/ai_popup_menu.dart';
import 'package:lotti/features/journal/state/journal_card_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/extended_header_modal.dart';
import 'package:lotti/features/journal/ui/widgets/journal_app_bar.dart';
import 'package:lotti/features/tasks/ui/linked_duration.dart';
import 'package:lotti/themes/theme.dart';
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
      return JournalSliverAppBar(entryId: taskId);
    }

    return SliverAppBar(
      leadingWidth: 100,
      titleSpacing: 0,
      toolbarHeight: 45,
      scrolledUnderElevation: 0,
      elevation: 10,
      title: LinkedDuration(taskId: item.id),
      leading: const BackWidget(),
      actions: [
        AiPopUpMenu(journalEntity: item, linkedFromId: null),
        IconButton(
          icon: Icon(
            Icons.more_horiz,
            color: context.colorScheme.outline,
          ),
          onPressed: () => ExtendedHeaderModal.show(
            context: context,
            entryId: taskId,
            linkedFromId: null,
            link: null,
            inLinkedEntries: false,
          ),
        ),
        const SizedBox(width: 10),
      ],
      pinned: true,
      automaticallyImplyLeading: false,
    );
  }
}
