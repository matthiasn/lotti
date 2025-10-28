import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';
import 'package:matrix/matrix.dart';

class OutboxBadgeIcon extends StatelessWidget {
  OutboxBadgeIcon({
    required this.icon,
    super.key,
  });

  final Widget icon;

  late final Stream<bool> flagStream =
      getIt<JournalDb>().watchConfigFlag(enableMatrixFlag);

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

        if (!syncEnabled) {
          return icon;
        }

        return Consumer(
          builder: (context, ref, _) {
            final loginState = ref.watch(loginStateStreamProvider).valueOrNull;
            final isLoggedIn = loginState == LoginState.loggedIn;
            final dimmed = !isLoggedIn;

            return StreamBuilder<int>(
              stream: outboxCountStream,
              builder: (
                BuildContext context,
                AsyncSnapshot<int> countSnapshot,
              ) {
                final count = countSnapshot.data ?? 0;
                final label = '$count';
                final badgeColor = dimmed
                    ? context.colorScheme.onSurfaceVariant
                    : context.colorScheme.error;

                final effectiveIcon = dimmed
                    ? ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
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
              },
            );
          },
        );
      },
    );
  }
}
