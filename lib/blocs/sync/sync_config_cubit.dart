import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_debounce/easy_debounce.dart';
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
  SyncConfigCubit() : super(SyncConfigState.loading()) {
    loadSyncConfig();

    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      testConnection();
    });
  }

  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  String? sharedSecret;
  ImapConfig? imapConfig;
  bool isAccountValid = false;
  bool saved = true;
  String? connectionError;

  Future<void> loadSyncConfig() async {
    emit(SyncConfigState.loading());
    sharedSecret = await _syncConfigService.getSharedKey();
    imapConfig = await _syncConfigService.getImapConfig();

    await testConnection();
    await emitState();

    if (imapConfig != null && sharedSecret != null) {
      await getIt<SyncInboxService>().init();
      await getIt<OutboxService>().init();
    }
  }

  void resetStatus() {
    isAccountValid = false;
    connectionError = null;
  }

  Future<void> emitState() async {
    if (imapConfig == null) {
      emit(SyncConfigState.empty());
    } else if (imapConfig != null &&
        sharedSecret != null &&
        isAccountValid &&
        saved) {
      emit(
        SyncConfigState.configured(
          imapConfig: imapConfig!,
          sharedSecret: sharedSecret!,
        ),
      );
    } else if (imapConfig != null &&
        connectionError == null &&
        isAccountValid &&
        saved) {
      emit(
        SyncConfigState.imapSaved(
          imapConfig: imapConfig!,
        ),
      );
    } else if (imapConfig != null &&
        connectionError == null &&
        isAccountValid) {
      emit(
        SyncConfigState.imapValid(
          imapConfig: imapConfig!,
        ),
      );
    } else if (imapConfig != null && connectionError != null) {
      emit(
        SyncConfigState.imapInvalid(
          imapConfig: imapConfig!,
          errorMessage: connectionError!,
        ),
      );
    }
  }

  Future<void> testConnection() async {
    resetStatus();

    if (imapConfig != null) {
      emit(SyncConfigState.imapTesting(imapConfig: imapConfig!));

      final client = await createImapClient(
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

    await emitState();
  }

  Future<void> generateSharedKey() async {
    emit(SyncConfigState.generating());
    await _syncConfigService.generateSharedKey();
    await loadSyncConfig();
  }

  Future<void> setSyncConfig(String configJson) async {
    await _syncConfigService.setSyncConfig(configJson);
    await loadSyncConfig();
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
      saved = true;
      await emitState();
    }
  }

  Future<void> deleteSharedKey() async {
    await _syncConfigService.deleteSharedKey();
    sharedSecret = null;
    await emitState();
  }

  Future<void> deleteImapConfig() async {
    await _syncConfigService.deleteImapConfig();
    imapConfig = null;
    await loadSyncConfig();
  }

  Future<void> setImapConfig(ImapConfig? config) async {
    imapConfig = config;
    saved = false;

    if (imapConfig != null) {
      EasyDebounce.debounce(
        'syncTestConnection',
        const Duration(seconds: 2),
        testConnection,
      );
    }
  }
}
