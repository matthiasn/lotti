import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_room_provider.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage roomConfigPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    stickyActionBar: Padding(
      padding: WoltModalConfig.pagePadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: OutlinedButton(
              onPressed: () =>
                  pageIndexNotifier.value = pageIndexNotifier.value - 1,
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
    ),
    title: context.messages.settingsMatrixRoomConfigTitle,
    padding: WoltModalConfig.pagePadding + const EdgeInsets.only(bottom: 80),
    child: const RoomConfig(),
  );
}

class RoomConfig extends ConsumerStatefulWidget {
  const RoomConfig({super.key});

  @override
  ConsumerState createState() => _RoomConfigState();
}

class _RoomConfigState extends ConsumerState<RoomConfig> {
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

    Future<void> joinRoom() async {
      await roomNotifier.joinRoom(manualRoomId);
    }

    Future<void> handleBarcode(BarcodeCapture barcodes) async {
      final barcode = barcodes.barcodes.firstOrNull;
      final userId = barcode?.rawValue;
      if (userId != null) {
        await roomNotifier.inviteToRoom(userId);
        setState(() {
          showCam = false;
        });
      }
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
          const SizedBox(height: 20),
          LottiSecondaryButton(
            label: 'Invite',
            onPressed: () {
              setState(() {
                showCam = true;
              });
            },
          ),
          const SizedBox(height: 20),
          if (showCam && isMobile)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: camDimension,
                width: camDimension,
                child: MobileScanner(onDetect: handleBarcode),
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
