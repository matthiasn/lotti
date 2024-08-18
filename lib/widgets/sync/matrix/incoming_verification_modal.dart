import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/rounded_filled_button.dart';
import 'package:lotti/widgets/sync/matrix/verification_emojis_row.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:matrix/encryption.dart';

class IncomingVerificationModal extends StatefulWidget {
  const IncomingVerificationModal(
    this.keyVerification, {
    super.key,
  });

  final KeyVerification keyVerification;

  @override
  State<IncomingVerificationModal> createState() =>
      _IncomingVerificationModalState();
}

class _IncomingVerificationModalState extends State<IncomingVerificationModal> {
  final _matrixService = getIt<MatrixService>();

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
                  RoundedFilledButton(
                    onPressed: runner?.acceptVerification,
                    labelText: 'Verify Session',
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
                      RoundedFilledButton(
                        key: const Key('matrix_cancel_verification'),
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        onPressed: () async {
                          closeModal();
                        },
                        labelText: context
                            .messages.settingsMatrixCancelVerificationLabel,
                      ),
                      RoundedFilledButton(
                        onPressed: runner?.acceptEmojiVerification,
                        labelText: 'They match',
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
                      RoundedFilledButton(
                        onPressed: () {
                          runner?.stopTimer();
                          pop();
                        },
                        labelText: context
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

class IncomingVerificationWrapper extends StatefulWidget {
  const IncomingVerificationWrapper({super.key});

  @override
  State<IncomingVerificationWrapper> createState() =>
      _IncomingVerificationWrapperState();
}

class _IncomingVerificationWrapperState
    extends State<IncomingVerificationWrapper> {
  final _stream = getIt<MatrixService>().getIncomingKeyVerificationStream();

  @override
  void initState() {
    super.initState();

    _stream.listen((keyVerification) {
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
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
