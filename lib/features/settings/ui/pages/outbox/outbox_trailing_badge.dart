import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';

/// Standalone count pill for pending outbox items, rendered in a trailing slot
/// (e.g. alongside Settings on the desktop navigation sidebar).
///
/// Only renders when sync is enabled and there are pending items.
class OutboxTrailingBadge extends ConsumerWidget {
  const OutboxTrailingBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(outboxConnectionStateProvider).value;
    if (connectionState != OutboxConnectionState.online) {
      return const SizedBox.shrink();
    }
    final count = ref.watch(outboxPendingCountProvider).value ?? 0;
    if (count == 0) {
      return const SizedBox.shrink();
    }
    return DesignSystemBadge.number(
      value: '$count',
      tone: DesignSystemBadgeTone.danger,
    );
  }
}
