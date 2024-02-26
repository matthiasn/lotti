import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/widgets/sync/matrix/verification_emojis_row.dart';
import 'package:lotti/widgets/sync/matrix/verification_modal.dart';
import 'package:matrix/encryption.dart';

enum IncomingVerificationStep {
  requested,
  started,
  accepted,
  emojisReceived,
  verified,
}

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
  List<KeyVerificationEmoji>? _emojis;
  IncomingVerificationStep _verificationStep =
      IncomingVerificationStep.requested;
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

    final unverifiedDevices = _matrixService.getUnverified();
    final requestingDevice = unverifiedDevices.firstWhereOrNull(
      (deviceKeys) => deviceKeys.deviceId == widget.keyVerification.deviceId,
    );

    Future<void> acceptEmojiVerification() async {
      final emojis = await _matrixService.acceptIncomingEmojiVerification();
      setState(() {
        _emojis = emojis;
        _verificationStep = IncomingVerificationStep.emojisReceived;
      });

      periodicallyCheckAndRun(
        eventType: 'm.key.verification.mac',
        voidCallback: () {
          setState(() {
            _verificationStep = IncomingVerificationStep.verified;
          });
          Timer(const Duration(seconds: 30), pop);
        },
      );
    }

    Future<void> continueVerification() async {
      await _matrixService.continueIncomingVerification();
      setState(() {
        //_verificationStep = IncomingVerificationStep.continued;
      });

      periodicallyCheckAndRun(
        eventType: 'm.key.verification.key',
        voidCallback: acceptEmojiVerification,
      );
    }

    Future<void> acceptIncomingVerification() async {
      await _matrixService.acceptIncomingVerification();

      setState(() {
        _verificationStep = IncomingVerificationStep.started;
      });

      periodicallyCheckAndRun(
        eventType: 'm.key.verification.start',
        voidCallback: continueVerification,
      );
    }

    final displayName = requestingDevice?.deviceDisplayName ??
        widget.keyVerification.deviceId ??
        'device name not found';

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
            if (_verificationStep == IncomingVerificationStep.requested)
              RoundedFilledButton(
                key: const Key('matrix_start_verify'),
                onPressed: acceptIncomingVerification,
                labelText:
                    localizations.settingsMatrixAcceptIncomingVerificationLabel,
              ),
            //if (_verificationStep == VerificationStep.started)
            // Text(
            //   localizations.settingsMatrixContinueVerificationLabel,
            // ),
            //if (_verificationStep == VerificationStep.continued)
            RoundedFilledButton(
              key: const Key('matrix_accept_verify'),
              onPressed: acceptEmojiVerification,
              labelText: localizations.settingsMatrixAcceptVerificationLabel,
            ),
            //if (_emojis != null && _verificationStep == VerificationStep.emojisReceived)
            ...[
              Text(
                localizations.settingsMatrixVerifyIncomingConfirm,
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
                  closeModal();
                },
                labelText: localizations.settingsMatrixCancelVerificationLabel,
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
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
