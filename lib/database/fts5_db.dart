import 'package:drift/drift.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';

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

  Future<void> insertText(JournalEntity entry) async {
    final plainText = entry.entryText?.plainText ?? '';
    final title = entry.maybeMap(
      task: (task) => task.data.title,
      survey: (survey) => survey.data.taskResult.identifier,
      orElse: () => '',
    );

    final summary = await entry.maybeMap(
      measurement: (m) async {
        final dataType = await getIt<JournalDb>()
            .getMeasurableDataTypeById(m.data.dataTypeId);
        final value = m.data.value;
        return '${dataType?.displayName} $value ${dataType?.unitName}';
      },
      survey: (survey) async {
        final scores = survey.data.calculatedScores.entries
            .map((mapEntry) => '${mapEntry.key}: ${mapEntry.value}');
        return scores.join('\n');
      },
      quantitative: (q) async {
        final healthType = healthTypes[q.data.dataType];
        final unit = healthType?.unit ?? q.data.unit;
        final displayName = healthType?.displayName ?? q.data.dataType;

        return '${q.data.value} $unit $displayName';
      },
      orElse: () async => '',
    );

    final uuid = entry.meta.id;

    if (plainText.trim().isNotEmpty ||
        title.trim().isNotEmpty ||
        summary.trim().isNotEmpty) {
      await insertJournalEntry(
        plainText,
        title,
        summary,
        uuid,
      );
    }
  }
}
