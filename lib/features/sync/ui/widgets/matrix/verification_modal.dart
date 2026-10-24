import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_ceremony_stages.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

class VerificationModal extends ConsumerStatefulWidget {
  const VerificationModal(
    this.device, {
    super.key,
  });

  /// The device to verify; `hasKeys` is true.
  final SyncDeviceInfo device;

  @override
  ConsumerState<VerificationModal> createState() => _VerificationModalState();
}

class _VerificationModalState extends ConsumerState<VerificationModal> {
  SyncService get _matrixService => ref.read(matrixServiceProvider);
  bool _awaitingOtherDevice = false;
  bool _didScheduleUnverifiedRefresh = false;
  bool _verificationStartInFlight = false;
  Timer? _autoDismiss;

  @override
  void dispose() {
    _autoDismiss?.cancel();
    super.dispose();
  }

  /// Schedules the one auto-dismiss for a ceremony that has reached a terminal
  /// state. Guarded because it is called from `build`, which a StreamBuilder
  /// re-runs while that state holds: previously each rebuild armed another
  /// 30-second timer, and every one of them popped — a route that by then may
  /// belong to something else entirely.
  void _scheduleAutoDismiss(VoidCallback pop) {
    if (_autoDismiss != null) return;
    _autoDismiss = Timer(const Duration(seconds: 30), () {
      if (mounted) pop();
    });
  }

  Future<void> startVerification({bool retry = false}) async {
    if (_verificationStartInFlight) return;
    _verificationStartInFlight = true;
    try {
      final maxAttempts = retry ? 5 : 1;
      var delay = const Duration(milliseconds: 350);

      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (!mounted) return;
        try {
          await _matrixService.verifyDevice(
            userId: widget.device.userId ?? '',
            deviceId: widget.device.deviceId,
          );
          return;
        } catch (_) {
          // Keep retrying in auto mode; manual fallback remains available.
        }

        if (attempt < maxAttempts - 1) {
          await Future<void>.delayed(delay);
          delay *= 2;
        }
      }
    } finally {
      _verificationStartInFlight = false;
      if (mounted) {
        setState(() {});
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
  void initState() {
    super.initState();
    unawaited(startVerification(retry: true));
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

    return StreamBuilder<SyncVerificationState>(
      stream: _matrixService.outgoingVerifications,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final lastStep = state?.lastStep;
        final emojis = state?.emojis;
        final isLastStepKey = lastStep == 'm.key.verification.key';

        // Not the SDK's `isDone`, which is equally true for a cancelled
        // ceremony — the modal used to render the cancellation notice and the
        // green success shield at the same time, telling the user a device had
        // been verified when it had not.
        final outcome = state?.outcome ?? KeyVerificationOutcome.pending;
        final isSuccess = outcome == KeyVerificationOutcome.success;
        final isCancelled = outcome == KeyVerificationOutcome.cancelled;

        if (isSuccess && !_didScheduleUnverifiedRefresh) {
          _didScheduleUnverifiedRefresh = true;
          unawaited(refreshUnverifiedDevices());
        }

        if (isSuccess || isCancelled) {
          _scheduleAutoDismiss(pop);
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
                  deviceName: widget.device.label,
                  userId: widget.device.userId,
                  deviceId: widget.device.deviceId,
                ),
                SizedBox(height: tokens.spacing.step5),
                if (state == null)
                  DesignSystemButton(
                    key: const Key('matrix_start_verify'),
                    onPressed: _verificationStartInFlight
                        ? null
                        : () => unawaited(startVerification()),
                    label:
                        context.messages.settingsMatrixStartVerificationLabel,
                    size: DesignSystemButtonSize.large,
                  ),
                if (lastStep?.isEmpty ?? false)
                  Column(
                    children: [
                      Text(
                        context
                            .messages
                            .settingsMatrixContinueVerificationLabel,
                        style: tokens.typography.styles.body.bodyMedium,
                      ),
                      SizedBox(height: tokens.spacing.step3),
                      DesignSystemButton(
                        key: const Key('matrix_restart_verify'),
                        onPressed: _verificationStartInFlight
                            ? null
                            : () => unawaited(startVerification(retry: true)),
                        label: context
                            .messages
                            .settingsMatrixStartVerificationLabel,
                        size: DesignSystemButtonSize.large,
                      ),
                    ],
                  ),
                if (isCancelled)
                  VerificationCancelledStage(
                    confirmKey: const Key('matrix_cancelled_confirm'),
                    onConfirm: pop,
                  ),
                if (isLastStepKey && emojis == null)
                  DesignSystemButton(
                    key: const Key('matrix_accept_verify'),
                    onPressed: () => _acceptEmojiVerification(state),
                    label:
                        context.messages.settingsMatrixAcceptVerificationLabel,
                    size: DesignSystemButtonSize.large,
                  ),
                if (outcome == KeyVerificationOutcome.pending && emojis != null)
                  VerificationEmojiStage(
                    emojis: emojis,
                    awaitingOtherDevice: _awaitingOtherDevice,
                    onAccept: () => unawaited(_acceptEmojiVerification(state)),
                    onCancel: () => unawaited(() async {
                      if (state != null) {
                        await _matrixService.cancelVerification(state.id);
                      }
                      pop();
                    }()),
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
