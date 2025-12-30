import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/themes/theme.dart';
import 'package:matrix/matrix.dart';

/// Grayscale color filter matrix using luminance weights (ITU-R BT.709).
/// Converts color to grayscale while preserving perceived brightness.
const grayscaleColorMatrix = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

class OutboxBadgeIcon extends ConsumerWidget {
  const OutboxBadgeIcon({
    required this.icon,
    super.key,
  });

  final Widget icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStateAsync = ref.watch(outboxConnectionStateProvider);
    final syncEnabled =
        connectionStateAsync.valueOrNull == OutboxConnectionState.online;

    if (!syncEnabled) {
      return icon;
    }

    final loginState = ref.watch(loginStateStreamProvider).valueOrNull;
    final isLoggedIn = loginState == LoginState.loggedIn;
    final dimmed = !isLoggedIn;

    final countAsync = ref.watch(outboxPendingCountProvider);
    final count = countAsync.valueOrNull ?? 0;
    final label = '$count';
    final badgeColor = dimmed
        ? context.colorScheme.onSurfaceVariant
        : context.colorScheme.error;

    final effectiveIcon = dimmed
        ? ColorFiltered(
            colorFilter: grayscaleColorMatrix,
            child: Opacity(opacity: 0.5, child: icon),
          )
        : icon;

    return Badge(
      label: Text(
        label,
        style: badgeStyle,
      ),
      backgroundColor: badgeColor,
      isLabelVisible: count > 0,
      child: effectiveIcon,
    );
  }
}
