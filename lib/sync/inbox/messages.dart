import 'dart:io';
import 'dart:isolate';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/config.dart';

part 'messages.freezed.dart';

@freezed
class InboxIsolateMessage with _$InboxIsolateMessage {
  factory InboxIsolateMessage.init({
    required SyncConfig syncConfig,
    required SendPort loggingDbConnectPort,
    required SendPort journalDbConnectPort,
    required SendPort settingsDbConnectPort,
    required bool allowInvalidCert,
    required String? hostHash,
    required Directory docDir,
    required int lastReadUid,
    //required ReceivePort port,
  }) = InboxIsolateInitMessage;

  factory InboxIsolateMessage.restart({
    required SyncConfig syncConfig,
  }) = InboxIsolateRestartMessage;
}

@freezed
class IsolateInboxMessage with _$IsolateInboxMessage {
  factory IsolateInboxMessage.setLastReadUid({
    required int lastReadUid,
  }) = IsolateInboxLastReadMessage;
}
