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
      // match the complete printed code as well as the type. Remote errors
      // print extended codes (e.g. 787 for FOREIGN KEY); SQLite stores the
      // primary result code in the low byte. Anchor at the exception header
      // so SQL text or parameters cannot masquerade as a constraint error.
      final resultCode = ex is SqliteException
          ? ex.resultCode
          : int.tryParse(
              RegExp(
                    r'^SqliteException\((\d+)\)',
                  ).firstMatch(ex.toString())?.group(1) ??
                  '',
            );
      final isConstraintViolation =
          resultCode != null && (resultCode & 0xff) == 19;
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

  /// Every live label definition, private ones included, whatever this
  /// device's privacy toggle says.
  Future<List<LabelDefinition>>
  getAllLabelDefinitionsIncludingPrivate() async =>
      labelDefinitionsStreamMapper(await allLabelDefinitions().get());

  Future<LabelDefinition?> getLabelDefinitionById(String id) async {
    final result = await _queryWithPrivateFilter(
      allPrivate: () => labelDefinitionById(id).get(),
      filtered: (s) => labelDefinitionByIdByPrivateStatuses(id, s).get(),
    );
    return labelDefinitionsStreamMapper(result).firstOrNull;
  }

  /// Every live speech dictionary entry, ordered by term.
  Future<List<SpeechDictionaryEntry>> getAllSpeechDictionaryEntries() async =>
      speechDictionaryEntriesStreamMapper(
        await allSpeechDictionaryEntries().get(),
      );

  /// Every speech dictionary entry, tombstones included — what the migration
  /// must see so it never writes a term the user deleted.
  Future<List<SpeechDictionaryEntry>>
  getSpeechDictionaryEntriesIncludingDeleted() async =>
      speechDictionaryEntriesStreamMapper(
        await speechDictionaryEntriesIncludingDeleted().get(),
      );

  /// The entry with [id], deleted or not, or null when there is none.
  Future<SpeechDictionaryEntry?> getSpeechDictionaryEntryById(
    String id,
  ) async => speechDictionaryEntriesStreamMapper(
    await speechDictionaryEntryByIdIncludingDeleted(id).get(),
  ).firstOrNull;

  Future<List<CategoryDefinition>> getAllCategories() async {
    return categoryDefinitionsStreamMapper(
      await allCategoryDefinitions().get(),
    );
  }

  /// Every live category, private ones included, whatever this device's
  /// privacy toggle says — for work on the data rather than its display.
  Future<List<CategoryDefinition>> getAllCategoriesIncludingPrivate() async =>
      categoryDefinitionsStreamMapper(
        await allCategoryDefinitionsIncludingPrivate().get(),
      );

  Future<List<HabitDefinition>> getAllHabitDefinitions() async {
    return habitDefinitionsStreamMapper(
      await allHabitDefinitions().get(),
    );
  }

  /// Every habit that is not deleted, private ones included whatever the
  /// `private` flag says — for work about the user's own reminders, which
  /// hiding private entries from view must not silence or skip.
  Future<List<HabitDefinition>> getAllHabitDefinitionsAllPrivate() async {
    return habitDefinitionsStreamMapper(
      await allHabitDefinitionsAllPrivate().get(),
    );
  }

  Future<List<DashboardDefinition>> getAllDashboards() async {
    return dashboardStreamMapper(await allDashboards().get());
  }

  Future<CategoryDefinition?> getCategoryById(String id) async {
    final rows = await categoryById(id).get();
    return categoryDefinitionsStreamMapper(rows).firstOrNull;
  }

  /// Reads a non-deleted category definition without applying the
  /// private-entry visibility gate.
  ///
  /// The categories counterpart of [getHabitByIdForIntegrity]: for a caller
  /// that already holds a reference to the category — headless prompt
  /// assembly reaches a task through the unfiltered `journalEntityById` and
  /// must see that task's category the same way. The privacy toggle hides
  /// things from a screen, not from an agent that already has the task.
  /// Never a discovery surface.
  Future<CategoryDefinition?> getCategoryByIdForIntegrity(String id) async {
    final rows =
        await (select(categoryDefinitions)..where(
              (definition) =>
                  definition.id.equals(id) & definition.deleted.equals(false),
            ))
            .get();
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
      table: measurableTypes,
      write: (definition) => into(measurableTypes).insertOnConflictUpdate(
        measurableDbEntity(definition as MeasurableDataType),
      ),
    );
  }

  Future<int> upsertHabitDefinition(HabitDefinition habitDefinition) {
    return _upsertDefinitionIfNotOlder(
      habitDefinition,
      table: habitDefinitions,
      write: (definition) => into(habitDefinitions).insertOnConflictUpdate(
        habitDefinitionDbEntity(definition as HabitDefinition),
      ),
    );
  }

  Future<int> upsertDashboardDefinition(
    DashboardDefinition dashboardDefinition,
  ) {
    return _upsertDefinitionIfNotOlder(
      dashboardDefinition,
      table: dashboardDefinitions,
      write: (definition) => into(dashboardDefinitions).insertOnConflictUpdate(
        dashboardDefinitionDbEntity(definition as DashboardDefinition),
      ),
    );
  }

  Future<int> upsertCategoryDefinition(
    CategoryDefinition categoryDefinition,
  ) {
    return _upsertDefinitionIfNotOlder(
      categoryDefinition,
      table: categoryDefinitions,
      write: (definition) => into(categoryDefinitions).insertOnConflictUpdate(
        categoryDefinitionDbEntity(definition as CategoryDefinition),
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
      speechDictionaryEntry: upsertSpeechDictionaryEntry,
    );
    return linesAffected;
  }

  Future<int> upsertSpeechDictionaryEntry(SpeechDictionaryEntry entry) {
    return _upsertDefinitionIfNotOlder(
      entry,
      table: speechDictionaryEntries,
      write: (definition) =>
          into(speechDictionaryEntries).insertOnConflictUpdate(
            speechDictionaryEntryDbEntity(definition as SpeechDictionaryEntry),
          ),
    );
  }

  Future<int> upsertLabelDefinition(
    LabelDefinition labelDefinition,
  ) {
    return _upsertDefinitionIfNotOlder(
      labelDefinition,
      table: labelDefinitions,
      write: (definition) => into(labelDefinitions).insertOnConflictUpdate(
        labelDefinitionDbEntity(definition as LabelDefinition),
      ),
    );
  }

  /// Every definition table, in the order [definitionById] searches them.
  List<TableInfo<Table, Object?>> get _definitionTables => [
    categoryDefinitions,
    labelDefinitions,
    habitDefinitions,
    dashboardDefinitions,
    measurableTypes,
    speechDictionaryEntries,
  ];

  TableInfo<Table, Object?> _tableOf(EntityDefinition definition) =>
      definition.map<TableInfo<Table, Object?>>(
        measurableDataType: (_) => measurableTypes,
        habit: (_) => habitDefinitions,
        dashboard: (_) => dashboardDefinitions,
        categoryDefinition: (_) => categoryDefinitions,
        labelDefinition: (_) => labelDefinitions,
        speechDictionaryEntry: (_) => speechDictionaryEntries,
      );

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

  /// The definition stored under [id], whichever kind it is, deleted and
  /// private ones included — what a backfill request for one of its
  /// counters is answered with. Null when no table holds [id], or when the
  /// stored document no longer parses.
  Future<EntityDefinition?> definitionById(String id) async {
    for (final table in _definitionTables) {
      final serialized = await _serializedById(table, id);
      if (serialized == null) continue;
      try {
        return EntityDefinition.fromJson(
          json.decode(serialized) as Map<String, dynamic>,
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Every stored definition that carries no vector clock, deleted and
  /// private ones included: what the manual clock migration stamps. A
  /// document that no longer parses is left out — it cannot be re-sent.
  Future<List<EntityDefinition>> clocklessDefinitions() async {
    final clockless = <EntityDefinition>[];
    for (final table in _definitionTables) {
      final rows = await customSelect(
        'SELECT serialized FROM ${table.actualTableName} '
        r"WHERE json_type(serialized, '$.vectorClock') IS NULL "
        r"OR json_type(serialized, '$.vectorClock') = 'null'",
        readsFrom: {table},
      ).get();
      for (final row in rows) {
        try {
          clockless.add(
            EntityDefinition.fromJson(
              json.decode(row.read<String>('serialized'))
                  as Map<String, dynamic>,
            ),
          );
        } catch (_) {
          // Unparseable legacy document: nothing to stamp or send.
        }
      }
    }
    return clockless;
  }

  /// Writes [incoming] where the recency gate lets it, and keeps the stored
  /// clock the join of every version the row has met.
  ///
  /// Definitions replicate as whole documents, each local write carrying
  /// the next own counter on top of the stored clock (DefinitionClocks.tla):
  ///
  /// - a version whose clock dominates the stored one is written, one the
  ///   stored clock dominates — a late or repeated arrival — is not;
  /// - two concurrent versions are settled last-writer-wins: the later
  ///   `updatedAt`, then the greater content (the document without its
  ///   clock), so every device keeps the same one whatever the arrival
  ///   order. The kept version is stored under the join of both clocks,
  ///   strictly greater than either, so the resolution spends no counter and
  ///   sends nothing;
  /// - a row written by an older build carries no clock. A clockless copy
  ///   never displaces a clocked row; a clockless row meets any copy by
  ///   `updatedAt` and content alone, and when it is kept against a clocked
  ///   copy the caller stamps it on top of that copy's clock.
  ///
  /// Only `updatedAt` and `vectorClock` of the stored document are decoded,
  /// never the whole document, which for legacy dashboards may not parse;
  /// the join is written into the stored JSON in place. Read and write share
  /// one transaction so the decision cannot interleave with another writer.
  /// Returns the write's result, or 0 when [incoming] was not written.
  Future<int> _upsertDefinitionIfNotOlder(
    EntityDefinition incoming, {
    required TableInfo<Table, Object?> table,
    required Future<int> Function(EntityDefinition definition) write,
  }) {
    return transaction(() async {
      final storedSerialized = await _serializedById(table, incoming.id);
      if (storedSerialized == null) return write(incoming);
      final stored = json.decode(storedSerialized) as Map<String, dynamic>;
      final decision = _decide(incoming, stored);
      switch (decision) {
        case _Write():
          return write(incoming);
        case _WriteJoined(:final clock):
          return write(incoming.copyWith(vectorClock: clock));
        case _KeepJoined(:final clock):
          await customUpdate(
            'UPDATE ${table.actualTableName} '
            r"SET serialized = json_set(serialized, '$.vectorClock', "
            'json(?)) WHERE id = ?',
            variables: [
              Variable.withString(jsonEncode(clock.toJson())),
              Variable.withString(incoming.id),
            ],
            updates: {table},
          );
        case _Keep():
      }
      DevLogger.log(
        name: 'JournalDb',
        message:
            'Kept stored definition ${incoming.id}: '
            'incoming ${incoming.updatedAt.toIso8601String()} '
            '${incoming.vectorClock?.canonicalKey} vs stored '
            '${stored['updatedAt']} ${_stampOf(stored).vectorClock?.canonicalKey}',
      );
      return 0;
    });
  }

  /// The `updatedAt` and `vectorClock` of the stored copy of [definition],
  /// or null when no row exists. Reads by id with no `deleted`/`private`
  /// filter — the same view the recency gate uses — so a local write can
  /// build a version that supersedes what is stored.
  Future<DefinitionStamp?> definitionStamp(EntityDefinition definition) async {
    final serialized = await _serializedById(
      _tableOf(definition),
      definition.id,
    );
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

  /// What the gate does with [incoming] against the [stored] document.
  static _GateDecision _decide(
    EntityDefinition incoming,
    Map<String, dynamic> stored,
  ) {
    final storedClock = _stampOf(stored).vectorClock;
    final incomingClock = incoming.vectorClock;
    if (incomingClock == null) {
      return storedClock == null && _isLater(incoming, stored)
          ? const _Write()
          : const _Keep();
    }
    if (storedClock == null) {
      return _isLater(incoming, stored) ? const _Write() : const _Keep();
    }
    switch (VectorClock.compare(storedClock, incomingClock)) {
      case VclockStatus.b_gt_a:
        return const _Write();
      case VclockStatus.a_gt_b:
      case VclockStatus.equal:
        return const _Keep();
      case VclockStatus.concurrent:
        final joined = VectorClock.merge(storedClock, incomingClock);
        return _isLater(incoming, stored)
            ? _WriteJoined(joined)
            : _KeepJoined(joined);
    }
  }

  /// Last-writer-wins between [incoming] and the [stored] document: the
  /// later `updatedAt`, then, on an exact tie, the greater content — the
  /// canonical JSON without the clock, which differs between devices that
  /// joined different clocks into the same version. Identical content counts
  /// as later, so a clockless re-delivery of the stored version applies.
  static bool _isLater(EntityDefinition incoming, Map<String, dynamic> stored) {
    final storedUpdatedAt = _stampOf(stored).updatedAt;
    if (storedUpdatedAt == null) return true;
    if (!incoming.updatedAt.isAtSameMomentAs(storedUpdatedAt)) {
      return incoming.updatedAt.isAfter(storedUpdatedAt);
    }
    String content(Map<String, dynamic> document) =>
        jsonEncode(Map<String, dynamic>.of(document)..remove('vectorClock'));
    return content(
          json.decode(jsonEncode(incoming)) as Map<String, dynamic>,
        ).compareTo(content(stored)) >=
        0;
  }
}

/// What the recency gate compares: the stored document's `updatedAt` (null
/// only for a document that has none, which no writer produces) and its
/// `vectorClock`.
typedef DefinitionStamp = ({DateTime? updatedAt, VectorClock? vectorClock});

/// The recency gate's verdict on an incoming definition.
sealed class _GateDecision {
  const _GateDecision();
}

/// Write the incoming version as it is.
final class _Write extends _GateDecision {
  const _Write();
}

/// Write the incoming version under the join of both clocks.
final class _WriteJoined extends _GateDecision {
  const _WriteJoined(this.clock);

  final VectorClock clock;
}

/// Keep the stored version, under the join of both clocks.
final class _KeepJoined extends _GateDecision {
  const _KeepJoined(this.clock);

  final VectorClock clock;
}

/// Keep the stored version unchanged.
final class _Keep extends _GateDecision {
  const _Keep();
}
