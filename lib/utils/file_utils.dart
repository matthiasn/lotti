import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
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

Future<void> saveJson(String path, String json) async {
  // Ensure parent directory exists
  final target = File(path);
  await target.parent.create(recursive: true);

  // Write to a temporary file first, then atomically rename to the target.
  // This avoids readers observing an empty or partially-written file.
  final tmpPath = '$path.tmp.${DateTime.now().microsecondsSinceEpoch}.$pid';
  final tmpFile = File(tmpPath);
  await tmpFile.writeAsString(json, flush: true);

  // Attempt an atomic rename in-place. On POSIX this replaces the target.
  // On Windows, rename fails if the target exists; in that case fall back to
  // a controlled replacement while keeping the primary path atomic where possible.
  try {
    await tmpFile.rename(path);
  } on FileSystemException catch (_) {
    // Best-effort fallback for platforms that don't allow overwrite.
    String? bakPath;
    var movedAside = false;
    try {
      bakPath = '$path.bak.${DateTime.now().microsecondsSinceEpoch}.$pid';
      // Try moving the existing target aside if it exists; ignore errors.
      try {
        await target.rename(bakPath);
        movedAside = true;
      } catch (_) {
        // If the target didn't exist or couldn't be moved, continue.
      }
      await tmpFile.rename(path);
      // Final rename succeeded; if we did move the target aside, try to
      // remove the backup to avoid accumulating .bak files.
      if (movedAside) {
        try {
          await File(bakPath).delete();
        } catch (_) {
          // Swallow cleanup errors.
        }
      }
    } catch (e) {
      // Cleanup tmp file to avoid leaving temporary files behind.
      try {
        await tmpFile.delete();
      } catch (_) {
        // Ignore cleanup failures.
      }
      // Attempt to restore the original file from backup if we moved it aside.
      try {
        if (movedAside && bakPath != null) {
          await File(bakPath).rename(path);
        }
      } catch (_) {
        // Ignore restore errors; do not mask the original exception.
      }
      // Do not mask the original error.
      rethrow;
    }
  }
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
