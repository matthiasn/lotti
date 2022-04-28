import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';

part 'sync_config_cubit.freezed.dart';
part 'sync_config_state.dart';

class SyncConfigCubit extends Cubit<SyncConfigState> {
  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();

  SyncConfigCubit() : super(Empty()) {
    loadSyncConfig();
  }

  Future<void> loadSyncConfig() async {
    emit(Loading());
    SyncConfig? syncConfig = await _syncConfigService.getSyncConfig();
    String? sharedSecret = syncConfig?.sharedSecret;
    ImapConfig? imapConfig = syncConfig?.imapConfig;

    if (sharedSecret == null) {
      emit(Empty());
    } else {
      emit(SyncConfigState(
        sharedSecret: sharedSecret,
        imapConfig: imapConfig,
      ));
    }
  }

  Future<void> generateSharedKey() async {
    emit(Generating());
    await _syncConfigService.generateSharedKey();
    loadSyncConfig();
  }

  Future<void> setSyncConfig(String configJson) async {
    emit(Generating());
    _syncConfigService.setSyncConfig(configJson);
    loadSyncConfig();
  }

  Future<void> deleteSharedKey() async {
    await _syncConfigService.deleteSharedKey();
    loadSyncConfig();
  }

  Future<void> setImapConfig(ImapConfig imapConfig) async {
    await _syncConfigService.setImapConfig(imapConfig);
    loadSyncConfig();
  }
}
