import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_flow_section.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_emojis_row.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
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

    final displayName = requestingDevice?.deviceDisplayName ??
        widget.keyVerification.deviceId ??
        'device name not found';

    return StreamBuilder<KeyVerificationRunner>(
      stream: _matrixService.incomingKeyVerificationRunnerStream,
      builder: (context, snapshot) {
        final runner = snapshot.data;
        final lastStep = runner?.lastStep;
        final emojis = runner?.emojis;
        final isLastStepDone = lastStep == 'm.key.verification.done';

        final isDone =
            isLastStepDone || (runner?.keyVerification.isDone ?? false);

        if (isDone && !_didScheduleUnverifiedRefresh) {
          _didScheduleUnverifiedRefresh = true;
          unawaited(refreshUnverifiedDevices());
        }

        if (!isDone &&
            emojis == null &&
            runner != null &&
            !_didAutoAcceptVerification) {
          _didAutoAcceptVerification = true;
          unawaited(_autoAcceptIncoming(runner));
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
                          displayName,
                          style: context.textTheme.titleLarge,
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!isDone && emojis == null)
                    LottiPrimaryButton(
                      onPressed: runner?.acceptVerification,
                      label: context.messages.settingsMatrixVerifyLabel,
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
                      context.messages.settingsMatrixVerifyIncomingConfirm,
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
                              closeModal();
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
                        '',
                        runner?.keyVerification.deviceId ?? '',
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

class IncomingVerificationWrapper extends ConsumerStatefulWidget {
  const IncomingVerificationWrapper({super.key});

  @override
  ConsumerState<IncomingVerificationWrapper> createState() =>
      _IncomingVerificationWrapperState();
}

class _IncomingVerificationWrapperState
    extends ConsumerState<IncomingVerificationWrapper> {
  StreamSubscription<KeyVerification>? _subscription;

  @override
  void initState() {
    super.initState();

    _subscription = ref
        .read(matrixServiceProvider)
        .getIncomingKeyVerificationStream()
        .listen((keyVerification) {
      if (mounted) {
        final lock = ref.read(matrixVerificationModalLockProvider.notifier);
        if (!lock.tryAcquire()) return;
        unawaited(() async {
          try {
            await showVerificationModalSheet(
              context: context,
              title: context.messages.settingsMatrixVerifyLabel,
              child: IncomingVerificationModal(keyVerification),
            );
          } finally {
            if (mounted) {
              ref.invalidate(matrixUnverifiedControllerProvider);
            }
            lock.release();
          }
        }());
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
