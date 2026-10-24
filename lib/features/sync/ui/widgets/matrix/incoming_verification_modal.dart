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
import 'package:material_ui/material_ui.dart';

class IncomingVerificationModal extends ConsumerStatefulWidget {
  const IncomingVerificationModal(
    this.request, {
    super.key,
  });

  /// The peer's request as it arrived; the live ceremony is read from the
  /// service's incoming stream.
  final SyncVerificationState request;

  @override
  ConsumerState<IncomingVerificationModal> createState() =>
      _IncomingVerificationModalState();
}

class _IncomingVerificationModalState
    extends ConsumerState<IncomingVerificationModal> {
  SyncService get _matrixService => ref.read(matrixServiceProvider);
  bool _awaitingOtherDevice = false;
  bool _didScheduleUnverifiedRefresh = false;
  bool _didAutoAcceptVerification = false;

  Future<void> _autoAcceptIncoming(SyncVerificationState state) async {
    try {
      await _matrixService.acceptVerification(state.id);
    } catch (_) {
      // Keep the manual "Verify" button available as fallback.
      if (mounted) {
        _didAutoAcceptVerification = false;
      }
    }
  }

  Future<void> _acceptEmojiVerification(SyncVerificationState? state) async {
    if (state == null || _awaitingOtherDevice) return;
    setState(() => _awaitingOtherDevice = true);
    try {
      await _matrixService.acceptEmojiVerification(state.id);
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
      (device) => device.deviceId == widget.request.peerDeviceId,
    );

    final displayName =
        requestingDevice?.displayName ??
        widget.request.peerDeviceId ??
        'device name not found';

    // The runner stream replays its state only to the first subscriber,
    // and the add-device page may already be one. Start from what the
    // service holds for this request, or from the request itself — the
    // service answers a request by id before it has a runner.
    final live = _matrixService.incomingVerification;
    return StreamBuilder<SyncVerificationState>(
      initialData: live?.id == widget.request.id ? live : widget.request,
      stream: _matrixService.incomingVerifications,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final emojis = state?.emojis;
        // Not the SDK's `isDone`: it is equally true for a cancelled ceremony,
        // so a remote cancel used to render the green success shield here —
        // and this modal has no cancellation notice to contradict it.
        final outcome = state?.outcome ?? KeyVerificationOutcome.pending;
        final isSuccess = outcome == KeyVerificationOutcome.success;
        final isPending = outcome == KeyVerificationOutcome.pending;

        if (isSuccess && !_didScheduleUnverifiedRefresh) {
          _didScheduleUnverifiedRefresh = true;
          unawaited(refreshUnverifiedDevices());
        }

        if (isPending &&
            emojis == null &&
            state != null &&
            !_didAutoAcceptVerification) {
          _didAutoAcceptVerification = true;
          unawaited(_autoAcceptIncoming(state));
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
                  deviceId: widget.request.peerDeviceId,
                ),
                SizedBox(height: tokens.spacing.step5),
                if (isPending && emojis == null)
                  DesignSystemButton(
                    onPressed: state == null
                        ? null
                        : () => _matrixService.acceptVerification(state.id),
                    label: context.messages.settingsMatrixVerifyLabel,
                    size: DesignSystemButtonSize.large,
                  ),
                if (isPending && emojis != null)
                  VerificationEmojiStage(
                    emojis: emojis,
                    awaitingOtherDevice: _awaitingOtherDevice,
                    onAccept: () => unawaited(_acceptEmojiVerification(state)),
                    onCancel: () => unawaited(() async {
                      if (state != null) {
                        await _matrixService.cancelVerification(state.id);
                      }
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
                    onConfirm: pop,
                  ),
                if (isSuccess)
                  VerificationSuccessStage(
                    onConfirm: () {
                      unawaited(refreshUnverifiedDevices());
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
  StreamSubscription<SyncVerificationState>? _subscription;
  StreamSubscription<SyncVerificationState>? _ownRunnerSubscription;
  ProviderSubscription<bool>? _lockSubscription;

  /// The latest request that arrived while another sheet held the lock.
  /// The service keeps one incoming ceremony — the latest — so an older
  /// deferred request would render the wrong ceremony anyway.
  SyncVerificationState? _deferred;

  /// Whether [deferred] is still live: the service's incoming ceremony when
  /// that is the same request, else the snapshot as it arrived.
  bool _stillPending(SyncVerificationState deferred) {
    final live = ref.read(matrixServiceProvider).incomingVerification;
    return live != null && live.id == deferred.id
        ? live.isPending
        : deferred.isPending;
  }

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
        if (_stillPending(deferred)) _arrived(deferred);
      },
    );
    final service = ref.read(matrixServiceProvider);
    _subscription = service.incomingVerificationRequests.listen((request) {
      if (mounted) _arrived(request);
    });
    // A request held back before this device's own ceremony existed is
    // offered again once it does, so the device that should yield can.
    _ownRunnerSubscription = reofferOnOwnVerification(service, () {
      final deferred = _deferred;
      if (!mounted || deferred == null || !_stillPending(deferred)) return;
      _deferred = null;
      _arrived(deferred);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ownRunnerSubscription?.cancel();
    _lockSubscription?.close();
    super.dispose();
  }

  /// Both arrivals — from the SDK, and back from the deferred slot — start
  /// the one fire-and-forget future this widget owns.
  void _arrived(SyncVerificationState request) => unawaited(_offer(request));

  Future<void> _offer(SyncVerificationState request) async {
    if (!mounted) return;
    final lock = ref.read(matrixVerificationModalLockProvider.notifier);
    if (lock.tryAcquire()) {
      await _show(request, lock);
      return;
    }

    final service = ref.read(matrixServiceProvider);
    final outgoing = service.outgoingVerification;
    if (outgoing != null &&
        shouldYieldTo(
          incoming: request,
          outgoing: outgoing,
          ownUserId: service.ownUserId,
          ownDeviceId: service.ownDeviceId,
        )) {
      // The device whose ceremony is being withdrawn was never really offered
      // one, so it must stay eligible for the launcher. The launcher's sheet
      // now shows the peer's ceremony instead: that peer is the one shown,
      // and the one "Show the emoji" reopens (`RecordHandedOff`).
      final handled = ref.read(matrixVerificationHandledProvider.notifier);
      final withdrawnDeviceId = outgoing.peerDeviceId;
      if (withdrawnDeviceId != null) {
        handled.release(
          MatrixVerificationHandled.identityOf(
            userId: outgoing.peerUserId,
            deviceId: withdrawnDeviceId,
          ),
        );
      }
      final peerDeviceId = request.peerDeviceId;
      if (peerDeviceId != null) {
        handled.markShown(
          MatrixVerificationHandled.identityOf(
            userId: request.peerUserId,
            deviceId: peerDeviceId,
          ),
        );
      }
      await service.handOffOutgoingVerificationTo(request.id);
      return;
    }

    _deferred = request;
  }

  Future<void> _show(
    SyncVerificationState request,
    MatrixVerificationModalLock lock,
  ) async {
    final service = ref.read(matrixServiceProvider);
    try {
      await showVerificationModalSheet(
        context: context,
        title: context.messages.syncVerifyModalTitle,
        child: IncomingVerificationModal(request),
      );
    } finally {
      // A finished ceremony is left alone; a live one the user walked away
      // from is cancelled so the peer's sheet closes too.
      if (service.incomingVerification?.id == request.id) {
        await service.cancelVerification(request.id);
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
