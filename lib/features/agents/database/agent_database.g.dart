// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_database.dart';

// ignore_for_file: type=lint
class AgentEntities extends Table with TableInfo<AgentEntities, AgentEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AgentEntities(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
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
  static const VerificationMeta _subtypeMeta = const VerificationMeta(
    'subtype',
  );
  late final GeneratedColumn<String> subtype = GeneratedColumn<String>(
    'subtype',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _threadIdMeta = const VerificationMeta(
    'threadId',
  );
  late final GeneratedColumn<String> threadId = GeneratedColumn<String>(
    'thread_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
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
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    $customConstraints: '',
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
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    agentId,
    type,
    subtype,
    threadId,
    createdAt,
    updatedAt,
    deletedAt,
    serialized,
    schemaVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('subtype')) {
      context.handle(
        _subtypeMeta,
        subtype.isAcceptableOrUnknown(data['subtype']!, _subtypeMeta),
      );
    }
    if (data.containsKey('thread_id')) {
      context.handle(
        _threadIdMeta,
        threadId.isAcceptableOrUnknown(data['thread_id']!, _threadIdMeta),
      );
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
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('serialized')) {
      context.handle(
        _serializedMeta,
        serialized.isAcceptableOrUnknown(data['serialized']!, _serializedMeta),
      );
    } else if (isInserting) {
      context.missing(_serializedMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgentEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      subtype: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtype'],
      ),
      threadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      serialized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serialized'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
    );
  }

  @override
  AgentEntities createAlias(String alias) {
    return AgentEntities(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class AgentEntity extends DataClass implements Insertable<AgentEntity> {
  final String id;
  final String agentId;
  final String type;
  final String? subtype;
  final String? threadId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String serialized;
  final int schemaVersion;
  const AgentEntity({
    required this.id,
    required this.agentId,
    required this.type,
    this.subtype,
    this.threadId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.serialized,
    required this.schemaVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['agent_id'] = Variable<String>(agentId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || subtype != null) {
      map['subtype'] = Variable<String>(subtype);
    }
    if (!nullToAbsent || threadId != null) {
      map['thread_id'] = Variable<String>(threadId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['serialized'] = Variable<String>(serialized);
    map['schema_version'] = Variable<int>(schemaVersion);
    return map;
  }

  AgentEntitiesCompanion toCompanion(bool nullToAbsent) {
    return AgentEntitiesCompanion(
      id: Value(id),
      agentId: Value(agentId),
      type: Value(type),
      subtype: subtype == null && nullToAbsent
          ? const Value.absent()
          : Value(subtype),
      threadId: threadId == null && nullToAbsent
          ? const Value.absent()
          : Value(threadId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      serialized: Value(serialized),
      schemaVersion: Value(schemaVersion),
    );
  }

  factory AgentEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentEntity(
      id: serializer.fromJson<String>(json['id']),
      agentId: serializer.fromJson<String>(json['agent_id']),
      type: serializer.fromJson<String>(json['type']),
      subtype: serializer.fromJson<String?>(json['subtype']),
      threadId: serializer.fromJson<String?>(json['thread_id']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      deletedAt: serializer.fromJson<DateTime?>(json['deleted_at']),
      serialized: serializer.fromJson<String>(json['serialized']),
      schemaVersion: serializer.fromJson<int>(json['schema_version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'agent_id': serializer.toJson<String>(agentId),
      'type': serializer.toJson<String>(type),
      'subtype': serializer.toJson<String?>(subtype),
      'thread_id': serializer.toJson<String?>(threadId),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'deleted_at': serializer.toJson<DateTime?>(deletedAt),
      'serialized': serializer.toJson<String>(serialized),
      'schema_version': serializer.toJson<int>(schemaVersion),
    };
  }

  AgentEntity copyWith({
    String? id,
    String? agentId,
    String? type,
    Value<String?> subtype = const Value.absent(),
    Value<String?> threadId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? serialized,
    int? schemaVersion,
  }) => AgentEntity(
    id: id ?? this.id,
    agentId: agentId ?? this.agentId,
    type: type ?? this.type,
    subtype: subtype.present ? subtype.value : this.subtype,
    threadId: threadId.present ? threadId.value : this.threadId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    serialized: serialized ?? this.serialized,
    schemaVersion: schemaVersion ?? this.schemaVersion,
  );
  AgentEntity copyWithCompanion(AgentEntitiesCompanion data) {
    return AgentEntity(
      id: data.id.present ? data.id.value : this.id,
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      type: data.type.present ? data.type.value : this.type,
      subtype: data.subtype.present ? data.subtype.value : this.subtype,
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      serialized: data.serialized.present
          ? data.serialized.value
          : this.serialized,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentEntity(')
          ..write('id: $id, ')
          ..write('agentId: $agentId, ')
          ..write('type: $type, ')
          ..write('subtype: $subtype, ')
          ..write('threadId: $threadId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serialized: $serialized, ')
          ..write('schemaVersion: $schemaVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    agentId,
    type,
    subtype,
    threadId,
    createdAt,
    updatedAt,
    deletedAt,
    serialized,
    schemaVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentEntity &&
          other.id == this.id &&
          other.agentId == this.agentId &&
          other.type == this.type &&
          other.subtype == this.subtype &&
          other.threadId == this.threadId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.serialized == this.serialized &&
          other.schemaVersion == this.schemaVersion);
}

class AgentEntitiesCompanion extends UpdateCompanion<AgentEntity> {
  final Value<String> id;
  final Value<String> agentId;
  final Value<String> type;
  final Value<String?> subtype;
  final Value<String?> threadId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> serialized;
  final Value<int> schemaVersion;
  final Value<int> rowid;
  const AgentEntitiesCompanion({
    this.id = const Value.absent(),
    this.agentId = const Value.absent(),
    this.type = const Value.absent(),
    this.subtype = const Value.absent(),
    this.threadId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serialized = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentEntitiesCompanion.insert({
    required String id,
    required String agentId,
    required String type,
    this.subtype = const Value.absent(),
    this.threadId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String serialized,
    this.schemaVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       agentId = Value(agentId),
       type = Value(type),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       serialized = Value(serialized);
  static Insertable<AgentEntity> custom({
    Expression<String>? id,
    Expression<String>? agentId,
    Expression<String>? type,
    Expression<String>? subtype,
    Expression<String>? threadId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? serialized,
    Expression<int>? schemaVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (agentId != null) 'agent_id': agentId,
      if (type != null) 'type': type,
      if (subtype != null) 'subtype': subtype,
      if (threadId != null) 'thread_id': threadId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (serialized != null) 'serialized': serialized,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentEntitiesCompanion copyWith({
    Value<String>? id,
    Value<String>? agentId,
    Value<String>? type,
    Value<String?>? subtype,
    Value<String?>? threadId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? serialized,
    Value<int>? schemaVersion,
    Value<int>? rowid,
  }) {
    return AgentEntitiesCompanion(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      type: type ?? this.type,
      subtype: subtype ?? this.subtype,
      threadId: threadId ?? this.threadId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      serialized: serialized ?? this.serialized,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (subtype.present) {
      map['subtype'] = Variable<String>(subtype.value);
    }
    if (threadId.present) {
      map['thread_id'] = Variable<String>(threadId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (serialized.present) {
      map['serialized'] = Variable<String>(serialized.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentEntitiesCompanion(')
          ..write('id: $id, ')
          ..write('agentId: $agentId, ')
          ..write('type: $type, ')
          ..write('subtype: $subtype, ')
          ..write('threadId: $threadId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serialized: $serialized, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AgentLinks extends Table with TableInfo<AgentLinks, AgentLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AgentLinks(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _fromIdMeta = const VerificationMeta('fromId');
  late final GeneratedColumn<String> fromId = GeneratedColumn<String>(
    'from_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _toIdMeta = const VerificationMeta('toId');
  late final GeneratedColumn<String> toId = GeneratedColumn<String>(
    'to_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
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
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    $customConstraints: '',
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
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fromId,
    toId,
    type,
    createdAt,
    updatedAt,
    deletedAt,
    serialized,
    schemaVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('from_id')) {
      context.handle(
        _fromIdMeta,
        fromId.isAcceptableOrUnknown(data['from_id']!, _fromIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fromIdMeta);
    }
    if (data.containsKey('to_id')) {
      context.handle(
        _toIdMeta,
        toId.isAcceptableOrUnknown(data['to_id']!, _toIdMeta),
      );
    } else if (isInserting) {
      context.missing(_toIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
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
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('serialized')) {
      context.handle(
        _serializedMeta,
        serialized.isAcceptableOrUnknown(data['serialized']!, _serializedMeta),
      );
    } else if (isInserting) {
      context.missing(_serializedMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgentLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentLink(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fromId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_id'],
      )!,
      toId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      serialized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serialized'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
    );
  }

  @override
  AgentLinks createAlias(String alias) {
    return AgentLinks(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class AgentLink extends DataClass implements Insertable<AgentLink> {
  final String id;
  final String fromId;
  final String toId;
  final String type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String serialized;
  final int schemaVersion;
  const AgentLink({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.serialized,
    required this.schemaVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['from_id'] = Variable<String>(fromId);
    map['to_id'] = Variable<String>(toId);
    map['type'] = Variable<String>(type);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['serialized'] = Variable<String>(serialized);
    map['schema_version'] = Variable<int>(schemaVersion);
    return map;
  }

  AgentLinksCompanion toCompanion(bool nullToAbsent) {
    return AgentLinksCompanion(
      id: Value(id),
      fromId: Value(fromId),
      toId: Value(toId),
      type: Value(type),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      serialized: Value(serialized),
      schemaVersion: Value(schemaVersion),
    );
  }

  factory AgentLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentLink(
      id: serializer.fromJson<String>(json['id']),
      fromId: serializer.fromJson<String>(json['from_id']),
      toId: serializer.fromJson<String>(json['to_id']),
      type: serializer.fromJson<String>(json['type']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      deletedAt: serializer.fromJson<DateTime?>(json['deleted_at']),
      serialized: serializer.fromJson<String>(json['serialized']),
      schemaVersion: serializer.fromJson<int>(json['schema_version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'from_id': serializer.toJson<String>(fromId),
      'to_id': serializer.toJson<String>(toId),
      'type': serializer.toJson<String>(type),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'deleted_at': serializer.toJson<DateTime?>(deletedAt),
      'serialized': serializer.toJson<String>(serialized),
      'schema_version': serializer.toJson<int>(schemaVersion),
    };
  }

  AgentLink copyWith({
    String? id,
    String? fromId,
    String? toId,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? serialized,
    int? schemaVersion,
  }) => AgentLink(
    id: id ?? this.id,
    fromId: fromId ?? this.fromId,
    toId: toId ?? this.toId,
    type: type ?? this.type,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    serialized: serialized ?? this.serialized,
    schemaVersion: schemaVersion ?? this.schemaVersion,
  );
  AgentLink copyWithCompanion(AgentLinksCompanion data) {
    return AgentLink(
      id: data.id.present ? data.id.value : this.id,
      fromId: data.fromId.present ? data.fromId.value : this.fromId,
      toId: data.toId.present ? data.toId.value : this.toId,
      type: data.type.present ? data.type.value : this.type,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      serialized: data.serialized.present
          ? data.serialized.value
          : this.serialized,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentLink(')
          ..write('id: $id, ')
          ..write('fromId: $fromId, ')
          ..write('toId: $toId, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serialized: $serialized, ')
          ..write('schemaVersion: $schemaVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fromId,
    toId,
    type,
    createdAt,
    updatedAt,
    deletedAt,
    serialized,
    schemaVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentLink &&
          other.id == this.id &&
          other.fromId == this.fromId &&
          other.toId == this.toId &&
          other.type == this.type &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.serialized == this.serialized &&
          other.schemaVersion == this.schemaVersion);
}

class AgentLinksCompanion extends UpdateCompanion<AgentLink> {
  final Value<String> id;
  final Value<String> fromId;
  final Value<String> toId;
  final Value<String> type;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> serialized;
  final Value<int> schemaVersion;
  final Value<int> rowid;
  const AgentLinksCompanion({
    this.id = const Value.absent(),
    this.fromId = const Value.absent(),
    this.toId = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serialized = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentLinksCompanion.insert({
    required String id,
    required String fromId,
    required String toId,
    required String type,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String serialized,
    this.schemaVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fromId = Value(fromId),
       toId = Value(toId),
       type = Value(type),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       serialized = Value(serialized);
  static Insertable<AgentLink> custom({
    Expression<String>? id,
    Expression<String>? fromId,
    Expression<String>? toId,
    Expression<String>? type,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? serialized,
    Expression<int>? schemaVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fromId != null) 'from_id': fromId,
      if (toId != null) 'to_id': toId,
      if (type != null) 'type': type,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (serialized != null) 'serialized': serialized,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentLinksCompanion copyWith({
    Value<String>? id,
    Value<String>? fromId,
    Value<String>? toId,
    Value<String>? type,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? serialized,
    Value<int>? schemaVersion,
    Value<int>? rowid,
  }) {
    return AgentLinksCompanion(
      id: id ?? this.id,
      fromId: fromId ?? this.fromId,
      toId: toId ?? this.toId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      serialized: serialized ?? this.serialized,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fromId.present) {
      map['from_id'] = Variable<String>(fromId.value);
    }
    if (toId.present) {
      map['to_id'] = Variable<String>(toId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (serialized.present) {
      map['serialized'] = Variable<String>(serialized.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentLinksCompanion(')
          ..write('id: $id, ')
          ..write('fromId: $fromId, ')
          ..write('toId: $toId, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serialized: $serialized, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AttentionClaimIndex extends Table
    with TableInfo<AttentionClaimIndex, AttentionClaimIndexData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AttentionClaimIndex(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _scopeKindMeta = const VerificationMeta(
    'scopeKind',
  );
  late final GeneratedColumn<String> scopeKind = GeneratedColumn<String>(
    'scope_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _visibilityStartMeta = const VerificationMeta(
    'visibilityStart',
  );
  late final GeneratedColumn<DateTime> visibilityStart =
      GeneratedColumn<DateTime>(
        'visibility_start',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      );
  static const VerificationMeta _visibilityEndMeta = const VerificationMeta(
    'visibilityEnd',
  );
  late final GeneratedColumn<DateTime> visibilityEnd =
      GeneratedColumn<DateTime>(
        'visibility_end',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      );
  static const VerificationMeta _deadlineMeta = const VerificationMeta(
    'deadline',
  );
  late final GeneratedColumn<DateTime> deadline = GeneratedColumn<DateTime>(
    'deadline',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _nextReviewAtMeta = const VerificationMeta(
    'nextReviewAt',
  );
  late final GeneratedColumn<DateTime> nextReviewAt = GeneratedColumn<DateTime>(
    'next_review_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _targetKindMeta = const VerificationMeta(
    'targetKind',
  );
  late final GeneratedColumn<String> targetKind = GeneratedColumn<String>(
    'target_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    requestId,
    agentId,
    status,
    scopeKind,
    visibilityStart,
    visibilityEnd,
    deadline,
    nextReviewAt,
    targetId,
    targetKind,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attention_claim_index';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttentionClaimIndexData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('scope_kind')) {
      context.handle(
        _scopeKindMeta,
        scopeKind.isAcceptableOrUnknown(data['scope_kind']!, _scopeKindMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeKindMeta);
    }
    if (data.containsKey('visibility_start')) {
      context.handle(
        _visibilityStartMeta,
        visibilityStart.isAcceptableOrUnknown(
          data['visibility_start']!,
          _visibilityStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_visibilityStartMeta);
    }
    if (data.containsKey('visibility_end')) {
      context.handle(
        _visibilityEndMeta,
        visibilityEnd.isAcceptableOrUnknown(
          data['visibility_end']!,
          _visibilityEndMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_visibilityEndMeta);
    }
    if (data.containsKey('deadline')) {
      context.handle(
        _deadlineMeta,
        deadline.isAcceptableOrUnknown(data['deadline']!, _deadlineMeta),
      );
    }
    if (data.containsKey('next_review_at')) {
      context.handle(
        _nextReviewAtMeta,
        nextReviewAt.isAcceptableOrUnknown(
          data['next_review_at']!,
          _nextReviewAtMeta,
        ),
      );
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    }
    if (data.containsKey('target_kind')) {
      context.handle(
        _targetKindMeta,
        targetKind.isAcceptableOrUnknown(data['target_kind']!, _targetKindMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {requestId};
  @override
  AttentionClaimIndexData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttentionClaimIndexData(
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      )!,
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      scopeKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_kind'],
      )!,
      visibilityStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}visibility_start'],
      )!,
      visibilityEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}visibility_end'],
      )!,
      deadline: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deadline'],
      ),
      nextReviewAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_review_at'],
      ),
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      ),
      targetKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_kind'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  AttentionClaimIndex createAlias(String alias) {
    return AttentionClaimIndex(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class AttentionClaimIndexData extends DataClass
    implements Insertable<AttentionClaimIndexData> {
  final String requestId;
  final String agentId;
  final String status;
  final String scopeKind;
  final DateTime visibilityStart;
  final DateTime visibilityEnd;
  final DateTime? deadline;
  final DateTime? nextReviewAt;
  final String? targetId;
  final String? targetKind;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const AttentionClaimIndexData({
    required this.requestId,
    required this.agentId,
    required this.status,
    required this.scopeKind,
    required this.visibilityStart,
    required this.visibilityEnd,
    this.deadline,
    this.nextReviewAt,
    this.targetId,
    this.targetKind,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['request_id'] = Variable<String>(requestId);
    map['agent_id'] = Variable<String>(agentId);
    map['status'] = Variable<String>(status);
    map['scope_kind'] = Variable<String>(scopeKind);
    map['visibility_start'] = Variable<DateTime>(visibilityStart);
    map['visibility_end'] = Variable<DateTime>(visibilityEnd);
    if (!nullToAbsent || deadline != null) {
      map['deadline'] = Variable<DateTime>(deadline);
    }
    if (!nullToAbsent || nextReviewAt != null) {
      map['next_review_at'] = Variable<DateTime>(nextReviewAt);
    }
    if (!nullToAbsent || targetId != null) {
      map['target_id'] = Variable<String>(targetId);
    }
    if (!nullToAbsent || targetKind != null) {
      map['target_kind'] = Variable<String>(targetKind);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  AttentionClaimIndexCompanion toCompanion(bool nullToAbsent) {
    return AttentionClaimIndexCompanion(
      requestId: Value(requestId),
      agentId: Value(agentId),
      status: Value(status),
      scopeKind: Value(scopeKind),
      visibilityStart: Value(visibilityStart),
      visibilityEnd: Value(visibilityEnd),
      deadline: deadline == null && nullToAbsent
          ? const Value.absent()
          : Value(deadline),
      nextReviewAt: nextReviewAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextReviewAt),
      targetId: targetId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetId),
      targetKind: targetKind == null && nullToAbsent
          ? const Value.absent()
          : Value(targetKind),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory AttentionClaimIndexData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttentionClaimIndexData(
      requestId: serializer.fromJson<String>(json['request_id']),
      agentId: serializer.fromJson<String>(json['agent_id']),
      status: serializer.fromJson<String>(json['status']),
      scopeKind: serializer.fromJson<String>(json['scope_kind']),
      visibilityStart: serializer.fromJson<DateTime>(json['visibility_start']),
      visibilityEnd: serializer.fromJson<DateTime>(json['visibility_end']),
      deadline: serializer.fromJson<DateTime?>(json['deadline']),
      nextReviewAt: serializer.fromJson<DateTime?>(json['next_review_at']),
      targetId: serializer.fromJson<String?>(json['target_id']),
      targetKind: serializer.fromJson<String?>(json['target_kind']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      deletedAt: serializer.fromJson<DateTime?>(json['deleted_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'request_id': serializer.toJson<String>(requestId),
      'agent_id': serializer.toJson<String>(agentId),
      'status': serializer.toJson<String>(status),
      'scope_kind': serializer.toJson<String>(scopeKind),
      'visibility_start': serializer.toJson<DateTime>(visibilityStart),
      'visibility_end': serializer.toJson<DateTime>(visibilityEnd),
      'deadline': serializer.toJson<DateTime?>(deadline),
      'next_review_at': serializer.toJson<DateTime?>(nextReviewAt),
      'target_id': serializer.toJson<String?>(targetId),
      'target_kind': serializer.toJson<String?>(targetKind),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'deleted_at': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  AttentionClaimIndexData copyWith({
    String? requestId,
    String? agentId,
    String? status,
    String? scopeKind,
    DateTime? visibilityStart,
    DateTime? visibilityEnd,
    Value<DateTime?> deadline = const Value.absent(),
    Value<DateTime?> nextReviewAt = const Value.absent(),
    Value<String?> targetId = const Value.absent(),
    Value<String?> targetKind = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => AttentionClaimIndexData(
    requestId: requestId ?? this.requestId,
    agentId: agentId ?? this.agentId,
    status: status ?? this.status,
    scopeKind: scopeKind ?? this.scopeKind,
    visibilityStart: visibilityStart ?? this.visibilityStart,
    visibilityEnd: visibilityEnd ?? this.visibilityEnd,
    deadline: deadline.present ? deadline.value : this.deadline,
    nextReviewAt: nextReviewAt.present ? nextReviewAt.value : this.nextReviewAt,
    targetId: targetId.present ? targetId.value : this.targetId,
    targetKind: targetKind.present ? targetKind.value : this.targetKind,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  AttentionClaimIndexData copyWithCompanion(AttentionClaimIndexCompanion data) {
    return AttentionClaimIndexData(
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      status: data.status.present ? data.status.value : this.status,
      scopeKind: data.scopeKind.present ? data.scopeKind.value : this.scopeKind,
      visibilityStart: data.visibilityStart.present
          ? data.visibilityStart.value
          : this.visibilityStart,
      visibilityEnd: data.visibilityEnd.present
          ? data.visibilityEnd.value
          : this.visibilityEnd,
      deadline: data.deadline.present ? data.deadline.value : this.deadline,
      nextReviewAt: data.nextReviewAt.present
          ? data.nextReviewAt.value
          : this.nextReviewAt,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      targetKind: data.targetKind.present
          ? data.targetKind.value
          : this.targetKind,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttentionClaimIndexData(')
          ..write('requestId: $requestId, ')
          ..write('agentId: $agentId, ')
          ..write('status: $status, ')
          ..write('scopeKind: $scopeKind, ')
          ..write('visibilityStart: $visibilityStart, ')
          ..write('visibilityEnd: $visibilityEnd, ')
          ..write('deadline: $deadline, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('targetId: $targetId, ')
          ..write('targetKind: $targetKind, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    requestId,
    agentId,
    status,
    scopeKind,
    visibilityStart,
    visibilityEnd,
    deadline,
    nextReviewAt,
    targetId,
    targetKind,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttentionClaimIndexData &&
          other.requestId == this.requestId &&
          other.agentId == this.agentId &&
          other.status == this.status &&
          other.scopeKind == this.scopeKind &&
          other.visibilityStart == this.visibilityStart &&
          other.visibilityEnd == this.visibilityEnd &&
          other.deadline == this.deadline &&
          other.nextReviewAt == this.nextReviewAt &&
          other.targetId == this.targetId &&
          other.targetKind == this.targetKind &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class AttentionClaimIndexCompanion
    extends UpdateCompanion<AttentionClaimIndexData> {
  final Value<String> requestId;
  final Value<String> agentId;
  final Value<String> status;
  final Value<String> scopeKind;
  final Value<DateTime> visibilityStart;
  final Value<DateTime> visibilityEnd;
  final Value<DateTime?> deadline;
  final Value<DateTime?> nextReviewAt;
  final Value<String?> targetId;
  final Value<String?> targetKind;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const AttentionClaimIndexCompanion({
    this.requestId = const Value.absent(),
    this.agentId = const Value.absent(),
    this.status = const Value.absent(),
    this.scopeKind = const Value.absent(),
    this.visibilityStart = const Value.absent(),
    this.visibilityEnd = const Value.absent(),
    this.deadline = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.targetId = const Value.absent(),
    this.targetKind = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttentionClaimIndexCompanion.insert({
    required String requestId,
    required String agentId,
    required String status,
    required String scopeKind,
    required DateTime visibilityStart,
    required DateTime visibilityEnd,
    this.deadline = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.targetId = const Value.absent(),
    this.targetKind = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : requestId = Value(requestId),
       agentId = Value(agentId),
       status = Value(status),
       scopeKind = Value(scopeKind),
       visibilityStart = Value(visibilityStart),
       visibilityEnd = Value(visibilityEnd),
       updatedAt = Value(updatedAt);
  static Insertable<AttentionClaimIndexData> custom({
    Expression<String>? requestId,
    Expression<String>? agentId,
    Expression<String>? status,
    Expression<String>? scopeKind,
    Expression<DateTime>? visibilityStart,
    Expression<DateTime>? visibilityEnd,
    Expression<DateTime>? deadline,
    Expression<DateTime>? nextReviewAt,
    Expression<String>? targetId,
    Expression<String>? targetKind,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (requestId != null) 'request_id': requestId,
      if (agentId != null) 'agent_id': agentId,
      if (status != null) 'status': status,
      if (scopeKind != null) 'scope_kind': scopeKind,
      if (visibilityStart != null) 'visibility_start': visibilityStart,
      if (visibilityEnd != null) 'visibility_end': visibilityEnd,
      if (deadline != null) 'deadline': deadline,
      if (nextReviewAt != null) 'next_review_at': nextReviewAt,
      if (targetId != null) 'target_id': targetId,
      if (targetKind != null) 'target_kind': targetKind,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttentionClaimIndexCompanion copyWith({
    Value<String>? requestId,
    Value<String>? agentId,
    Value<String>? status,
    Value<String>? scopeKind,
    Value<DateTime>? visibilityStart,
    Value<DateTime>? visibilityEnd,
    Value<DateTime?>? deadline,
    Value<DateTime?>? nextReviewAt,
    Value<String?>? targetId,
    Value<String?>? targetKind,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return AttentionClaimIndexCompanion(
      requestId: requestId ?? this.requestId,
      agentId: agentId ?? this.agentId,
      status: status ?? this.status,
      scopeKind: scopeKind ?? this.scopeKind,
      visibilityStart: visibilityStart ?? this.visibilityStart,
      visibilityEnd: visibilityEnd ?? this.visibilityEnd,
      deadline: deadline ?? this.deadline,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      targetId: targetId ?? this.targetId,
      targetKind: targetKind ?? this.targetKind,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (scopeKind.present) {
      map['scope_kind'] = Variable<String>(scopeKind.value);
    }
    if (visibilityStart.present) {
      map['visibility_start'] = Variable<DateTime>(visibilityStart.value);
    }
    if (visibilityEnd.present) {
      map['visibility_end'] = Variable<DateTime>(visibilityEnd.value);
    }
    if (deadline.present) {
      map['deadline'] = Variable<DateTime>(deadline.value);
    }
    if (nextReviewAt.present) {
      map['next_review_at'] = Variable<DateTime>(nextReviewAt.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (targetKind.present) {
      map['target_kind'] = Variable<String>(targetKind.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttentionClaimIndexCompanion(')
          ..write('requestId: $requestId, ')
          ..write('agentId: $agentId, ')
          ..write('status: $status, ')
          ..write('scopeKind: $scopeKind, ')
          ..write('visibilityStart: $visibilityStart, ')
          ..write('visibilityEnd: $visibilityEnd, ')
          ..write('deadline: $deadline, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('targetId: $targetId, ')
          ..write('targetKind: $targetKind, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class StandingAgreementIndex extends Table
    with TableInfo<StandingAgreementIndex, StandingAgreementIndexData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  StandingAgreementIndex(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agreementIdMeta = const VerificationMeta(
    'agreementId',
  );
  late final GeneratedColumn<String> agreementId = GeneratedColumn<String>(
    'agreement_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _cadenceMeta = const VerificationMeta(
    'cadence',
  );
  late final GeneratedColumn<String> cadence = GeneratedColumn<String>(
    'cadence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _approvalModeMeta = const VerificationMeta(
    'approvalMode',
  );
  late final GeneratedColumn<String> approvalMode = GeneratedColumn<String>(
    'approval_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _enforcementMeta = const VerificationMeta(
    'enforcement',
  );
  late final GeneratedColumn<String> enforcement = GeneratedColumn<String>(
    'enforcement',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _activeFromMeta = const VerificationMeta(
    'activeFrom',
  );
  late final GeneratedColumn<DateTime> activeFrom = GeneratedColumn<DateTime>(
    'active_from',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _activeUntilMeta = const VerificationMeta(
    'activeUntil',
  );
  late final GeneratedColumn<DateTime> activeUntil = GeneratedColumn<DateTime>(
    'active_until',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _targetKindMeta = const VerificationMeta(
    'targetKind',
  );
  late final GeneratedColumn<String> targetKind = GeneratedColumn<String>(
    'target_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    agreementId,
    agentId,
    status,
    scope,
    cadence,
    approvalMode,
    enforcement,
    activeFrom,
    activeUntil,
    priority,
    targetId,
    targetKind,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'standing_agreement_index';
  @override
  VerificationContext validateIntegrity(
    Insertable<StandingAgreementIndexData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agreement_id')) {
      context.handle(
        _agreementIdMeta,
        agreementId.isAcceptableOrUnknown(
          data['agreement_id']!,
          _agreementIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_agreementIdMeta);
    }
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('cadence')) {
      context.handle(
        _cadenceMeta,
        cadence.isAcceptableOrUnknown(data['cadence']!, _cadenceMeta),
      );
    } else if (isInserting) {
      context.missing(_cadenceMeta);
    }
    if (data.containsKey('approval_mode')) {
      context.handle(
        _approvalModeMeta,
        approvalMode.isAcceptableOrUnknown(
          data['approval_mode']!,
          _approvalModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_approvalModeMeta);
    }
    if (data.containsKey('enforcement')) {
      context.handle(
        _enforcementMeta,
        enforcement.isAcceptableOrUnknown(
          data['enforcement']!,
          _enforcementMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_enforcementMeta);
    }
    if (data.containsKey('active_from')) {
      context.handle(
        _activeFromMeta,
        activeFrom.isAcceptableOrUnknown(data['active_from']!, _activeFromMeta),
      );
    } else if (isInserting) {
      context.missing(_activeFromMeta);
    }
    if (data.containsKey('active_until')) {
      context.handle(
        _activeUntilMeta,
        activeUntil.isAcceptableOrUnknown(
          data['active_until']!,
          _activeUntilMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activeUntilMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    }
    if (data.containsKey('target_kind')) {
      context.handle(
        _targetKindMeta,
        targetKind.isAcceptableOrUnknown(data['target_kind']!, _targetKindMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agreementId};
  @override
  StandingAgreementIndexData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StandingAgreementIndexData(
      agreementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agreement_id'],
      )!,
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      cadence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cadence'],
      )!,
      approvalMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approval_mode'],
      )!,
      enforcement: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enforcement'],
      )!,
      activeFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}active_from'],
      )!,
      activeUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}active_until'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      ),
      targetKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_kind'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  StandingAgreementIndex createAlias(String alias) {
    return StandingAgreementIndex(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class StandingAgreementIndexData extends DataClass
    implements Insertable<StandingAgreementIndexData> {
  final String agreementId;
  final String agentId;
  final String status;
  final String scope;
  final String cadence;
  final String approvalMode;
  final String enforcement;
  final DateTime activeFrom;
  final DateTime activeUntil;
  final int priority;
  final String? targetId;
  final String? targetKind;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const StandingAgreementIndexData({
    required this.agreementId,
    required this.agentId,
    required this.status,
    required this.scope,
    required this.cadence,
    required this.approvalMode,
    required this.enforcement,
    required this.activeFrom,
    required this.activeUntil,
    required this.priority,
    this.targetId,
    this.targetKind,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agreement_id'] = Variable<String>(agreementId);
    map['agent_id'] = Variable<String>(agentId);
    map['status'] = Variable<String>(status);
    map['scope'] = Variable<String>(scope);
    map['cadence'] = Variable<String>(cadence);
    map['approval_mode'] = Variable<String>(approvalMode);
    map['enforcement'] = Variable<String>(enforcement);
    map['active_from'] = Variable<DateTime>(activeFrom);
    map['active_until'] = Variable<DateTime>(activeUntil);
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || targetId != null) {
      map['target_id'] = Variable<String>(targetId);
    }
    if (!nullToAbsent || targetKind != null) {
      map['target_kind'] = Variable<String>(targetKind);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  StandingAgreementIndexCompanion toCompanion(bool nullToAbsent) {
    return StandingAgreementIndexCompanion(
      agreementId: Value(agreementId),
      agentId: Value(agentId),
      status: Value(status),
      scope: Value(scope),
      cadence: Value(cadence),
      approvalMode: Value(approvalMode),
      enforcement: Value(enforcement),
      activeFrom: Value(activeFrom),
      activeUntil: Value(activeUntil),
      priority: Value(priority),
      targetId: targetId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetId),
      targetKind: targetKind == null && nullToAbsent
          ? const Value.absent()
          : Value(targetKind),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory StandingAgreementIndexData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StandingAgreementIndexData(
      agreementId: serializer.fromJson<String>(json['agreement_id']),
      agentId: serializer.fromJson<String>(json['agent_id']),
      status: serializer.fromJson<String>(json['status']),
      scope: serializer.fromJson<String>(json['scope']),
      cadence: serializer.fromJson<String>(json['cadence']),
      approvalMode: serializer.fromJson<String>(json['approval_mode']),
      enforcement: serializer.fromJson<String>(json['enforcement']),
      activeFrom: serializer.fromJson<DateTime>(json['active_from']),
      activeUntil: serializer.fromJson<DateTime>(json['active_until']),
      priority: serializer.fromJson<int>(json['priority']),
      targetId: serializer.fromJson<String?>(json['target_id']),
      targetKind: serializer.fromJson<String?>(json['target_kind']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      deletedAt: serializer.fromJson<DateTime?>(json['deleted_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agreement_id': serializer.toJson<String>(agreementId),
      'agent_id': serializer.toJson<String>(agentId),
      'status': serializer.toJson<String>(status),
      'scope': serializer.toJson<String>(scope),
      'cadence': serializer.toJson<String>(cadence),
      'approval_mode': serializer.toJson<String>(approvalMode),
      'enforcement': serializer.toJson<String>(enforcement),
      'active_from': serializer.toJson<DateTime>(activeFrom),
      'active_until': serializer.toJson<DateTime>(activeUntil),
      'priority': serializer.toJson<int>(priority),
      'target_id': serializer.toJson<String?>(targetId),
      'target_kind': serializer.toJson<String?>(targetKind),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'deleted_at': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  StandingAgreementIndexData copyWith({
    String? agreementId,
    String? agentId,
    String? status,
    String? scope,
    String? cadence,
    String? approvalMode,
    String? enforcement,
    DateTime? activeFrom,
    DateTime? activeUntil,
    int? priority,
    Value<String?> targetId = const Value.absent(),
    Value<String?> targetKind = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => StandingAgreementIndexData(
    agreementId: agreementId ?? this.agreementId,
    agentId: agentId ?? this.agentId,
    status: status ?? this.status,
    scope: scope ?? this.scope,
    cadence: cadence ?? this.cadence,
    approvalMode: approvalMode ?? this.approvalMode,
    enforcement: enforcement ?? this.enforcement,
    activeFrom: activeFrom ?? this.activeFrom,
    activeUntil: activeUntil ?? this.activeUntil,
    priority: priority ?? this.priority,
    targetId: targetId.present ? targetId.value : this.targetId,
    targetKind: targetKind.present ? targetKind.value : this.targetKind,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  StandingAgreementIndexData copyWithCompanion(
    StandingAgreementIndexCompanion data,
  ) {
    return StandingAgreementIndexData(
      agreementId: data.agreementId.present
          ? data.agreementId.value
          : this.agreementId,
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      status: data.status.present ? data.status.value : this.status,
      scope: data.scope.present ? data.scope.value : this.scope,
      cadence: data.cadence.present ? data.cadence.value : this.cadence,
      approvalMode: data.approvalMode.present
          ? data.approvalMode.value
          : this.approvalMode,
      enforcement: data.enforcement.present
          ? data.enforcement.value
          : this.enforcement,
      activeFrom: data.activeFrom.present
          ? data.activeFrom.value
          : this.activeFrom,
      activeUntil: data.activeUntil.present
          ? data.activeUntil.value
          : this.activeUntil,
      priority: data.priority.present ? data.priority.value : this.priority,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      targetKind: data.targetKind.present
          ? data.targetKind.value
          : this.targetKind,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StandingAgreementIndexData(')
          ..write('agreementId: $agreementId, ')
          ..write('agentId: $agentId, ')
          ..write('status: $status, ')
          ..write('scope: $scope, ')
          ..write('cadence: $cadence, ')
          ..write('approvalMode: $approvalMode, ')
          ..write('enforcement: $enforcement, ')
          ..write('activeFrom: $activeFrom, ')
          ..write('activeUntil: $activeUntil, ')
          ..write('priority: $priority, ')
          ..write('targetId: $targetId, ')
          ..write('targetKind: $targetKind, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    agreementId,
    agentId,
    status,
    scope,
    cadence,
    approvalMode,
    enforcement,
    activeFrom,
    activeUntil,
    priority,
    targetId,
    targetKind,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StandingAgreementIndexData &&
          other.agreementId == this.agreementId &&
          other.agentId == this.agentId &&
          other.status == this.status &&
          other.scope == this.scope &&
          other.cadence == this.cadence &&
          other.approvalMode == this.approvalMode &&
          other.enforcement == this.enforcement &&
          other.activeFrom == this.activeFrom &&
          other.activeUntil == this.activeUntil &&
          other.priority == this.priority &&
          other.targetId == this.targetId &&
          other.targetKind == this.targetKind &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class StandingAgreementIndexCompanion
    extends UpdateCompanion<StandingAgreementIndexData> {
  final Value<String> agreementId;
  final Value<String> agentId;
  final Value<String> status;
  final Value<String> scope;
  final Value<String> cadence;
  final Value<String> approvalMode;
  final Value<String> enforcement;
  final Value<DateTime> activeFrom;
  final Value<DateTime> activeUntil;
  final Value<int> priority;
  final Value<String?> targetId;
  final Value<String?> targetKind;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const StandingAgreementIndexCompanion({
    this.agreementId = const Value.absent(),
    this.agentId = const Value.absent(),
    this.status = const Value.absent(),
    this.scope = const Value.absent(),
    this.cadence = const Value.absent(),
    this.approvalMode = const Value.absent(),
    this.enforcement = const Value.absent(),
    this.activeFrom = const Value.absent(),
    this.activeUntil = const Value.absent(),
    this.priority = const Value.absent(),
    this.targetId = const Value.absent(),
    this.targetKind = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StandingAgreementIndexCompanion.insert({
    required String agreementId,
    required String agentId,
    required String status,
    required String scope,
    required String cadence,
    required String approvalMode,
    required String enforcement,
    required DateTime activeFrom,
    required DateTime activeUntil,
    required int priority,
    this.targetId = const Value.absent(),
    this.targetKind = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : agreementId = Value(agreementId),
       agentId = Value(agentId),
       status = Value(status),
       scope = Value(scope),
       cadence = Value(cadence),
       approvalMode = Value(approvalMode),
       enforcement = Value(enforcement),
       activeFrom = Value(activeFrom),
       activeUntil = Value(activeUntil),
       priority = Value(priority),
       updatedAt = Value(updatedAt);
  static Insertable<StandingAgreementIndexData> custom({
    Expression<String>? agreementId,
    Expression<String>? agentId,
    Expression<String>? status,
    Expression<String>? scope,
    Expression<String>? cadence,
    Expression<String>? approvalMode,
    Expression<String>? enforcement,
    Expression<DateTime>? activeFrom,
    Expression<DateTime>? activeUntil,
    Expression<int>? priority,
    Expression<String>? targetId,
    Expression<String>? targetKind,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agreementId != null) 'agreement_id': agreementId,
      if (agentId != null) 'agent_id': agentId,
      if (status != null) 'status': status,
      if (scope != null) 'scope': scope,
      if (cadence != null) 'cadence': cadence,
      if (approvalMode != null) 'approval_mode': approvalMode,
      if (enforcement != null) 'enforcement': enforcement,
      if (activeFrom != null) 'active_from': activeFrom,
      if (activeUntil != null) 'active_until': activeUntil,
      if (priority != null) 'priority': priority,
      if (targetId != null) 'target_id': targetId,
      if (targetKind != null) 'target_kind': targetKind,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StandingAgreementIndexCompanion copyWith({
    Value<String>? agreementId,
    Value<String>? agentId,
    Value<String>? status,
    Value<String>? scope,
    Value<String>? cadence,
    Value<String>? approvalMode,
    Value<String>? enforcement,
    Value<DateTime>? activeFrom,
    Value<DateTime>? activeUntil,
    Value<int>? priority,
    Value<String?>? targetId,
    Value<String?>? targetKind,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return StandingAgreementIndexCompanion(
      agreementId: agreementId ?? this.agreementId,
      agentId: agentId ?? this.agentId,
      status: status ?? this.status,
      scope: scope ?? this.scope,
      cadence: cadence ?? this.cadence,
      approvalMode: approvalMode ?? this.approvalMode,
      enforcement: enforcement ?? this.enforcement,
      activeFrom: activeFrom ?? this.activeFrom,
      activeUntil: activeUntil ?? this.activeUntil,
      priority: priority ?? this.priority,
      targetId: targetId ?? this.targetId,
      targetKind: targetKind ?? this.targetKind,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agreementId.present) {
      map['agreement_id'] = Variable<String>(agreementId.value);
    }
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (cadence.present) {
      map['cadence'] = Variable<String>(cadence.value);
    }
    if (approvalMode.present) {
      map['approval_mode'] = Variable<String>(approvalMode.value);
    }
    if (enforcement.present) {
      map['enforcement'] = Variable<String>(enforcement.value);
    }
    if (activeFrom.present) {
      map['active_from'] = Variable<DateTime>(activeFrom.value);
    }
    if (activeUntil.present) {
      map['active_until'] = Variable<DateTime>(activeUntil.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (targetKind.present) {
      map['target_kind'] = Variable<String>(targetKind.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StandingAgreementIndexCompanion(')
          ..write('agreementId: $agreementId, ')
          ..write('agentId: $agentId, ')
          ..write('status: $status, ')
          ..write('scope: $scope, ')
          ..write('cadence: $cadence, ')
          ..write('approvalMode: $approvalMode, ')
          ..write('enforcement: $enforcement, ')
          ..write('activeFrom: $activeFrom, ')
          ..write('activeUntil: $activeUntil, ')
          ..write('priority: $priority, ')
          ..write('targetId: $targetId, ')
          ..write('targetKind: $targetKind, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class WakeRunLog extends Table with TableInfo<WakeRunLog, WakeRunLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  WakeRunLog(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _runKeyMeta = const VerificationMeta('runKey');
  late final GeneratedColumn<String> runKey = GeneratedColumn<String>(
    'run_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _reasonIdMeta = const VerificationMeta(
    'reasonId',
  );
  late final GeneratedColumn<String> reasonId = GeneratedColumn<String>(
    'reason_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _threadIdMeta = const VerificationMeta(
    'threadId',
  );
  late final GeneratedColumn<String> threadId = GeneratedColumn<String>(
    'thread_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _logicalChangeKeyMeta = const VerificationMeta(
    'logicalChangeKey',
  );
  late final GeneratedColumn<String> logicalChangeKey = GeneratedColumn<String>(
    'logical_change_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
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
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _templateVersionIdMeta = const VerificationMeta(
    'templateVersionId',
  );
  late final GeneratedColumn<String> templateVersionId =
      GeneratedColumn<String>(
        'template_version_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _resolvedModelIdMeta = const VerificationMeta(
    'resolvedModelId',
  );
  late final GeneratedColumn<String> resolvedModelId = GeneratedColumn<String>(
    'resolved_model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _soulIdMeta = const VerificationMeta('soulId');
  late final GeneratedColumn<String> soulId = GeneratedColumn<String>(
    'soul_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _soulVersionIdMeta = const VerificationMeta(
    'soulVersionId',
  );
  late final GeneratedColumn<String> soulVersionId = GeneratedColumn<String>(
    'soul_version_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _userRatingMeta = const VerificationMeta(
    'userRating',
  );
  late final GeneratedColumn<double> userRating = GeneratedColumn<double>(
    'user_rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _ratedAtMeta = const VerificationMeta(
    'ratedAt',
  );
  late final GeneratedColumn<DateTime> ratedAt = GeneratedColumn<DateTime>(
    'rated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    runKey,
    agentId,
    reason,
    reasonId,
    threadId,
    status,
    logicalChangeKey,
    createdAt,
    startedAt,
    completedAt,
    errorMessage,
    templateId,
    templateVersionId,
    resolvedModelId,
    soulId,
    soulVersionId,
    userRating,
    ratedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wake_run_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<WakeRunLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('run_key')) {
      context.handle(
        _runKeyMeta,
        runKey.isAcceptableOrUnknown(data['run_key']!, _runKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_runKeyMeta);
    }
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('reason_id')) {
      context.handle(
        _reasonIdMeta,
        reasonId.isAcceptableOrUnknown(data['reason_id']!, _reasonIdMeta),
      );
    }
    if (data.containsKey('thread_id')) {
      context.handle(
        _threadIdMeta,
        threadId.isAcceptableOrUnknown(data['thread_id']!, _threadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_threadIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('logical_change_key')) {
      context.handle(
        _logicalChangeKeyMeta,
        logicalChangeKey.isAcceptableOrUnknown(
          data['logical_change_key']!,
          _logicalChangeKeyMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    }
    if (data.containsKey('template_version_id')) {
      context.handle(
        _templateVersionIdMeta,
        templateVersionId.isAcceptableOrUnknown(
          data['template_version_id']!,
          _templateVersionIdMeta,
        ),
      );
    }
    if (data.containsKey('resolved_model_id')) {
      context.handle(
        _resolvedModelIdMeta,
        resolvedModelId.isAcceptableOrUnknown(
          data['resolved_model_id']!,
          _resolvedModelIdMeta,
        ),
      );
    }
    if (data.containsKey('soul_id')) {
      context.handle(
        _soulIdMeta,
        soulId.isAcceptableOrUnknown(data['soul_id']!, _soulIdMeta),
      );
    }
    if (data.containsKey('soul_version_id')) {
      context.handle(
        _soulVersionIdMeta,
        soulVersionId.isAcceptableOrUnknown(
          data['soul_version_id']!,
          _soulVersionIdMeta,
        ),
      );
    }
    if (data.containsKey('user_rating')) {
      context.handle(
        _userRatingMeta,
        userRating.isAcceptableOrUnknown(data['user_rating']!, _userRatingMeta),
      );
    }
    if (data.containsKey('rated_at')) {
      context.handle(
        _ratedAtMeta,
        ratedAt.isAcceptableOrUnknown(data['rated_at']!, _ratedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {runKey};
  @override
  WakeRunLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WakeRunLogData(
      runKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_key'],
      )!,
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      reasonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason_id'],
      ),
      threadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      logicalChangeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logical_change_key'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      ),
      templateVersionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_version_id'],
      ),
      resolvedModelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolved_model_id'],
      ),
      soulId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}soul_id'],
      ),
      soulVersionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}soul_version_id'],
      ),
      userRating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}user_rating'],
      ),
      ratedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}rated_at'],
      ),
    );
  }

  @override
  WakeRunLog createAlias(String alias) {
    return WakeRunLog(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class WakeRunLogData extends DataClass implements Insertable<WakeRunLogData> {
  final String runKey;
  final String agentId;
  final String reason;
  final String? reasonId;
  final String threadId;
  final String status;
  final String? logicalChangeKey;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final String? templateId;
  final String? templateVersionId;
  final String? resolvedModelId;
  final String? soulId;
  final String? soulVersionId;
  final double? userRating;
  final DateTime? ratedAt;
  const WakeRunLogData({
    required this.runKey,
    required this.agentId,
    required this.reason,
    this.reasonId,
    required this.threadId,
    required this.status,
    this.logicalChangeKey,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
    this.templateId,
    this.templateVersionId,
    this.resolvedModelId,
    this.soulId,
    this.soulVersionId,
    this.userRating,
    this.ratedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['run_key'] = Variable<String>(runKey);
    map['agent_id'] = Variable<String>(agentId);
    map['reason'] = Variable<String>(reason);
    if (!nullToAbsent || reasonId != null) {
      map['reason_id'] = Variable<String>(reasonId);
    }
    map['thread_id'] = Variable<String>(threadId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || logicalChangeKey != null) {
      map['logical_change_key'] = Variable<String>(logicalChangeKey);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || templateId != null) {
      map['template_id'] = Variable<String>(templateId);
    }
    if (!nullToAbsent || templateVersionId != null) {
      map['template_version_id'] = Variable<String>(templateVersionId);
    }
    if (!nullToAbsent || resolvedModelId != null) {
      map['resolved_model_id'] = Variable<String>(resolvedModelId);
    }
    if (!nullToAbsent || soulId != null) {
      map['soul_id'] = Variable<String>(soulId);
    }
    if (!nullToAbsent || soulVersionId != null) {
      map['soul_version_id'] = Variable<String>(soulVersionId);
    }
    if (!nullToAbsent || userRating != null) {
      map['user_rating'] = Variable<double>(userRating);
    }
    if (!nullToAbsent || ratedAt != null) {
      map['rated_at'] = Variable<DateTime>(ratedAt);
    }
    return map;
  }

  WakeRunLogCompanion toCompanion(bool nullToAbsent) {
    return WakeRunLogCompanion(
      runKey: Value(runKey),
      agentId: Value(agentId),
      reason: Value(reason),
      reasonId: reasonId == null && nullToAbsent
          ? const Value.absent()
          : Value(reasonId),
      threadId: Value(threadId),
      status: Value(status),
      logicalChangeKey: logicalChangeKey == null && nullToAbsent
          ? const Value.absent()
          : Value(logicalChangeKey),
      createdAt: Value(createdAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      templateId: templateId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateId),
      templateVersionId: templateVersionId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateVersionId),
      resolvedModelId: resolvedModelId == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedModelId),
      soulId: soulId == null && nullToAbsent
          ? const Value.absent()
          : Value(soulId),
      soulVersionId: soulVersionId == null && nullToAbsent
          ? const Value.absent()
          : Value(soulVersionId),
      userRating: userRating == null && nullToAbsent
          ? const Value.absent()
          : Value(userRating),
      ratedAt: ratedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(ratedAt),
    );
  }

  factory WakeRunLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WakeRunLogData(
      runKey: serializer.fromJson<String>(json['run_key']),
      agentId: serializer.fromJson<String>(json['agent_id']),
      reason: serializer.fromJson<String>(json['reason']),
      reasonId: serializer.fromJson<String?>(json['reason_id']),
      threadId: serializer.fromJson<String>(json['thread_id']),
      status: serializer.fromJson<String>(json['status']),
      logicalChangeKey: serializer.fromJson<String?>(
        json['logical_change_key'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      startedAt: serializer.fromJson<DateTime?>(json['started_at']),
      completedAt: serializer.fromJson<DateTime?>(json['completed_at']),
      errorMessage: serializer.fromJson<String?>(json['error_message']),
      templateId: serializer.fromJson<String?>(json['template_id']),
      templateVersionId: serializer.fromJson<String?>(
        json['template_version_id'],
      ),
      resolvedModelId: serializer.fromJson<String?>(json['resolved_model_id']),
      soulId: serializer.fromJson<String?>(json['soul_id']),
      soulVersionId: serializer.fromJson<String?>(json['soul_version_id']),
      userRating: serializer.fromJson<double?>(json['user_rating']),
      ratedAt: serializer.fromJson<DateTime?>(json['rated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'run_key': serializer.toJson<String>(runKey),
      'agent_id': serializer.toJson<String>(agentId),
      'reason': serializer.toJson<String>(reason),
      'reason_id': serializer.toJson<String?>(reasonId),
      'thread_id': serializer.toJson<String>(threadId),
      'status': serializer.toJson<String>(status),
      'logical_change_key': serializer.toJson<String?>(logicalChangeKey),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'started_at': serializer.toJson<DateTime?>(startedAt),
      'completed_at': serializer.toJson<DateTime?>(completedAt),
      'error_message': serializer.toJson<String?>(errorMessage),
      'template_id': serializer.toJson<String?>(templateId),
      'template_version_id': serializer.toJson<String?>(templateVersionId),
      'resolved_model_id': serializer.toJson<String?>(resolvedModelId),
      'soul_id': serializer.toJson<String?>(soulId),
      'soul_version_id': serializer.toJson<String?>(soulVersionId),
      'user_rating': serializer.toJson<double?>(userRating),
      'rated_at': serializer.toJson<DateTime?>(ratedAt),
    };
  }

  WakeRunLogData copyWith({
    String? runKey,
    String? agentId,
    String? reason,
    Value<String?> reasonId = const Value.absent(),
    String? threadId,
    String? status,
    Value<String?> logicalChangeKey = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    Value<String?> templateId = const Value.absent(),
    Value<String?> templateVersionId = const Value.absent(),
    Value<String?> resolvedModelId = const Value.absent(),
    Value<String?> soulId = const Value.absent(),
    Value<String?> soulVersionId = const Value.absent(),
    Value<double?> userRating = const Value.absent(),
    Value<DateTime?> ratedAt = const Value.absent(),
  }) => WakeRunLogData(
    runKey: runKey ?? this.runKey,
    agentId: agentId ?? this.agentId,
    reason: reason ?? this.reason,
    reasonId: reasonId.present ? reasonId.value : this.reasonId,
    threadId: threadId ?? this.threadId,
    status: status ?? this.status,
    logicalChangeKey: logicalChangeKey.present
        ? logicalChangeKey.value
        : this.logicalChangeKey,
    createdAt: createdAt ?? this.createdAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    templateId: templateId.present ? templateId.value : this.templateId,
    templateVersionId: templateVersionId.present
        ? templateVersionId.value
        : this.templateVersionId,
    resolvedModelId: resolvedModelId.present
        ? resolvedModelId.value
        : this.resolvedModelId,
    soulId: soulId.present ? soulId.value : this.soulId,
    soulVersionId: soulVersionId.present
        ? soulVersionId.value
        : this.soulVersionId,
    userRating: userRating.present ? userRating.value : this.userRating,
    ratedAt: ratedAt.present ? ratedAt.value : this.ratedAt,
  );
  WakeRunLogData copyWithCompanion(WakeRunLogCompanion data) {
    return WakeRunLogData(
      runKey: data.runKey.present ? data.runKey.value : this.runKey,
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      reason: data.reason.present ? data.reason.value : this.reason,
      reasonId: data.reasonId.present ? data.reasonId.value : this.reasonId,
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
      status: data.status.present ? data.status.value : this.status,
      logicalChangeKey: data.logicalChangeKey.present
          ? data.logicalChangeKey.value
          : this.logicalChangeKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      templateVersionId: data.templateVersionId.present
          ? data.templateVersionId.value
          : this.templateVersionId,
      resolvedModelId: data.resolvedModelId.present
          ? data.resolvedModelId.value
          : this.resolvedModelId,
      soulId: data.soulId.present ? data.soulId.value : this.soulId,
      soulVersionId: data.soulVersionId.present
          ? data.soulVersionId.value
          : this.soulVersionId,
      userRating: data.userRating.present
          ? data.userRating.value
          : this.userRating,
      ratedAt: data.ratedAt.present ? data.ratedAt.value : this.ratedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WakeRunLogData(')
          ..write('runKey: $runKey, ')
          ..write('agentId: $agentId, ')
          ..write('reason: $reason, ')
          ..write('reasonId: $reasonId, ')
          ..write('threadId: $threadId, ')
          ..write('status: $status, ')
          ..write('logicalChangeKey: $logicalChangeKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('templateId: $templateId, ')
          ..write('templateVersionId: $templateVersionId, ')
          ..write('resolvedModelId: $resolvedModelId, ')
          ..write('soulId: $soulId, ')
          ..write('soulVersionId: $soulVersionId, ')
          ..write('userRating: $userRating, ')
          ..write('ratedAt: $ratedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    runKey,
    agentId,
    reason,
    reasonId,
    threadId,
    status,
    logicalChangeKey,
    createdAt,
    startedAt,
    completedAt,
    errorMessage,
    templateId,
    templateVersionId,
    resolvedModelId,
    soulId,
    soulVersionId,
    userRating,
    ratedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WakeRunLogData &&
          other.runKey == this.runKey &&
          other.agentId == this.agentId &&
          other.reason == this.reason &&
          other.reasonId == this.reasonId &&
          other.threadId == this.threadId &&
          other.status == this.status &&
          other.logicalChangeKey == this.logicalChangeKey &&
          other.createdAt == this.createdAt &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.errorMessage == this.errorMessage &&
          other.templateId == this.templateId &&
          other.templateVersionId == this.templateVersionId &&
          other.resolvedModelId == this.resolvedModelId &&
          other.soulId == this.soulId &&
          other.soulVersionId == this.soulVersionId &&
          other.userRating == this.userRating &&
          other.ratedAt == this.ratedAt);
}

class WakeRunLogCompanion extends UpdateCompanion<WakeRunLogData> {
  final Value<String> runKey;
  final Value<String> agentId;
  final Value<String> reason;
  final Value<String?> reasonId;
  final Value<String> threadId;
  final Value<String> status;
  final Value<String?> logicalChangeKey;
  final Value<DateTime> createdAt;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> completedAt;
  final Value<String?> errorMessage;
  final Value<String?> templateId;
  final Value<String?> templateVersionId;
  final Value<String?> resolvedModelId;
  final Value<String?> soulId;
  final Value<String?> soulVersionId;
  final Value<double?> userRating;
  final Value<DateTime?> ratedAt;
  final Value<int> rowid;
  const WakeRunLogCompanion({
    this.runKey = const Value.absent(),
    this.agentId = const Value.absent(),
    this.reason = const Value.absent(),
    this.reasonId = const Value.absent(),
    this.threadId = const Value.absent(),
    this.status = const Value.absent(),
    this.logicalChangeKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.templateId = const Value.absent(),
    this.templateVersionId = const Value.absent(),
    this.resolvedModelId = const Value.absent(),
    this.soulId = const Value.absent(),
    this.soulVersionId = const Value.absent(),
    this.userRating = const Value.absent(),
    this.ratedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WakeRunLogCompanion.insert({
    required String runKey,
    required String agentId,
    required String reason,
    this.reasonId = const Value.absent(),
    required String threadId,
    required String status,
    this.logicalChangeKey = const Value.absent(),
    required DateTime createdAt,
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.templateId = const Value.absent(),
    this.templateVersionId = const Value.absent(),
    this.resolvedModelId = const Value.absent(),
    this.soulId = const Value.absent(),
    this.soulVersionId = const Value.absent(),
    this.userRating = const Value.absent(),
    this.ratedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : runKey = Value(runKey),
       agentId = Value(agentId),
       reason = Value(reason),
       threadId = Value(threadId),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<WakeRunLogData> custom({
    Expression<String>? runKey,
    Expression<String>? agentId,
    Expression<String>? reason,
    Expression<String>? reasonId,
    Expression<String>? threadId,
    Expression<String>? status,
    Expression<String>? logicalChangeKey,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<String>? errorMessage,
    Expression<String>? templateId,
    Expression<String>? templateVersionId,
    Expression<String>? resolvedModelId,
    Expression<String>? soulId,
    Expression<String>? soulVersionId,
    Expression<double>? userRating,
    Expression<DateTime>? ratedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (runKey != null) 'run_key': runKey,
      if (agentId != null) 'agent_id': agentId,
      if (reason != null) 'reason': reason,
      if (reasonId != null) 'reason_id': reasonId,
      if (threadId != null) 'thread_id': threadId,
      if (status != null) 'status': status,
      if (logicalChangeKey != null) 'logical_change_key': logicalChangeKey,
      if (createdAt != null) 'created_at': createdAt,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (errorMessage != null) 'error_message': errorMessage,
      if (templateId != null) 'template_id': templateId,
      if (templateVersionId != null) 'template_version_id': templateVersionId,
      if (resolvedModelId != null) 'resolved_model_id': resolvedModelId,
      if (soulId != null) 'soul_id': soulId,
      if (soulVersionId != null) 'soul_version_id': soulVersionId,
      if (userRating != null) 'user_rating': userRating,
      if (ratedAt != null) 'rated_at': ratedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WakeRunLogCompanion copyWith({
    Value<String>? runKey,
    Value<String>? agentId,
    Value<String>? reason,
    Value<String?>? reasonId,
    Value<String>? threadId,
    Value<String>? status,
    Value<String?>? logicalChangeKey,
    Value<DateTime>? createdAt,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? completedAt,
    Value<String?>? errorMessage,
    Value<String?>? templateId,
    Value<String?>? templateVersionId,
    Value<String?>? resolvedModelId,
    Value<String?>? soulId,
    Value<String?>? soulVersionId,
    Value<double?>? userRating,
    Value<DateTime?>? ratedAt,
    Value<int>? rowid,
  }) {
    return WakeRunLogCompanion(
      runKey: runKey ?? this.runKey,
      agentId: agentId ?? this.agentId,
      reason: reason ?? this.reason,
      reasonId: reasonId ?? this.reasonId,
      threadId: threadId ?? this.threadId,
      status: status ?? this.status,
      logicalChangeKey: logicalChangeKey ?? this.logicalChangeKey,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      templateId: templateId ?? this.templateId,
      templateVersionId: templateVersionId ?? this.templateVersionId,
      resolvedModelId: resolvedModelId ?? this.resolvedModelId,
      soulId: soulId ?? this.soulId,
      soulVersionId: soulVersionId ?? this.soulVersionId,
      userRating: userRating ?? this.userRating,
      ratedAt: ratedAt ?? this.ratedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (runKey.present) {
      map['run_key'] = Variable<String>(runKey.value);
    }
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (reasonId.present) {
      map['reason_id'] = Variable<String>(reasonId.value);
    }
    if (threadId.present) {
      map['thread_id'] = Variable<String>(threadId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (logicalChangeKey.present) {
      map['logical_change_key'] = Variable<String>(logicalChangeKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (templateVersionId.present) {
      map['template_version_id'] = Variable<String>(templateVersionId.value);
    }
    if (resolvedModelId.present) {
      map['resolved_model_id'] = Variable<String>(resolvedModelId.value);
    }
    if (soulId.present) {
      map['soul_id'] = Variable<String>(soulId.value);
    }
    if (soulVersionId.present) {
      map['soul_version_id'] = Variable<String>(soulVersionId.value);
    }
    if (userRating.present) {
      map['user_rating'] = Variable<double>(userRating.value);
    }
    if (ratedAt.present) {
      map['rated_at'] = Variable<DateTime>(ratedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WakeRunLogCompanion(')
          ..write('runKey: $runKey, ')
          ..write('agentId: $agentId, ')
          ..write('reason: $reason, ')
          ..write('reasonId: $reasonId, ')
          ..write('threadId: $threadId, ')
          ..write('status: $status, ')
          ..write('logicalChangeKey: $logicalChangeKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('templateId: $templateId, ')
          ..write('templateVersionId: $templateVersionId, ')
          ..write('resolvedModelId: $resolvedModelId, ')
          ..write('soulId: $soulId, ')
          ..write('soulVersionId: $soulVersionId, ')
          ..write('userRating: $userRating, ')
          ..write('ratedAt: $ratedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SagaLog extends Table with TableInfo<SagaLog, SagaLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SagaLog(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _runKeyMeta = const VerificationMeta('runKey');
  late final GeneratedColumn<String> runKey = GeneratedColumn<String>(
    'run_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _toolNameMeta = const VerificationMeta(
    'toolName',
  );
  late final GeneratedColumn<String> toolName = GeneratedColumn<String>(
    'tool_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
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
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    agentId,
    runKey,
    phase,
    status,
    toolName,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saga_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<SagaLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('run_key')) {
      context.handle(
        _runKeyMeta,
        runKey.isAcceptableOrUnknown(data['run_key']!, _runKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_runKeyMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    } else if (isInserting) {
      context.missing(_phaseMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('tool_name')) {
      context.handle(
        _toolNameMeta,
        toolName.isAcceptableOrUnknown(data['tool_name']!, _toolNameMeta),
      );
    } else if (isInserting) {
      context.missing(_toolNameMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
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
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  SagaLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SagaLogData(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      runKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_key'],
      )!,
      phase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phase'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      toolName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_name'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  SagaLog createAlias(String alias) {
    return SagaLog(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SagaLogData extends DataClass implements Insertable<SagaLogData> {
  final String operationId;
  final String agentId;
  final String runKey;
  final String phase;
  final String status;
  final String toolName;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SagaLogData({
    required this.operationId,
    required this.agentId,
    required this.runKey,
    required this.phase,
    required this.status,
    required this.toolName,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['agent_id'] = Variable<String>(agentId);
    map['run_key'] = Variable<String>(runKey);
    map['phase'] = Variable<String>(phase);
    map['status'] = Variable<String>(status);
    map['tool_name'] = Variable<String>(toolName);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SagaLogCompanion toCompanion(bool nullToAbsent) {
    return SagaLogCompanion(
      operationId: Value(operationId),
      agentId: Value(agentId),
      runKey: Value(runKey),
      phase: Value(phase),
      status: Value(status),
      toolName: Value(toolName),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SagaLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SagaLogData(
      operationId: serializer.fromJson<String>(json['operation_id']),
      agentId: serializer.fromJson<String>(json['agent_id']),
      runKey: serializer.fromJson<String>(json['run_key']),
      phase: serializer.fromJson<String>(json['phase']),
      status: serializer.fromJson<String>(json['status']),
      toolName: serializer.fromJson<String>(json['tool_name']),
      lastError: serializer.fromJson<String?>(json['last_error']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operation_id': serializer.toJson<String>(operationId),
      'agent_id': serializer.toJson<String>(agentId),
      'run_key': serializer.toJson<String>(runKey),
      'phase': serializer.toJson<String>(phase),
      'status': serializer.toJson<String>(status),
      'tool_name': serializer.toJson<String>(toolName),
      'last_error': serializer.toJson<String?>(lastError),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SagaLogData copyWith({
    String? operationId,
    String? agentId,
    String? runKey,
    String? phase,
    String? status,
    String? toolName,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SagaLogData(
    operationId: operationId ?? this.operationId,
    agentId: agentId ?? this.agentId,
    runKey: runKey ?? this.runKey,
    phase: phase ?? this.phase,
    status: status ?? this.status,
    toolName: toolName ?? this.toolName,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SagaLogData copyWithCompanion(SagaLogCompanion data) {
    return SagaLogData(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      runKey: data.runKey.present ? data.runKey.value : this.runKey,
      phase: data.phase.present ? data.phase.value : this.phase,
      status: data.status.present ? data.status.value : this.status,
      toolName: data.toolName.present ? data.toolName.value : this.toolName,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SagaLogData(')
          ..write('operationId: $operationId, ')
          ..write('agentId: $agentId, ')
          ..write('runKey: $runKey, ')
          ..write('phase: $phase, ')
          ..write('status: $status, ')
          ..write('toolName: $toolName, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    agentId,
    runKey,
    phase,
    status,
    toolName,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SagaLogData &&
          other.operationId == this.operationId &&
          other.agentId == this.agentId &&
          other.runKey == this.runKey &&
          other.phase == this.phase &&
          other.status == this.status &&
          other.toolName == this.toolName &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SagaLogCompanion extends UpdateCompanion<SagaLogData> {
  final Value<String> operationId;
  final Value<String> agentId;
  final Value<String> runKey;
  final Value<String> phase;
  final Value<String> status;
  final Value<String> toolName;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SagaLogCompanion({
    this.operationId = const Value.absent(),
    this.agentId = const Value.absent(),
    this.runKey = const Value.absent(),
    this.phase = const Value.absent(),
    this.status = const Value.absent(),
    this.toolName = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SagaLogCompanion.insert({
    required String operationId,
    required String agentId,
    required String runKey,
    required String phase,
    required String status,
    required String toolName,
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       agentId = Value(agentId),
       runKey = Value(runKey),
       phase = Value(phase),
       status = Value(status),
       toolName = Value(toolName),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SagaLogData> custom({
    Expression<String>? operationId,
    Expression<String>? agentId,
    Expression<String>? runKey,
    Expression<String>? phase,
    Expression<String>? status,
    Expression<String>? toolName,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (agentId != null) 'agent_id': agentId,
      if (runKey != null) 'run_key': runKey,
      if (phase != null) 'phase': phase,
      if (status != null) 'status': status,
      if (toolName != null) 'tool_name': toolName,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SagaLogCompanion copyWith({
    Value<String>? operationId,
    Value<String>? agentId,
    Value<String>? runKey,
    Value<String>? phase,
    Value<String>? status,
    Value<String>? toolName,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SagaLogCompanion(
      operationId: operationId ?? this.operationId,
      agentId: agentId ?? this.agentId,
      runKey: runKey ?? this.runKey,
      phase: phase ?? this.phase,
      status: status ?? this.status,
      toolName: toolName ?? this.toolName,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (runKey.present) {
      map['run_key'] = Variable<String>(runKey.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (toolName.present) {
      map['tool_name'] = Variable<String>(toolName.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
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
    return (StringBuffer('SagaLogCompanion(')
          ..write('operationId: $operationId, ')
          ..write('agentId: $agentId, ')
          ..write('runKey: $runKey, ')
          ..write('phase: $phase, ')
          ..write('status: $status, ')
          ..write('toolName: $toolName, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AgentDatabase extends GeneratedDatabase {
  _$AgentDatabase(QueryExecutor e) : super(e);
  _$AgentDatabase.connect(DatabaseConnection c) : super.connect(c);
  $AgentDatabaseManager get managers => $AgentDatabaseManager(this);
  late final AgentEntities agentEntities = AgentEntities(this);
  late final Index idxAgentEntitiesAgentId = Index(
    'idx_agent_entities_agent_id',
    'CREATE INDEX idx_agent_entities_agent_id ON agent_entities (agent_id)',
  );
  late final Index idxAgentEntitiesType = Index(
    'idx_agent_entities_type',
    'CREATE INDEX idx_agent_entities_type ON agent_entities (type, agent_id, created_at DESC)',
  );
  late final Index idxAgentEntitiesAgentTypeSub = Index(
    'idx_agent_entities_agent_type_sub',
    'CREATE INDEX idx_agent_entities_agent_type_sub ON agent_entities (agent_id, type, subtype, created_at DESC)',
  );
  late final Index idxAgentEntitiesThread = Index(
    'idx_agent_entities_thread',
    'CREATE INDEX idx_agent_entities_thread ON agent_entities (agent_id, thread_id, created_at DESC)',
  );
  late final Index idxAgentEntitiesActiveAgentTypeCreatedId = Index(
    'idx_agent_entities_active_agent_type_created_id',
    'CREATE INDEX idx_agent_entities_active_agent_type_created_id ON agent_entities (agent_id, type, created_at DESC, id DESC) WHERE deleted_at IS NULL',
  );
  late final Index idxAgentEntitiesActiveAgentTypeSubCreatedId = Index(
    'idx_agent_entities_active_agent_type_sub_created_id',
    'CREATE INDEX idx_agent_entities_active_agent_type_sub_created_id ON agent_entities (agent_id, type, subtype, created_at DESC, id DESC) WHERE deleted_at IS NULL',
  );
  late final Index idxAgentEntitiesActiveTypeCreated = Index(
    'idx_agent_entities_active_type_created',
    'CREATE INDEX idx_agent_entities_active_type_created ON agent_entities (type, created_at DESC) WHERE deleted_at IS NULL',
  );
  late final Index idxAgentEntitiesActiveTypeSubCreatedId = Index(
    'idx_agent_entities_active_type_sub_created_id',
    'CREATE INDEX idx_agent_entities_active_type_sub_created_id ON agent_entities (type, subtype, created_at DESC, id DESC) WHERE deleted_at IS NULL',
  );
  late final Index idxAgentEntitiesTokenUsageSince = Index(
    'idx_agent_entities_token_usage_since',
    'CREATE INDEX idx_agent_entities_token_usage_since ON agent_entities (type, created_at DESC) WHERE type = \'wakeTokenUsage\' AND deleted_at IS NULL',
  );
  late final Index idxAgentEntitiesDueWake = Index(
    'idx_agent_entities_due_wake',
    'CREATE INDEX idx_agent_entities_due_wake ON agent_entities (json_extract(serialized, \'\$.scheduledWakeAt\') ASC) WHERE type = \'agentState\' AND deleted_at IS NULL AND json_extract(serialized, \'\$.scheduledWakeAt\') IS NOT NULL',
  );
  late final AgentLinks agentLinks = AgentLinks(this);
  late final Index idxAgentLinksFrom = Index(
    'idx_agent_links_from',
    'CREATE INDEX idx_agent_links_from ON agent_links (from_id, type)',
  );
  late final Index idxAgentLinksTo = Index(
    'idx_agent_links_to',
    'CREATE INDEX idx_agent_links_to ON agent_links (to_id, type)',
  );
  late final Index idxAgentLinksType = Index(
    'idx_agent_links_type',
    'CREATE INDEX idx_agent_links_type ON agent_links (type)',
  );
  late final Index idxAgentLinksUniqueFromToType = Index(
    'idx_agent_links_unique_from_to_type',
    'CREATE UNIQUE INDEX idx_agent_links_unique_from_to_type ON agent_links (from_id, to_id, type) WHERE type != \'message_payload\'',
  );
  late final Index idxUniqueImproverPerTemplate = Index(
    'idx_unique_improver_per_template',
    'CREATE UNIQUE INDEX idx_unique_improver_per_template ON agent_links (to_id) WHERE type = \'improver_target\' AND deleted_at IS NULL',
  );
  late final Index idxUniqueSoulPerTemplate = Index(
    'idx_unique_soul_per_template',
    'CREATE UNIQUE INDEX idx_unique_soul_per_template ON agent_links (from_id) WHERE type = \'soul_assignment\' AND deleted_at IS NULL',
  );
  late final Index idxAgentLinksActiveFromTypeTo = Index(
    'idx_agent_links_active_from_type_to',
    'CREATE INDEX idx_agent_links_active_from_type_to ON agent_links (from_id, type, to_id) WHERE deleted_at IS NULL',
  );
  late final Index idxAgentLinksActiveToType = Index(
    'idx_agent_links_active_to_type',
    'CREATE INDEX idx_agent_links_active_to_type ON agent_links (to_id, type) WHERE deleted_at IS NULL',
  );
  late final AttentionClaimIndex attentionClaimIndex = AttentionClaimIndex(
    this,
  );
  late final Index idxAttentionClaimsActiveWindow = Index(
    'idx_attention_claims_active_window',
    'CREATE INDEX idx_attention_claims_active_window ON attention_claim_index (status, visibility_start, visibility_end, next_review_at, deadline, request_id) WHERE deleted_at IS NULL',
  );
  late final Index idxAttentionClaimsActiveDeadline = Index(
    'idx_attention_claims_active_deadline',
    'CREATE INDEX idx_attention_claims_active_deadline ON attention_claim_index (status, deadline, request_id) WHERE deleted_at IS NULL AND deadline IS NOT NULL',
  );
  late final Index idxAttentionClaimsActiveTarget = Index(
    'idx_attention_claims_active_target',
    'CREATE INDEX idx_attention_claims_active_target ON attention_claim_index (target_kind, target_id, status, updated_at DESC, request_id) WHERE deleted_at IS NULL AND target_kind IS NOT NULL AND target_id IS NOT NULL',
  );
  late final StandingAgreementIndex standingAgreementIndex =
      StandingAgreementIndex(this);
  late final Index idxStandingAgreementsActiveWindow = Index(
    'idx_standing_agreements_active_window',
    'CREATE INDEX idx_standing_agreements_active_window ON standing_agreement_index (status, active_from, active_until, priority DESC, updated_at DESC, agreement_id) WHERE deleted_at IS NULL',
  );
  late final Index idxStandingAgreementsActiveScopeWindow = Index(
    'idx_standing_agreements_active_scope_window',
    'CREATE INDEX idx_standing_agreements_active_scope_window ON standing_agreement_index (status, scope, active_from, active_until, priority DESC, updated_at DESC, agreement_id) WHERE deleted_at IS NULL',
  );
  late final WakeRunLog wakeRunLog = WakeRunLog(this);
  late final Index idxWakeRunLogAgent = Index(
    'idx_wake_run_log_agent',
    'CREATE INDEX idx_wake_run_log_agent ON wake_run_log (agent_id, created_at DESC)',
  );
  late final Index idxWakeRunLogTemplate = Index(
    'idx_wake_run_log_template',
    'CREATE INDEX idx_wake_run_log_template ON wake_run_log (template_id, created_at DESC)',
  );
  late final Index idxWakeRunLogStatus = Index(
    'idx_wake_run_log_status',
    'CREATE INDEX idx_wake_run_log_status ON wake_run_log (status)',
  );
  late final Index idxWakeRunLogAgentThread = Index(
    'idx_wake_run_log_agent_thread',
    'CREATE INDEX idx_wake_run_log_agent_thread ON wake_run_log (agent_id, thread_id, created_at DESC)',
  );
  late final Index idxWakeRunLogCreatedAt = Index(
    'idx_wake_run_log_created_at',
    'CREATE INDEX idx_wake_run_log_created_at ON wake_run_log (created_at DESC)',
  );
  late final SagaLog sagaLog = SagaLog(this);
  late final Index idxSagaLogAgent = Index(
    'idx_saga_log_agent',
    'CREATE INDEX idx_saga_log_agent ON saga_log (agent_id)',
  );
  late final Index idxSagaLogStatus = Index(
    'idx_saga_log_status',
    'CREATE INDEX idx_saga_log_status ON saga_log (status, updated_at)',
  );
  late final Index idxSagaLogStatusCreatedAt = Index(
    'idx_saga_log_status_created_at',
    'CREATE INDEX idx_saga_log_status_created_at ON saga_log (status, created_at ASC)',
  );
  Selectable<AgentEntity> getAgentEntitiesByAgentId(String agentId, int limit) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE agent_id = ?1 AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?2',
      variables: [Variable<String>(agentId), Variable<int>(limit)],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getAgentEntitiesByType(
    String agentId,
    String type,
    int limit,
  ) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE agent_id = ?1 AND type = ?2 AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?3',
      variables: [
        Variable<String>(agentId),
        Variable<String>(type),
        Variable<int>(limit),
      ],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getAgentEntitiesByTypeAndSubtype(
    String agentId,
    String type,
    String? subtype,
    int limit,
  ) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE agent_id = ?1 AND type = ?2 AND subtype = ?3 AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?4',
      variables: [
        Variable<String>(agentId),
        Variable<String>(type),
        Variable<String>(subtype),
        Variable<int>(limit),
      ],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getAgentEntityById(String id) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE id = ?1 AND deleted_at IS NULL',
      variables: [Variable<String>(id)],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<String?> getAgentEntityVectorClockById(String id) {
    return customSelect(
      'SELECT json_extract(serialized, \'\$.vectorClock\') AS vector_clock FROM agent_entities WHERE id = ?1 AND deleted_at IS NULL',
      variables: [Variable<String>(id)],
      readsFrom: {agentEntities},
    ).map((QueryRow row) => row.readNullable<String>('vector_clock'));
  }

  Selectable<AgentEntity> getAgentMessagesByThread(
    String agentId,
    String? threadId,
    int limit,
  ) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE agent_id = ?1 AND type = \'agentMessage\' AND thread_id = ?2 AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?3',
      variables: [
        Variable<String>(agentId),
        Variable<String>(threadId),
        Variable<int>(limit),
      ],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentLink> getAgentLinkById(String id) {
    return customSelect(
      'SELECT * FROM agent_links WHERE id = ?1 AND deleted_at IS NULL',
      variables: [Variable<String>(id)],
      readsFrom: {agentLinks},
    ).asyncMap(agentLinks.mapFromRow);
  }

  Selectable<String?> getAgentLinkVectorClockById(String id) {
    return customSelect(
      'SELECT json_extract(serialized, \'\$.vectorClock\') AS vector_clock FROM agent_links WHERE id = ?1 AND deleted_at IS NULL',
      variables: [Variable<String>(id)],
      readsFrom: {agentLinks},
    ).map((QueryRow row) => row.readNullable<String>('vector_clock'));
  }

  Selectable<AgentLink> getAgentLinksByFromId(String fromId) {
    return customSelect(
      'SELECT * FROM agent_links WHERE from_id = ?1 AND deleted_at IS NULL',
      variables: [Variable<String>(fromId)],
      readsFrom: {agentLinks},
    ).asyncMap(agentLinks.mapFromRow);
  }

  Selectable<AgentLink> getAgentLinksByFromIdAndType(
    String fromId,
    String type,
  ) {
    return customSelect(
      'SELECT * FROM agent_links WHERE from_id = ?1 AND type = ?2 AND deleted_at IS NULL',
      variables: [Variable<String>(fromId), Variable<String>(type)],
      readsFrom: {agentLinks},
    ).asyncMap(agentLinks.mapFromRow);
  }

  Selectable<AgentLink> getAgentLinksByToId(String toId) {
    return customSelect(
      'SELECT * FROM agent_links WHERE to_id = ?1 AND deleted_at IS NULL',
      variables: [Variable<String>(toId)],
      readsFrom: {agentLinks},
    ).asyncMap(agentLinks.mapFromRow);
  }

  Selectable<AgentLink> getAgentLinksByToIdAndType(String toId, String type) {
    return customSelect(
      'SELECT * FROM agent_links WHERE to_id = ?1 AND type = ?2 AND deleted_at IS NULL',
      variables: [Variable<String>(toId), Variable<String>(type)],
      readsFrom: {agentLinks},
    ).asyncMap(agentLinks.mapFromRow);
  }

  Selectable<WakeRunLogData> getWakeRunsByAgentId(String agentId, int limit) {
    return customSelect(
      'SELECT * FROM wake_run_log WHERE agent_id = ?1 ORDER BY created_at DESC LIMIT ?2',
      variables: [Variable<String>(agentId), Variable<int>(limit)],
      readsFrom: {wakeRunLog},
    ).asyncMap(wakeRunLog.mapFromRow);
  }

  Selectable<WakeRunLogData> getWakeRunByKey(String runKey) {
    return customSelect(
      'SELECT * FROM wake_run_log WHERE run_key = ?1',
      variables: [Variable<String>(runKey)],
      readsFrom: {wakeRunLog},
    ).asyncMap(wakeRunLog.mapFromRow);
  }

  Selectable<WakeRunLogData> getWakeRunByThreadId(
    String agentId,
    String threadId,
  ) {
    return customSelect(
      'SELECT * FROM wake_run_log WHERE agent_id = ?1 AND thread_id = ?2 ORDER BY created_at DESC LIMIT 1',
      variables: [Variable<String>(agentId), Variable<String>(threadId)],
      readsFrom: {wakeRunLog},
    ).asyncMap(wakeRunLog.mapFromRow);
  }

  Selectable<AgentEntity> getAllAgentIdentities() {
    return customSelect(
      'SELECT * FROM agent_entities WHERE type = \'agent\' AND deleted_at IS NULL ORDER BY created_at DESC',
      variables: [],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<SagaLogData> getPendingSagaOps() {
    return customSelect(
      'SELECT * FROM saga_log WHERE status = \'pending\' ORDER BY created_at ASC',
      variables: [],
      readsFrom: {sagaLog},
    ).asyncMap(sagaLog.mapFromRow);
  }

  Future<int> deleteAgentEntities(String agentId) {
    return customUpdate(
      'DELETE FROM agent_entities WHERE agent_id = ?1',
      variables: [Variable<String>(agentId)],
      updates: {agentEntities},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> deleteAgentLinks(String agentId) {
    return customUpdate(
      'DELETE FROM agent_links WHERE from_id = ?1 OR to_id = ?1 OR from_id IN (SELECT id FROM agent_entities WHERE agent_id = ?1) OR to_id IN (SELECT id FROM agent_entities WHERE agent_id = ?1)',
      variables: [Variable<String>(agentId)],
      updates: {agentLinks},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> deleteAgentWakeRuns(String agentId) {
    return customUpdate(
      'DELETE FROM wake_run_log WHERE agent_id = ?1',
      variables: [Variable<String>(agentId)],
      updates: {wakeRunLog},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> deleteAgentSagaOps(String agentId) {
    return customUpdate(
      'DELETE FROM saga_log WHERE agent_id = ?1',
      variables: [Variable<String>(agentId)],
      updates: {sagaLog},
      updateKind: UpdateKind.delete,
    );
  }

  Selectable<AgentEntity> getAllAgentTemplates() {
    return customSelect(
      'SELECT * FROM agent_entities WHERE type = \'agentTemplate\' AND deleted_at IS NULL ORDER BY created_at DESC',
      variables: [],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getAgentEntitiesByTypeGlobal(String type) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE type = ?1 AND deleted_at IS NULL ORDER BY updated_at DESC',
      variables: [Variable<String>(type)],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getAllAgentEntities() {
    return customSelect(
      'SELECT * FROM agent_entities WHERE deleted_at IS NULL ORDER BY created_at ASC',
      variables: [],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getAgentEntitiesInInterval(
    DateTime start,
    DateTime end,
    int limit,
    int offset,
  ) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE updated_at >= ?1 AND updated_at < ?2 ORDER BY updated_at ASC, id ASC LIMIT ?3 OFFSET ?4',
      variables: [
        Variable<DateTime>(start),
        Variable<DateTime>(end),
        Variable<int>(limit),
        Variable<int>(offset),
      ],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<int> countAgentEntitiesInInterval(DateTime start, DateTime end) {
    return customSelect(
      'SELECT COUNT(*) AS cnt FROM agent_entities WHERE updated_at >= ?1 AND updated_at < ?2',
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
      readsFrom: {agentEntities},
    ).map((QueryRow row) => row.read<int>('cnt'));
  }

  Selectable<AgentLink> getAllAgentLinks() {
    return customSelect(
      'SELECT * FROM agent_links WHERE deleted_at IS NULL ORDER BY created_at ASC',
      variables: [],
      readsFrom: {agentLinks},
    ).asyncMap(agentLinks.mapFromRow);
  }

  Selectable<AgentLink> getAgentLinksInInterval(
    DateTime start,
    DateTime end,
    int limit,
    int offset,
  ) {
    return customSelect(
      'SELECT * FROM agent_links WHERE updated_at >= ?1 AND updated_at < ?2 ORDER BY updated_at ASC, id ASC LIMIT ?3 OFFSET ?4',
      variables: [
        Variable<DateTime>(start),
        Variable<DateTime>(end),
        Variable<int>(limit),
        Variable<int>(offset),
      ],
      readsFrom: {agentLinks},
    ).asyncMap(agentLinks.mapFromRow);
  }

  Selectable<int> countAgentLinksInInterval(DateTime start, DateTime end) {
    return customSelect(
      'SELECT COUNT(*) AS cnt FROM agent_links WHERE updated_at >= ?1 AND updated_at < ?2',
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
      readsFrom: {agentLinks},
    ).map((QueryRow row) => row.read<int>('cnt'));
  }

  Selectable<WakeRunLogData> getWakeRunsByTemplateId(
    String? templateId,
    int limit,
  ) {
    return customSelect(
      'SELECT * FROM wake_run_log WHERE template_id = ?1 ORDER BY created_at DESC LIMIT ?2',
      variables: [Variable<String>(templateId), Variable<int>(limit)],
      readsFrom: {wakeRunLog},
    ).asyncMap(wakeRunLog.mapFromRow);
  }

  Selectable<int> countWakeRunsByTemplateId(String? templateId) {
    return customSelect(
      'SELECT COUNT(*) AS cnt FROM wake_run_log WHERE template_id = ?1',
      variables: [Variable<String>(templateId)],
      readsFrom: {wakeRunLog},
    ).map((QueryRow row) => row.read<int>('cnt'));
  }

  Selectable<AggregateWakeRunMetricsByTemplateIdResult>
  aggregateWakeRunMetricsByTemplateId(String? templateId) {
    return customSelect(
      'SELECT COUNT(CASE WHEN status = \'completed\' THEN 1 END) AS success_count, COUNT(CASE WHEN status = \'failed\' THEN 1 END) AS failure_count, CAST(SUM(CASE WHEN started_at IS NOT NULL AND completed_at IS NOT NULL AND completed_at - started_at > 0 THEN(completed_at - started_at)* 1000 ELSE 0 END) AS INT) AS duration_sum_ms, COUNT(CASE WHEN started_at IS NOT NULL AND completed_at IS NOT NULL AND completed_at - started_at > 0 THEN 1 END) AS duration_count, MIN(created_at) AS first_wake_at, MAX(created_at) AS last_wake_at FROM wake_run_log WHERE template_id = ?1',
      variables: [Variable<String>(templateId)],
      readsFrom: {wakeRunLog},
    ).map(
      (QueryRow row) => AggregateWakeRunMetricsByTemplateIdResult(
        successCount: row.read<int>('success_count'),
        failureCount: row.read<int>('failure_count'),
        durationSumMs: row.readNullable<int>('duration_sum_ms'),
        durationCount: row.read<int>('duration_count'),
        firstWakeAt: row.readNullable<DateTime>('first_wake_at'),
        lastWakeAt: row.readNullable<DateTime>('last_wake_at'),
      ),
    );
  }

  Selectable<WakeRunLogData> getWakeRunsByTemplateInWindow(
    String? templateId,
    DateTime since,
    DateTime until,
  ) {
    return customSelect(
      'SELECT * FROM wake_run_log WHERE template_id = ?1 AND created_at >= ?2 AND created_at <= ?3 ORDER BY created_at DESC',
      variables: [
        Variable<String>(templateId),
        Variable<DateTime>(since),
        Variable<DateTime>(until),
      ],
      readsFrom: {wakeRunLog},
    ).asyncMap(wakeRunLog.mapFromRow);
  }

  Selectable<WakeRunLogData> getWakeRunsInWindow(
    DateTime since,
    DateTime until,
  ) {
    return customSelect(
      'SELECT * FROM wake_run_log WHERE created_at >= ?1 AND created_at <= ?2 ORDER BY created_at DESC',
      variables: [Variable<DateTime>(since), Variable<DateTime>(until)],
      readsFrom: {wakeRunLog},
    ).asyncMap(wakeRunLog.mapFromRow);
  }

  Selectable<AgentEntity> getRecentReportsByTemplate(
    String templateId,
    int limit,
  ) {
    return customSelect(
      'SELECT ae.* FROM agent_entities AS ae INNER JOIN agent_links AS al ON al.to_id = ae.agent_id AND al.type = \'template_assignment\' WHERE al.from_id = ?1 AND ae.type = \'agentReport\' AND ae.subtype = \'current\' AND ae.deleted_at IS NULL AND al.deleted_at IS NULL ORDER BY ae.created_at DESC LIMIT ?2',
      variables: [Variable<String>(templateId), Variable<int>(limit)],
      readsFrom: {agentEntities, agentLinks},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getRecentObservationsByTemplate(
    String templateId,
    int limit,
  ) {
    return customSelect(
      'SELECT ae.* FROM agent_entities AS ae INNER JOIN agent_links AS al ON al.to_id = ae.agent_id AND al.type = \'template_assignment\' WHERE al.from_id = ?1 AND ae.type = \'agentMessage\' AND ae.subtype = \'observation\' AND ae.deleted_at IS NULL AND al.deleted_at IS NULL ORDER BY ae.created_at DESC LIMIT ?2',
      variables: [Variable<String>(templateId), Variable<int>(limit)],
      readsFrom: {agentEntities, agentLinks},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getEvolutionSessionsByTemplate(
    String templateId,
    int limit,
  ) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE agent_id = ?1 AND type = \'evolutionSession\' AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?2',
      variables: [Variable<String>(templateId), Variable<int>(limit)],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<GetAllEvolutionSessionsResult> getAllEvolutionSessions() {
    return customSelect(
      'SELECT"es"."id" AS "nested_0.id", "es"."agent_id" AS "nested_0.agent_id", "es"."type" AS "nested_0.type", "es"."subtype" AS "nested_0.subtype", "es"."thread_id" AS "nested_0.thread_id", "es"."created_at" AS "nested_0.created_at", "es"."updated_at" AS "nested_0.updated_at", "es"."deleted_at" AS "nested_0.deleted_at", "es"."serialized" AS "nested_0.serialized", "es"."schema_version" AS "nested_0.schema_version" FROM agent_entities AS es INNER JOIN agent_entities AS tpl ON tpl.id = es.agent_id AND tpl.type = \'agentTemplate\' AND tpl.deleted_at IS NULL WHERE es.type = \'evolutionSession\' AND es.deleted_at IS NULL ORDER BY es.updated_at DESC',
      variables: [],
      readsFrom: {agentEntities},
    ).asyncMap(
      (QueryRow row) async => GetAllEvolutionSessionsResult(
        es: await agentEntities.mapFromRow(row, tablePrefix: 'nested_0'),
      ),
    );
  }

  Selectable<AgentEntity> getEvolutionNotesByTemplate(
    String templateId,
    int limit,
  ) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE agent_id = ?1 AND type = \'evolutionNote\' AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?2',
      variables: [Variable<String>(templateId), Variable<int>(limit)],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<int> countEntitiesChangedSinceForTemplate(
    String templateId,
    DateTime since,
  ) {
    return customSelect(
      'SELECT COUNT(*) AS cnt FROM agent_entities AS ae INNER JOIN agent_links AS al ON al.to_id = ae.agent_id AND al.type = \'template_assignment\' WHERE al.from_id = ?1 AND ae.updated_at > ?2 AND ae.deleted_at IS NULL AND al.deleted_at IS NULL',
      variables: [Variable<String>(templateId), Variable<DateTime>(since)],
      readsFrom: {agentEntities, agentLinks},
    ).map((QueryRow row) => row.read<int>('cnt'));
  }

  Selectable<AgentEntity> getChangeSetsForAgent(String agentId, int limit) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE agent_id = ?1 AND type = \'changeSet\' AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?2',
      variables: [Variable<String>(agentId), Variable<int>(limit)],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getPendingChangeSetsForAgent(
    String agentId,
    int limit,
  ) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE agent_id = ?1 AND type = \'changeSet\' AND subtype IN (\'pending\', \'partiallyResolved\') AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?2',
      variables: [Variable<String>(agentId), Variable<int>(limit)],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getRecentDecisionsForAgent(
    String agentId,
    int limit,
  ) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE agent_id = ?1 AND type = \'changeDecision\' AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?2',
      variables: [Variable<String>(agentId), Variable<int>(limit)],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getRecentDecisionsByTemplate(
    String templateId,
    DateTime since,
    int limit,
  ) {
    return customSelect(
      'SELECT ae.* FROM agent_entities AS ae INNER JOIN agent_links AS al ON al.to_id = ae.agent_id AND al.type = \'template_assignment\' WHERE al.from_id = ?1 AND ae.type = \'changeDecision\' AND ae.created_at >= ?2 AND ae.deleted_at IS NULL AND al.deleted_at IS NULL ORDER BY ae.created_at DESC LIMIT ?3',
      variables: [
        Variable<String>(templateId),
        Variable<DateTime>(since),
        Variable<int>(limit),
      ],
      readsFrom: {agentEntities, agentLinks},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getTokenUsageByAgentId(String agentId, int limit) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE agent_id = ?1 AND type = \'wakeTokenUsage\' AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?2',
      variables: [Variable<String>(agentId), Variable<int>(limit)],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getTokenUsageByTemplateId(
    String templateId,
    int limit,
  ) {
    return customSelect(
      'SELECT ae.* FROM agent_entities AS ae INNER JOIN agent_links AS al ON al.to_id = ae.agent_id AND al.type = \'template_assignment\' WHERE al.from_id = ?1 AND ae.type = \'wakeTokenUsage\' AND ae.deleted_at IS NULL AND al.deleted_at IS NULL ORDER BY ae.created_at DESC LIMIT ?2',
      variables: [Variable<String>(templateId), Variable<int>(limit)],
      readsFrom: {agentEntities, agentLinks},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getTokenUsageByTemplateSince(
    String templateId,
    DateTime since,
  ) {
    return customSelect(
      'SELECT ae.* FROM agent_entities AS ae INNER JOIN agent_links AS al ON al.to_id = ae.agent_id AND al.type = \'template_assignment\' WHERE al.from_id = ?1 AND ae.type = \'wakeTokenUsage\' AND ae.created_at >= ?2 AND ae.deleted_at IS NULL AND al.deleted_at IS NULL ORDER BY ae.created_at DESC',
      variables: [Variable<String>(templateId), Variable<DateTime>(since)],
      readsFrom: {agentEntities, agentLinks},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<SumTokenUsageByTemplateResult> sumTokenUsageByTemplate(
    String templateId,
  ) {
    return customSelect(
      'SELECT CAST(COALESCE(SUM(json_extract(ae.serialized, \'\$.inputTokens\')), 0) AS INT) AS total_input, CAST(COALESCE(SUM(json_extract(ae.serialized, \'\$.outputTokens\')), 0) AS INT) AS total_output, CAST(COALESCE(SUM(json_extract(ae.serialized, \'\$.thoughtsTokens\')), 0) AS INT) AS total_thoughts FROM agent_entities AS ae INNER JOIN agent_links AS al ON al.to_id = ae.agent_id AND al.type = \'template_assignment\' WHERE al.from_id = ?1 AND ae.type = \'wakeTokenUsage\' AND ae.deleted_at IS NULL AND al.deleted_at IS NULL',
      variables: [Variable<String>(templateId)],
      readsFrom: {agentEntities, agentLinks},
    ).map(
      (QueryRow row) => SumTokenUsageByTemplateResult(
        totalInput: row.read<int>('total_input'),
        totalOutput: row.read<int>('total_output'),
        totalThoughts: row.read<int>('total_thoughts'),
      ),
    );
  }

  Selectable<SumTokenUsageByTemplateSinceResult> sumTokenUsageByTemplateSince(
    String templateId,
    DateTime since,
  ) {
    return customSelect(
      'SELECT CAST(COALESCE(SUM(json_extract(ae.serialized, \'\$.inputTokens\')), 0) AS INT) AS total_input, CAST(COALESCE(SUM(json_extract(ae.serialized, \'\$.outputTokens\')), 0) AS INT) AS total_output, CAST(COALESCE(SUM(json_extract(ae.serialized, \'\$.thoughtsTokens\')), 0) AS INT) AS total_thoughts FROM agent_entities AS ae INNER JOIN agent_links AS al ON al.to_id = ae.agent_id AND al.type = \'template_assignment\' WHERE al.from_id = ?1 AND ae.type = \'wakeTokenUsage\' AND ae.created_at >= ?2 AND ae.deleted_at IS NULL AND al.deleted_at IS NULL',
      variables: [Variable<String>(templateId), Variable<DateTime>(since)],
      readsFrom: {agentEntities, agentLinks},
    ).map(
      (QueryRow row) => SumTokenUsageByTemplateSinceResult(
        totalInput: row.read<int>('total_input'),
        totalOutput: row.read<int>('total_output'),
        totalThoughts: row.read<int>('total_thoughts'),
      ),
    );
  }

  Selectable<AgentEntity> getGlobalTokenUsageSince(DateTime since) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE type = \'wakeTokenUsage\' AND created_at >= ?1 AND deleted_at IS NULL ORDER BY created_at DESC',
      variables: [Variable<DateTime>(since)],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getDueScheduledAgentStates(String nowIso) {
    return customSelect(
      'SELECT * FROM agent_entities WHERE type = \'agentState\' AND deleted_at IS NULL AND json_extract(serialized, \'\$.scheduledWakeAt\') IS NOT NULL AND json_extract(serialized, \'\$.scheduledWakeAt\') <= ?1',
      variables: [Variable<String>(nowIso)],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<AgentEntity> getAgentEntitiesWithNullVectorClock() {
    return customSelect(
      'SELECT * FROM agent_entities WHERE json_extract(serialized, \'\$.vectorClock\') IS NULL ORDER BY created_at ASC',
      variables: [],
      readsFrom: {agentEntities},
    ).asyncMap(agentEntities.mapFromRow);
  }

  Selectable<int> countAgentEntitiesWithNullVectorClock() {
    return customSelect(
      'SELECT COUNT(*) AS cnt FROM agent_entities WHERE json_extract(serialized, \'\$.vectorClock\') IS NULL',
      variables: [],
      readsFrom: {agentEntities},
    ).map((QueryRow row) => row.read<int>('cnt'));
  }

  Selectable<AgentLink> getAgentLinksWithNullVectorClock() {
    return customSelect(
      'SELECT * FROM agent_links WHERE json_extract(serialized, \'\$.vectorClock\') IS NULL ORDER BY created_at ASC',
      variables: [],
      readsFrom: {agentLinks},
    ).asyncMap(agentLinks.mapFromRow);
  }

  Selectable<int> countAgentLinksWithNullVectorClock() {
    return customSelect(
      'SELECT COUNT(*) AS cnt FROM agent_links WHERE json_extract(serialized, \'\$.vectorClock\') IS NULL',
      variables: [],
      readsFrom: {agentLinks},
    ).map((QueryRow row) => row.read<int>('cnt'));
  }

  Selectable<String> getAgentTaskLinkToIds() {
    return customSelect(
      'SELECT DISTINCT to_id FROM agent_links WHERE type = \'agent_task\' AND deleted_at IS NULL',
      variables: [],
      readsFrom: {agentLinks},
    ).map((QueryRow row) => row.read<String>('to_id'));
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    agentEntities,
    idxAgentEntitiesAgentId,
    idxAgentEntitiesType,
    idxAgentEntitiesAgentTypeSub,
    idxAgentEntitiesThread,
    idxAgentEntitiesActiveAgentTypeCreatedId,
    idxAgentEntitiesActiveAgentTypeSubCreatedId,
    idxAgentEntitiesActiveTypeCreated,
    idxAgentEntitiesActiveTypeSubCreatedId,
    idxAgentEntitiesTokenUsageSince,
    idxAgentEntitiesDueWake,
    agentLinks,
    idxAgentLinksFrom,
    idxAgentLinksTo,
    idxAgentLinksType,
    idxAgentLinksUniqueFromToType,
    idxUniqueImproverPerTemplate,
    idxUniqueSoulPerTemplate,
    idxAgentLinksActiveFromTypeTo,
    idxAgentLinksActiveToType,
    attentionClaimIndex,
    idxAttentionClaimsActiveWindow,
    idxAttentionClaimsActiveDeadline,
    idxAttentionClaimsActiveTarget,
    standingAgreementIndex,
    idxStandingAgreementsActiveWindow,
    idxStandingAgreementsActiveScopeWindow,
    wakeRunLog,
    idxWakeRunLogAgent,
    idxWakeRunLogTemplate,
    idxWakeRunLogStatus,
    idxWakeRunLogAgentThread,
    idxWakeRunLogCreatedAt,
    sagaLog,
    idxSagaLogAgent,
    idxSagaLogStatus,
    idxSagaLogStatusCreatedAt,
  ];
}

typedef $AgentEntitiesCreateCompanionBuilder =
    AgentEntitiesCompanion Function({
      required String id,
      required String agentId,
      required String type,
      Value<String?> subtype,
      Value<String?> threadId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      required String serialized,
      Value<int> schemaVersion,
      Value<int> rowid,
    });
typedef $AgentEntitiesUpdateCompanionBuilder =
    AgentEntitiesCompanion Function({
      Value<String> id,
      Value<String> agentId,
      Value<String> type,
      Value<String?> subtype,
      Value<String?> threadId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> serialized,
      Value<int> schemaVersion,
      Value<int> rowid,
    });

class $AgentEntitiesFilterComposer
    extends Composer<_$AgentDatabase, AgentEntities> {
  $AgentEntitiesFilterComposer({
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

  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtype => $composableBuilder(
    column: $table.subtype,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get threadId => $composableBuilder(
    column: $table.threadId,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serialized => $composableBuilder(
    column: $table.serialized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $AgentEntitiesOrderingComposer
    extends Composer<_$AgentDatabase, AgentEntities> {
  $AgentEntitiesOrderingComposer({
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

  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtype => $composableBuilder(
    column: $table.subtype,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get threadId => $composableBuilder(
    column: $table.threadId,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serialized => $composableBuilder(
    column: $table.serialized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AgentEntitiesAnnotationComposer
    extends Composer<_$AgentDatabase, AgentEntities> {
  $AgentEntitiesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get subtype =>
      $composableBuilder(column: $table.subtype, builder: (column) => column);

  GeneratedColumn<String> get threadId =>
      $composableBuilder(column: $table.threadId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get serialized => $composableBuilder(
    column: $table.serialized,
    builder: (column) => column,
  );

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );
}

class $AgentEntitiesTableManager
    extends
        RootTableManager<
          _$AgentDatabase,
          AgentEntities,
          AgentEntity,
          $AgentEntitiesFilterComposer,
          $AgentEntitiesOrderingComposer,
          $AgentEntitiesAnnotationComposer,
          $AgentEntitiesCreateCompanionBuilder,
          $AgentEntitiesUpdateCompanionBuilder,
          (
            AgentEntity,
            BaseReferences<_$AgentDatabase, AgentEntities, AgentEntity>,
          ),
          AgentEntity,
          PrefetchHooks Function()
        > {
  $AgentEntitiesTableManager(_$AgentDatabase db, AgentEntities table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AgentEntitiesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AgentEntitiesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AgentEntitiesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> agentId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> subtype = const Value.absent(),
                Value<String?> threadId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> serialized = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentEntitiesCompanion(
                id: id,
                agentId: agentId,
                type: type,
                subtype: subtype,
                threadId: threadId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serialized: serialized,
                schemaVersion: schemaVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String agentId,
                required String type,
                Value<String?> subtype = const Value.absent(),
                Value<String?> threadId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String serialized,
                Value<int> schemaVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentEntitiesCompanion.insert(
                id: id,
                agentId: agentId,
                type: type,
                subtype: subtype,
                threadId: threadId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serialized: serialized,
                schemaVersion: schemaVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AgentEntitiesProcessedTableManager =
    ProcessedTableManager<
      _$AgentDatabase,
      AgentEntities,
      AgentEntity,
      $AgentEntitiesFilterComposer,
      $AgentEntitiesOrderingComposer,
      $AgentEntitiesAnnotationComposer,
      $AgentEntitiesCreateCompanionBuilder,
      $AgentEntitiesUpdateCompanionBuilder,
      (
        AgentEntity,
        BaseReferences<_$AgentDatabase, AgentEntities, AgentEntity>,
      ),
      AgentEntity,
      PrefetchHooks Function()
    >;
typedef $AgentLinksCreateCompanionBuilder =
    AgentLinksCompanion Function({
      required String id,
      required String fromId,
      required String toId,
      required String type,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      required String serialized,
      Value<int> schemaVersion,
      Value<int> rowid,
    });
typedef $AgentLinksUpdateCompanionBuilder =
    AgentLinksCompanion Function({
      Value<String> id,
      Value<String> fromId,
      Value<String> toId,
      Value<String> type,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> serialized,
      Value<int> schemaVersion,
      Value<int> rowid,
    });

class $AgentLinksFilterComposer extends Composer<_$AgentDatabase, AgentLinks> {
  $AgentLinksFilterComposer({
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

  ColumnFilters<String> get fromId => $composableBuilder(
    column: $table.fromId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toId => $composableBuilder(
    column: $table.toId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serialized => $composableBuilder(
    column: $table.serialized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $AgentLinksOrderingComposer
    extends Composer<_$AgentDatabase, AgentLinks> {
  $AgentLinksOrderingComposer({
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

  ColumnOrderings<String> get fromId => $composableBuilder(
    column: $table.fromId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toId => $composableBuilder(
    column: $table.toId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serialized => $composableBuilder(
    column: $table.serialized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AgentLinksAnnotationComposer
    extends Composer<_$AgentDatabase, AgentLinks> {
  $AgentLinksAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fromId =>
      $composableBuilder(column: $table.fromId, builder: (column) => column);

  GeneratedColumn<String> get toId =>
      $composableBuilder(column: $table.toId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get serialized => $composableBuilder(
    column: $table.serialized,
    builder: (column) => column,
  );

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );
}

class $AgentLinksTableManager
    extends
        RootTableManager<
          _$AgentDatabase,
          AgentLinks,
          AgentLink,
          $AgentLinksFilterComposer,
          $AgentLinksOrderingComposer,
          $AgentLinksAnnotationComposer,
          $AgentLinksCreateCompanionBuilder,
          $AgentLinksUpdateCompanionBuilder,
          (AgentLink, BaseReferences<_$AgentDatabase, AgentLinks, AgentLink>),
          AgentLink,
          PrefetchHooks Function()
        > {
  $AgentLinksTableManager(_$AgentDatabase db, AgentLinks table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AgentLinksFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AgentLinksOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AgentLinksAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fromId = const Value.absent(),
                Value<String> toId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> serialized = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentLinksCompanion(
                id: id,
                fromId: fromId,
                toId: toId,
                type: type,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serialized: serialized,
                schemaVersion: schemaVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fromId,
                required String toId,
                required String type,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String serialized,
                Value<int> schemaVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentLinksCompanion.insert(
                id: id,
                fromId: fromId,
                toId: toId,
                type: type,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serialized: serialized,
                schemaVersion: schemaVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AgentLinksProcessedTableManager =
    ProcessedTableManager<
      _$AgentDatabase,
      AgentLinks,
      AgentLink,
      $AgentLinksFilterComposer,
      $AgentLinksOrderingComposer,
      $AgentLinksAnnotationComposer,
      $AgentLinksCreateCompanionBuilder,
      $AgentLinksUpdateCompanionBuilder,
      (AgentLink, BaseReferences<_$AgentDatabase, AgentLinks, AgentLink>),
      AgentLink,
      PrefetchHooks Function()
    >;
typedef $AttentionClaimIndexCreateCompanionBuilder =
    AttentionClaimIndexCompanion Function({
      required String requestId,
      required String agentId,
      required String status,
      required String scopeKind,
      required DateTime visibilityStart,
      required DateTime visibilityEnd,
      Value<DateTime?> deadline,
      Value<DateTime?> nextReviewAt,
      Value<String?> targetId,
      Value<String?> targetKind,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $AttentionClaimIndexUpdateCompanionBuilder =
    AttentionClaimIndexCompanion Function({
      Value<String> requestId,
      Value<String> agentId,
      Value<String> status,
      Value<String> scopeKind,
      Value<DateTime> visibilityStart,
      Value<DateTime> visibilityEnd,
      Value<DateTime?> deadline,
      Value<DateTime?> nextReviewAt,
      Value<String?> targetId,
      Value<String?> targetKind,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $AttentionClaimIndexFilterComposer
    extends Composer<_$AgentDatabase, AttentionClaimIndex> {
  $AttentionClaimIndexFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeKind => $composableBuilder(
    column: $table.scopeKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get visibilityStart => $composableBuilder(
    column: $table.visibilityStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get visibilityEnd => $composableBuilder(
    column: $table.visibilityEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $AttentionClaimIndexOrderingComposer
    extends Composer<_$AgentDatabase, AttentionClaimIndex> {
  $AttentionClaimIndexOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeKind => $composableBuilder(
    column: $table.scopeKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get visibilityStart => $composableBuilder(
    column: $table.visibilityStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get visibilityEnd => $composableBuilder(
    column: $table.visibilityEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AttentionClaimIndexAnnotationComposer
    extends Composer<_$AgentDatabase, AttentionClaimIndex> {
  $AttentionClaimIndexAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get scopeKind =>
      $composableBuilder(column: $table.scopeKind, builder: (column) => column);

  GeneratedColumn<DateTime> get visibilityStart => $composableBuilder(
    column: $table.visibilityStart,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get visibilityEnd => $composableBuilder(
    column: $table.visibilityEnd,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deadline =>
      $composableBuilder(column: $table.deadline, builder: (column) => column);

  GeneratedColumn<DateTime> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $AttentionClaimIndexTableManager
    extends
        RootTableManager<
          _$AgentDatabase,
          AttentionClaimIndex,
          AttentionClaimIndexData,
          $AttentionClaimIndexFilterComposer,
          $AttentionClaimIndexOrderingComposer,
          $AttentionClaimIndexAnnotationComposer,
          $AttentionClaimIndexCreateCompanionBuilder,
          $AttentionClaimIndexUpdateCompanionBuilder,
          (
            AttentionClaimIndexData,
            BaseReferences<
              _$AgentDatabase,
              AttentionClaimIndex,
              AttentionClaimIndexData
            >,
          ),
          AttentionClaimIndexData,
          PrefetchHooks Function()
        > {
  $AttentionClaimIndexTableManager(
    _$AgentDatabase db,
    AttentionClaimIndex table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AttentionClaimIndexFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AttentionClaimIndexOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AttentionClaimIndexAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> requestId = const Value.absent(),
                Value<String> agentId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> scopeKind = const Value.absent(),
                Value<DateTime> visibilityStart = const Value.absent(),
                Value<DateTime> visibilityEnd = const Value.absent(),
                Value<DateTime?> deadline = const Value.absent(),
                Value<DateTime?> nextReviewAt = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<String?> targetKind = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttentionClaimIndexCompanion(
                requestId: requestId,
                agentId: agentId,
                status: status,
                scopeKind: scopeKind,
                visibilityStart: visibilityStart,
                visibilityEnd: visibilityEnd,
                deadline: deadline,
                nextReviewAt: nextReviewAt,
                targetId: targetId,
                targetKind: targetKind,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String requestId,
                required String agentId,
                required String status,
                required String scopeKind,
                required DateTime visibilityStart,
                required DateTime visibilityEnd,
                Value<DateTime?> deadline = const Value.absent(),
                Value<DateTime?> nextReviewAt = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<String?> targetKind = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttentionClaimIndexCompanion.insert(
                requestId: requestId,
                agentId: agentId,
                status: status,
                scopeKind: scopeKind,
                visibilityStart: visibilityStart,
                visibilityEnd: visibilityEnd,
                deadline: deadline,
                nextReviewAt: nextReviewAt,
                targetId: targetId,
                targetKind: targetKind,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AttentionClaimIndexProcessedTableManager =
    ProcessedTableManager<
      _$AgentDatabase,
      AttentionClaimIndex,
      AttentionClaimIndexData,
      $AttentionClaimIndexFilterComposer,
      $AttentionClaimIndexOrderingComposer,
      $AttentionClaimIndexAnnotationComposer,
      $AttentionClaimIndexCreateCompanionBuilder,
      $AttentionClaimIndexUpdateCompanionBuilder,
      (
        AttentionClaimIndexData,
        BaseReferences<
          _$AgentDatabase,
          AttentionClaimIndex,
          AttentionClaimIndexData
        >,
      ),
      AttentionClaimIndexData,
      PrefetchHooks Function()
    >;
typedef $StandingAgreementIndexCreateCompanionBuilder =
    StandingAgreementIndexCompanion Function({
      required String agreementId,
      required String agentId,
      required String status,
      required String scope,
      required String cadence,
      required String approvalMode,
      required String enforcement,
      required DateTime activeFrom,
      required DateTime activeUntil,
      required int priority,
      Value<String?> targetId,
      Value<String?> targetKind,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $StandingAgreementIndexUpdateCompanionBuilder =
    StandingAgreementIndexCompanion Function({
      Value<String> agreementId,
      Value<String> agentId,
      Value<String> status,
      Value<String> scope,
      Value<String> cadence,
      Value<String> approvalMode,
      Value<String> enforcement,
      Value<DateTime> activeFrom,
      Value<DateTime> activeUntil,
      Value<int> priority,
      Value<String?> targetId,
      Value<String?> targetKind,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $StandingAgreementIndexFilterComposer
    extends Composer<_$AgentDatabase, StandingAgreementIndex> {
  $StandingAgreementIndexFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agreementId => $composableBuilder(
    column: $table.agreementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cadence => $composableBuilder(
    column: $table.cadence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get approvalMode => $composableBuilder(
    column: $table.approvalMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enforcement => $composableBuilder(
    column: $table.enforcement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get activeFrom => $composableBuilder(
    column: $table.activeFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get activeUntil => $composableBuilder(
    column: $table.activeUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $StandingAgreementIndexOrderingComposer
    extends Composer<_$AgentDatabase, StandingAgreementIndex> {
  $StandingAgreementIndexOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agreementId => $composableBuilder(
    column: $table.agreementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cadence => $composableBuilder(
    column: $table.cadence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get approvalMode => $composableBuilder(
    column: $table.approvalMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enforcement => $composableBuilder(
    column: $table.enforcement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get activeFrom => $composableBuilder(
    column: $table.activeFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get activeUntil => $composableBuilder(
    column: $table.activeUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $StandingAgreementIndexAnnotationComposer
    extends Composer<_$AgentDatabase, StandingAgreementIndex> {
  $StandingAgreementIndexAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agreementId => $composableBuilder(
    column: $table.agreementId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get cadence =>
      $composableBuilder(column: $table.cadence, builder: (column) => column);

  GeneratedColumn<String> get approvalMode => $composableBuilder(
    column: $table.approvalMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get enforcement => $composableBuilder(
    column: $table.enforcement,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get activeFrom => $composableBuilder(
    column: $table.activeFrom,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get activeUntil => $composableBuilder(
    column: $table.activeUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $StandingAgreementIndexTableManager
    extends
        RootTableManager<
          _$AgentDatabase,
          StandingAgreementIndex,
          StandingAgreementIndexData,
          $StandingAgreementIndexFilterComposer,
          $StandingAgreementIndexOrderingComposer,
          $StandingAgreementIndexAnnotationComposer,
          $StandingAgreementIndexCreateCompanionBuilder,
          $StandingAgreementIndexUpdateCompanionBuilder,
          (
            StandingAgreementIndexData,
            BaseReferences<
              _$AgentDatabase,
              StandingAgreementIndex,
              StandingAgreementIndexData
            >,
          ),
          StandingAgreementIndexData,
          PrefetchHooks Function()
        > {
  $StandingAgreementIndexTableManager(
    _$AgentDatabase db,
    StandingAgreementIndex table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $StandingAgreementIndexFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $StandingAgreementIndexOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $StandingAgreementIndexAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> agreementId = const Value.absent(),
                Value<String> agentId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> cadence = const Value.absent(),
                Value<String> approvalMode = const Value.absent(),
                Value<String> enforcement = const Value.absent(),
                Value<DateTime> activeFrom = const Value.absent(),
                Value<DateTime> activeUntil = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<String?> targetKind = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StandingAgreementIndexCompanion(
                agreementId: agreementId,
                agentId: agentId,
                status: status,
                scope: scope,
                cadence: cadence,
                approvalMode: approvalMode,
                enforcement: enforcement,
                activeFrom: activeFrom,
                activeUntil: activeUntil,
                priority: priority,
                targetId: targetId,
                targetKind: targetKind,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agreementId,
                required String agentId,
                required String status,
                required String scope,
                required String cadence,
                required String approvalMode,
                required String enforcement,
                required DateTime activeFrom,
                required DateTime activeUntil,
                required int priority,
                Value<String?> targetId = const Value.absent(),
                Value<String?> targetKind = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StandingAgreementIndexCompanion.insert(
                agreementId: agreementId,
                agentId: agentId,
                status: status,
                scope: scope,
                cadence: cadence,
                approvalMode: approvalMode,
                enforcement: enforcement,
                activeFrom: activeFrom,
                activeUntil: activeUntil,
                priority: priority,
                targetId: targetId,
                targetKind: targetKind,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $StandingAgreementIndexProcessedTableManager =
    ProcessedTableManager<
      _$AgentDatabase,
      StandingAgreementIndex,
      StandingAgreementIndexData,
      $StandingAgreementIndexFilterComposer,
      $StandingAgreementIndexOrderingComposer,
      $StandingAgreementIndexAnnotationComposer,
      $StandingAgreementIndexCreateCompanionBuilder,
      $StandingAgreementIndexUpdateCompanionBuilder,
      (
        StandingAgreementIndexData,
        BaseReferences<
          _$AgentDatabase,
          StandingAgreementIndex,
          StandingAgreementIndexData
        >,
      ),
      StandingAgreementIndexData,
      PrefetchHooks Function()
    >;
typedef $WakeRunLogCreateCompanionBuilder =
    WakeRunLogCompanion Function({
      required String runKey,
      required String agentId,
      required String reason,
      Value<String?> reasonId,
      required String threadId,
      required String status,
      Value<String?> logicalChangeKey,
      required DateTime createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<String?> errorMessage,
      Value<String?> templateId,
      Value<String?> templateVersionId,
      Value<String?> resolvedModelId,
      Value<String?> soulId,
      Value<String?> soulVersionId,
      Value<double?> userRating,
      Value<DateTime?> ratedAt,
      Value<int> rowid,
    });
typedef $WakeRunLogUpdateCompanionBuilder =
    WakeRunLogCompanion Function({
      Value<String> runKey,
      Value<String> agentId,
      Value<String> reason,
      Value<String?> reasonId,
      Value<String> threadId,
      Value<String> status,
      Value<String?> logicalChangeKey,
      Value<DateTime> createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<String?> errorMessage,
      Value<String?> templateId,
      Value<String?> templateVersionId,
      Value<String?> resolvedModelId,
      Value<String?> soulId,
      Value<String?> soulVersionId,
      Value<double?> userRating,
      Value<DateTime?> ratedAt,
      Value<int> rowid,
    });

class $WakeRunLogFilterComposer extends Composer<_$AgentDatabase, WakeRunLog> {
  $WakeRunLogFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get runKey => $composableBuilder(
    column: $table.runKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasonId => $composableBuilder(
    column: $table.reasonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get threadId => $composableBuilder(
    column: $table.threadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logicalChangeKey => $composableBuilder(
    column: $table.logicalChangeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateVersionId => $composableBuilder(
    column: $table.templateVersionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolvedModelId => $composableBuilder(
    column: $table.resolvedModelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get soulId => $composableBuilder(
    column: $table.soulId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get soulVersionId => $composableBuilder(
    column: $table.soulVersionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ratedAt => $composableBuilder(
    column: $table.ratedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $WakeRunLogOrderingComposer
    extends Composer<_$AgentDatabase, WakeRunLog> {
  $WakeRunLogOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get runKey => $composableBuilder(
    column: $table.runKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasonId => $composableBuilder(
    column: $table.reasonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get threadId => $composableBuilder(
    column: $table.threadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logicalChangeKey => $composableBuilder(
    column: $table.logicalChangeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateVersionId => $composableBuilder(
    column: $table.templateVersionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolvedModelId => $composableBuilder(
    column: $table.resolvedModelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get soulId => $composableBuilder(
    column: $table.soulId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get soulVersionId => $composableBuilder(
    column: $table.soulVersionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ratedAt => $composableBuilder(
    column: $table.ratedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $WakeRunLogAnnotationComposer
    extends Composer<_$AgentDatabase, WakeRunLog> {
  $WakeRunLogAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get runKey =>
      $composableBuilder(column: $table.runKey, builder: (column) => column);

  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get reasonId =>
      $composableBuilder(column: $table.reasonId, builder: (column) => column);

  GeneratedColumn<String> get threadId =>
      $composableBuilder(column: $table.threadId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get logicalChangeKey => $composableBuilder(
    column: $table.logicalChangeKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateVersionId => $composableBuilder(
    column: $table.templateVersionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolvedModelId => $composableBuilder(
    column: $table.resolvedModelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get soulId =>
      $composableBuilder(column: $table.soulId, builder: (column) => column);

  GeneratedColumn<String> get soulVersionId => $composableBuilder(
    column: $table.soulVersionId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get ratedAt =>
      $composableBuilder(column: $table.ratedAt, builder: (column) => column);
}

class $WakeRunLogTableManager
    extends
        RootTableManager<
          _$AgentDatabase,
          WakeRunLog,
          WakeRunLogData,
          $WakeRunLogFilterComposer,
          $WakeRunLogOrderingComposer,
          $WakeRunLogAnnotationComposer,
          $WakeRunLogCreateCompanionBuilder,
          $WakeRunLogUpdateCompanionBuilder,
          (
            WakeRunLogData,
            BaseReferences<_$AgentDatabase, WakeRunLog, WakeRunLogData>,
          ),
          WakeRunLogData,
          PrefetchHooks Function()
        > {
  $WakeRunLogTableManager(_$AgentDatabase db, WakeRunLog table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $WakeRunLogFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $WakeRunLogOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $WakeRunLogAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> runKey = const Value.absent(),
                Value<String> agentId = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String?> reasonId = const Value.absent(),
                Value<String> threadId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> logicalChangeKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> templateId = const Value.absent(),
                Value<String?> templateVersionId = const Value.absent(),
                Value<String?> resolvedModelId = const Value.absent(),
                Value<String?> soulId = const Value.absent(),
                Value<String?> soulVersionId = const Value.absent(),
                Value<double?> userRating = const Value.absent(),
                Value<DateTime?> ratedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WakeRunLogCompanion(
                runKey: runKey,
                agentId: agentId,
                reason: reason,
                reasonId: reasonId,
                threadId: threadId,
                status: status,
                logicalChangeKey: logicalChangeKey,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: completedAt,
                errorMessage: errorMessage,
                templateId: templateId,
                templateVersionId: templateVersionId,
                resolvedModelId: resolvedModelId,
                soulId: soulId,
                soulVersionId: soulVersionId,
                userRating: userRating,
                ratedAt: ratedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String runKey,
                required String agentId,
                required String reason,
                Value<String?> reasonId = const Value.absent(),
                required String threadId,
                required String status,
                Value<String?> logicalChangeKey = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> templateId = const Value.absent(),
                Value<String?> templateVersionId = const Value.absent(),
                Value<String?> resolvedModelId = const Value.absent(),
                Value<String?> soulId = const Value.absent(),
                Value<String?> soulVersionId = const Value.absent(),
                Value<double?> userRating = const Value.absent(),
                Value<DateTime?> ratedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WakeRunLogCompanion.insert(
                runKey: runKey,
                agentId: agentId,
                reason: reason,
                reasonId: reasonId,
                threadId: threadId,
                status: status,
                logicalChangeKey: logicalChangeKey,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: completedAt,
                errorMessage: errorMessage,
                templateId: templateId,
                templateVersionId: templateVersionId,
                resolvedModelId: resolvedModelId,
                soulId: soulId,
                soulVersionId: soulVersionId,
                userRating: userRating,
                ratedAt: ratedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $WakeRunLogProcessedTableManager =
    ProcessedTableManager<
      _$AgentDatabase,
      WakeRunLog,
      WakeRunLogData,
      $WakeRunLogFilterComposer,
      $WakeRunLogOrderingComposer,
      $WakeRunLogAnnotationComposer,
      $WakeRunLogCreateCompanionBuilder,
      $WakeRunLogUpdateCompanionBuilder,
      (
        WakeRunLogData,
        BaseReferences<_$AgentDatabase, WakeRunLog, WakeRunLogData>,
      ),
      WakeRunLogData,
      PrefetchHooks Function()
    >;
typedef $SagaLogCreateCompanionBuilder =
    SagaLogCompanion Function({
      required String operationId,
      required String agentId,
      required String runKey,
      required String phase,
      required String status,
      required String toolName,
      Value<String?> lastError,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $SagaLogUpdateCompanionBuilder =
    SagaLogCompanion Function({
      Value<String> operationId,
      Value<String> agentId,
      Value<String> runKey,
      Value<String> phase,
      Value<String> status,
      Value<String> toolName,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $SagaLogFilterComposer extends Composer<_$AgentDatabase, SagaLog> {
  $SagaLogFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runKey => $composableBuilder(
    column: $table.runKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolName => $composableBuilder(
    column: $table.toolName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
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

class $SagaLogOrderingComposer extends Composer<_$AgentDatabase, SagaLog> {
  $SagaLogOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runKey => $composableBuilder(
    column: $table.runKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolName => $composableBuilder(
    column: $table.toolName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
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

class $SagaLogAnnotationComposer extends Composer<_$AgentDatabase, SagaLog> {
  $SagaLogAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get runKey =>
      $composableBuilder(column: $table.runKey, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get toolName =>
      $composableBuilder(column: $table.toolName, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $SagaLogTableManager
    extends
        RootTableManager<
          _$AgentDatabase,
          SagaLog,
          SagaLogData,
          $SagaLogFilterComposer,
          $SagaLogOrderingComposer,
          $SagaLogAnnotationComposer,
          $SagaLogCreateCompanionBuilder,
          $SagaLogUpdateCompanionBuilder,
          (SagaLogData, BaseReferences<_$AgentDatabase, SagaLog, SagaLogData>),
          SagaLogData,
          PrefetchHooks Function()
        > {
  $SagaLogTableManager(_$AgentDatabase db, SagaLog table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SagaLogFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SagaLogOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SagaLogAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> agentId = const Value.absent(),
                Value<String> runKey = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> toolName = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SagaLogCompanion(
                operationId: operationId,
                agentId: agentId,
                runKey: runKey,
                phase: phase,
                status: status,
                toolName: toolName,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String agentId,
                required String runKey,
                required String phase,
                required String status,
                required String toolName,
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SagaLogCompanion.insert(
                operationId: operationId,
                agentId: agentId,
                runKey: runKey,
                phase: phase,
                status: status,
                toolName: toolName,
                lastError: lastError,
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

typedef $SagaLogProcessedTableManager =
    ProcessedTableManager<
      _$AgentDatabase,
      SagaLog,
      SagaLogData,
      $SagaLogFilterComposer,
      $SagaLogOrderingComposer,
      $SagaLogAnnotationComposer,
      $SagaLogCreateCompanionBuilder,
      $SagaLogUpdateCompanionBuilder,
      (SagaLogData, BaseReferences<_$AgentDatabase, SagaLog, SagaLogData>),
      SagaLogData,
      PrefetchHooks Function()
    >;

class $AgentDatabaseManager {
  final _$AgentDatabase _db;
  $AgentDatabaseManager(this._db);
  $AgentEntitiesTableManager get agentEntities =>
      $AgentEntitiesTableManager(_db, _db.agentEntities);
  $AgentLinksTableManager get agentLinks =>
      $AgentLinksTableManager(_db, _db.agentLinks);
  $AttentionClaimIndexTableManager get attentionClaimIndex =>
      $AttentionClaimIndexTableManager(_db, _db.attentionClaimIndex);
  $StandingAgreementIndexTableManager get standingAgreementIndex =>
      $StandingAgreementIndexTableManager(_db, _db.standingAgreementIndex);
  $WakeRunLogTableManager get wakeRunLog =>
      $WakeRunLogTableManager(_db, _db.wakeRunLog);
  $SagaLogTableManager get sagaLog => $SagaLogTableManager(_db, _db.sagaLog);
}

class AggregateWakeRunMetricsByTemplateIdResult {
  final int successCount;
  final int failureCount;
  final int? durationSumMs;
  final int durationCount;
  final DateTime? firstWakeAt;
  final DateTime? lastWakeAt;
  AggregateWakeRunMetricsByTemplateIdResult({
    required this.successCount,
    required this.failureCount,
    this.durationSumMs,
    required this.durationCount,
    this.firstWakeAt,
    this.lastWakeAt,
  });
}

class GetAllEvolutionSessionsResult {
  final AgentEntity es;
  GetAllEvolutionSessionsResult({required this.es});
}

class SumTokenUsageByTemplateResult {
  final int totalInput;
  final int totalOutput;
  final int totalThoughts;
  SumTokenUsageByTemplateResult({
    required this.totalInput,
    required this.totalOutput,
    required this.totalThoughts,
  });
}

class SumTokenUsageByTemplateSinceResult {
  final int totalInput;
  final int totalOutput;
  final int totalThoughts;
  SumTokenUsageByTemplateSinceResult({
    required this.totalInput,
    required this.totalOutput,
    required this.totalThoughts,
  });
}
