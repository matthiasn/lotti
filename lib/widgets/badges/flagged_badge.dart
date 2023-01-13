import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';

class FlaggedBadge extends StatelessWidget {
  FlaggedBadge({super.key, this.child});

  final JournalDb _db = getIt<JournalDb>();
  final Widget? child;

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
          child: child,
        );
      },
    );
  }
}
