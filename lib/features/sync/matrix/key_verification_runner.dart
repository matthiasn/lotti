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
    this.onCompleted,
  }) {
    lastStep = keyVerification.lastStep ?? '';
    _lastIsDone = keyVerification.isDone;
    _previousOnUpdate = keyVerification.onUpdate;
    keyVerification.onUpdate = _handleSdkUpdate;
    publishState();
    _notifyCompletionIfNeeded();

    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _pollState(),
    );
  }

  String name;
  String lastStep = '';
  List<KeyVerificationEmoji>? emojis;
  KeyVerification keyVerification;
  StreamController<KeyVerificationRunner> controller;
  final Future<void> Function(String source)? onCompleted;
  Timer? _timer;
  bool _lastIsDone = false;
  bool _completionNotified = false;
  void Function()? _previousOnUpdate;

  void _handleSdkUpdate() {
    _pollState();
    _previousOnUpdate?.call();
  }

  void _pollState() {
    var changed = false;
    final newLastStep = keyVerification.lastStep ?? '';
    if (newLastStep != lastStep) {
      lastStep = newLastStep;
      changed = true;
      DevLogger.log(
        name: 'KeyVerificationRunner',
        message: '$name newLastStep: $newLastStep',
      );

      if (lastStep == 'm.key.verification.key') {
        readEmojis();
      }
    }

    final isDone = keyVerification.isDone;
    if (_lastIsDone != isDone) {
      _lastIsDone = isDone;
      changed = true;
    }

    if (changed) {
      publishState();
    }

    _notifyCompletionIfNeeded();

    if (lastStep == EventTypes.KeyVerificationDone ||
        lastStep == 'm.key.verification.cancel' ||
        isDone) {
      stopTimer();
    }
  }

  void _notifyCompletionIfNeeded() {
    if (_completionNotified || !_lastIsDone) return;
    _completionNotified = true;
    if (onCompleted != null) {
      unawaited(onCompleted!(name));
    }
  }

  void stopTimer() {
    _timer?.cancel();
    keyVerification.onUpdate = _previousOnUpdate;
    _previousOnUpdate = null;
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
  await listenForKeyVerificationRequestsWithSubscription(
    service: service,
    loggingService: loggingService,
    requests: requests,
  );
}

Future<StreamSubscription<KeyVerification>?>
    listenForKeyVerificationRequestsWithSubscription({
  required MatrixService service,
  required LoggingService loggingService,
  Stream<KeyVerification>? requests,
}) async {
  try {
    final subscription =
        (requests ?? service.client.onKeyVerificationRequest.stream).listen((
      KeyVerification keyVerification,
    ) {
      service.incomingKeyVerificationRunner = KeyVerificationRunner(
        keyVerification,
        controller: service.incomingKeyVerificationRunnerController,
        name: 'Incoming KeyVerificationRunner',
        onCompleted: (source) =>
            service.onVerificationCompleted(source: source),
      );

      DevLogger.log(
        name: 'KeyVerificationRunner',
        message: 'Key Verification Request from ${keyVerification.deviceId}',
      );
      service.incomingKeyVerificationController.add(keyVerification);
    });
    return subscription;
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
    return null;
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
    onCompleted: (source) => service.onVerificationCompleted(source: source),
  );
}
