import 'package:badges/badges.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class FlaggedBadgeIcon extends StatelessWidget {
  final JournalDb _db = getIt<JournalDb>();

  FlaggedBadgeIcon({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _db.watchCountImportFlagEntries(),
      builder: (
        BuildContext context,
        AsyncSnapshot<int> snapshot,
      ) {
        int? count = snapshot.data;
        return Badge(
          badgeContent: Text(snapshot.data.toString()),
          showBadge: count != null && count != 0,
          toAnimate: false,
          elevation: 3,
          child: const Icon(
            MdiIcons.flagOutline,
            size: AppTheme.bottomNavIconSize,
          ),
        );
      },
    );
  }
}
