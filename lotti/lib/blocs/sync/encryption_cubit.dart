import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'config_classes.dart';

part 'encryption_cubit.freezed.dart';
part 'encryption_state.dart';

class EncryptionCubit extends Cubit<EncryptionState> {
  final _storage = const FlutterSecureStorage();
  final String sharedSecretKey = 'sharedSecret';
  final String imapConfigKey = 'imapConfig';

  EncryptionCubit() : super(Empty()) {
    loadSyncConfig();
  }

  Future<SyncConfig?> loadSyncConfig() async {
    emit(Loading());
    String? sharedKey = await _storage.read(key: sharedSecretKey);
    String? imapConfigJson = await _storage.read(key: imapConfigKey);
    ImapConfig? imapConfig;

    if (imapConfigJson != null) {
      imapConfig = ImapConfig.fromJson(json.decode(imapConfigJson));
    }

    if (sharedKey == null) {
      emit(Empty());
    } else {
      emit(EncryptionState(
        sharedKey: sharedKey,
        imapConfig: imapConfig,
      ));
      if (imapConfig != null) {
        return SyncConfig(
          imapConfig: imapConfig,
          sharedSecret: sharedKey,
        );
      }
    }
  }

  Future<void> generateSharedKey() async {
    emit(Generating());
    final Key key = Key.fromSecureRandom(32);
    String sharedKey = key.base64;
    await _storage.write(key: sharedSecretKey, value: sharedKey);
    loadSyncConfig();
  }

  Future<void> setSyncConfig(String configJson) async {
    emit(Generating());
    SyncConfig syncConfig = SyncConfig.fromJson(json.decode(configJson));
    await _storage.write(
      key: sharedSecretKey,
      value: syncConfig.sharedSecret,
    );
    await _storage.write(
      key: imapConfigKey,
      value: json.encode(syncConfig.imapConfig.toJson()),
    );
    loadSyncConfig();
  }

  Future<void> deleteSharedKey() async {
    await _storage.delete(key: sharedSecretKey);
    loadSyncConfig();
  }

  Future<void> setImapConfig(ImapConfig imapConfig) async {
    String json = jsonEncode(imapConfig);
    await _storage.write(key: imapConfigKey, value: json);
    loadSyncConfig();
  }
}
