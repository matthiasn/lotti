import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/file_utils.dart';

class AudioUtils {
  static Future<String> getFullAudioPath(JournalAudio j) async {
    final docDir = getDocumentsDirectory();
    return '${docDir.path}${j.data.audioDirectory}${j.data.audioFile}';
  }

  static String getAudioPath(JournalAudio j, Directory docDir) {
    return '${docDir.path}${j.data.audioDirectory}${j.data.audioFile}';
  }

  static Future<void> moveToTrash(JournalAudio journalDbAudio) async {
    final docDir = getDocumentsDirectory();
    final trashDirectory =
        await Directory('${docDir.path}/audio/trash/').create(recursive: true);
    final fullAudioPath = await AudioUtils.getFullAudioPath(journalDbAudio);

    await File(fullAudioPath)
        .rename('${trashDirectory.path}/${journalDbAudio.data.audioFile}');
    await File('$fullAudioPath.json')
        .rename('${trashDirectory.path}/${journalDbAudio.data.audioFile}.json');
  }
}
