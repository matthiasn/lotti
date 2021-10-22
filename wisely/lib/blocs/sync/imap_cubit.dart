import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:wisely/blocs/sync/classes.dart';
import 'package:wisely/blocs/sync/encryption_cubit.dart';
import 'package:wisely/blocs/sync/imap_state.dart';
import 'package:wisely/db/audio_note.dart';
import 'package:wisely/sync/encryption.dart';
import 'package:wisely/sync/encryption_salsa.dart';
import 'package:wisely/sync/imap.dart';
import 'package:wisely/utils/audio_utils.dart';

import '../audio_notes_cubit.dart';

class ImapCubit extends Cubit<ImapState> {
  late final EncryptionCubit _encryptionCubit;
  late final AudioNotesCubit _audioNotesCubit;
  late ImapSyncClient imapSyncClient;

  ImapCubit({
    required EncryptionCubit encryptionCubit,
    required AudioNotesCubit audioNotesCubit,
  }) : super(ImapState.initial()) {
    _encryptionCubit = encryptionCubit;
    _audioNotesCubit = audioNotesCubit;

    imapClientInit();
  }

  Future<void> imapClientInit() async {
    await _encryptionCubit.loadSyncConfig();
    ImapConfig? imapConfig =
        _encryptionCubit.state.maybeWhen((sharedKey, imapConfig) {
      return imapConfig!;
    }, orElse: () {});
    if (imapConfig != null) {
      emit(ImapState.loading());
      imapSyncClient = ImapSyncClient(imapConfig, _audioNotesCubit);
    }
  }

  void saveEncryptedImap(AudioNote audioNote) async {
    String jsonString = json.encode(audioNote.toJson());
    String subject = audioNote.vectorClock.toString();
    String? b64Secret = _encryptionCubit.state.maybeWhen(
      (sharedKey, imapConfig) => sharedKey,
      orElse: () => null,
    );

    File? audioFile = await AudioUtils.getAudioFile(audioNote);

    if (b64Secret != null) {
      String encryptedMessage = encryptSalsa(jsonString, b64Secret);
      imapSyncClient.saveImapMessage(subject, encryptedMessage, null);

      if (audioFile != null) {
        int fileLength = audioFile.lengthSync();
        if (fileLength > 0) {
          File encryptedFile = File('${audioFile.path}.aes');
          encryptFile(audioFile, encryptedFile, b64Secret);
          imapSyncClient.saveImapMessage(
              subject, encryptedMessage, encryptedFile);
        }
      }
    }
  }
}
