import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/matrix/utils/atomic_write.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

Uuid uuid = const Uuid();

String folderForJournalEntity(JournalEntity journalEntity) {
  return journalEntity.map(
    habitCompletion: (_) => 'habit_completion',
    journalAudio: (_) => 'audio',
    journalEntry: (_) => 'text_entries',
    event: (_) => 'events',
    aiResponse: (_) => 'ai_responses',
    journalImage: (_) => 'images',
    measurement: (_) => 'measurement',
    quantitative: (_) => 'quantitative',
    workout: (_) => 'workout',
    survey: (_) => 'surveys',
    task: (_) => 'tasks',
    checklist: (_) => 'checklist',
    checklistItem: (_) => 'checklist_item',
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
    event: (_) => 'event',
    aiResponse: (_) => 'ai_response',
    checklist: (_) => 'checklist',
    checklistItem: (_) => 'checklist_item',
  );
}

String entityPath(JournalEntity journalEntity, Directory docDir) {
  return '${docDir.path}${relativeEntityPath(journalEntity)}';
}

String relativeEntityPath(JournalEntity journalEntity) {
  return journalEntity.maybeMap(
    journalImage: (JournalImage journalImage) =>
        '${getRelativeImagePath(journalImage)}.json',
    journalAudio: (journalAudio) =>
        '${AudioUtils.getRelativeAudioPath(journalAudio)}.json',
    orElse: () {
      final df = DateFormat('yyyy-MM-dd');
      final dateSubFolder = df.format(journalEntity.meta.createdAt);
      final folder = folderForJournalEntity(journalEntity);
      final entityType = typeSuffix(journalEntity);
      final fileName = '${journalEntity.meta.id}.$entityType.json';
      return '/$folder/$dateSubFolder/$fileName';
    },
  );
}

Future<void> saveJournalEntityJson(JournalEntity journalEntity) async {
  final json = jsonEncode(journalEntity);
  final docDir = getDocumentsDirectory();
  final path = entityPath(journalEntity, docDir);
  await saveJson(path, json);
}

/// Resolves a user-provided [jsonPath] against the app's documents directory,
/// ensuring it does not escape the sandbox. Returns a [File] pointing to the
/// normalized candidate path or throws [FileSystemException] if the resolved
/// path is outside the documents directory.
File resolveJsonCandidateFile(String jsonPath) {
  final docDir = getDocumentsDirectory();
  final normalized = normalize(jsonPath);
  final relative =
      normalized.startsWith(separator) ? normalized.substring(1) : normalized;
  final candidate = normalize(join(docDir.path, relative));
  final docPath = normalize(docDir.path);
  if (!isWithin(docPath, candidate) && docPath != candidate) {
    throw FileSystemException(
      'jsonPath resolves outside documents directory',
      jsonPath,
    );
  }
  return File(candidate);
}

Future<void> saveJson(String path, String json) async {
  // Ensure parent directory exists
  final target = File(path);
  await target.parent.create(recursive: true);
  // Use shared atomic writer; logging is optional to avoid hard dependency in tests
  final logger =
      getIt.isRegistered<LoggingService>() ? getIt<LoggingService>() : null;
  await atomicWriteString(
    text: json,
    filePath: path,
    logging: logger,
    subDomain: 'file_utils.saveJson',
  );
}

Future<String> createAssetDirectory(String relativePath) async {
  final docDir = getDocumentsDirectory();
  final directory =
      await Directory('${docDir.path}$relativePath').create(recursive: true);
  return directory.path;
}

Directory getDocumentsDirectory() {
  return getIt<Directory>();
}

Future<Directory> findDocumentsDirectory() async {
  final docDir = await getApplicationDocumentsDirectory();
  final appSupportDir = await getApplicationSupportDirectory();

  if (Platform.isWindows || Platform.isLinux) {
    return appSupportDir;
  } else {
    return docDir;
  }
}

Future<JournalEntity> readEntityFromJson(String jsonPath) async {
  final jsonString = await File(
    join(getDocumentsDirectory().path, jsonPath),
  ).readAsString();

  return JournalEntity.fromJson(
    jsonDecode(jsonString) as Map<String, dynamic>,
  );
}
