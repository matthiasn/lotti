import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/ui/invite_dialog_helper.dart';
import 'package:lotti/providers/service_providers.dart';

/// Reusable mixin to attach a fallback invite listener to pages that are shown
/// inside the Matrix settings modal. If a central listener is active
/// (InviteDialogScope.globalListenerActive), the mixin remains idle.
mixin InviteListenerMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  StreamSubscription<SyncRoomInvite>? _inviteSub;
  bool _dialogOpen = false;

  void setupFallbackInviteListener({VoidCallback? onAccepted}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (InviteDialogScope.globalListenerActive) return;
      final matrixService = ref.read(matrixServiceProvider);
      _inviteSub =
          matrixService.inviteRequests.listen((SyncRoomInvite invite) async {
        if (!mounted || _dialogOpen) return;
        _dialogOpen = true;
        try {
          final accept = await showInviteDialog(context, invite);
          if (accept) {
            await ref.read(matrixServiceProvider).acceptInvite(invite);
            onAccepted?.call();
          }
        } finally {
          _dialogOpen = false;
        }
      });
    });
  }

  void disposeFallbackInviteListener() {
    _inviteSub?.cancel();
    _inviteSub = null;
  }
}
