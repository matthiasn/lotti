import 'package:flutter/material.dart';
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
        return Badge(
          label: Text(
            label,
            style: badgeStyle,
          ),
          backgroundColor: styleConfig().alarm,
          isLabelVisible: count > 0,
          child: icon,
        );
      },
    );
  }
}
