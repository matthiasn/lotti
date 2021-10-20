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
    loadSharedKey();
  }

  Future<void> loadSharedKey() async {
    emit(Loading());
    String? sharedKey = await _storage.read(key: sharedSecretKey);
    if (sharedKey == null) {
      emit(Empty());
    } else {
      emit(EncryptionState(sharedKey: sharedKey));
    }
  }

  Future<void> generateSharedKey() async {
    emit(Generating());
    final Key key = Key.fromSecureRandom(32);
    String sharedKey = key.base64;
    await Future.delayed(const Duration(seconds: 1));
    await _storage.write(key: sharedSecretKey, value: sharedKey);
    loadSharedKey();
  }

  Future<void> setSharedKey(String newKey) async {
    emit(Generating());
    await Future.delayed(const Duration(seconds: 1));
    await _storage.write(key: sharedSecretKey, value: newKey);
    loadSharedKey();
  }

  Future<void> deleteSharedKey() async {
    await _storage.delete(key: sharedSecretKey);
    print('deleted key');
    loadSharedKey();
  }

  Future<void> setImapConfig(ImapConfig imapConfig) async {
    print('EncryptionCubit setImapConfig $imapConfig');
    String json = jsonEncode(imapConfig);
    print('EncryptionCubit setImapConfig JSON $json');
    await _storage.write(key: imapConfigKey, value: json);
    String? fromStore = await _storage.read(key: imapConfigKey);
    print('EncryptionCubit setImapConfig JSON from store $fromStore');
  }
}
