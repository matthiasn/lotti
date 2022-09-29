import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';

class FlaggedBadgeIcon extends StatelessWidget {
  FlaggedBadgeIcon({super.key, this.active = false});

  final JournalDb _db = getIt<JournalDb>();
  final bool active;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _db.watchCountImportFlagEntries(),
      builder: (
        BuildContext context,
        AsyncSnapshot<int> snapshot,
      ) {
        final count = snapshot.data;
        return Badge(
          badgeColor: styleConfig().alarm,
          badgeContent: Text(
            snapshot.data.toString(),
            style: badgeStyle,
          ),
          showBadge: count != null && count != 0,
          toAnimate: false,
          elevation: 3,
          child: active
              ? SvgPicture.asset(styleConfig().navJournalIconActive)
              : SvgPicture.asset(styleConfig().navJournalIcon),
        );
      },
    );
  }
}
