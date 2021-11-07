import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:wisely/classes/journal_entities.dart';

class AudioUtils {
  static Future<String> getFullAudioPath(JournalAudio data) async {
    var docDir = await getApplicationDocumentsDirectory();
    return '${docDir.path}${data.audioDirectory}${data.audioFile}';
  }

  static String getAudioPath(JournalAudio data, Directory docDir) {
    return '${docDir.path}${data.audioDirectory}${data.audioFile}';
  }

  static Future<String> saveAudioNoteJson(JournalAudio journalAudio) async {
    String json = jsonEncode(journalAudio);
    File file = File('${await AudioUtils.getFullAudioPath(journalAudio)}.json');
    await file.writeAsString(json);
    return json;
  }

  static Future<String> createAssetDirectory(String relativePath) async {
    var docDir = await getApplicationDocumentsDirectory();
    Directory directory =
        await Directory('${docDir.path}$relativePath').create(recursive: true);
    return directory.path;
  }

  static Future<void> moveToTrash(JournalAudio journalDbAudio) async {
    var docDir = await getApplicationDocumentsDirectory();
    Directory trashDirectory =
        await Directory('${docDir.path}/audio/trash/').create(recursive: true);
    String fullAudioPath = await AudioUtils.getFullAudioPath(journalDbAudio);

    await File(fullAudioPath)
        .rename('${trashDirectory.path}/${journalDbAudio.audioFile}');
    await File('$fullAudioPath.json')
        .rename('${trashDirectory.path}/${journalDbAudio.audioFile}.json');
  }
}
