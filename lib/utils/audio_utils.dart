import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/confined_path.dart';
import 'package:lotti/utils/file_utils.dart';

class AudioUtils {
  static Future<String> getFullAudioPath(JournalAudio j) async =>
      getAudioPath(j, getDocumentsDirectory());

  static String getRelativeAudioPath(JournalAudio j) {
    return '${j.data.audioDirectory}${j.data.audioFile}';
  }

  /// [j]'s file under [docDir], confined to it: the directory and file name
  /// arrive by sync (see [confinedDocumentPath]).
  static String getAudioPath(JournalAudio j, Directory docDir) =>
      confinedDocumentPath(
        docDir.path,
        j.data.audioDirectory,
        j.data.audioFile,
      );
}
