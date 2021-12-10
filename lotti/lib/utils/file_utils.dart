import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'audio_utils.dart';
import 'image_utils.dart';

Uuid uuid = const Uuid();

String folderForJournalEntity(JournalEntity journalEntity) {
  return journalEntity.map(
    journalEntry: (_) => 'text_entries',
    journalImage: (_) => 'images',
    journalAudio: (_) => 'audio',
    loggedTime: (_) => 'logged_time',
    task: (_) => 'tasks',
    quantitative: (_) => 'quantitative',
    survey: (_) => 'surveys',
    measurement: (_) => 'measurement',
  );
}

String typeSuffix(JournalEntity journalEntity) {
  return journalEntity.map(
    journalEntry: (_) => 'text',
    journalImage: (_) => 'image',
    journalAudio: (_) => 'audio',
    loggedTime: (_) => 'logged_time',
    task: (_) => 'task',
    quantitative: (_) => 'quantitative',
    survey: (_) => 'survey',
    measurement: (_) => 'measurement',
  );
}

String entityPath(JournalEntity journalEntity, Directory docDir) {
  return journalEntity.maybeMap(
    journalImage: (JournalImage journalImage) =>
        '${getFullImagePathWithDocDir(journalImage, docDir)}.json',
    journalAudio: (journalAudio) =>
        '${AudioUtils.getAudioPath(journalAudio, docDir)}.json',
    orElse: () {
      DateFormat df = DateFormat('yyyy-MM-dd');
      String dateSubFolder = df.format(journalEntity.meta.createdAt);
      String folder = folderForJournalEntity(journalEntity);
      String entityType = typeSuffix(journalEntity);
      String fileName = '${journalEntity.meta.id}.$entityType.json';
      return '${docDir.path}/$folder/$dateSubFolder/$fileName';
    },
  );
}

Future<void> saveJournalEntityJson(JournalEntity journalEntity) async {
  String json = jsonEncode(journalEntity);
  Directory docDir = await getApplicationDocumentsDirectory();
  String path = entityPath(journalEntity, docDir);
  File file = await File(path).create(recursive: true);
  await file.writeAsString(json);
}
