import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/state/matrix_room_provider.dart';
import 'package:lotti/features/sync/ui/invite_dialog_helper.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
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

@visibleForTesting
abstract class RoomConfigStateAccess {
  bool get showCamForTesting;
  set showCamForTesting(bool value);
  Future<void> handleBarcodeForTesting(BarcodeCapture barcodes);
}

class _RoomConfigState extends ConsumerState<RoomConfig>
    implements RoomConfigStateAccess {
  bool showCam = false;
  final joinRoomController = TextEditingController();
  String manualRoomId = '';
  final MobileScannerController _scannerController = MobileScannerController();
  bool _inviting = false;
  String? _lastCode;
  DateTime? _lastScanAt;
  StreamSubscription<SyncRoomInvite>? _inviteSub;
  bool _dialogOpen = false;

  @override
  void dispose() {
    _inviteSub?.cancel();
    _scannerController.dispose();
    joinRoomController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Fallback invite listener only when no central listener is active.
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
            if (mounted) setState(() {});
          }
        } finally {
          _dialogOpen = false;
        }
      });
    });
  }

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
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _handleBarcode,
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

  Future<void> _handleBarcode(BarcodeCapture barcodes) async {
    if (_inviting) return;
    final barcode = barcodes.barcodes.firstOrNull;
    final userId = barcode?.rawValue;
    if (userId == null || userId.isEmpty) return;

    final now = DateTime.now();
    if (_lastCode == userId &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < const Duration(seconds: 2)) {
      return; // drop duplicate scans within window
    }

    _lastCode = userId;
    _lastScanAt = now;
    _inviting = true;
    try {
      await _scannerController.stop();
    } catch (_) {
      // best-effort
    }

    try {
      await ref
          .read(matrixRoomControllerProvider.notifier)
          .inviteToRoom(userId);
      if (mounted) {
        setState(() {
          showCam = false;
        });
      }
    } finally {
      _inviting = false;
    }
  }

  @override
  bool get showCamForTesting => showCam;

  @override
  set showCamForTesting(bool value) {
    setState(() {
      showCam = value;
    });
  }

  @override
  Future<void> handleBarcodeForTesting(BarcodeCapture barcodes) =>
      _handleBarcode(barcodes);
}
