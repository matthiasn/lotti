import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_flow_section.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_emojis_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:matrix/matrix.dart';

class VerificationModal extends ConsumerStatefulWidget {
  const VerificationModal(
    this.deviceKeys, {
    super.key,
  });

  final DeviceKeys deviceKeys;

  @override
  ConsumerState<VerificationModal> createState() => _VerificationModalState();
}

class _VerificationModalState extends ConsumerState<VerificationModal> {
  MatrixService get _matrixService => ref.read(matrixServiceProvider);
  KeyVerificationRunner? _runner;
  bool _awaitingOtherDevice = false;
  bool _didScheduleUnverifiedRefresh = false;
  bool _verificationStartInFlight = false;

  @override
  void dispose() {
    _runner?.stopTimer();
    super.dispose();
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
          await _matrixService.verifyDevice(widget.deviceKeys);
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

    return StreamBuilder<KeyVerificationRunner>(
      stream: _matrixService.keyVerificationStream,
      builder: (context, snapshot) {
        final runner = snapshot.data;
        _runner = runner;
        final lastStep = runner?.lastStep;
        final emojis = runner?.emojis;
        final isLastStepKey = lastStep == 'm.key.verification.key';
        final isLastStepDone = lastStep == 'm.key.verification.done';
        final isLastStepCancel = lastStep == 'm.key.verification.cancel';

        final isDone =
            isLastStepDone || (runner?.keyVerification.isDone ?? false);

        if (isDone && !_didScheduleUnverifiedRefresh) {
          _didScheduleUnverifiedRefresh = true;
          unawaited(refreshUnverifiedDevices());
        }

        if (isLastStepCancel) {
          Timer(const Duration(seconds: 30), pop);
        }

        if (isLastStepDone) {
          Timer(const Duration(seconds: 30), pop);
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SyncFlowSection(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          widget.deviceKeys.deviceDisplayName ??
                              widget.deviceKeys.deviceId ??
                              '',
                          style: context.textTheme.titleLarge,
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Opacity(
                    opacity: 0.5,
                    child: Text(
                      widget.deviceKeys.userId,
                      style: context.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (runner == null)
                    LottiPrimaryButton(
                      key: const Key('matrix_start_verify'),
                      onPressed: _verificationStartInFlight
                          ? null
                          : () => unawaited(startVerification()),
                      label:
                          context.messages.settingsMatrixStartVerificationLabel,
                    ),
                  if (lastStep?.isEmpty ?? false)
                    Column(
                      children: [
                        Text(
                          context
                              .messages.settingsMatrixContinueVerificationLabel,
                        ),
                        const SizedBox(height: 12),
                        LottiPrimaryButton(
                          key: const Key('matrix_restart_verify'),
                          onPressed: _verificationStartInFlight
                              ? null
                              : () => unawaited(startVerification(retry: true)),
                          label: context
                              .messages.settingsMatrixStartVerificationLabel,
                        ),
                      ],
                    ),
                  if (isLastStepCancel)
                    Text(
                      context.messages.settingsMatrixVerificationCancelledLabel,
                    ),
                  if (isLastStepKey && emojis == null)
                    LottiPrimaryButton(
                      key: const Key('matrix_accept_verify'),
                      onPressed: runner?.acceptEmojiVerification,
                      label: context
                          .messages.settingsMatrixAcceptVerificationLabel,
                    ),
                  if (!isDone && emojis != null) ...[
                    if (_awaitingOtherDevice)
                      Text(
                        context
                            .messages.settingsMatrixContinueVerificationLabel,
                        style: context.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    if (_awaitingOtherDevice) const SizedBox(height: 12),
                    Text(
                      context.messages.settingsMatrixVerifyConfirm,
                      style: context.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    VerificationEmojisRow(emojis.take(4)),
                    VerificationEmojisRow(emojis.skip(4)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: LottiPrimaryButton(
                            key: const Key('matrix_cancel_verification'),
                            onPressed: () async {
                              await runner?.cancelVerification();
                              pop();
                            },
                            label: context
                                .messages.settingsMatrixCancelVerificationLabel,
                            isDestructive: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: LottiPrimaryButton(
                            onPressed: _awaitingOtherDevice
                                ? null
                                : () => _acceptEmojiVerification(runner),
                            label: _awaitingOtherDevice
                                ? context.messages
                                    .settingsMatrixContinueVerificationLabel
                                : context.messages.settingsMatrixAccept,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (isDone) ...[
                    Text(
                      context.messages.settingsMatrixVerificationSuccessLabel(
                        widget.deviceKeys.deviceDisplayName ?? '',
                        widget.deviceKeys.deviceId ?? '',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Icon(
                      MdiIcons.shieldCheck,
                      color: Colors.greenAccent,
                      size: 128,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        LottiPrimaryButton(
                          onPressed: () {
                            unawaited(refreshUnverifiedDevices());
                            runner?.stopTimer();
                            pop();
                          },
                          label: context.messages
                              .settingsMatrixVerificationSuccessConfirm,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
