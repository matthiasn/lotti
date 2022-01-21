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
    habitCompletion: (_) => 'habit_completion',
    journalAudio: (_) => 'audio',
    journalEntry: (_) => 'text_entries',
    journalImage: (_) => 'images',
    loggedTime: (_) => 'logged_time',
    measurement: (_) => 'measurement',
    quantitative: (_) => 'quantitative',
    survey: (_) => 'surveys',
    task: (_) => 'tasks',
  );
}

String typeSuffix(JournalEntity journalEntity) {
  return journalEntity.map(
    habitCompletion: (_) => 'habit_completion',
    journalAudio: (_) => 'audio',
    journalEntry: (_) => 'text',
    journalImage: (_) => 'image',
    loggedTime: (_) => 'logged_time',
    measurement: (_) => 'measurement',
    quantitative: (_) => 'quantitative',
    survey: (_) => 'survey',
    task: (_) => 'task',
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
