import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_room_provider.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage roomConfigPage({
  required BuildContext context,
  required TextTheme textTheme,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return WoltModalSheetPage(
    stickyActionBar: Padding(
      padding: WoltModalConfig.pagePadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: () =>
                pageIndexNotifier.value = pageIndexNotifier.value - 1,
            child: Center(
              child: Text(context.messages.settingsMatrixPreviousPage),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () =>
                pageIndexNotifier.value = pageIndexNotifier.value + 1,
            child: Center(
              child: Text(context.messages.settingsMatrixNextPage),
            ),
          ),
        ],
      ),
    ),
    topBarTitle: Text(
      context.messages.settingsMatrixRoomConfigTitle,
      style: textTheme.titleMedium,
    ),
    isTopBarLayerAlwaysVisible: true,
    trailingNavBarWidget: IconButton(
      padding: WoltModalConfig.pagePadding,
      icon: const Icon(Icons.close),
      onPressed: Navigator.of(context).pop,
    ),
    child: Padding(
      padding: WoltModalConfig.pagePadding + const EdgeInsets.only(bottom: 80),
      child: const RoomConfig(),
    ),
  );
}

class RoomConfig extends ConsumerStatefulWidget {
  const RoomConfig({super.key});

  @override
  ConsumerState createState() => _RoomConfigState();
}

class _RoomConfigState extends ConsumerState<RoomConfig> {
  final _qrKey = GlobalKey(debugLabel: 'matrix_QR_key');
  QRViewController? controller;
  bool showCam = false;
  final joinRoomController = TextEditingController();
  String manualRoomId = '';

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(matrixRoomControllerProvider).value;
    final roomNotifier = ref.read(matrixRoomControllerProvider.notifier);
    final isRoomDefined = room != null;

    final camDimension =
        max(MediaQuery.of(context).size.width - 100, 300).toDouble();

    void onQRViewCreated(QRViewController controller) {
      this.controller = controller;
      controller.scannedDataStream.listen((scanData) async {
        final userId = scanData.code;

        debugPrint('scanned: $userId');
        if (userId != null) {
          await roomNotifier.inviteToRoom(userId);
          setState(() {
            showCam = false;
          });
        }
      });
    }

    Future<void> invitePressed() async {
      setState(() {
        showCam = true;
      });
    }

    Future<void> joinRoom() async {
      await roomNotifier.joinRoom(manualRoomId);
    }

    return Column(
      children: [
        if (isRoomDefined) SelectableText(room),
        const SizedBox(height: 20),
        if (isRoomDefined) ...[
          OutlinedButton(
            key: const Key('matrix_invite_to_room'),
            onPressed: invitePressed,
            child: const Text('Invite'),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            key: const Key('matrix_leave_room'),
            onPressed: roomNotifier.leaveRoom,
            child: const Text('Leave room'),
          ),
          const SizedBox(height: 20),
          if (showCam && isMobile)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: camDimension,
                width: camDimension,
                child: QRView(
                  key: _qrKey,
                  onQRViewCreated: onQRViewCreated,
                ),
              ),
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
