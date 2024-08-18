import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/rounded_filled_button.dart';
import 'package:lotti/widgets/sync/matrix/verification_emojis_row.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:matrix/matrix.dart';

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
  KeyVerificationRunner? _runner;

  @override
  void dispose() {
    _runner?.stopTimer();
    super.dispose();
  }

  void startVerification() => _matrixService.verifyDevice(widget.deviceKeys);

  @override
  void initState() {
    startVerification();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final pop = Navigator.of(context).pop;

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

        if (isLastStepCancel) {
          Timer(const Duration(seconds: 30), pop);
        }

        if (isLastStepDone) {
          Timer(const Duration(seconds: 30), pop);
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
                  RoundedFilledButton(
                    key: const Key('matrix_start_verify'),
                    onPressed: startVerification,
                    labelText:
                        context.messages.settingsMatrixStartVerificationLabel,
                  ),
                if (lastStep?.isEmpty ?? false)
                  Text(
                    context.messages.settingsMatrixContinueVerificationLabel,
                  ),
                if (isLastStepCancel)
                  Text(
                    context.messages.settingsMatrixVerificationCancelledLabel,
                  ),
                if (isLastStepKey && emojis == null)
                  RoundedFilledButton(
                    key: const Key('matrix_accept_verify'),
                    onPressed: runner?.acceptEmojiVerification,
                    labelText:
                        context.messages.settingsMatrixAcceptVerificationLabel,
                  ),
                if (!isDone && emojis != null) ...[
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
                      RoundedFilledButton(
                        key: const Key('matrix_cancel_verification'),
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        onPressed: () async {
                          await runner?.cancelVerification();
                          pop();
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
