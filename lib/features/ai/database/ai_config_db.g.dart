// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_config_db.dart';

// ignore_for_file: type=lint
class AiConfigs extends Table with TableInfo<AiConfigs, AiConfigDbEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AiConfigs(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _serializedMeta = const VerificationMeta(
    'serialized',
  );
  late final GeneratedColumn<String> serialized = GeneratedColumn<String>(
    'serialized',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    name,
    serialized,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiConfigDbEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('serialized')) {
      context.handle(
        _serializedMeta,
        serialized.isAcceptableOrUnknown(data['serialized']!, _serializedMeta),
      );
    } else if (isInserting) {
      context.missing(_serializedMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiConfigDbEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiConfigDbEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      serialized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serialized'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  AiConfigs createAlias(String alias) {
    return AiConfigs(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class AiConfigDbEntity extends DataClass
    implements Insertable<AiConfigDbEntity> {
  final String id;
  final String type;
  final String name;
  final String serialized;
  final DateTime createdAt;
  final DateTime? updatedAt;
  const AiConfigDbEntity({
    required this.id,
    required this.type,
    required this.name,
    required this.serialized,
    required this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['name'] = Variable<String>(name);
    map['serialized'] = Variable<String>(serialized);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  AiConfigsCompanion toCompanion(bool nullToAbsent) {
    return AiConfigsCompanion(
      id: Value(id),
      type: Value(type),
      name: Value(name),
      serialized: Value(serialized),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory AiConfigDbEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiConfigDbEntity(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      name: serializer.fromJson<String>(json['name']),
      serialized: serializer.fromJson<String>(json['serialized']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime?>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'name': serializer.toJson<String>(name),
      'serialized': serializer.toJson<String>(serialized),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  AiConfigDbEntity copyWith({
    String? id,
    String? type,
    String? name,
    String? serialized,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => AiConfigDbEntity(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name ?? this.name,
    serialized: serialized ?? this.serialized,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  AiConfigDbEntity copyWithCompanion(AiConfigsCompanion data) {
    return AiConfigDbEntity(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      serialized: data.serialized.present
          ? data.serialized.value
          : this.serialized,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiConfigDbEntity(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('serialized: $serialized, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, type, name, serialized, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiConfigDbEntity &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.serialized == this.serialized &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AiConfigsCompanion extends UpdateCompanion<AiConfigDbEntity> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> name;
  final Value<String> serialized;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const AiConfigsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.serialized = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiConfigsCompanion.insert({
    required String id,
    required String type,
    required String name,
    required String serialized,
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       name = Value(name),
       serialized = Value(serialized),
       createdAt = Value(createdAt);
  static Insertable<AiConfigDbEntity> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? name,
    Expression<String>? serialized,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (serialized != null) 'serialized': serialized,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiConfigsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? name,
    Value<String>? serialized,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return AiConfigsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      serialized: serialized ?? this.serialized,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (serialized.present) {
      map['serialized'] = Variable<String>(serialized.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiConfigsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('serialized: $serialized, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AiConfigVersions extends Table
    with TableInfo<AiConfigVersions, AiConfigVersionEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AiConfigVersions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _stampMeta = const VerificationMeta('stamp');
  late final GeneratedColumn<int> stamp = GeneratedColumn<int>(
    'stamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, stamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_config_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiConfigVersionEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('stamp')) {
      context.handle(
        _stampMeta,
        stamp.isAcceptableOrUnknown(data['stamp']!, _stampMeta),
      );
    } else if (isInserting) {
      context.missing(_stampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiConfigVersionEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiConfigVersionEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      stamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stamp'],
      )!,
    );
  }

  @override
  AiConfigVersions createAlias(String alias) {
    return AiConfigVersions(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class AiConfigVersionEntity extends DataClass
    implements Insertable<AiConfigVersionEntity> {
  final String id;
  final int stamp;
  const AiConfigVersionEntity({required this.id, required this.stamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['stamp'] = Variable<int>(stamp);
    return map;
  }

  AiConfigVersionsCompanion toCompanion(bool nullToAbsent) {
    return AiConfigVersionsCompanion(id: Value(id), stamp: Value(stamp));
  }

  factory AiConfigVersionEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiConfigVersionEntity(
      id: serializer.fromJson<String>(json['id']),
      stamp: serializer.fromJson<int>(json['stamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'stamp': serializer.toJson<int>(stamp),
    };
  }

  AiConfigVersionEntity copyWith({String? id, int? stamp}) =>
      AiConfigVersionEntity(id: id ?? this.id, stamp: stamp ?? this.stamp);
  AiConfigVersionEntity copyWithCompanion(AiConfigVersionsCompanion data) {
    return AiConfigVersionEntity(
      id: data.id.present ? data.id.value : this.id,
      stamp: data.stamp.present ? data.stamp.value : this.stamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiConfigVersionEntity(')
          ..write('id: $id, ')
          ..write('stamp: $stamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, stamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiConfigVersionEntity &&
          other.id == this.id &&
          other.stamp == this.stamp);
}

class AiConfigVersionsCompanion extends UpdateCompanion<AiConfigVersionEntity> {
  final Value<String> id;
  final Value<int> stamp;
  final Value<int> rowid;
  const AiConfigVersionsCompanion({
    this.id = const Value.absent(),
    this.stamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiConfigVersionsCompanion.insert({
    required String id,
    required int stamp,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       stamp = Value(stamp);
  static Insertable<AiConfigVersionEntity> custom({
    Expression<String>? id,
    Expression<int>? stamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (stamp != null) 'stamp': stamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiConfigVersionsCompanion copyWith({
    Value<String>? id,
    Value<int>? stamp,
    Value<int>? rowid,
  }) {
    return AiConfigVersionsCompanion(
      id: id ?? this.id,
      stamp: stamp ?? this.stamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (stamp.present) {
      map['stamp'] = Variable<int>(stamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiConfigVersionsCompanion(')
          ..write('id: $id, ')
          ..write('stamp: $stamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AiConfigDb extends GeneratedDatabase {
  _$AiConfigDb(QueryExecutor e) : super(e);
  _$AiConfigDb.connect(DatabaseConnection c) : super.connect(c);
  $AiConfigDbManager get managers => $AiConfigDbManager(this);
  late final AiConfigs aiConfigs = AiConfigs(this);
  late final AiConfigVersions aiConfigVersions = AiConfigVersions(this);
  Selectable<AiConfigDbEntity> configById(String id) {
    return customSelect(
      'SELECT * FROM ai_configs WHERE id = ?1',
      variables: [Variable<String>(id)],
      readsFrom: {aiConfigs},
    ).asyncMap(aiConfigs.mapFromRow);
  }

  Selectable<AiConfigDbEntity> configsByType(String type) {
    return customSelect(
      'SELECT * FROM ai_configs WHERE type = ?1 ORDER BY created_at DESC',
      variables: [Variable<String>(type)],
      readsFrom: {aiConfigs},
    ).asyncMap(aiConfigs.mapFromRow);
  }

  Selectable<int> versionStampById(String id) {
    return customSelect(
      'SELECT stamp FROM ai_config_versions WHERE id = ?1',
      variables: [Variable<String>(id)],
      readsFrom: {aiConfigVersions},
    ).map((QueryRow row) => row.read<int>('stamp'));
  }

  Selectable<AiConfigVersionEntity> hardDeletions() {
    return customSelect(
      'SELECT * FROM ai_config_versions WHERE id NOT IN (SELECT id FROM ai_configs) ORDER BY id',
      variables: [],
      readsFrom: {aiConfigVersions, aiConfigs},
    ).asyncMap(aiConfigVersions.mapFromRow);
  }

  Selectable<AiConfigDbEntity> allConfigs() {
    return customSelect(
      'SELECT * FROM ai_configs ORDER BY created_at DESC',
      variables: [],
      readsFrom: {aiConfigs},
    ).asyncMap(aiConfigs.mapFromRow);
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    aiConfigs,
    aiConfigVersions,
  ];
}

typedef $AiConfigsCreateCompanionBuilder =
    AiConfigsCompanion Function({
      required String id,
      required String type,
      required String name,
      required String serialized,
      required DateTime createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $AiConfigsUpdateCompanionBuilder =
    AiConfigsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> name,
      Value<String> serialized,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $AiConfigsFilterComposer extends Composer<_$AiConfigDb, AiConfigs> {
  $AiConfigsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serialized => $composableBuilder(
    column: $table.serialized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $AiConfigsOrderingComposer extends Composer<_$AiConfigDb, AiConfigs> {
  $AiConfigsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serialized => $composableBuilder(
    column: $table.serialized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AiConfigsAnnotationComposer extends Composer<_$AiConfigDb, AiConfigs> {
  $AiConfigsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get serialized => $composableBuilder(
    column: $table.serialized,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $AiConfigsTableManager
    extends
        RootTableManager<
          _$AiConfigDb,
          AiConfigs,
          AiConfigDbEntity,
          $AiConfigsFilterComposer,
          $AiConfigsOrderingComposer,
          $AiConfigsAnnotationComposer,
          $AiConfigsCreateCompanionBuilder,
          $AiConfigsUpdateCompanionBuilder,
          (
            AiConfigDbEntity,
            BaseReferences<_$AiConfigDb, AiConfigs, AiConfigDbEntity>,
          ),
          AiConfigDbEntity,
          PrefetchHooks Function()
        > {
  $AiConfigsTableManager(_$AiConfigDb db, AiConfigs table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AiConfigsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AiConfigsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AiConfigsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> serialized = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiConfigsCompanion(
                id: id,
                type: type,
                name: name,
                serialized: serialized,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String name,
                required String serialized,
                required DateTime createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiConfigsCompanion.insert(
                id: id,
                type: type,
                name: name,
                serialized: serialized,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AiConfigsProcessedTableManager =
    ProcessedTableManager<
      _$AiConfigDb,
      AiConfigs,
      AiConfigDbEntity,
      $AiConfigsFilterComposer,
      $AiConfigsOrderingComposer,
      $AiConfigsAnnotationComposer,
      $AiConfigsCreateCompanionBuilder,
      $AiConfigsUpdateCompanionBuilder,
      (
        AiConfigDbEntity,
        BaseReferences<_$AiConfigDb, AiConfigs, AiConfigDbEntity>,
      ),
      AiConfigDbEntity,
      PrefetchHooks Function()
    >;
typedef $AiConfigVersionsCreateCompanionBuilder =
    AiConfigVersionsCompanion Function({
      required String id,
      required int stamp,
      Value<int> rowid,
    });
typedef $AiConfigVersionsUpdateCompanionBuilder =
    AiConfigVersionsCompanion Function({
      Value<String> id,
      Value<int> stamp,
      Value<int> rowid,
    });

class $AiConfigVersionsFilterComposer
    extends Composer<_$AiConfigDb, AiConfigVersions> {
  $AiConfigVersionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stamp => $composableBuilder(
    column: $table.stamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $AiConfigVersionsOrderingComposer
    extends Composer<_$AiConfigDb, AiConfigVersions> {
  $AiConfigVersionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stamp => $composableBuilder(
    column: $table.stamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AiConfigVersionsAnnotationComposer
    extends Composer<_$AiConfigDb, AiConfigVersions> {
  $AiConfigVersionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get stamp =>
      $composableBuilder(column: $table.stamp, builder: (column) => column);
}

class $AiConfigVersionsTableManager
    extends
        RootTableManager<
          _$AiConfigDb,
          AiConfigVersions,
          AiConfigVersionEntity,
          $AiConfigVersionsFilterComposer,
          $AiConfigVersionsOrderingComposer,
          $AiConfigVersionsAnnotationComposer,
          $AiConfigVersionsCreateCompanionBuilder,
          $AiConfigVersionsUpdateCompanionBuilder,
          (
            AiConfigVersionEntity,
            BaseReferences<
              _$AiConfigDb,
              AiConfigVersions,
              AiConfigVersionEntity
            >,
          ),
          AiConfigVersionEntity,
          PrefetchHooks Function()
        > {
  $AiConfigVersionsTableManager(_$AiConfigDb db, AiConfigVersions table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AiConfigVersionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AiConfigVersionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AiConfigVersionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> stamp = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  AiConfigVersionsCompanion(id: id, stamp: stamp, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required int stamp,
                Value<int> rowid = const Value.absent(),
              }) => AiConfigVersionsCompanion.insert(
                id: id,
                stamp: stamp,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AiConfigVersionsProcessedTableManager =
    ProcessedTableManager<
      _$AiConfigDb,
      AiConfigVersions,
      AiConfigVersionEntity,
      $AiConfigVersionsFilterComposer,
      $AiConfigVersionsOrderingComposer,
      $AiConfigVersionsAnnotationComposer,
      $AiConfigVersionsCreateCompanionBuilder,
      $AiConfigVersionsUpdateCompanionBuilder,
      (
        AiConfigVersionEntity,
        BaseReferences<_$AiConfigDb, AiConfigVersions, AiConfigVersionEntity>,
      ),
      AiConfigVersionEntity,
      PrefetchHooks Function()
    >;

class $AiConfigDbManager {
  final _$AiConfigDb _db;
  $AiConfigDbManager(this._db);
  $AiConfigsTableManager get aiConfigs =>
      $AiConfigsTableManager(_db, _db.aiConfigs);
  $AiConfigVersionsTableManager get aiConfigVersions =>
      $AiConfigVersionsTableManager(_db, _db.aiConfigVersions);
}
