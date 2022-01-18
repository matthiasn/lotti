import 'package:badges/badges.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/main.dart';
import 'package:lotti/widgets/pages/settings/settings_icon.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class OutboxBadgeIcon extends StatelessWidget {
  final SyncDatabase db = getIt<SyncDatabase>();
  late final Stream<List<OutboxItem>> stream =
      db.watchOutboxItems(statuses: [OutboxStatus.pending]);

  OutboxBadgeIcon({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OutboxItem>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<OutboxItem>> snapshot,
      ) {
        int count = snapshot.data?.length ?? 0;
        return Badge(
          badgeContent: Text('$count'),
          showBadge: count > 0,
          toAnimate: false,
          elevation: 3,
          child: const SettingsIcon(MdiIcons.mailbox),
        );
      },
    );
  }
}
