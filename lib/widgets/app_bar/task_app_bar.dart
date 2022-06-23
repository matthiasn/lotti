import 'package:flutter/material.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/app_bar_version.dart';
import 'package:lotti/widgets/app_bar/auto_leading_button.dart';
import 'package:lotti/widgets/tasks/linked_duration.dart';

class TaskAppBar extends StatelessWidget with PreferredSizeWidget {
  TaskAppBar({
    super.key,
    required this.itemId,
  });

  final String itemId;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<JournalEntity?>(
      stream: _db.watchEntityById(itemId),
      builder: (
        BuildContext context,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        final item = snapshot.data;
        if (item == null || item.meta.deletedAt != null) {
          return AppBar(
            backgroundColor: AppColors.headerBgColor,
            title: FadeIn(
              duration: const Duration(milliseconds: 500),
              child: Text(
                localizations.taskNotFound,
                style: appBarTextStyle,
              ),
            ),
            centerTitle: true,
            leading: const TestDetectingAutoLeadingButton(),
          );
        }

        final isTask = item is Task;

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
            leading: const TestDetectingAutoLeadingButton(),
          );
        }
      },
    );
  }
}
