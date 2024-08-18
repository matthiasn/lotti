import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/save_button.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/tasks/linked_duration.dart';

class TaskAppBar extends StatelessWidget implements PreferredSizeWidget {
  TaskAppBar({
    required this.itemId,
    super.key,
  });

  final String itemId;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<JournalEntity?>(
      stream: _db.watchEntityById(itemId),
      builder: (
        BuildContext context,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        final item = snapshot.data;
        if (item == null || item.meta.deletedAt != null) {
          return const TitleAppBar(title: '');
        }

        final isTask = item is Task;

        if (!isTask) {
          return const TitleAppBar(title: 'Lotti');
        } else {
          return AppBar(
            title: LinkedDuration(task: item),
            centerTitle: true,
            leadingWidth: 100,
            leading: const BackWidget(),
            actions: [
              SaveButton(entryId: item.meta.id),
            ],
          );
        }
      },
    );
  }
}
