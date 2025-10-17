import 'package:flutter/material.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Shows an invite dialog and returns whether the user accepted.
/// Returns `false` if the dialog is dismissed.
Future<bool> showInviteDialog(
  BuildContext context,
  SyncRoomInvite invite,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.messages.settingsMatrixRoomInviteTitle),
      content: Text(
        context.messages.settingsMatrixRoomInviteMessage(
          invite.roomId,
          invite.senderId,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(context.messages.settingsMatrixCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(context.messages.settingsMatrixAccept),
        ),
      ],
    ),
  );

  return result ?? false;
}
