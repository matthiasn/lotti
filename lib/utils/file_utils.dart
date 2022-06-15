import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

Uuid uuid = const Uuid();

String folderForJournalEntity(JournalEntity journalEntity) {
  return journalEntity.map(
    habitCompletion: (_) => 'habit_completion',
    journalAudio: (_) => 'audio',
    journalEntry: (_) => 'text_entries',
    journalImage: (_) => 'images',
    measurement: (_) => 'measurement',
    quantitative: (_) => 'quantitative',
    workout: (_) => 'workout',
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
    measurement: (_) => 'measurement',
    quantitative: (_) => 'quantitative',
    workout: (_) => 'workout',
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
      final df = DateFormat('yyyy-MM-dd');
      final dateSubFolder = df.format(journalEntity.meta.createdAt);
      final folder = folderForJournalEntity(journalEntity);
      final entityType = typeSuffix(journalEntity);
      final fileName = '${journalEntity.meta.id}.$entityType.json';
      return '${docDir.path}/$folder/$dateSubFolder/$fileName';
    },
  );
}

Future<void> saveJournalEntityJson(JournalEntity journalEntity) async {
  final json = jsonEncode(journalEntity);
  final docDir = await getApplicationDocumentsDirectory();
  final path = entityPath(journalEntity, docDir);
  final file = await File(path).create(recursive: true);
  await file.writeAsString(json);
}

Future<String> createAssetDirectory(String relativePath) async {
  final docDir = await getApplicationDocumentsDirectory();
  final directory =
      await Directory('${docDir.path}$relativePath').create(recursive: true);
  return directory.path;
}
