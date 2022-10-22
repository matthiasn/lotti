import 'dart:io';
import 'dart:isolate';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/config.dart';

part 'messages.freezed.dart';

@freezed
class InboxIsolateMessage with _$InboxIsolateMessage {
  factory InboxIsolateMessage.init({
    required SyncConfig syncConfig,
    required bool networkConnected,
    required SendPort syncDbConnectPort,
    required SendPort loggingDbConnectPort,
    required SendPort journalDbConnectPort,
    required bool allowInvalidCert,
  }) = InboxIsolateInitMessage;

  factory InboxIsolateMessage.restart({
    required SyncConfig syncConfig,
    required bool networkConnected,
  }) = InboxIsolateRestartMessage;
}
