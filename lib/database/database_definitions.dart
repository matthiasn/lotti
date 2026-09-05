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

  /// Reads a non-deleted habit definition without applying the private-entry
  /// visibility gate.
  ///
  /// This is an integrity lookup for already-persisted references, not a
  /// discovery surface: callers use it to distinguish a hidden private habit
  /// from one that was deleted or deactivated while an editor was open.
  Future<HabitDefinition?> getHabitByIdForIntegrity(String id) async {
    final rows =
        await (select(habitDefinitions)..where(
              (definition) =>
                  definition.id.equals(id) & definition.deleted.equals(false),
            ))
            .get();
    return habitDefinitionsStreamMapper(rows).firstOrNull;
  }

  Future<DashboardDefinition?> getDashboardById(String id) async {
    final rows = await dashboardById(id).get();
    return dashboardStreamMapper(rows).firstOrNull;
  }

  Future<int> upsertMeasurableDataType(
    MeasurableDataType entityDefinition,
  ) {
    return _upsertDefinitionIfNotOlder(
      entityDefinition,
      readExistingSerialized: () => _serializedById(
        measurableTypes,
        entityDefinition.id,
      ),
      write: () => into(
        measurableTypes,
      ).insertOnConflictUpdate(measurableDbEntity(entityDefinition)),
    );
  }

  Future<int> upsertHabitDefinition(HabitDefinition habitDefinition) {
    return _upsertDefinitionIfNotOlder(
      habitDefinition,
      readExistingSerialized: () => _serializedById(
        habitDefinitions,
        habitDefinition.id,
      ),
      write: () => into(
        habitDefinitions,
      ).insertOnConflictUpdate(habitDefinitionDbEntity(habitDefinition)),
    );
  }

  Future<int> upsertDashboardDefinition(
    DashboardDefinition dashboardDefinition,
  ) {
    return _upsertDefinitionIfNotOlder(
      dashboardDefinition,
      readExistingSerialized: () => _serializedById(
        dashboardDefinitions,
        dashboardDefinition.id,
      ),
      write: () => into(dashboardDefinitions).insertOnConflictUpdate(
        dashboardDefinitionDbEntity(dashboardDefinition),
      ),
    );
  }

  Future<int> upsertCategoryDefinition(
    CategoryDefinition categoryDefinition,
  ) {
    return _upsertDefinitionIfNotOlder(
      categoryDefinition,
      readExistingSerialized: () => _serializedById(
        categoryDefinitions,
        categoryDefinition.id,
      ),
      write: () => into(categoryDefinitions).insertOnConflictUpdate(
        categoryDefinitionDbEntity(categoryDefinition),
      ),
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
  ) {
    return _upsertDefinitionIfNotOlder(
      labelDefinition,
      readExistingSerialized: () => _serializedById(
        labelDefinitions,
        labelDefinition.id,
      ),
      write: () => into(
        labelDefinitions,
      ).insertOnConflictUpdate(labelDefinitionDbEntity(labelDefinition)),
    );
  }

  /// The stored JSON document for [id] in [table], or null when absent.
  ///
  /// Reads by primary key with no `deleted`/`private` filter: the recency
  /// gate must see a deleted-but-newer row, or an older live copy arriving
  /// late would resurrect it.
  Future<String?> _serializedById<T extends Table, R>(
    TableInfo<T, R> table,
    String id,
  ) async {
    final row = await customSelect(
      'SELECT serialized FROM ${table.actualTableName} WHERE id = ?',
      variables: [Variable.withString(id)],
      readsFrom: {table},
    ).getSingleOrNull();
    return row?.read<String>('serialized');
  }

  /// Writes [incoming] unless the stored definition is strictly newer.
  ///
  /// Definitions replicate as whole documents and the local edit paths
  /// refresh `updatedAt` so that "the later edit wins" on sync. This is
  /// where that rule is enforced: an older definition arriving late — a
  /// delayed sync event, a historical re-send — must not overwrite a newer
  /// local one, and an older live copy must not resurrect a newer deletion.
  /// When both sides carry a vector clock that orders them, the clock
  /// decides; otherwise `updatedAt` does, and an exact tie applies
  /// [incoming] so a local re-save never silently disappears.
  ///
  /// Only `updatedAt` and `vectorClock` of the stored document are decoded,
  /// never the whole document, which for legacy dashboards may not parse.
  /// Read and write share one transaction so the decision cannot interleave
  /// with another writer. Returns the write's result, or 0 when skipped.
  Future<int> _upsertDefinitionIfNotOlder(
    EntityDefinition incoming, {
    required Future<String?> Function() readExistingSerialized,
    required Future<int> Function() write,
  }) {
    return transaction(() async {
      final existingSerialized = await readExistingSerialized();
      if (existingSerialized != null) {
        final existing =
            json.decode(existingSerialized) as Map<String, dynamic>;
        if (_definitionIsOlder(incoming, than: existing)) {
          DevLogger.log(
            name: 'JournalDb',
            message:
                'Skipping older definition ${incoming.id}: '
                'incoming ${incoming.updatedAt.toIso8601String()} '
                'vs stored ${existing['updatedAt']}',
          );
          return 0;
        }
      }
      return write();
    });
  }

  /// The `updatedAt` and `vectorClock` of the stored copy of [definition],
  /// or null when no row exists. Reads by id with no `deleted`/`private`
  /// filter — the same view the recency gate uses — so a caller whose write
  /// was refused can build a copy that is genuinely newer than what is
  /// stored.
  Future<DefinitionStamp?> definitionStamp(EntityDefinition definition) async {
    final table = definition.map<TableInfo<Table, Object?>>(
      measurableDataType: (_) => measurableTypes,
      habit: (_) => habitDefinitions,
      dashboard: (_) => dashboardDefinitions,
      categoryDefinition: (_) => categoryDefinitions,
      labelDefinition: (_) => labelDefinitions,
    );
    final serialized = await _serializedById(table, definition.id);
    if (serialized == null) return null;
    return _stampOf(json.decode(serialized) as Map<String, dynamic>);
  }

  static DefinitionStamp _stampOf(Map<String, dynamic> stored) {
    final updatedAt = stored['updatedAt'];
    final vectorClock = stored['vectorClock'];
    return (
      updatedAt: updatedAt is String ? DateTime.tryParse(updatedAt) : null,
      vectorClock: vectorClock is Map<String, dynamic>
          ? VectorClock.fromJson(vectorClock)
          : null,
    );
  }

  static bool _definitionIsOlder(
    EntityDefinition incoming, {
    required Map<String, dynamic> than,
  }) {
    final stored = _stampOf(than);
    final incomingClock = incoming.vectorClock;
    final storedClock = stored.vectorClock;
    if (incomingClock != null && storedClock != null) {
      switch (VectorClock.compare(storedClock, incomingClock)) {
        case VclockStatus.a_gt_b:
          return true;
        case VclockStatus.b_gt_a:
          return false;
        case VclockStatus.equal:
        case VclockStatus.concurrent:
          break;
      }
    }
    final storedUpdatedAt = stored.updatedAt;
    return storedUpdatedAt != null &&
        incoming.updatedAt.isBefore(storedUpdatedAt);
  }
}

/// What the recency gate compares: the stored document's `updatedAt` (null
/// only for a document that has none, which no writer produces) and its
/// `vectorClock`.
typedef DefinitionStamp = ({DateTime? updatedAt, VectorClock? vectorClock});
