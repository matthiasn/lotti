import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/key_verification_runner.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
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
    final localizations = AppLocalizations.of(context)!;
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
                        style: Theme.of(context).textTheme.titleLarge,
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
                    localizations.settingsMatrixVerifyIncomingConfirm,
                    style: Theme.of(context).textTheme.bodyLarge,
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
                        labelText:
                            localizations.settingsMatrixCancelVerificationLabel,
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
                    localizations.settingsMatrixVerificationSuccessLabel(
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
                        labelText: localizations
                            .settingsMatrixVerificationSuccessConfirm,
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
      showModalBottomSheet<void>(
        context: context,
        builder: (context) {
          return IncomingVerificationModal(keyVerification);
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
