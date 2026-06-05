part of 'database.dart';

/// Entity-definition surface for [JournalDb]: measurable, habit,
/// dashboard, category, and label definition lookups and upserts, plus
/// label-assignment bookkeeping on the `labeled` join table.
mixin _JournalDbDefinitions on _$JournalDb, _JournalDbConfigFlags {
  Future<void> insertLabel(String journalId, String labelId) async {
    try {
      await into(labeled).insert(
        LabeledWith(
          id: uuid.v1(),
          journalId: journalId,
          labelId: labelId,
        ),
      );
    } catch (ex) {
      // SQLITE_CONSTRAINT (19) covers the duplicate (journal_id, label_id)
      // pair — re-applying labels must stay idempotent — and FK failures
      // when the label definition has not arrived via sync yet. Those were
      // always tolerated; anything else now propagates so addLabeled's
      // transaction rolls back instead of committing a partial reconcile.
      // Drift can wrap SqliteException when running through an isolate, so
      // match the printed form as well as the type.
      final isConstraintViolation =
          (ex is SqliteException && ex.resultCode == 19) ||
          ex.toString().contains('SqliteException(19');
      if (!isConstraintViolation) rethrow;
      DevLogger.error(
        name: 'JournalDb',
        message: 'insertLabel failed',
        error: ex,
      );
    }
  }

  Future<Set<String>> _labelIdsForJournalId(String journalId) async {
    final existing = await labeledForJournal(journalId).get();
    return existing.toSet();
  }

  Future<void> addLabeled(JournalEntity journalEntity) async {
    final journalId = journalEntity.meta.id;
    final targetLabelIds = journalEntity.meta.labelIds?.toSet() ?? {};
    final currentLabelIds = await _labelIdsForJournalId(journalId);

    final labelsToAdd = targetLabelIds.difference(currentLabelIds);
    final labelsToRemove = currentLabelIds.difference(targetLabelIds);
    await transaction(() async {
      for (final labelId in labelsToAdd) {
        await insertLabel(journalId, labelId);
      }

      for (final labelId in labelsToRemove) {
        await deleteLabeledRow(journalId, labelId);
      }
    });
  }

  Future<int> getLabeledCount() async {
    return (await countLabeled().get()).first;
  }

  Future<MeasurableDataType?> getMeasurableDataTypeById(String id) async {
    final res = await measurableTypeById(id).get();
    return res.map(measurableDataType).firstOrNull;
  }

  Future<List<MeasurableDataType>> getAllMeasurableDataTypes() async {
    return measurableDataTypeStreamMapper(
      await activeMeasurableTypes().get(),
    );
  }

  /// Snapshot version of label usage statistics for prompt construction or
  /// one-off queries.
  ///
  /// Only counts labels on visible journal entries: soft-deleted entries are
  /// excluded, and private entries only count while the `private` config flag
  /// is enabled (the same `private IN (0, flag)` gate the definition queries
  /// in `database.drift` use), so usage stats can neither overcount nor leak
  /// hidden-entry volume.
  Future<Map<String, int>> getLabelUsageCounts() async {
    final query = customSelect(
      '''
      SELECT l.label_id AS label_id, COUNT(*) AS usage_count
      FROM labeled l
      INNER JOIN journal j ON j.id = l.journal_id
      WHERE j.deleted = FALSE
        AND j.private IN (0, (SELECT status FROM config_flags WHERE name = 'private'))
      GROUP BY l.label_id
      ''',
      readsFrom: {labeled, journal, configFlags},
    );

    final rows = await query.get();
    final usage = <String, int>{};
    for (final row in rows) {
      usage[row.read<String>('label_id')] = row.read<int>('usage_count');
    }
    return usage;
  }

  /// Alias to snapshot method for clarity when used alongside the stream variant.
  Future<Map<String, int>> getLabelUsageCountsSnapshot() =>
      getLabelUsageCounts();

  Future<List<LabelDefinition>> getAllLabelDefinitions() async {
    final labels = await _queryWithPrivateFilter(
      allPrivate: () => allLabelDefinitions().get(),
      filtered: (s) => allLabelDefinitionsByPrivateStatuses(s).get(),
    );
    return labelDefinitionsStreamMapper(labels);
  }

  Future<LabelDefinition?> getLabelDefinitionById(String id) async {
    final result = await _queryWithPrivateFilter(
      allPrivate: () => labelDefinitionById(id).get(),
      filtered: (s) => labelDefinitionByIdByPrivateStatuses(id, s).get(),
    );
    return labelDefinitionsStreamMapper(result).firstOrNull;
  }

  Future<List<CategoryDefinition>> getAllCategories() async {
    return categoryDefinitionsStreamMapper(
      await allCategoryDefinitions().get(),
    );
  }

  Future<List<HabitDefinition>> getAllHabitDefinitions() async {
    return habitDefinitionsStreamMapper(
      await allHabitDefinitions().get(),
    );
  }

  Future<List<DashboardDefinition>> getAllDashboards() async {
    return dashboardStreamMapper(await allDashboards().get());
  }

  Future<CategoryDefinition?> getCategoryById(String id) async {
    final rows = await categoryById(id).get();
    return categoryDefinitionsStreamMapper(rows).firstOrNull;
  }

  Future<HabitDefinition?> getHabitById(String id) async {
    final rows = await habitById(id).get();
    return habitDefinitionsStreamMapper(rows).firstOrNull;
  }

  Future<DashboardDefinition?> getDashboardById(String id) async {
    final rows = await dashboardById(id).get();
    return dashboardStreamMapper(rows).firstOrNull;
  }

  Future<int> upsertMeasurableDataType(
    MeasurableDataType entityDefinition,
  ) async {
    return into(
      measurableTypes,
    ).insertOnConflictUpdate(measurableDbEntity(entityDefinition));
  }

  Future<int> upsertHabitDefinition(HabitDefinition habitDefinition) async {
    return into(
      habitDefinitions,
    ).insertOnConflictUpdate(habitDefinitionDbEntity(habitDefinition));
  }

  Future<int> upsertDashboardDefinition(
    DashboardDefinition dashboardDefinition,
  ) async {
    return into(dashboardDefinitions).insertOnConflictUpdate(
      dashboardDefinitionDbEntity(dashboardDefinition),
    );
  }

  Future<int> upsertCategoryDefinition(
    CategoryDefinition categoryDefinition,
  ) async {
    return into(categoryDefinitions).insertOnConflictUpdate(
      categoryDefinitionDbEntity(categoryDefinition),
    );
  }

  Future<int> upsertEntityDefinition(EntityDefinition entityDefinition) async {
    final linesAffected = await entityDefinition.map(
      measurableDataType: (MeasurableDataType measurableDataType) async {
        return upsertMeasurableDataType(measurableDataType);
      },
      habit: upsertHabitDefinition,
      dashboard: upsertDashboardDefinition,
      categoryDefinition: upsertCategoryDefinition,
      labelDefinition: upsertLabelDefinition,
    );
    return linesAffected;
  }

  Future<int> upsertLabelDefinition(
    LabelDefinition labelDefinition,
  ) async {
    return into(
      labelDefinitions,
    ).insertOnConflictUpdate(labelDefinitionDbEntity(labelDefinition));
  }
}
