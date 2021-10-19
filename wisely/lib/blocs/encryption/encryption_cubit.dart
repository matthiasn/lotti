import 'package:bloc/bloc.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'encryption_cubit.freezed.dart';
part 'encryption_state.dart';

class EncryptionCubit extends Cubit<EncryptionState> {
  final _storage = const FlutterSecureStorage();
  final String sharedSecretKey = 'sharedSecret';

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
    emit(Empty());
  }
}
