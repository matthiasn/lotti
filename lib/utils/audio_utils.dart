import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:path_provider/path_provider.dart';

class AudioUtils {
  static Future<String> getFullAudioPath(JournalAudio j) async {
    final docDir = await getApplicationDocumentsDirectory();
    return '${docDir.path}${j.data.audioDirectory}${j.data.audioFile}';
  }

  static String getAudioPath(JournalAudio j, Directory docDir) {
    return '${docDir.path}${j.data.audioDirectory}${j.data.audioFile}';
  }

  static Future<void> moveToTrash(JournalAudio journalDbAudio) async {
    final docDir = await getApplicationDocumentsDirectory();
    final trashDirectory =
        await Directory('${docDir.path}/audio/trash/').create(recursive: true);
    final fullAudioPath = await AudioUtils.getFullAudioPath(journalDbAudio);

    await File(fullAudioPath)
        .rename('${trashDirectory.path}/${journalDbAudio.data.audioFile}');
    await File('$fullAudioPath.json')
        .rename('${trashDirectory.path}/${journalDbAudio.data.audioFile}.json');
  }
}
