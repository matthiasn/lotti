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
    publishState();

    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        final newLastStep = keyVerification.lastStep;
        if (newLastStep != null && newLastStep != lastStep) {
          lastStep = newLastStep;
          debugPrint('$name newLastStep: $newLastStep');

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
  bool? startedVerification;
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
