import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

part 'fts5_db.g.dart';

const fts5DbFileName = 'fts5_db.sqlite';

@DriftDatabase(include: {'fts5_db.drift'})
class Fts5Db extends _$Fts5Db {
  Fts5Db({
    this.inMemoryDatabase = false,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : super(
         openDbConnection(
           fts5DbFileName,
           inMemoryDatabase: inMemoryDatabase,
           documentsDirectoryProvider: documentsDirectoryProvider,
           tempDirectoryProvider: tempDirectoryProvider,
         ),
       );

  final bool inMemoryDatabase;

  @override
  int get schemaVersion => 1;

  Stream<List<String>> watchFullTextMatches(String query) {
    return findMatching(query).watch();
  }

  Future<void> insertText(
    JournalEntity entry, {
    bool removePrevious = false,
  }) async {
    final uuid = entry.meta.id;

    if (removePrevious) {
      await deleteEntry('"$uuid"');
    }

    final plainText = entry.entryText?.plainText ?? '';
    final title = entry.maybeMap(
      task: (task) => task.data.title,
      survey: (survey) => survey.data.taskResult.identifier,
      orElse: () => '',
    );

    final summary = entry.maybeMap(
      measurement: (m) {
        // Resolved lazily so non-measurement indexing (incl. seeding a
        // non-active world through WorldHandle) never touches the active
        // generation's cache.
        final dataType = getIt<EntitiesCacheService>().getDataTypeById(
          m.data.dataTypeId,
        );
        // A choice recording indexes the choice's title, so searching for
        // "clear" finds the hydration entry; a number keeps value and unit.
        final value = dataType == null
            ? '${m.data.value}'
            : measurementValueLabel(m.data, dataType);
        return '${dataType?.displayName} $value';
      },
      survey: (survey) {
        final scores = survey.data.calculatedScores.entries.map(
          (mapEntry) => '${mapEntry.key}: ${mapEntry.value}',
        );
        return scores.join('\n');
      },
      quantitative: (q) {
        final healthType = healthTypes[q.data.dataType];
        final unit = healthType?.unit ?? q.data.unit;
        final displayName = healthType?.displayName ?? q.data.dataType;

        return '${q.data.value} $unit $displayName';
      },
      orElse: () => '',
    );

    if (plainText.trim().isNotEmpty ||
        title.trim().isNotEmpty ||
        summary.trim().isNotEmpty) {
      await insertJournalEntry(
        plainText,
        title,
        summary,
        '',
        uuid,
      );
    }
  }
}
