import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:wisely/db/audio_note.dart';

class AudioUtils {
  static Future<String> getFullAudioPath(AudioNote audioNote) async {
    var docDir = await getApplicationDocumentsDirectory();
    return '${docDir.path}${audioNote.audioDirectory}${audioNote.audioFile}';
  }

  static Future<String> createAudioDirectory(String relativePath) async {
    var docDir = await getApplicationDocumentsDirectory();
    Directory directory =
        await Directory('${docDir.path}$relativePath').create(recursive: true);
    return directory.path;
  }

  static Future<void> moveToTrash(AudioNote audioNote) async {
    var docDir = await getApplicationDocumentsDirectory();
    Directory trashDirectory =
        await Directory('${docDir.path}/audio/trash/').create(recursive: true);
    String fullAudioPath = await AudioUtils.getFullAudioPath(audioNote);

    await File(fullAudioPath)
        .rename('${trashDirectory.path}/${audioNote.audioFile}');
    await File('$fullAudioPath.json')
        .rename('${trashDirectory.path}/${audioNote.audioFile}.json');
  }
}
