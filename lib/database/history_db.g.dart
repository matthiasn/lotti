// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_db.dart';

// ignore_for_file: type=lint
class HistoryEntries extends Table
    with TableInfo<HistoryEntries, HistoryEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  HistoryEntries(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY AUTOINCREMENT',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _routeMeta = const VerificationMeta('route');
  late final GeneratedColumn<String> route = GeneratedColumn<String>(
    'route',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _visitedAtMeta = const VerificationMeta(
    'visitedAt',
  );
  late final GeneratedColumn<DateTime> visitedAt = GeneratedColumn<DateTime>(
    'visited_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, entityId, route, visitedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('route')) {
      context.handle(
        _routeMeta,
        route.isAcceptableOrUnknown(data['route']!, _routeMeta),
      );
    } else if (isInserting) {
      context.missing(_routeMeta);
    }
    if (data.containsKey('visited_at')) {
      context.handle(
        _visitedAtMeta,
        visitedAt.isAcceptableOrUnknown(data['visited_at']!, _visitedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_visitedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      route: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route'],
      )!,
      visitedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}visited_at'],
      )!,
    );
  }

  @override
  HistoryEntries createAlias(String alias) {
    return HistoryEntries(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class HistoryEntryRow extends DataClass implements Insertable<HistoryEntryRow> {
  final int id;

  /// The HistoryEntityKind name: which table the entity id points into.
  final String kind;
  final String entityId;

  /// The route the visit was made at, beamed again to return to it.
  final String route;
  final DateTime visitedAt;
  const HistoryEntryRow({
    required this.id,
    required this.kind,
    required this.entityId,
    required this.route,
    required this.visitedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['entity_id'] = Variable<String>(entityId);
    map['route'] = Variable<String>(route);
    map['visited_at'] = Variable<DateTime>(visitedAt);
    return map;
  }

  HistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return HistoryEntriesCompanion(
      id: Value(id),
      kind: Value(kind),
      entityId: Value(entityId),
      route: Value(route),
      visitedAt: Value(visitedAt),
    );
  }

  factory HistoryEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryEntryRow(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      entityId: serializer.fromJson<String>(json['entity_id']),
      route: serializer.fromJson<String>(json['route']),
      visitedAt: serializer.fromJson<DateTime>(json['visited_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'entity_id': serializer.toJson<String>(entityId),
      'route': serializer.toJson<String>(route),
      'visited_at': serializer.toJson<DateTime>(visitedAt),
    };
  }

  HistoryEntryRow copyWith({
    int? id,
    String? kind,
    String? entityId,
    String? route,
    DateTime? visitedAt,
  }) => HistoryEntryRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    entityId: entityId ?? this.entityId,
    route: route ?? this.route,
    visitedAt: visitedAt ?? this.visitedAt,
  );
  HistoryEntryRow copyWithCompanion(HistoryEntriesCompanion data) {
    return HistoryEntryRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      route: data.route.present ? data.route.value : this.route,
      visitedAt: data.visitedAt.present ? data.visitedAt.value : this.visitedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryEntryRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('route: $route, ')
          ..write('visitedAt: $visitedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, entityId, route, visitedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryEntryRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.entityId == this.entityId &&
          other.route == this.route &&
          other.visitedAt == this.visitedAt);
}

class HistoryEntriesCompanion extends UpdateCompanion<HistoryEntryRow> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> entityId;
  final Value<String> route;
  final Value<DateTime> visitedAt;
  const HistoryEntriesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.entityId = const Value.absent(),
    this.route = const Value.absent(),
    this.visitedAt = const Value.absent(),
  });
  HistoryEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String entityId,
    required String route,
    required DateTime visitedAt,
  }) : kind = Value(kind),
       entityId = Value(entityId),
       route = Value(route),
       visitedAt = Value(visitedAt);
  static Insertable<HistoryEntryRow> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? entityId,
    Expression<String>? route,
    Expression<DateTime>? visitedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (entityId != null) 'entity_id': entityId,
      if (route != null) 'route': route,
      if (visitedAt != null) 'visited_at': visitedAt,
    });
  }

  HistoryEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? entityId,
    Value<String>? route,
    Value<DateTime>? visitedAt,
  }) {
    return HistoryEntriesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      entityId: entityId ?? this.entityId,
      route: route ?? this.route,
      visitedAt: visitedAt ?? this.visitedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (route.present) {
      map['route'] = Variable<String>(route.value);
    }
    if (visitedAt.present) {
      map['visited_at'] = Variable<DateTime>(visitedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('route: $route, ')
          ..write('visitedAt: $visitedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$HistoryDb extends GeneratedDatabase {
  _$HistoryDb(QueryExecutor e) : super(e);
  _$HistoryDb.connect(DatabaseConnection c) : super.connect(c);
  $HistoryDbManager get managers => $HistoryDbManager(this);
  late final HistoryEntries historyEntries = HistoryEntries(this);
  late final Index idxHistoryEntriesVisitedAt = Index(
    'idx_history_entries_visited_at',
    'CREATE INDEX idx_history_entries_visited_at ON history_entries (visited_at)',
  );
  Selectable<HistoryEntryRow> latestHistoryEntry() {
    return customSelect(
      'SELECT * FROM history_entries ORDER BY id DESC LIMIT 1',
      variables: [],
      readsFrom: {historyEntries},
    ).asyncMap(historyEntries.mapFromRow);
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    historyEntries,
    idxHistoryEntriesVisitedAt,
  ];
}

typedef $HistoryEntriesCreateCompanionBuilder =
    HistoryEntriesCompanion Function({
      Value<int> id,
      required String kind,
      required String entityId,
      required String route,
      required DateTime visitedAt,
    });
typedef $HistoryEntriesUpdateCompanionBuilder =
    HistoryEntriesCompanion Function({
      Value<int> id,
      Value<String> kind,
      Value<String> entityId,
      Value<String> route,
      Value<DateTime> visitedAt,
    });

class $HistoryEntriesFilterComposer
    extends Composer<_$HistoryDb, HistoryEntries> {
  $HistoryEntriesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get route => $composableBuilder(
    column: $table.route,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get visitedAt => $composableBuilder(
    column: $table.visitedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $HistoryEntriesOrderingComposer
    extends Composer<_$HistoryDb, HistoryEntries> {
  $HistoryEntriesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get route => $composableBuilder(
    column: $table.route,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get visitedAt => $composableBuilder(
    column: $table.visitedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $HistoryEntriesAnnotationComposer
    extends Composer<_$HistoryDb, HistoryEntries> {
  $HistoryEntriesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get route =>
      $composableBuilder(column: $table.route, builder: (column) => column);

  GeneratedColumn<DateTime> get visitedAt =>
      $composableBuilder(column: $table.visitedAt, builder: (column) => column);
}

class $HistoryEntriesTableManager
    extends
        RootTableManager<
          _$HistoryDb,
          HistoryEntries,
          HistoryEntryRow,
          $HistoryEntriesFilterComposer,
          $HistoryEntriesOrderingComposer,
          $HistoryEntriesAnnotationComposer,
          $HistoryEntriesCreateCompanionBuilder,
          $HistoryEntriesUpdateCompanionBuilder,
          (
            HistoryEntryRow,
            BaseReferences<_$HistoryDb, HistoryEntries, HistoryEntryRow>,
          ),
          HistoryEntryRow,
          PrefetchHooks Function()
        > {
  $HistoryEntriesTableManager(_$HistoryDb db, HistoryEntries table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $HistoryEntriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $HistoryEntriesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $HistoryEntriesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> route = const Value.absent(),
                Value<DateTime> visitedAt = const Value.absent(),
              }) => HistoryEntriesCompanion(
                id: id,
                kind: kind,
                entityId: entityId,
                route: route,
                visitedAt: visitedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String entityId,
                required String route,
                required DateTime visitedAt,
              }) => HistoryEntriesCompanion.insert(
                id: id,
                kind: kind,
                entityId: entityId,
                route: route,
                visitedAt: visitedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $HistoryEntriesProcessedTableManager =
    ProcessedTableManager<
      _$HistoryDb,
      HistoryEntries,
      HistoryEntryRow,
      $HistoryEntriesFilterComposer,
      $HistoryEntriesOrderingComposer,
      $HistoryEntriesAnnotationComposer,
      $HistoryEntriesCreateCompanionBuilder,
      $HistoryEntriesUpdateCompanionBuilder,
      (
        HistoryEntryRow,
        BaseReferences<_$HistoryDb, HistoryEntries, HistoryEntryRow>,
      ),
      HistoryEntryRow,
      PrefetchHooks Function()
    >;

class $HistoryDbManager {
  final _$HistoryDb _db;
  $HistoryDbManager(this._db);
  $HistoryEntriesTableManager get historyEntries =>
      $HistoryEntriesTableManager(_db, _db.historyEntries);
}
