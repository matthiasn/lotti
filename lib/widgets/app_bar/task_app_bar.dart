import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/app_bar_version.dart';
import 'package:lotti/widgets/tasks/linked_duration.dart';

class TaskAppBar extends StatelessWidget with PreferredSizeWidget {
  final String itemId;

  TaskAppBar({
    Key? key,
    required this.itemId,
  }) : super(key: key);

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
          JournalEntity? item = snapshot.data;
          if (item == null || item.meta.deletedAt != null) {
            return const SizedBox.shrink();
          }

          bool isTask = item is Task;

          if (!isTask) {
            return const VersionAppBar(title: 'Lotti');
          } else {
            return AppBar(
              backgroundColor: AppColors.headerBgColor,
              title: Stack(
                children: [
                  Opacity(
                    opacity: 0.2,
                    child: LinkedDuration(task: item),
                  ),
                  Positioned(
                    top: 10,
                    left: 48,
                    child: Text(
                      item.data.title,
                      style: appBarTextStyle.copyWith(
                        fontWeight: FontWeight.w300,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              leading: AutoBackButton(
                color: AppColors.entryTextColor,
              ),
            );
          }
        });
  }
}