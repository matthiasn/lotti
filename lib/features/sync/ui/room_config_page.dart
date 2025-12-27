import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_room_provider.dart';
import 'package:lotti/features/sync/ui/invite_listener_mixin.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
    with InviteListenerMixin<RoomConfig>
    implements RoomConfigStateAccess {
  bool showCam = false;
  final joinRoomController = TextEditingController();
  String manualRoomId = '';
  final MobileScannerController _scannerController = MobileScannerController();
  bool _inviting = false;
  String? _lastCode;
  DateTime? _lastScanAt;

  @override
  void dispose() {
    disposeFallbackInviteListener();
    _scannerController.dispose();
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
    } catch (error, stackTrace) {
      // Classify the error and determine if it's recoverable
      final errorInfo = _classifyInviteError(error);

      // Log the exception with full details for debugging
      ref.read(loggingServiceProvider).captureException(
            error,
            domain: 'ROOM_CONFIG',
            subDomain: 'invite.${errorInfo.errorType}',
            stackTrace: stackTrace,
          );

      // Show user feedback if mounted
      if (mounted) {
        _showInviteErrorFeedback(errorInfo, userId);
      }

      // Restart scanner for recoverable errors so user can retry
      if (mounted && showCam && errorInfo.isRecoverable) {
        try {
          await _scannerController.start();
        } catch (_) {
          // best-effort restart
        }
      }
    } finally {
      _inviting = false;
    }
  }

  /// Classifies an invite error to determine recoverability and user messaging.
  _InviteErrorInfo _classifyInviteError(Object error) {
    // Network/connectivity errors - recoverable
    if (error is SocketException || error is TimeoutException) {
      return const _InviteErrorInfo(
        errorType: 'network',
        isRecoverable: true,
        messageKey: _InviteErrorMessage.network,
      );
    }

    // Matrix-specific errors
    if (error is MatrixException) {
      final code = error.errcode;
      switch (code) {
        case 'M_NOT_FOUND':
          return const _InviteErrorInfo(
            errorType: 'userNotFound',
            isRecoverable: false,
            messageKey: _InviteErrorMessage.userNotFound,
          );
        case 'M_FORBIDDEN':
          return const _InviteErrorInfo(
            errorType: 'forbidden',
            isRecoverable: false,
            messageKey: _InviteErrorMessage.forbidden,
          );
        case 'M_LIMIT_EXCEEDED':
          return const _InviteErrorInfo(
            errorType: 'rateLimited',
            isRecoverable: true,
            messageKey: _InviteErrorMessage.rateLimited,
          );
        case 'M_UNKNOWN':
        default:
          // Check if the error message hints at network issues
          final msg = error.errorMessage.toLowerCase();
          if (msg.contains('timeout') || msg.contains('connection')) {
            return const _InviteErrorInfo(
              errorType: 'network',
              isRecoverable: true,
              messageKey: _InviteErrorMessage.network,
            );
          }
          return _InviteErrorInfo(
            errorType: 'matrix.$code',
            isRecoverable: false,
            messageKey: _InviteErrorMessage.unknown,
          );
      }
    }

    // Check string representation for common network patterns
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('timeout') ||
        errorStr.contains('socket') ||
        errorStr.contains('connection')) {
      return const _InviteErrorInfo(
        errorType: 'network',
        isRecoverable: true,
        messageKey: _InviteErrorMessage.network,
      );
    }

    // Unknown error - treat as non-recoverable
    return const _InviteErrorInfo(
      errorType: 'unknown',
      isRecoverable: false,
      messageKey: _InviteErrorMessage.unknown,
    );
  }

  /// Shows appropriate user feedback based on the error classification.
  void _showInviteErrorFeedback(_InviteErrorInfo errorInfo, String userId) {
    final messages = context.messages;
    final String message;
    final SnackBarAction? action;

    switch (errorInfo.messageKey) {
      case _InviteErrorMessage.network:
        message = messages.syncInviteErrorNetwork;
        action = SnackBarAction(
          label: messages.syncRetry,
          onPressed: () {
            // Clear the duplicate-scan lock so retry works immediately
            _lastCode = null;
            _lastScanAt = null;
          },
        );
      case _InviteErrorMessage.userNotFound:
        message = messages.syncInviteErrorUserNotFound;
        action = null;
      case _InviteErrorMessage.forbidden:
        message = messages.syncInviteErrorForbidden;
        action = null;
      case _InviteErrorMessage.rateLimited:
        message = messages.syncInviteErrorRateLimited;
        action = SnackBarAction(
          label: messages.syncRetry,
          onPressed: () {
            _lastCode = null;
            _lastScanAt = null;
          },
        );
      case _InviteErrorMessage.unknown:
        message = messages.syncInviteErrorUnknown;
        action = null;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: Duration(seconds: errorInfo.isRecoverable ? 5 : 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

/// Error message types for invite failures.
enum _InviteErrorMessage {
  network,
  userNotFound,
  forbidden,
  rateLimited,
  unknown,
}

/// Holds classification info for an invite error.
class _InviteErrorInfo {
  const _InviteErrorInfo({
    required this.errorType,
    required this.isRecoverable,
    required this.messageKey,
  });

  /// Type identifier for logging (e.g., 'network', 'userNotFound', 'matrix.M_FORBIDDEN')
  final String errorType;

  /// Whether the error is recoverable (scanner should restart for retry)
  final bool isRecoverable;

  /// Key to select the appropriate user-facing message
  final _InviteErrorMessage messageKey;
}
