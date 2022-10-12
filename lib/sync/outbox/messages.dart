import 'dart:io';
import 'dart:isolate';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/config.dart';

part 'messages.freezed.dart';

@freezed
class OutboxIsolateMessage with _$OutboxIsolateMessage {
  factory OutboxIsolateMessage.init({
    required SyncConfig syncConfig,
    required bool networkConnected,
    required SendPort syncDbConnectPort,
    required SendPort loggingDbConnectPort,
    required bool allowInvalidCert,
    required Directory docDir,
  }) = OutboxIsolateInitMessage;
}
