import 'package:bloc/bloc.dart';
import 'package:encrypt/encrypt.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/sync/secure_storage.dart';

part 'encryption_cubit.freezed.dart';
part 'encryption_state.dart';

class EncryptionCubit extends Cubit<EncryptionState> {
  EncryptionCubit() : super(EncryptionState.empty());

  Future<void> loadSharedKey() async {
    emit(Loading());
    await Future.delayed(const Duration(seconds: 2));
    String? sharedKey = await SecureStorage.readValue("sharedSecret");
    emit(EncryptionState(sharedKey: sharedKey));
  }

  Future<void> generateSharedKey() async {
    emit(Loading());
    final Key key = Key.fromSecureRandom(32);
    String sharedKey = key.base64;
    await SecureStorage.writeValue("sharedSecret", sharedKey);
    await Future.delayed(const Duration(seconds: 2));
    loadSharedKey();
  }
}
