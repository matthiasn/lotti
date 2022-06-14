import 'package:bloc/bloc.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/sync/imap_client.dart';
import 'package:lotti/sync/inbox_service.dart';
import 'package:lotti/sync/outbox.dart';

part 'sync_config_cubit.freezed.dart';
part 'sync_config_state.dart';

class SyncConfigCubit extends Cubit<SyncConfigState> {
  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();

  String? sharedSecret;
  ImapConfig? imapConfig;
  bool isAccountValid = false;
  String? connectionError;

  SyncConfigCubit() : super(SyncConfigState.loading()) {
    loadSyncConfig();
  }

  Future<void> loadSyncConfig() async {
    emit(SyncConfigState.loading());
    SyncConfig? syncConfig = await _syncConfigService.getSyncConfig();
    imapConfig = syncConfig?.imapConfig;
    sharedSecret = syncConfig?.sharedSecret;

    if (sharedSecret != null) {
      getIt<SyncInboxService>().init();
      getIt<OutboxService>().init();
    }

    testConnection();
  }

  void resetStatus() {
    isAccountValid = false;
    connectionError = null;
  }

  Future<void> emitState() async {
    if (imapConfig == null && sharedSecret == null) {
      emit(SyncConfigState.empty());
    } else if (imapConfig != null && sharedSecret != null && isAccountValid) {
      emit(SyncConfigState.configured(
        imapConfig: imapConfig!,
        sharedSecret: sharedSecret!,
      ));
    } else if (imapConfig != null &&
        connectionError == null &&
        isAccountValid) {
      emit(SyncConfigState.imapValid(
        imapConfig: imapConfig!,
      ));
    } else if (imapConfig != null && connectionError != null) {
      emit(SyncConfigState.imapInvalid(
        imapConfig: imapConfig!,
        errorMessage: connectionError,
      ));
    }
  }

  Future<void> testConnection() async {
    resetStatus();

    if (imapConfig != null) {
      ImapClient? client = await createImapClient(
        SyncConfig(
          imapConfig: imapConfig!,
          sharedSecret: '',
        ),
      );

      if (client != null) {
        isAccountValid = true;
        debugPrint('testConnection isAccountValid');
      } else {
        debugPrint('testConnection error');
        connectionError = 'Error';
      }
    }

    emitState();
  }

  Future<void> generateSharedKey() async {
    emit(SyncConfigState.generating());
    await _syncConfigService.generateSharedKey();
    loadSyncConfig();
  }

  Future<void> setSyncConfig(String configJson) async {
    _syncConfigService.setSyncConfig(configJson);
    emitState();
  }

  void testImapConfig(ImapConfig? config) {
    if (config != null) {
      imapConfig = config;
      testConnection();
    }
  }

  Future<void> saveImapConfig() async {
    if (imapConfig != null && isAccountValid && connectionError == null) {
      await _syncConfigService.setImapConfig(imapConfig!);
    }
    emitState();
  }

  Future<void> deleteSharedKey() async {
    await _syncConfigService.deleteSharedKey();
    loadSyncConfig();
  }

  Future<void> setImapConfig(ImapConfig? config) async {
    imapConfig = config;
    debugPrint('setImapConfig $config');

    emit(SyncConfigState.imapTesting(imapConfig: imapConfig));

    EasyDebounce.debounce(
      'syncTestConnection',
      const Duration(seconds: 2),
      testConnection,
    );
  }
}
