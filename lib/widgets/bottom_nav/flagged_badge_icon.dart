import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme/theme.dart';

class FlaggedBadgeIcon extends StatelessWidget {
  FlaggedBadgeIcon({super.key});

  final JournalDb _db = getIt<JournalDb>();

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
          badgeContent: Text(
            snapshot.data.toString(),
            style: badgeStyle,
          ),
          showBadge: count != null && count != 0,
          toAnimate: false,
          elevation: 3,
          child: const Icon(
            Icons.home_outlined,
            size: AppTheme.bottomNavIconSize,
          ),
        );
      },
    );
  }
}
