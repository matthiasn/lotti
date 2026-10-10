import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_handled_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_ceremony_stages.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/encryption.dart';

class IncomingVerificationModal extends ConsumerStatefulWidget {
  const IncomingVerificationModal(
    this.keyVerification, {
    super.key,
  });

  final KeyVerification keyVerification;

  @override
  ConsumerState<IncomingVerificationModal> createState() =>
      _IncomingVerificationModalState();
}

class _IncomingVerificationModalState
    extends ConsumerState<IncomingVerificationModal> {
  MatrixService get _matrixService => ref.read(matrixServiceProvider);
  bool _awaitingOtherDevice = false;
  bool _didScheduleUnverifiedRefresh = false;
  bool _didAutoAcceptVerification = false;

  Future<void> _autoAcceptIncoming(KeyVerificationRunner runner) async {
    try {
      await runner.acceptVerification();
    } catch (_) {
      // Keep the manual "Verify" button available as fallback.
      if (mounted) {
        _didAutoAcceptVerification = false;
      }
    }
  }

  Future<void> _acceptEmojiVerification(KeyVerificationRunner? runner) async {
    if (runner == null || _awaitingOtherDevice) return;
    setState(() => _awaitingOtherDevice = true);
    try {
      await runner.acceptEmojiVerification();
    } catch (_) {
      if (mounted) {
        setState(() => _awaitingOtherDevice = false);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pop = Navigator.of(context).pop;

    Future<void> refreshUnverifiedDevices() async {
      const attempts = 12;
      const retryDelay = Duration(milliseconds: 400);

      for (var i = 0; i < attempts; i++) {
        ref.invalidate(matrixUnverifiedControllerProvider);
        if (_matrixService.getUnverifiedDevices().isEmpty) {
          break;
        }
        await Future<void>.delayed(retryDelay);
        if (!mounted) return;
      }

      if (!mounted) return;
      ref.invalidate(matrixUnverifiedControllerProvider);
    }

    void closeModal() {
      Navigator.of(context).pop();
    }

    final unverifiedDevices = _matrixService.getUnverifiedDevices();
    final requestingDevice = unverifiedDevices.firstWhereOrNull(
      (deviceKeys) => deviceKeys.deviceId == widget.keyVerification.deviceId,
    );

    final displayName =
        requestingDevice?.deviceDisplayName ??
        widget.keyVerification.deviceId ??
        'device name not found';

    return StreamBuilder<KeyVerificationRunner>(
      stream: _matrixService.incomingKeyVerificationRunnerStream,
      builder: (context, snapshot) {
        final runner = snapshot.data;
        final emojis = runner?.emojis;
        // Not the SDK's `isDone`: it is equally true for a cancelled ceremony,
        // so a remote cancel used to render the green success shield here —
        // and this modal has no cancellation notice to contradict it.
        final outcome = runner?.outcome ?? KeyVerificationOutcome.pending;
        final isSuccess = outcome == KeyVerificationOutcome.success;
        final isPending = outcome == KeyVerificationOutcome.pending;

        if (isSuccess && !_didScheduleUnverifiedRefresh) {
          _didScheduleUnverifiedRefresh = true;
          unawaited(refreshUnverifiedDevices());
        }

        if (isPending &&
            emojis == null &&
            runner != null &&
            !_didAutoAcceptVerification) {
          _didAutoAcceptVerification = true;
          unawaited(_autoAcceptIncoming(runner));
        }

        final tokens = context.designTokens;

        return SingleChildScrollView(
          child: Padding(
            // The sheet itself is the card: nesting a second bordered,
            // shadowed surface inside it was the one screen in the journey
            // still drawn card-in-card.
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step2,
              vertical: tokens.spacing.step4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VerificationCeremonyHeader(
                  deviceName: displayName,
                  userId: requestingDevice?.userId,
                  deviceId: widget.keyVerification.deviceId,
                ),
                SizedBox(height: tokens.spacing.step5),
                if (isPending && emojis == null)
                  DesignSystemButton(
                    onPressed: runner?.acceptVerification,
                    label: context.messages.settingsMatrixVerifyLabel,
                    size: DesignSystemButtonSize.large,
                  ),
                if (isPending && emojis != null)
                  VerificationEmojiStage(
                    emojis: emojis,
                    awaitingOtherDevice: _awaitingOtherDevice,
                    onAccept: () => unawaited(_acceptEmojiVerification(runner)),
                    onCancel: () => unawaited(() async {
                      await runner?.cancelVerification();
                      closeModal();
                    }()),
                  ),
                // Without a confirm the cancelled state is a dead end:
                // every other branch is gated off and nothing is left to
                // dismiss the sheet with.
                if (outcome == KeyVerificationOutcome.cancelled)
                  VerificationCancelledStage(
                    confirmKey: const Key(
                      'matrix_incoming_cancelled_confirm',
                    ),
                    onConfirm: () {
                      runner?.stopTimer();
                      pop();
                    },
                  ),
                if (isSuccess)
                  VerificationSuccessStage(
                    onConfirm: () {
                      unawaited(refreshUnverifiedDevices());
                      runner?.stopTimer();
                      pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Listens for incoming verification requests and shows each one in the
/// ceremony sheet — at once if the modal lock is free, otherwise as the
/// model-checked rules in `specs/tla/VerificationLaunch.tla` require:
///
/// * **Yield.** If this device's own outgoing ceremony is still unanswered and
///   the request comes from a smaller identity, the outgoing ceremony is
///   withdrawn and the open sheet carries on with the peer's. Two devices
///   starting at each other used to leave both sheets waiting forever.
/// * **Defer.** Otherwise the request is kept until the lock frees and shown
///   then, if the peer has not cancelled it. Dropped, it could never be shown
///   again, and the launcher — which offers each device once — never asked.
class IncomingVerificationWrapper extends ConsumerStatefulWidget {
  const IncomingVerificationWrapper({super.key});

  @override
  ConsumerState<IncomingVerificationWrapper> createState() =>
      _IncomingVerificationWrapperState();
}

class _IncomingVerificationWrapperState
    extends ConsumerState<IncomingVerificationWrapper> {
  StreamSubscription<KeyVerification>? _subscription;
  ProviderSubscription<bool>? _lockSubscription;

  /// The latest request that arrived while another sheet held the lock.
  /// `MatrixService` keeps one incoming runner — the latest — so an older
  /// deferred request would render the wrong ceremony anyway.
  KeyVerification? _deferred;

  @override
  void initState() {
    super.initState();

    // Guest/demo worlds have no Matrix stack; resolving matrixServiceProvider
    // there would throw. No sync means no incoming verifications to listen
    // for.
    if (!ref.read(syncFeatureAvailableProvider)) {
      return;
    }

    _lockSubscription = ref.listenManual<bool>(
      matrixVerificationModalLockProvider,
      (_, held) {
        if (held) return;
        final deferred = _deferred;
        if (deferred == null) return;
        _deferred = null;
        if (!deferred.isDone) _arrived(deferred);
      },
    );
    _subscription = ref
        .read(matrixServiceProvider)
        .getIncomingKeyVerificationStream()
        .listen((keyVerification) {
          if (mounted) _arrived(keyVerification);
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _lockSubscription?.close();
    super.dispose();
  }

  /// Both arrivals — from the SDK, and back from the deferred slot — start
  /// the one fire-and-forget future this widget owns.
  void _arrived(KeyVerification keyVerification) =>
      unawaited(_offer(keyVerification));

  Future<void> _offer(KeyVerification keyVerification) async {
    if (!mounted) return;
    final lock = ref.read(matrixVerificationModalLockProvider.notifier);
    if (lock.tryAcquire()) {
      await _show(keyVerification, lock);
      return;
    }

    final service = ref.read(matrixServiceProvider);
    final outgoing = service.keyVerificationRunner;
    if (outgoing != null &&
        shouldYieldTo(
          incoming: keyVerification,
          outgoing: outgoing,
          ownUserId: service.ownUserId,
          ownDeviceId: service.ownDeviceId,
        )) {
      // The device whose ceremony is being withdrawn was never really offered
      // one, so it must stay eligible for the launcher.
      final withdrawn = outgoing.keyVerification;
      final withdrawnDeviceId = withdrawn.deviceId;
      if (withdrawnDeviceId != null) {
        ref
            .read(matrixVerificationHandledProvider.notifier)
            .release(
              MatrixVerificationHandled.identityOf(
                userId: withdrawn.userId,
                deviceId: withdrawnDeviceId,
              ),
            );
      }
      await handOffOutgoingVerification(
        service: service,
        incoming: keyVerification,
        domainLogger: ref.read(domainLoggerProvider),
      );
      return;
    }

    _deferred = keyVerification;
  }

  Future<void> _show(
    KeyVerification keyVerification,
    MatrixVerificationModalLock lock,
  ) async {
    final service = ref.read(matrixServiceProvider);
    final logger = ref.read(domainLoggerProvider);
    try {
      await showVerificationModalSheet(
        context: context,
        title: context.messages.syncVerifyModalTitle,
        child: IncomingVerificationModal(keyVerification),
      );
    } finally {
      final runner = service.incomingKeyVerificationRunner;
      if (runner != null &&
          identical(runner.keyVerification, keyVerification)) {
        await cancelAbandonedVerification(runner, loggingService: logger);
      }
      if (mounted) {
        ref
          ..invalidate(matrixUnverifiedControllerProvider)
          ..invalidate(syncDevicesControllerProvider);
      }
      lock.release();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
