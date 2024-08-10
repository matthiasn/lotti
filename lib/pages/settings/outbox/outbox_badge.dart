import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';

class OutboxBadgeIcon extends StatelessWidget {
  OutboxBadgeIcon({
    required this.icon,
    super.key,
  });

  final Widget icon;

  late final Stream<bool> flagStream =
      getIt<JournalDb>().watchConfigFlag(enableSyncFlag);

  late final Stream<int> outboxCountStream =
      getIt<SyncDatabase>().watchOutboxCount();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: flagStream,
      builder: (
        BuildContext context,
        AsyncSnapshot<bool> flagSnapshot,
      ) {
        final syncEnabled = flagSnapshot.data ?? false;

        if (syncEnabled) {
          return StreamBuilder<int>(
            stream: outboxCountStream,
            builder: (
              BuildContext context,
              AsyncSnapshot<int> countSnapshot,
            ) {
              final count = countSnapshot.data ?? 0;
              final label = '$count';
              return Badge(
                label: Text(
                  label,
                  style: badgeStyle,
                ),
                backgroundColor: context.colorScheme.error,
                isLabelVisible: count > 0,
                child: icon,
              );
            },
          );
        } else {
          return icon;
        }
      },
    );
  }
}
