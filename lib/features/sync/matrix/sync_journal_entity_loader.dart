import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/utils/file_utils.dart';

/// Abstraction for loading journal entities and related attachments when
/// processing sync messages.
abstract class SyncJournalEntityLoader {
  Directory? get documentsDirectory;

  Future<JournalEntity> load({
    required String jsonPath,
    VectorClock? incomingVectorClock,
  });
}

/// Loads journal entities from the documents directory on disk.
class FileSyncJournalEntityLoader implements SyncJournalEntityLoader {
  const FileSyncJournalEntityLoader({this.documentsDirectory});

  @override
  final Directory? documentsDirectory;

  @override
  Future<JournalEntity> load({
    required String jsonPath,
    VectorClock? incomingVectorClock,
  }) async {
    final documentsDirectory =
        this.documentsDirectory ?? getDocumentsDirectory();
    final candidateFile = resolveJsonCandidateFileInDirectory(
      jsonPath,
      documentsDirectory,
    );
    final jsonString = await candidateFile.readAsString();
    return JournalEntity.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}
