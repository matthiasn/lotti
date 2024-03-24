import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

class KeyVerificationRunner {
  KeyVerificationRunner(
    this.keyVerification, {
    required this.controller,
    required this.name,
  }) {
    lastStep = keyVerification.lastStep ?? '';
    startedVerification = keyVerification.startedVerification;
    lastStepHistory.add(lastStep);
    publishState();

    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        final newLastStep = keyVerification.lastStep;
        if (newLastStep != null && newLastStep != lastStep) {
          lastStep = newLastStep;
          lastStepHistory.add(newLastStep);
          debugPrint('$name newLastStep: $newLastStep ');

          if (lastStep == 'm.key.verification.key') {
            readEmojis();
          }

          if (lastStep == EventTypes.KeyVerificationDone) {
            stopTimer();
          }

          if (lastStep == 'm.key.verification.mac') {
            //keyVerification.acceptVerification();
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
  bool? startedVerification;
  List<String> lastStepHistory = [];
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

  Future<List<KeyVerificationEmoji>?> acceptEmojiVerification() async {
    await keyVerification.acceptSas();
    emojis = keyVerification.sasEmojis;
    publishState();
    return emojis;
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
