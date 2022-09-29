import 'package:badges/badges.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';

class TasksBadgeIcon extends StatelessWidget {
  TasksBadgeIcon({super.key, this.active = false});

  final JournalDb _db = getIt<JournalDb>();
  final bool active;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JournalEntity>>(
      stream: _db.watchTasks(
        starredStatuses: [true, false],
        taskStatuses: ['IN PROGRESS'],
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity>> snapshot,
      ) {
        final count = snapshot.data?.length ?? 0;
        return Badge(
          badgeContent: Text(
            '$count',
            style: badgeStyle,
          ),
          badgeColor: styleConfig().alarm,
          showBadge: count != 0,
          toAnimate: false,
          elevation: 3,
          child: active
              ? SvgPicture.asset(styleConfig().navTasksIconActive)
              : SvgPicture.asset(styleConfig().navTasksIcon),
        );
      },
    );
  }
}
