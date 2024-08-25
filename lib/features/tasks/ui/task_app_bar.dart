import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/journal_card_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/save_button.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/ui/linked_duration.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

class TaskSliverAppBar extends ConsumerWidget {
  const TaskSliverAppBar({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = journalCardControllerProvider(id: entryId);
    final item = ref.watch(provider).value;

    final scrollOffsetProvider = taskAppBarControllerProvider(
      id: entryId,
    );

    final scrollOffset = ref.watch(scrollOffsetProvider).value ?? 0.0;

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
      collapsedHeight: 60,
      leadingWidth: 100,
      titleSpacing: 0,
      scrolledUnderElevation: 10,
      elevation: 10,
      title: LinkedDuration(task: item),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(25),
        child: AnimatedOpacity(
          opacity: scrollOffset > 160 ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: Container(
            padding: const EdgeInsets.only(
              bottom: 5,
              left: 20,
              right: 20,
            ),
            child: Text(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              item.data.title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.start,
            ),
          ),
        ),
      ),
      leading: const BackWidget(),
      actions: [
        SaveButton(entryId: entryId),
      ],
      pinned: true,
      automaticallyImplyLeading: false,
    );
  }
}

extension CategoryExtension on CategoryDefinition {
  Color get colorValue {
    return color != null ? colorFromCssHex(color) : Colors.grey;
  }
}
