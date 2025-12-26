import 'dart:async';

import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

class KeyVerificationRunner {
  KeyVerificationRunner(
    this.keyVerification, {
    required this.controller,
    required this.name,
  }) {
    lastStep = keyVerification.lastStep ?? '';
    publishState();

    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        final newLastStep = keyVerification.lastStep;
        if (newLastStep != null && newLastStep != lastStep) {
          lastStep = newLastStep;
          DevLogger.log(
            name: 'KeyVerificationRunner',
            message: '$name newLastStep: $newLastStep',
          );

          if (lastStep == 'm.key.verification.key') {
            readEmojis();
          }

          if (lastStep == EventTypes.KeyVerificationDone) {
            stopTimer();
          }

          if (lastStep == 'm.key.verification.cancel') {
            stopTimer();
          }

          publishState();
        }
      },
    );
  }

  String name;
  String lastStep = '';
  List<KeyVerificationEmoji>? emojis;
  KeyVerification keyVerification;
  StreamController<KeyVerificationRunner> controller;
  Timer? _timer;

  void stopTimer() {
    _timer?.cancel();
  }

  Future<void> acceptVerification() async {
    await keyVerification.acceptVerification();
  }

  Future<void> acceptEmojiVerification() async {
    await keyVerification.acceptSas();
  }

  void readEmojis() {
    emojis = keyVerification.sasEmojis;
  }

  void publishState() {
    controller.add(this);
  }

  Future<void> cancelVerification() async {
    await keyVerification.cancel();
    stopTimer();
  }
}

Future<void> listenForKeyVerificationRequests({
  required MatrixService service,
  required LoggingService loggingService,
  Stream<KeyVerification>? requests,
}) async {
  try {
    (requests ?? service.client.onKeyVerificationRequest.stream).listen((
      KeyVerification keyVerification,
    ) {
      service.incomingKeyVerificationRunner = KeyVerificationRunner(
        keyVerification,
        controller: service.incomingKeyVerificationRunnerController,
        name: 'Incoming KeyVerificationRunner',
      );

      DevLogger.log(
        name: 'KeyVerificationRunner',
        message: 'Key Verification Request from ${keyVerification.deviceId}',
      );
      service.incomingKeyVerificationController.add(keyVerification);
    });
  } catch (e, stackTrace) {
    DevLogger.error(
      name: 'KeyVerificationRunner',
      message: 'Error listening for key verification requests',
      error: e,
      stackTrace: stackTrace,
    );
    loggingService.captureException(
      e,
      domain: 'MATRIX_SERVICE',
      subDomain: 'listen',
      stackTrace: stackTrace,
    );
  }
}

Future<void> verifyMatrixDevice({
  required DeviceKeys deviceKeys,
  required MatrixService service,
}) async {
  final keyVerification = await deviceKeys.startVerification();
  service.keyVerificationRunner = KeyVerificationRunner(
    keyVerification,
    controller: service.keyVerificationController,
    name: 'Outgoing KeyVerificationRunner',
  );
}
