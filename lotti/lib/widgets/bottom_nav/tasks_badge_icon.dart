import 'package:badges/badges.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TasksBadgeIcon extends StatelessWidget {
  final JournalDb _db = getIt<JournalDb>();

  TasksBadgeIcon({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JournalEntity>>(
      stream: _db.watchTasks(
        starredStatuses: [true, false],
        taskStatuses: ['STARTED'],
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity>> snapshot,
      ) {
        int count = snapshot.data?.length ?? 0;
        return Badge(
          badgeContent: Text('$count'),
          showBadge: count != 0,
          toAnimate: false,
          elevation: 3,
          child: const Icon(MdiIcons.checkboxOutline),
        );
      },
    );
  }
}
