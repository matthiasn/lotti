import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_emojis_row.dart';
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

  @override
  Widget build(BuildContext context) {
    final pop = Navigator.of(context).pop;

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

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                    label: 'Verify Session',
                  ),
                if (!isDone && emojis != null) ...[
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
                          onPressed: runner?.acceptEmojiVerification,
                          label: 'They match',
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
                          runner?.stopTimer();
                          pop();
                        },
                        label: context
                            .messages.settingsMatrixVerificationSuccessConfirm,
                      ),
                    ],
                  ),
                ],
              ],
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
        showModalBottomSheet<void>(
          context: context,
          builder: (context) {
            return IncomingVerificationModal(keyVerification);
          },
        );
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
