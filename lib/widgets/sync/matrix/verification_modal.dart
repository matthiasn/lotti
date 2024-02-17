import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/widgets/sync/matrix/verification_emojis_row.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';

enum VerificationStep {
  initial,
  started,
  continued,
  accepted,
  emojisReceived,
}

class VerificationModal extends StatefulWidget {
  const VerificationModal(
    this.deviceKeys, {
    super.key,
  });

  final DeviceKeys deviceKeys;

  @override
  State<VerificationModal> createState() => _VerificationModalState();
}

class _VerificationModalState extends State<VerificationModal> {
  final _matrixService = getIt<MatrixService>();
  List<KeyVerificationEmoji>? _emojis;
  VerificationStep _verificationStep = VerificationStep.initial;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    void closeModal() {
      Navigator.of(context).pop();
    }

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
                    widget.deviceKeys.deviceDisplayName ??
                        widget.deviceKeys.deviceId ??
                        '',
                    style: Theme.of(context).textTheme.titleLarge,
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
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 20),
            if (_verificationStep == VerificationStep.initial)
              OutlinedButton(
                key: const Key('matrix_start_verify'),
                onPressed: () async {
                  await _matrixService.verifyDevice(widget.deviceKeys);
                  setState(() {
                    _verificationStep = VerificationStep.started;
                  });
                },
                child: Text(
                  localizations.settingsMatrixStartVerificationLabel,
                  semanticsLabel:
                      localizations.settingsMatrixStartVerificationLabel,
                ),
              ),
            if (_verificationStep == VerificationStep.started)
              OutlinedButton(
                key: const Key('matrix_continue_verify'),
                onPressed: () async {
                  await _matrixService.continueVerification();
                  setState(() {
                    _verificationStep = VerificationStep.continued;
                  });
                },
                child: Text(
                  localizations.settingsMatrixContinueVerificationLabel,
                ),
              ),
            if (_verificationStep == VerificationStep.continued)
              OutlinedButton(
                key: const Key('matrix_accept_verify'),
                onPressed: () async {
                  final emojis = await _matrixService.acceptEmojiVerification();
                  setState(() {
                    _emojis = emojis;
                    _verificationStep = VerificationStep.emojisReceived;
                  });
                },
                child: Text(
                  localizations.settingsMatrixAcceptVerificationLabel,
                  semanticsLabel:
                      localizations.settingsMatrixAcceptVerificationLabel,
                ),
              ),
            if (_emojis != null &&
                _verificationStep == VerificationStep.emojisReceived) ...[
              Text(
                localizations.settingsMatrixVerifyConfirm,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              VerificationEmojisRow(_emojis?.take(4)),
              VerificationEmojisRow(_emojis?.skip(4)),
              const SizedBox(height: 20),
              OutlinedButton(
                key: const Key('matrix_cancel_verification'),
                onPressed: () async {
                  await _matrixService.cancelVerification();
                  closeModal();
                },
                child: Text(
                  localizations.settingsMatrixCancelVerificationLabel,
                  semanticsLabel:
                      localizations.settingsMatrixCancelVerificationLabel,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
