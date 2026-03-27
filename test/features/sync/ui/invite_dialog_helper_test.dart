import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/ui/invite_dialog_helper.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('InviteDialogScope', () {
    test('globalListenerActive defaults to false', () {
      expect(InviteDialogScope.globalListenerActive, isFalse);
    });

    test('globalListenerActive can be set', () {
      InviteDialogScope.globalListenerActive = true;
      addTearDown(() => InviteDialogScope.globalListenerActive = false);

      expect(InviteDialogScope.globalListenerActive, isTrue);
    });
  });

  group('showInviteDialog', () {
    final invite = SyncRoomInvite(
      roomId: '!room:server',
      senderId: '@user:server',
      matchesExistingRoom: false,
    );

    testWidgets('shows dialog with invite information', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showInviteDialog(context, invite),
              child: const Text('Invite'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Invite'));
      await tester.pumpAndSettle();

      // Dialog should be visible
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('returns false when dialog is dismissed', (tester) async {
      bool? result;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showInviteDialog(context, invite);
              },
              child: const Text('Invite'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Invite'));
      await tester.pumpAndSettle();

      // Tap outside dialog to dismiss
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });
}
