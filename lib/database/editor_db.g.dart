// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editor_db.dart';

// ignore_for_file: type=lint
class EditorDrafts extends Table
    with TableInfo<EditorDrafts, EditorDraftState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  EditorDrafts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _entryIdMeta =
      const VerificationMeta('entryId');
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
      'entry_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _lastSavedMeta =
      const VerificationMeta('lastSaved');
  late final GeneratedColumn<DateTime> lastSaved = GeneratedColumn<DateTime>(
      'last_saved', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _deltaMeta = const VerificationMeta('delta');
  late final GeneratedColumn<String> delta = GeneratedColumn<String>(
      'delta', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns =>
      [id, entryId, status, createdAt, lastSaved, delta];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'editor_drafts';
  @override
  VerificationContext validateIntegrity(Insertable<EditorDraftState> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(_entryIdMeta,
          entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta));
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_saved')) {
      context.handle(_lastSavedMeta,
          lastSaved.isAcceptableOrUnknown(data['last_saved']!, _lastSavedMeta));
    } else if (isInserting) {
      context.missing(_lastSavedMeta);
    }
    if (data.containsKey('delta')) {
      context.handle(
          _deltaMeta, delta.isAcceptableOrUnknown(data['delta']!, _deltaMeta));
    } else if (isInserting) {
      context.missing(_deltaMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EditorDraftState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EditorDraftState(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      entryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entry_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastSaved: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_saved'])!,
      delta: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}delta'])!,
    );
  }

  @override
  EditorDrafts createAlias(String alias) {
    return EditorDrafts(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(id)'];
  @override
  bool get dontWriteConstraints => true;
}

class EditorDraftState extends DataClass
    implements Insertable<EditorDraftState> {
  final String id;
  final String entryId;
  final String status;
  final DateTime createdAt;
  final DateTime lastSaved;
  final String delta;
  const EditorDraftState(
      {required this.id,
      required this.entryId,
      required this.status,
      required this.createdAt,
      required this.lastSaved,
      required this.delta});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entry_id'] = Variable<String>(entryId);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_saved'] = Variable<DateTime>(lastSaved);
    map['delta'] = Variable<String>(delta);
    return map;
  }

  EditorDraftsCompanion toCompanion(bool nullToAbsent) {
    return EditorDraftsCompanion(
      id: Value(id),
      entryId: Value(entryId),
      status: Value(status),
      createdAt: Value(createdAt),
      lastSaved: Value(lastSaved),
      delta: Value(delta),
    );
  }

  factory EditorDraftState.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EditorDraftState(
      id: serializer.fromJson<String>(json['id']),
      entryId: serializer.fromJson<String>(json['entry_id']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      lastSaved: serializer.fromJson<DateTime>(json['last_saved']),
      delta: serializer.fromJson<String>(json['delta']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entry_id': serializer.toJson<String>(entryId),
      'status': serializer.toJson<String>(status),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'last_saved': serializer.toJson<DateTime>(lastSaved),
      'delta': serializer.toJson<String>(delta),
    };
  }

  EditorDraftState copyWith(
          {String? id,
          String? entryId,
          String? status,
          DateTime? createdAt,
          DateTime? lastSaved,
          String? delta}) =>
      EditorDraftState(
        id: id ?? this.id,
        entryId: entryId ?? this.entryId,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        lastSaved: lastSaved ?? this.lastSaved,
        delta: delta ?? this.delta,
      );
  EditorDraftState copyWithCompanion(EditorDraftsCompanion data) {
    return EditorDraftState(
      id: data.id.present ? data.id.value : this.id,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastSaved: data.lastSaved.present ? data.lastSaved.value : this.lastSaved,
      delta: data.delta.present ? data.delta.value : this.delta,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EditorDraftState(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSaved: $lastSaved, ')
          ..write('delta: $delta')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, entryId, status, createdAt, lastSaved, delta);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EditorDraftState &&
          other.id == this.id &&
          other.entryId == this.entryId &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.lastSaved == this.lastSaved &&
          other.delta == this.delta);
}

class EditorDraftsCompanion extends UpdateCompanion<EditorDraftState> {
  final Value<String> id;
  final Value<String> entryId;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastSaved;
  final Value<String> delta;
  final Value<int> rowid;
  const EditorDraftsCompanion({
    this.id = const Value.absent(),
    this.entryId = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastSaved = const Value.absent(),
    this.delta = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EditorDraftsCompanion.insert({
    required String id,
    required String entryId,
    required String status,
    required DateTime createdAt,
    required DateTime lastSaved,
    required String delta,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        entryId = Value(entryId),
        status = Value(status),
        createdAt = Value(createdAt),
        lastSaved = Value(lastSaved),
        delta = Value(delta);
  static Insertable<EditorDraftState> custom({
    Expression<String>? id,
    Expression<String>? entryId,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastSaved,
    Expression<String>? delta,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entryId != null) 'entry_id': entryId,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (lastSaved != null) 'last_saved': lastSaved,
      if (delta != null) 'delta': delta,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EditorDraftsCompanion copyWith(
      {Value<String>? id,
      Value<String>? entryId,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<DateTime>? lastSaved,
      Value<String>? delta,
      Value<int>? rowid}) {
    return EditorDraftsCompanion(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastSaved: lastSaved ?? this.lastSaved,
      delta: delta ?? this.delta,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastSaved.present) {
      map['last_saved'] = Variable<DateTime>(lastSaved.value);
    }
    if (delta.present) {
      map['delta'] = Variable<String>(delta.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EditorDraftsCompanion(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSaved: $lastSaved, ')
          ..write('delta: $delta, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$EditorDb extends GeneratedDatabase {
  _$EditorDb(QueryExecutor e) : super(e);
  _$EditorDb.connect(DatabaseConnection c) : super.connect(c);
  $EditorDbManager get managers => $EditorDbManager(this);
  late final EditorDrafts editorDrafts = EditorDrafts(this);
  late final Index editorDraftsId = Index('editor_drafts_id',
      'CREATE INDEX editor_drafts_id ON editor_drafts (id)');
  late final Index editorDraftsEntryId = Index('editor_drafts_entry_id',
      'CREATE INDEX editor_drafts_entry_id ON editor_drafts (entry_id)');
  late final Index editorDraftsStatus = Index('editor_drafts_status',
      'CREATE INDEX editor_drafts_status ON editor_drafts (status)');
  late final Index editorDraftsCreatedAt = Index('editor_drafts_created_at',
      'CREATE INDEX editor_drafts_created_at ON editor_drafts (created_at)');
  Selectable<EditorDraftState> allDrafts() {
    return customSelect(
        'SELECT * FROM editor_drafts WHERE status = \'DRAFT\' ORDER BY created_at DESC',
        variables: [],
        readsFrom: {
          editorDrafts,
        }).asyncMap(editorDrafts.mapFromRow);
  }

  Selectable<EditorDraftState> latestDraft(String entryId, DateTime lastSaved) {
    return customSelect(
        'SELECT * FROM editor_drafts WHERE entry_id = ?1 AND last_saved = ?2 AND status = \'DRAFT\' ORDER BY created_at DESC',
        variables: [
          Variable<String>(entryId),
          Variable<DateTime>(lastSaved)
        ],
        readsFrom: {
          editorDrafts,
        }).asyncMap(editorDrafts.mapFromRow);
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        editorDrafts,
        editorDraftsId,
        editorDraftsEntryId,
        editorDraftsStatus,
        editorDraftsCreatedAt
      ];
}

typedef $EditorDraftsCreateCompanionBuilder = EditorDraftsCompanion Function({
  required String id,
  required String entryId,
  required String status,
  required DateTime createdAt,
  required DateTime lastSaved,
  required String delta,
  Value<int> rowid,
});
typedef $EditorDraftsUpdateCompanionBuilder = EditorDraftsCompanion Function({
  Value<String> id,
  Value<String> entryId,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime> lastSaved,
  Value<String> delta,
  Value<int> rowid,
});

class $EditorDraftsFilterComposer
    extends FilterComposer<_$EditorDb, EditorDrafts> {
  $EditorDraftsFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get entryId => $state.composableBuilder(
      column: $state.table.entryId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get lastSaved => $state.composableBuilder(
      column: $state.table.lastSaved,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get delta => $state.composableBuilder(
      column: $state.table.delta,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $EditorDraftsOrderingComposer
    extends OrderingComposer<_$EditorDb, EditorDrafts> {
  $EditorDraftsOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get entryId => $state.composableBuilder(
      column: $state.table.entryId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get lastSaved => $state.composableBuilder(
      column: $state.table.lastSaved,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get delta => $state.composableBuilder(
      column: $state.table.delta,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $EditorDraftsTableManager extends RootTableManager<
    _$EditorDb,
    EditorDrafts,
    EditorDraftState,
    $EditorDraftsFilterComposer,
    $EditorDraftsOrderingComposer,
    $EditorDraftsCreateCompanionBuilder,
    $EditorDraftsUpdateCompanionBuilder,
    (
      EditorDraftState,
      BaseReferences<_$EditorDb, EditorDrafts, EditorDraftState>
    ),
    EditorDraftState,
    PrefetchHooks Function()> {
  $EditorDraftsTableManager(_$EditorDb db, EditorDrafts table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $EditorDraftsFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $EditorDraftsOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> entryId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> lastSaved = const Value.absent(),
            Value<String> delta = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EditorDraftsCompanion(
            id: id,
            entryId: entryId,
            status: status,
            createdAt: createdAt,
            lastSaved: lastSaved,
            delta: delta,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String entryId,
            required String status,
            required DateTime createdAt,
            required DateTime lastSaved,
            required String delta,
            Value<int> rowid = const Value.absent(),
          }) =>
              EditorDraftsCompanion.insert(
            id: id,
            entryId: entryId,
            status: status,
            createdAt: createdAt,
            lastSaved: lastSaved,
            delta: delta,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $EditorDraftsProcessedTableManager = ProcessedTableManager<
    _$EditorDb,
    EditorDrafts,
    EditorDraftState,
    $EditorDraftsFilterComposer,
    $EditorDraftsOrderingComposer,
    $EditorDraftsCreateCompanionBuilder,
    $EditorDraftsUpdateCompanionBuilder,
    (
      EditorDraftState,
      BaseReferences<_$EditorDb, EditorDrafts, EditorDraftState>
    ),
    EditorDraftState,
    PrefetchHooks Function()>;

class $EditorDbManager {
  final _$EditorDb _db;
  $EditorDbManager(this._db);
  $EditorDraftsTableManager get editorDrafts =>
      $EditorDraftsTableManager(_db, _db.editorDrafts);
}
