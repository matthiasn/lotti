import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/ui/invite_dialog_helper.dart';
import 'package:lotti/features/sync/ui/login/sync_login_modal_page.dart';
import 'package:lotti/features/sync/ui/matrix_logged_in_config_page.dart';
import 'package:lotti/features/sync/ui/matrix_stats_page.dart';
import 'package:lotti/features/sync/ui/room_config_page.dart';
import 'package:lotti/features/sync/ui/unverified_devices_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class MatrixSettingsCard extends ConsumerStatefulWidget {
  const MatrixSettingsCard({super.key});

  @override
  ConsumerState<MatrixSettingsCard> createState() => _MatrixSettingsCardState();
}

@visibleForTesting
abstract class MatrixSettingsCardStateAccess {
  MatrixSettingsCardTestHandle get testHandle;
}

class MatrixSettingsCardTestHandle {
  MatrixSettingsCardTestHandle._(this._state);

  final _MatrixSettingsCardState _state;

  ValueNotifier<int> get pageIndexNotifier =>
      _state.pageIndexNotifierForTesting;

  void updatePageIndex() => _state.updatePageIndexForTesting();
}

class _MatrixSettingsCardState extends ConsumerState<MatrixSettingsCard>
    implements MatrixSettingsCardStateAccess {
  late final ValueNotifier<int> pageIndexNotifier;
  StreamSubscription<SyncRoomInvite>? _inviteSub;
  bool _inviteOpen = false;

  @override
  void initState() {
    super.initState();
    pageIndexNotifier = ValueNotifier(0);
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    pageIndexNotifier.dispose();
    super.dispose();
  }

  @override
  MatrixSettingsCardTestHandle get testHandle =>
      MatrixSettingsCardTestHandle._(this);

  @visibleForTesting
  ValueNotifier<int> get pageIndexNotifierForTesting => pageIndexNotifier;

  @visibleForTesting
  void updatePageIndexForTesting() {
    if (ref.read(matrixServiceProvider).isLoggedIn()) {
      pageIndexNotifier.value = 1;
    } else {
      pageIndexNotifier.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedModernSettingsCardWithIcon(
      title: context.messages.settingsMatrixTitle,
      subtitle: 'Configure end-to-end encrypted sync',
      icon: Icons.sync,
      onTap: () {
        updatePageIndexForTesting();
        // Subscribe to invites for the lifetime of the modal to avoid
        // duplicate page-level listeners.
        final matrixService = ref.read(matrixServiceProvider);
        _inviteSub?.cancel();
        InviteDialogScope.globalListenerActive = true;
        _inviteSub =
            matrixService.inviteRequests.listen((SyncRoomInvite invite) async {
          if (!mounted || _inviteOpen) return;
          _inviteOpen = true;
          try {
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            final accept = await showInviteDialog(context, invite);
            if (!mounted) return;
            if (accept) {
              await ref.read(matrixServiceProvider).acceptInvite(invite);
            }
          } finally {
            _inviteOpen = false;
          }
        });

        ModalUtils.showMultiPageModal<void>(
          context: context,
          pageIndexNotifier: pageIndexNotifier,
          pageListBuilder: (modalSheetContext) => [
            syncLoginModalPage(
              context: modalSheetContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
            homeServerLoggedInPage(
              context: modalSheetContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
            roomConfigPage(
              context: modalSheetContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
            unverifiedDevicesPage(
              context: modalSheetContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
            matrixStatsPage(
              context: modalSheetContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
          ],
        ).whenComplete(() {
          _inviteSub?.cancel();
          _inviteSub = null;
          InviteDialogScope.globalListenerActive = false;
        });
      },
    );
  }
}
