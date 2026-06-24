import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';

/// Live trailing indicator for the `sync/outbox` settings-tree row.
///
/// Shows a standalone pending-count badge (a design-system number badge) when
/// the outbox is online with a backlog, and nothing otherwise. This replaces
/// the earlier postbox-glyph-with-overlaid-badge: the row already names the
/// "Sync Outbox" surface with its own leading icon, so the trailing slot only
/// needs the count — a clean pill rather than a second, cramped icon.
class OutboxCountIndicator extends ConsumerWidget {
  const OutboxCountIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online =
        ref.watch(outboxConnectionStateProvider).value ==
        OutboxConnectionState.online;
    final count = ref.watch(outboxPendingCountProvider).value ?? 0;
    if (!online || count == 0) {
      return const SizedBox.shrink();
    }
    return DesignSystemBadge.number(
      value: '$count',
      tone: DesignSystemBadgeTone.danger,
    );
  }
}
