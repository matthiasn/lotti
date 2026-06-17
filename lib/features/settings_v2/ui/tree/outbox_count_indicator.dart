import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_badge.dart';

/// Live trailing indicator for the `sync/outbox` settings-tree row.
///
/// Restores the teal postbox glyph + pending-count badge the standalone
/// mobile `SyncSettingsPage` showed before sync was folded into the shared
/// tree. Renders through the same [OutboxBadgeIcon] the live bottom nav
/// uses, wired into the shared `SettingsTreeRow` trailing slot so both the
/// desktop V2 sidebar and the mobile drill-down surface it from one
/// definition.
///
/// [OutboxBadgeIcon] owns the reactive behaviour: the postbox always
/// shows, a red count badge overlays it when the outbox is online with a
/// backlog, the glyph mutes to grayscale when online but logged out, and
/// the badge stays hidden when the queue is empty.
class OutboxCountIndicator extends ConsumerWidget {
  const OutboxCountIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutboxBadgeIcon(
      icon: Icon(
        MdiIcons.mailboxOutline,
        color: context.designTokens.colors.interactive.enabled,
      ),
    );
  }
}
