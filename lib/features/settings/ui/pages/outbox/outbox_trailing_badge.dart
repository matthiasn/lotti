import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/outbox/sync_queue_count_format.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Compact incoming/outgoing sync queue pills rendered in a trailing slot
/// (e.g. alongside Settings on the desktop navigation sidebar).
///
/// Only renders when sync is enabled and at least one queue has pending work.
/// Down/up arrows identify the incoming/outgoing directions, while the neutral
/// outline communicates ordinary queued work rather than an error.
///
/// Counts are shown through [formatSyncQueueCount] and shaped with tabular
/// figures. Both serve the row rather than the number: the compact form caps
/// how much width a busy queue can take from the Settings label beside it, and
/// the digit shaping stops the pills resizing on every count change. The
/// accessible label keeps the exact figure — a screen reader has no width
/// problem to solve.
class OutboxTrailingBadge extends ConsumerWidget {
  const OutboxTrailingBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(outboxConnectionStateProvider).value;
    if (connectionState != OutboxConnectionState.online) {
      return const SizedBox.shrink();
    }
    final incomingCount = ref.watch(inboundQueueDepthProvider).value ?? 0;
    final outgoingCount = ref.watch(outboxPendingCountProvider).value ?? 0;
    if (incomingCount == 0 && outgoingCount == 0) {
      return const SizedBox.shrink();
    }

    final messages = context.messages;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Each pill is `Flexible`, so a slot too narrow for both — the 200 px
        // rail with six-figure queues in both directions — shares the
        // shortfall between them instead of overflowing. Both directions
        // shorten together rather than one winning the row.
        if (incomingCount > 0)
          Flexible(
            child: DesignSystemBadge.outlined(
              label: '↓ ${formatSyncQueueCount(incomingCount, messages)}',
              tone: DesignSystemBadgeTone.neutral,
              numeric: true,
              semanticLabel:
                  '${messages.syncActivityInboxLabel}: $incomingCount',
            ),
          ),
        if (incomingCount > 0 && outgoingCount > 0)
          SizedBox(width: context.designTokens.spacing.step1),
        if (outgoingCount > 0)
          Flexible(
            child: DesignSystemBadge.outlined(
              label: '↑ ${formatSyncQueueCount(outgoingCount, messages)}',
              tone: DesignSystemBadgeTone.neutral,
              numeric: true,
              semanticLabel:
                  '${messages.syncActivityOutboxLabel}: $outgoingCount',
            ),
          ),
      ],
    );
  }
}
