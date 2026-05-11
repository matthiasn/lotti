// ignore_for_file: one_member_abstracts

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as path;

/// Abstraction for loading journal entities and related attachments when
/// processing sync messages.
abstract class SyncJournalEntityLoader {
  Future<JournalEntity> load({
    required String jsonPath,
    VectorClock? incomingVectorClock,
  });
}

/// Loads journal entities from the documents directory on disk.
class FileSyncJournalEntityLoader implements SyncJournalEntityLoader {
  const FileSyncJournalEntityLoader();

  @override
  Future<JournalEntity> load({
    required String jsonPath,
    VectorClock? incomingVectorClock,
  }) async {
    final candidateFile = resolveJsonCandidateFile(jsonPath);
    final docPath = path.normalize(getDocumentsDirectory().path);
    final jsonRelative = path.relative(candidateFile.path, from: docPath);
    return readEntityFromJson(jsonRelative);
  }
}
