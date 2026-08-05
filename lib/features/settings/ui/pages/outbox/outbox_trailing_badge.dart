import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Compact incoming/outgoing sync queue pills rendered in a trailing slot
/// (e.g. alongside Settings on the desktop navigation sidebar).
///
/// Only renders when sync is enabled and at least one queue has pending work.
/// Down/up arrows identify the incoming/outgoing directions, while the neutral
/// outline communicates ordinary queued work rather than an error.
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (incomingCount > 0)
          DesignSystemBadge.outlined(
            label: '↓ $incomingCount',
            tone: DesignSystemBadgeTone.neutral,
            semanticLabel:
                '${context.messages.syncActivityInboxLabel}: $incomingCount',
          ),
        if (incomingCount > 0 && outgoingCount > 0)
          SizedBox(width: context.designTokens.spacing.step1),
        if (outgoingCount > 0)
          DesignSystemBadge.outlined(
            label: '↑ $outgoingCount',
            tone: DesignSystemBadgeTone.neutral,
            semanticLabel:
                '${context.messages.syncActivityOutboxLabel}: $outgoingCount',
          ),
      ],
    );
  }
}
