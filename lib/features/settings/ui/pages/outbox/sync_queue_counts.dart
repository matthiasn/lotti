import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/features/settings/ui/pages/outbox/sync_queue_count_format.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:material_ui/material_ui.dart';

/// Compact incoming/outgoing sync queue counts rendered in a trailing slot
/// (e.g. alongside Settings on the desktop navigation sidebar).
///
/// Only renders when sync is enabled and at least one queue has pending work.
/// Down/up arrows identify the incoming/outgoing directions.
///
/// These read as quiet metadata rather than as status chips. A queue depth is
/// ambient — it resolves itself, and nothing here is asking to be acted on —
/// so it carries neither an outline nor the ink weight of the Settings label
/// it sits beside. The row's one piece of navigation stays its most prominent
/// element.
///
/// Counts are shown through [formatSyncQueueLabel] and shaped with tabular
/// figures. Both serve the row rather than the number: the compact form caps
/// how much width a busy queue can take from the Settings label beside it, and
/// the digit shaping stops the counts resizing on every count change. The
/// accessible label keeps the exact figure — a screen reader has no width
/// problem to solve.
class SyncQueueCounts extends ConsumerWidget {
  const SyncQueueCounts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Before any other sync provider. `inboundQueueDepthProvider` resolves
    // `matrixServiceProvider`, which a guest world deliberately leaves
    // unoverridden so an accidental resolution throws loudly rather than
    // silently no-opping — so reaching it at all is the bug, not the throw.
    if (!ref.watch(syncFeatureAvailableProvider)) {
      return const SizedBox.shrink();
    }
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
        // Each count is `Flexible`, so a slot too narrow for both — the 200 px
        // rail with six-figure queues in both directions — shares the
        // shortfall between them instead of overflowing. Both directions
        // shorten together rather than one winning the row.
        if (incomingCount > 0)
          Flexible(
            child: _SyncQueueCount(
              label: formatSyncQueueLabel(
                SyncQueueDirection.incoming,
                incomingCount,
                messages,
              ),
              semanticLabel: messages.syncQueueIncomingSemanticLabel(
                incomingCount,
              ),
            ),
          ),
        // Wider than the gap inside each count, and deliberately so: with the
        // outlines gone this space is the only thing separating the two
        // directions. Too little and the pair reads as one run of glyphs.
        if (incomingCount > 0 && outgoingCount > 0)
          SizedBox(width: context.designTokens.spacing.step3),
        if (outgoingCount > 0)
          Flexible(
            child: _SyncQueueCount(
              label: formatSyncQueueLabel(
                SyncQueueDirection.outgoing,
                outgoingCount,
                messages,
              ),
              semanticLabel: messages.syncQueueOutgoingSemanticLabel(
                outgoingCount,
              ),
            ),
          ),
      ],
    );
  }
}

/// One direction's queue depth, rendered as quiet metadata.
class _SyncQueueCount extends StatelessWidget {
  const _SyncQueueCount({
    required this.label,
    required this.semanticLabel,
  });

  /// The visible string, as composed by [formatSyncQueueLabel].
  final String label;

  /// The exact, uncompacted figure announced to assistive technology.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        // One `Text`, not an arrow widget beside a count widget: the pair
        // ellipsizes and shrinks as a unit under `Flexible`, which is what
        // keeps a busy queue from overflowing a narrow rail.
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
            // Tabular figures and open-digit variants, so a 9 → 10 → 99
            // transition neither jiggles nor blurs at caption size. See
            // `numericBadgeFontFeatures` for the complete rationale.
            fontFeatures: numericBadgeFontFeatures,
          ),
        ),
      ),
    );
  }
}
