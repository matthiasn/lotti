import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/file_utils.dart';

class AudioUtils {
  static Future<String> getFullAudioPath(JournalAudio j) async {
    final docDir = getDocumentsDirectory();
    return '${docDir.path}${j.data.audioDirectory}${j.data.audioFile}';
  }

  static String getRelativeAudioPath(JournalAudio j) {
    return '${j.data.audioDirectory}${j.data.audioFile}';
  }

  static String getAudioPath(JournalAudio j, Directory docDir) {
    return '${docDir.path}${getRelativeAudioPath(j)}';
  }
}
