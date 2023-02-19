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
          label: Text(
            snapshot.data.toString(),
            style: badgeStyle,
          ),
          isLabelVisible: count != null && count != 0,
          backgroundColor: styleConfig().alarm,
          child: child,
        );
      },
    );
  }
}
