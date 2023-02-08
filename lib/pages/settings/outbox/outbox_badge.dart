import 'dart:math';

import 'package:badges/badges.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';

class OutboxBadgeIcon extends StatelessWidget {
  OutboxBadgeIcon({
    required this.icon,
    super.key,
  });

  final SyncDatabase db = getIt<SyncDatabase>();

  late final Stream<int> stream = db.watchOutboxCount();
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<int> snapshot,
      ) {
        final count = snapshot.data ?? 0;
        final label = '$count';
        final padding = max(6 - '$count'.length, 4);
        return Badge(
          badgeContent: Text(
            label,
            style: badgeStyle,
          ),
          badgeStyle: BadgeStyle(
            badgeColor: styleConfig().alarm,
            padding: EdgeInsets.all(padding.toDouble()),
            elevation: 3,
          ),
          showBadge: count > 0,
          child: icon,
        );
      },
    );
  }
}
