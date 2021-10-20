import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'classes.dart';

part 'encryption_cubit.freezed.dart';
part 'encryption_state.dart';

class EncryptionCubit extends Cubit<EncryptionState> {
  final _storage = const FlutterSecureStorage();
  final String sharedSecretKey = 'sharedSecret';
  final String imapConfigKey = 'imapConfig';

  EncryptionCubit() : super(Empty()) {
    loadSyncConfig();
  }

  Future<void> loadSyncConfig() async {
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
    }
  }

  Future<void> generateSharedKey() async {
    emit(Generating());
    final Key key = Key.fromSecureRandom(32);
    String sharedKey = key.base64;
    await _storage.write(key: sharedSecretKey, value: sharedKey);
    loadSyncConfig();
  }

  Future<void> setSharedKey(String newKey) async {
    emit(Generating());
    await _storage.write(key: sharedSecretKey, value: newKey);
    loadSyncConfig();
  }

  Future<void> deleteSharedKey() async {
    await _storage.delete(key: sharedSecretKey);
    print('deleted key');
    loadSyncConfig();
  }

  Future<void> setImapConfig(ImapConfig imapConfig) async {
    String json = jsonEncode(imapConfig);
    await _storage.write(key: imapConfigKey, value: json);
    String? fromStore = await _storage.read(key: imapConfigKey);
    print('EncryptionCubit setImapConfig JSON from store $fromStore');
    loadSyncConfig();
  }
}
