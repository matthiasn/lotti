import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:enough_mail/imap/imap_client.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:wisely/blocs/sync/classes.dart';
import 'package:wisely/blocs/sync/encryption_cubit.dart';
import 'package:wisely/blocs/sync/imap_state.dart';
import 'package:wisely/utils/image_utils.dart';

import 'imap_tools.dart';

class ImapOutCubit extends Cubit<ImapState> {
  late final EncryptionCubit _encryptionCubit;
  late final ImapClient _imapClient;
  late String? _b64Secret;

  final String sharedSecretKey = 'sharedSecret';
  final String imapConfigKey = 'imapConfig';
  final String lastReadUidKey = 'lastReadUid';

  ImapOutCubit({
    required EncryptionCubit encryptionCubit,
  }) : super(ImapState.initial()) {
    _encryptionCubit = encryptionCubit;
    _imapClient = ImapClient(isLogEnabled: false);
    imapClientInit();
  }

  Future<void> imapClientInit() async {
    SyncConfig? syncConfig = await _encryptionCubit.loadSyncConfig();

    try {
      if (syncConfig != null) {
        _b64Secret = syncConfig.sharedSecret;
        emit(ImapState.loading());
        ImapConfig imapConfig = syncConfig.imapConfig;

        await _imapClient.connectToServer(
          imapConfig.host,
          imapConfig.port,
          isSecure: true,
        );
        emit(ImapState.connected());
        await _imapClient.login(imapConfig.userName, imapConfig.password);
        emit(ImapState.loggedIn());
        await _imapClient.selectInbox();
        emit(ImapState.online(lastUpdate: DateTime.now()));
        debugPrint('ImapOutCubit initialized');
      }
    } catch (e) {
      emit(ImapState.failed(error: 'failed: $e ${e.toString()}'));
    }
  }

  Future<bool> saveImap(
    String encryptedMessage,
    String subject, {
    String? encryptedFilePath,
  }) async {
    GenericImapResult? res;
    if (_b64Secret != null) {
      if (encryptedFilePath != null && encryptedFilePath.isNotEmpty) {
        File encryptedFile = File(await getFullAssetPath(encryptedFilePath));
        int fileLength = encryptedFile.lengthSync();
        if (fileLength > 0) {
          res = await saveImapMessage(_imapClient, subject, encryptedMessage,
              file: encryptedFile);
        }
      } else {
        res = await saveImapMessage(_imapClient, subject, encryptedMessage);
      }
    }
    if (res?.details != null && res!.details!.contains('completed')) {
      return true;
    } else {
      return false;
    }
  }
}
