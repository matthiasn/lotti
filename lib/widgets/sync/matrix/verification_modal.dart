import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/widgets/sync/matrix/verification_emojis_row.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';

enum VerificationStep {
  initial,
  started,
  continued,
  accepted,
  emojisReceived,
  verified,
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
  KeyVerification? _keyVerification;
  Timer? _timer;

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void periodicallyCheckAndRun({
    required String eventType,
    required VoidCallback voidCallback,
  }) {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_keyVerification?.lastStep == eventType) {
        cancelTimer();
        voidCallback();
      }
    });
  }

  @override
  void dispose() {
    cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final pop = Navigator.of(context).pop;

    void closeModal() {
      Navigator.of(context).pop();
    }

    Future<void> acceptEmojiVerification() async {
      final emojis = await _matrixService.acceptEmojiVerification();
      setState(() {
        _emojis = emojis;
        _verificationStep = VerificationStep.emojisReceived;
      });

      periodicallyCheckAndRun(
        eventType: 'm.key.verification.mac',
        voidCallback: () {
          setState(() {
            _verificationStep = VerificationStep.verified;
          });
          Timer(const Duration(seconds: 30), pop);
        },
      );
    }

    Future<void> continueVerification() async {
      setState(() {
        _verificationStep = VerificationStep.continued;
      });

      periodicallyCheckAndRun(
        eventType: 'm.key.verification.key',
        voidCallback: acceptEmojiVerification,
      );
    }

    Future<void> startVerification() async {
      final keyVerification =
          await _matrixService.verifyDevice(widget.deviceKeys);

      setState(() {
        _keyVerification = keyVerification;
        _verificationStep = VerificationStep.started;
      });

      periodicallyCheckAndRun(
        eventType: 'm.key.verification.ready',
        voidCallback: continueVerification,
      );
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
              RoundedFilledButton(
                key: const Key('matrix_start_verify'),
                onPressed: startVerification,
                labelText: localizations.settingsMatrixStartVerificationLabel,
              ),
            if (_verificationStep == VerificationStep.started)
              Text(
                localizations.settingsMatrixContinueVerificationLabel,
              ),
            if (_verificationStep == VerificationStep.continued)
              RoundedFilledButton(
                key: const Key('matrix_accept_verify'),
                onPressed: acceptEmojiVerification,
                labelText: localizations.settingsMatrixAcceptVerificationLabel,
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
              RoundedFilledButton(
                key: const Key('matrix_cancel_verification'),
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                onPressed: () async {
                  await _matrixService.cancelVerification();
                  closeModal();
                },
                labelText: localizations.settingsMatrixCancelVerificationLabel,
              ),
              const SizedBox(height: 20),
            ],
            if (_verificationStep == VerificationStep.verified) ...[
              Text(
                localizations.settingsMatrixVerificationSuccessLabel(
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
                  RoundedFilledButton(
                    onPressed: pop,
                    labelText:
                        localizations.settingsMatrixVerificationSuccessConfirm,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RoundedFilledButton extends StatelessWidget {
  const RoundedFilledButton({
    required this.onPressed,
    required this.labelText,
    this.backgroundColor = Colors.greenAccent,
    this.foregroundColor = Colors.black87,
    this.semanticsLabel,
    super.key,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;
  final String labelText;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        labelText,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}
