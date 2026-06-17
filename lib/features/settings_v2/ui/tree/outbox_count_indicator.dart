import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/ui/settings_v2_constants.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:matrix/matrix.dart';

/// Live trailing indicator for the `sync/outbox` settings-tree row.
///
/// Restores the at-a-glance pending-sync count that the old mobile
/// `SyncSettingsPage` showed via `OutboxBadgeIcon`, now driven through the
/// shared `SettingsTreeRow` trailing slot so both the desktop V2 sidebar
/// and the mobile drill-down surface it from one definition.
///
/// Renders nothing unless the outbox is online and has pending items —
/// matching the old badge's `isLabelVisible: count > 0` rule (an empty,
/// online, idle outbox is silent). When sync is online but the device is
/// not logged in, the pill is muted rather than alarming-red, mirroring
/// the old grayscale-dimmed treatment.
class OutboxCountIndicator extends ConsumerWidget {
  const OutboxCountIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online =
        ref.watch(outboxConnectionStateProvider).value ==
        OutboxConnectionState.online;
    if (!online) return const SizedBox.shrink();

    final count = ref.watch(outboxPendingCountProvider).value ?? 0;
    if (count <= 0) return const SizedBox.shrink();

    final loggedIn =
        ref.watch(loginStateStreamProvider).value == LoginState.loggedIn;

    final tokens = context.designTokens;
    const bgAlpha = SettingsV2Constants.badgeBackgroundAlpha;
    final (bg, fg) = loggedIn
        ? (
            tokens.colors.alert.error.defaultColor.withValues(alpha: bgAlpha),
            tokens.colors.alert.error.defaultColor,
          )
        : (
            tokens.colors.text.lowEmphasis.withValues(alpha: bgAlpha),
            tokens.colors.text.mediumEmphasis,
          );

    return Container(
      height: SettingsV2Constants.badgeHeight,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(tokens.radii.xl),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: tokens.typography.styles.others.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
