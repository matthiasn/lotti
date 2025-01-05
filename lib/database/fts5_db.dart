import 'package:drift/drift.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/tags_service.dart';

part 'fts5_db.g.dart';

const fts5DbFileName = 'fts5_db.sqlite';

@DriftDatabase(include: {'fts5_db.drift'})
class Fts5Db extends _$Fts5Db {
  Fts5Db({this.inMemoryDatabase = false})
      : super(
          openDbConnection(
            fts5DbFileName,
            inMemoryDatabase: inMemoryDatabase,
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

    // TODO: add test that previous entry is removed
    if (removePrevious) {
      await deleteEntry('"$uuid"');
    }

    final tagsService = getIt<TagsService>();
    final entitiesCacheService = getIt<EntitiesCacheService>();

    final plainText = entry.entryText?.plainText ?? '';
    final title = entry.maybeMap(
      task: (task) => task.data.title,
      survey: (survey) => survey.data.taskResult.identifier,
      orElse: () => '',
    );

    final summary = entry.maybeMap(
      measurement: (m) {
        final dataType =
            entitiesCacheService.getDataTypeById(m.data.dataTypeId);
        final value = m.data.value;
        return '${dataType?.displayName} $value ${dataType?.unitName}';
      },
      survey: (survey) {
        final scores = survey.data.calculatedScores.entries
            .map((mapEntry) => '${mapEntry.key}: ${mapEntry.value}');
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

    final tagsString = entry.meta.tagIds
        ?.map((tagId) => tagsService.getTagById(tagId)?.tag ?? '')
        .join(' , ');

    if (plainText.trim().isNotEmpty ||
        title.trim().isNotEmpty ||
        summary.trim().isNotEmpty) {
      await insertJournalEntry(
        plainText,
        title,
        summary,
        tagsString ?? '',
        uuid,
      );
    }
  }
}
