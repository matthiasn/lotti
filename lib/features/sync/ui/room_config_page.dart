import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_room_provider.dart';
import 'package:lotti/features/sync/ui/invite_listener_mixin.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage roomConfigPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    stickyActionBar: _RoomConfigActionBar(pageIndexNotifier: pageIndexNotifier),
    title: context.messages.settingsMatrixRoomConfigTitle,
    padding: WoltModalConfig.pagePadding + const EdgeInsets.only(bottom: 80),
    child: const RoomConfig(),
  );
}

/// Sticky action bar for room config page.
///
/// When a room is already configured, the back button skips the room discovery
/// page (index 2) and goes directly to the logged-in config page (index 1).
class _RoomConfigActionBar extends ConsumerWidget {
  const _RoomConfigActionBar({required this.pageIndexNotifier});

  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(matrixRoomControllerProvider).value;
    final isRoomConfigured = room != null;

    return Padding(
      padding: WoltModalConfig.pagePadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: OutlinedButton(
              onPressed: () {
                // Skip room discovery (page 2) if a room is already configured
                // Go directly to logged-in config (page 1) instead
                if (isRoomConfigured) {
                  pageIndexNotifier.value = 1; // logged-in config
                } else {
                  pageIndexNotifier.value = pageIndexNotifier.value - 1;
                }
              },
              child: Text(context.messages.settingsMatrixPreviousPage),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: LottiPrimaryButton(
              onPressed: () =>
                  pageIndexNotifier.value = pageIndexNotifier.value + 1,
              label: context.messages.settingsMatrixNextPage,
            ),
          ),
        ],
      ),
    );
  }
}

/// Room configuration widget for viewing and managing the sync room.
///
/// This page allows users to:
/// - View the current room ID
/// - Leave the current room
/// - Create a new room (if no room is configured)
/// - Manually join a room by ID (edge case)
///
/// Note: The old invite-based device pairing has been replaced by the
/// single-user QR code flow. Use "Add Device" from the Stats page instead.
class RoomConfig extends ConsumerStatefulWidget {
  const RoomConfig({super.key});

  @override
  ConsumerState createState() => _RoomConfigState();
}

class _RoomConfigState extends ConsumerState<RoomConfig>
    with InviteListenerMixin<RoomConfig> {
  final joinRoomController = TextEditingController();
  String manualRoomId = '';

  @override
  void dispose() {
    disposeFallbackInviteListener();
    joinRoomController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    setupFallbackInviteListener(onAccepted: () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(matrixRoomControllerProvider).value;
    final roomNotifier = ref.read(matrixRoomControllerProvider.notifier);
    final isRoomDefined = room != null;

    Future<void> joinRoom() async {
      await roomNotifier.joinRoom(manualRoomId);
    }

    return Column(
      children: [
        if (isRoomDefined) SelectableText(room),
        const SizedBox(height: 20),
        if (isRoomDefined) ...[
          LottiSecondaryButton(
            label: 'Leave room',
            onPressed: roomNotifier.leaveRoom,
          ),
        ] else ...[
          TextField(
            controller: joinRoomController,
            onChanged: (s) {
              setState(() {
                manualRoomId = s;
              });
            },
          ),
          if (manualRoomId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: OutlinedButton(
                key: const Key('matrix_join_room'),
                onPressed: joinRoom,
                child: const Text('Join room'),
              ),
            ),
          const SizedBox(height: 20),
          OutlinedButton(
            key: const Key('matrix_create_room'),
            onPressed: roomNotifier.createRoom,
            child: const Text('Create room'),
          ),
        ],
      ],
    );
  }
}
