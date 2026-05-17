// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_db.dart';

// ignore_for_file: type=lint
class Notifications extends Table
    with TableInfo<Notifications, NotificationDbEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Notifications(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
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
  static const VerificationMeta _scheduledForMeta = const VerificationMeta(
    'scheduledFor',
  );
  late final GeneratedColumn<DateTime> scheduledFor = GeneratedColumn<DateTime>(
    'scheduled_for',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _seenAtMeta = const VerificationMeta('seenAt');
  late final GeneratedColumn<DateTime> seenAt = GeneratedColumn<DateTime>(
    'seen_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _actedOnAtMeta = const VerificationMeta(
    'actedOnAt',
  );
  late final GeneratedColumn<DateTime> actedOnAt = GeneratedColumn<DateTime>(
    'acted_on_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    $customConstraints: '',
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
  static const VerificationMeta _linkedEntityIdMeta = const VerificationMeta(
    'linkedEntityId',
  );
  late final GeneratedColumn<String> linkedEntityId = GeneratedColumn<String>(
    'linked_entity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
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
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _vectorClockMeta = const VerificationMeta(
    'vectorClock',
  );
  late final GeneratedColumn<String> vectorClock = GeneratedColumn<String>(
    'vector_clock',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _originatingHostIdMeta = const VerificationMeta(
    'originatingHostId',
  );
  late final GeneratedColumn<String> originatingHostId =
      GeneratedColumn<String>(
        'originating_host_id',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    scheduledFor,
    seenAt,
    actedOnAt,
    deletedAt,
    linkedEntityId,
    type,
    category,
    vectorClock,
    originatingHostId,
    serialized,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationDbEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('scheduled_for')) {
      context.handle(
        _scheduledForMeta,
        scheduledFor.isAcceptableOrUnknown(
          data['scheduled_for']!,
          _scheduledForMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledForMeta);
    }
    if (data.containsKey('seen_at')) {
      context.handle(
        _seenAtMeta,
        seenAt.isAcceptableOrUnknown(data['seen_at']!, _seenAtMeta),
      );
    }
    if (data.containsKey('acted_on_at')) {
      context.handle(
        _actedOnAtMeta,
        actedOnAt.isAcceptableOrUnknown(data['acted_on_at']!, _actedOnAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('linked_entity_id')) {
      context.handle(
        _linkedEntityIdMeta,
        linkedEntityId.isAcceptableOrUnknown(
          data['linked_entity_id']!,
          _linkedEntityIdMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('vector_clock')) {
      context.handle(
        _vectorClockMeta,
        vectorClock.isAcceptableOrUnknown(
          data['vector_clock']!,
          _vectorClockMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vectorClockMeta);
    }
    if (data.containsKey('originating_host_id')) {
      context.handle(
        _originatingHostIdMeta,
        originatingHostId.isAcceptableOrUnknown(
          data['originating_host_id']!,
          _originatingHostIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originatingHostIdMeta);
    }
    if (data.containsKey('serialized')) {
      context.handle(
        _serializedMeta,
        serialized.isAcceptableOrUnknown(data['serialized']!, _serializedMeta),
      );
    } else if (isInserting) {
      context.missing(_serializedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationDbEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationDbEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      scheduledFor: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_for'],
      )!,
      seenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}seen_at'],
      ),
      actedOnAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}acted_on_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      linkedEntityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_entity_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      vectorClock: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vector_clock'],
      )!,
      originatingHostId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}originating_host_id'],
      )!,
      serialized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serialized'],
      )!,
    );
  }

  @override
  Notifications createAlias(String alias) {
    return Notifications(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class NotificationDbEntity extends DataClass
    implements Insertable<NotificationDbEntity> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime scheduledFor;
  final DateTime? seenAt;
  final DateTime? actedOnAt;
  final DateTime? deletedAt;
  final String? linkedEntityId;
  final String type;
  final String? category;
  final String vectorClock;
  final String originatingHostId;
  final String serialized;
  const NotificationDbEntity({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.scheduledFor,
    this.seenAt,
    this.actedOnAt,
    this.deletedAt,
    this.linkedEntityId,
    required this.type,
    this.category,
    required this.vectorClock,
    required this.originatingHostId,
    required this.serialized,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['scheduled_for'] = Variable<DateTime>(scheduledFor);
    if (!nullToAbsent || seenAt != null) {
      map['seen_at'] = Variable<DateTime>(seenAt);
    }
    if (!nullToAbsent || actedOnAt != null) {
      map['acted_on_at'] = Variable<DateTime>(actedOnAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || linkedEntityId != null) {
      map['linked_entity_id'] = Variable<String>(linkedEntityId);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['vector_clock'] = Variable<String>(vectorClock);
    map['originating_host_id'] = Variable<String>(originatingHostId);
    map['serialized'] = Variable<String>(serialized);
    return map;
  }

  NotificationsCompanion toCompanion(bool nullToAbsent) {
    return NotificationsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      scheduledFor: Value(scheduledFor),
      seenAt: seenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(seenAt),
      actedOnAt: actedOnAt == null && nullToAbsent
          ? const Value.absent()
          : Value(actedOnAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      linkedEntityId: linkedEntityId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedEntityId),
      type: Value(type),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      vectorClock: Value(vectorClock),
      originatingHostId: Value(originatingHostId),
      serialized: Value(serialized),
    );
  }

  factory NotificationDbEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationDbEntity(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      scheduledFor: serializer.fromJson<DateTime>(json['scheduled_for']),
      seenAt: serializer.fromJson<DateTime?>(json['seen_at']),
      actedOnAt: serializer.fromJson<DateTime?>(json['acted_on_at']),
      deletedAt: serializer.fromJson<DateTime?>(json['deleted_at']),
      linkedEntityId: serializer.fromJson<String?>(json['linked_entity_id']),
      type: serializer.fromJson<String>(json['type']),
      category: serializer.fromJson<String?>(json['category']),
      vectorClock: serializer.fromJson<String>(json['vector_clock']),
      originatingHostId: serializer.fromJson<String>(
        json['originating_host_id'],
      ),
      serialized: serializer.fromJson<String>(json['serialized']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'scheduled_for': serializer.toJson<DateTime>(scheduledFor),
      'seen_at': serializer.toJson<DateTime?>(seenAt),
      'acted_on_at': serializer.toJson<DateTime?>(actedOnAt),
      'deleted_at': serializer.toJson<DateTime?>(deletedAt),
      'linked_entity_id': serializer.toJson<String?>(linkedEntityId),
      'type': serializer.toJson<String>(type),
      'category': serializer.toJson<String?>(category),
      'vector_clock': serializer.toJson<String>(vectorClock),
      'originating_host_id': serializer.toJson<String>(originatingHostId),
      'serialized': serializer.toJson<String>(serialized),
    };
  }

  NotificationDbEntity copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? scheduledFor,
    Value<DateTime?> seenAt = const Value.absent(),
    Value<DateTime?> actedOnAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<String?> linkedEntityId = const Value.absent(),
    String? type,
    Value<String?> category = const Value.absent(),
    String? vectorClock,
    String? originatingHostId,
    String? serialized,
  }) => NotificationDbEntity(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    scheduledFor: scheduledFor ?? this.scheduledFor,
    seenAt: seenAt.present ? seenAt.value : this.seenAt,
    actedOnAt: actedOnAt.present ? actedOnAt.value : this.actedOnAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    linkedEntityId: linkedEntityId.present
        ? linkedEntityId.value
        : this.linkedEntityId,
    type: type ?? this.type,
    category: category.present ? category.value : this.category,
    vectorClock: vectorClock ?? this.vectorClock,
    originatingHostId: originatingHostId ?? this.originatingHostId,
    serialized: serialized ?? this.serialized,
  );
  NotificationDbEntity copyWithCompanion(NotificationsCompanion data) {
    return NotificationDbEntity(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      scheduledFor: data.scheduledFor.present
          ? data.scheduledFor.value
          : this.scheduledFor,
      seenAt: data.seenAt.present ? data.seenAt.value : this.seenAt,
      actedOnAt: data.actedOnAt.present ? data.actedOnAt.value : this.actedOnAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      linkedEntityId: data.linkedEntityId.present
          ? data.linkedEntityId.value
          : this.linkedEntityId,
      type: data.type.present ? data.type.value : this.type,
      category: data.category.present ? data.category.value : this.category,
      vectorClock: data.vectorClock.present
          ? data.vectorClock.value
          : this.vectorClock,
      originatingHostId: data.originatingHostId.present
          ? data.originatingHostId.value
          : this.originatingHostId,
      serialized: data.serialized.present
          ? data.serialized.value
          : this.serialized,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationDbEntity(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('scheduledFor: $scheduledFor, ')
          ..write('seenAt: $seenAt, ')
          ..write('actedOnAt: $actedOnAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('linkedEntityId: $linkedEntityId, ')
          ..write('type: $type, ')
          ..write('category: $category, ')
          ..write('vectorClock: $vectorClock, ')
          ..write('originatingHostId: $originatingHostId, ')
          ..write('serialized: $serialized')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    scheduledFor,
    seenAt,
    actedOnAt,
    deletedAt,
    linkedEntityId,
    type,
    category,
    vectorClock,
    originatingHostId,
    serialized,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationDbEntity &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.scheduledFor == this.scheduledFor &&
          other.seenAt == this.seenAt &&
          other.actedOnAt == this.actedOnAt &&
          other.deletedAt == this.deletedAt &&
          other.linkedEntityId == this.linkedEntityId &&
          other.type == this.type &&
          other.category == this.category &&
          other.vectorClock == this.vectorClock &&
          other.originatingHostId == this.originatingHostId &&
          other.serialized == this.serialized);
}

class NotificationsCompanion extends UpdateCompanion<NotificationDbEntity> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime> scheduledFor;
  final Value<DateTime?> seenAt;
  final Value<DateTime?> actedOnAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> linkedEntityId;
  final Value<String> type;
  final Value<String?> category;
  final Value<String> vectorClock;
  final Value<String> originatingHostId;
  final Value<String> serialized;
  final Value<int> rowid;
  const NotificationsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.scheduledFor = const Value.absent(),
    this.seenAt = const Value.absent(),
    this.actedOnAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.linkedEntityId = const Value.absent(),
    this.type = const Value.absent(),
    this.category = const Value.absent(),
    this.vectorClock = const Value.absent(),
    this.originatingHostId = const Value.absent(),
    this.serialized = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime scheduledFor,
    this.seenAt = const Value.absent(),
    this.actedOnAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.linkedEntityId = const Value.absent(),
    required String type,
    this.category = const Value.absent(),
    required String vectorClock,
    required String originatingHostId,
    required String serialized,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       scheduledFor = Value(scheduledFor),
       type = Value(type),
       vectorClock = Value(vectorClock),
       originatingHostId = Value(originatingHostId),
       serialized = Value(serialized);
  static Insertable<NotificationDbEntity> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? scheduledFor,
    Expression<DateTime>? seenAt,
    Expression<DateTime>? actedOnAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? linkedEntityId,
    Expression<String>? type,
    Expression<String>? category,
    Expression<String>? vectorClock,
    Expression<String>? originatingHostId,
    Expression<String>? serialized,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (scheduledFor != null) 'scheduled_for': scheduledFor,
      if (seenAt != null) 'seen_at': seenAt,
      if (actedOnAt != null) 'acted_on_at': actedOnAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (linkedEntityId != null) 'linked_entity_id': linkedEntityId,
      if (type != null) 'type': type,
      if (category != null) 'category': category,
      if (vectorClock != null) 'vector_clock': vectorClock,
      if (originatingHostId != null) 'originating_host_id': originatingHostId,
      if (serialized != null) 'serialized': serialized,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime>? scheduledFor,
    Value<DateTime?>? seenAt,
    Value<DateTime?>? actedOnAt,
    Value<DateTime?>? deletedAt,
    Value<String?>? linkedEntityId,
    Value<String>? type,
    Value<String?>? category,
    Value<String>? vectorClock,
    Value<String>? originatingHostId,
    Value<String>? serialized,
    Value<int>? rowid,
  }) {
    return NotificationsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      seenAt: seenAt ?? this.seenAt,
      actedOnAt: actedOnAt ?? this.actedOnAt,
      deletedAt: deletedAt ?? this.deletedAt,
      linkedEntityId: linkedEntityId ?? this.linkedEntityId,
      type: type ?? this.type,
      category: category ?? this.category,
      vectorClock: vectorClock ?? this.vectorClock,
      originatingHostId: originatingHostId ?? this.originatingHostId,
      serialized: serialized ?? this.serialized,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (scheduledFor.present) {
      map['scheduled_for'] = Variable<DateTime>(scheduledFor.value);
    }
    if (seenAt.present) {
      map['seen_at'] = Variable<DateTime>(seenAt.value);
    }
    if (actedOnAt.present) {
      map['acted_on_at'] = Variable<DateTime>(actedOnAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (linkedEntityId.present) {
      map['linked_entity_id'] = Variable<String>(linkedEntityId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (vectorClock.present) {
      map['vector_clock'] = Variable<String>(vectorClock.value);
    }
    if (originatingHostId.present) {
      map['originating_host_id'] = Variable<String>(originatingHostId.value);
    }
    if (serialized.present) {
      map['serialized'] = Variable<String>(serialized.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('scheduledFor: $scheduledFor, ')
          ..write('seenAt: $seenAt, ')
          ..write('actedOnAt: $actedOnAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('linkedEntityId: $linkedEntityId, ')
          ..write('type: $type, ')
          ..write('category: $category, ')
          ..write('vectorClock: $vectorClock, ')
          ..write('originatingHostId: $originatingHostId, ')
          ..write('serialized: $serialized, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$NotificationsDb extends GeneratedDatabase {
  _$NotificationsDb(QueryExecutor e) : super(e);
  _$NotificationsDb.connect(DatabaseConnection c) : super.connect(c);
  $NotificationsDbManager get managers => $NotificationsDbManager(this);
  late final Notifications notifications = Notifications(this);
  late final Index notificationsScheduledForIdx = Index(
    'notifications_scheduled_for_idx',
    'CREATE INDEX notifications_scheduled_for_idx ON notifications (scheduled_for)',
  );
  late final Index notificationsLinkedIdx = Index(
    'notifications_linked_idx',
    'CREATE INDEX notifications_linked_idx ON notifications (linked_entity_id)',
  );
  late final Index notificationsPendingIdx = Index(
    'notifications_pending_idx',
    'CREATE INDEX notifications_pending_idx ON notifications (seen_at, deleted_at, scheduled_for)',
  );
  Selectable<NotificationDbEntity> notificationRowById(String id) {
    return customSelect(
      'SELECT * FROM notifications WHERE id = ?1',
      variables: [Variable<String>(id)],
      readsFrom: {notifications},
    ).asyncMap(notifications.mapFromRow);
  }

  Selectable<NotificationDbEntity> dueNotificationRows(DateTime now) {
    return customSelect(
      'SELECT * FROM notifications WHERE scheduled_for <= ?1 AND seen_at IS NULL AND acted_on_at IS NULL AND deleted_at IS NULL ORDER BY scheduled_for ASC',
      variables: [Variable<DateTime>(now)],
      readsFrom: {notifications},
    ).asyncMap(notifications.mapFromRow);
  }

  Selectable<NotificationDbEntity> upcomingNotificationRows(DateTime now) {
    return customSelect(
      'SELECT * FROM notifications WHERE scheduled_for > ?1 AND seen_at IS NULL AND acted_on_at IS NULL AND deleted_at IS NULL ORDER BY scheduled_for ASC',
      variables: [Variable<DateTime>(now)],
      readsFrom: {notifications},
    ).asyncMap(notifications.mapFromRow);
  }

  Selectable<NotificationDbEntity> notificationRowsForLinkedEntity(String? id) {
    return customSelect(
      'SELECT * FROM notifications WHERE linked_entity_id = ?1 ORDER BY scheduled_for DESC',
      variables: [Variable<String>(id)],
      readsFrom: {notifications},
    ).asyncMap(notifications.mapFromRow);
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    notifications,
    notificationsScheduledForIdx,
    notificationsLinkedIdx,
    notificationsPendingIdx,
  ];
}

typedef $NotificationsCreateCompanionBuilder =
    NotificationsCompanion Function({
      required String id,
      required DateTime createdAt,
      required DateTime updatedAt,
      required DateTime scheduledFor,
      Value<DateTime?> seenAt,
      Value<DateTime?> actedOnAt,
      Value<DateTime?> deletedAt,
      Value<String?> linkedEntityId,
      required String type,
      Value<String?> category,
      required String vectorClock,
      required String originatingHostId,
      required String serialized,
      Value<int> rowid,
    });
typedef $NotificationsUpdateCompanionBuilder =
    NotificationsCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime> scheduledFor,
      Value<DateTime?> seenAt,
      Value<DateTime?> actedOnAt,
      Value<DateTime?> deletedAt,
      Value<String?> linkedEntityId,
      Value<String> type,
      Value<String?> category,
      Value<String> vectorClock,
      Value<String> originatingHostId,
      Value<String> serialized,
      Value<int> rowid,
    });

class $NotificationsFilterComposer
    extends Composer<_$NotificationsDb, Notifications> {
  $NotificationsFilterComposer({
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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get seenAt => $composableBuilder(
    column: $table.seenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get actedOnAt => $composableBuilder(
    column: $table.actedOnAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedEntityId => $composableBuilder(
    column: $table.linkedEntityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vectorClock => $composableBuilder(
    column: $table.vectorClock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originatingHostId => $composableBuilder(
    column: $table.originatingHostId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serialized => $composableBuilder(
    column: $table.serialized,
    builder: (column) => ColumnFilters(column),
  );
}

class $NotificationsOrderingComposer
    extends Composer<_$NotificationsDb, Notifications> {
  $NotificationsOrderingComposer({
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

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get seenAt => $composableBuilder(
    column: $table.seenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get actedOnAt => $composableBuilder(
    column: $table.actedOnAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedEntityId => $composableBuilder(
    column: $table.linkedEntityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vectorClock => $composableBuilder(
    column: $table.vectorClock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originatingHostId => $composableBuilder(
    column: $table.originatingHostId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serialized => $composableBuilder(
    column: $table.serialized,
    builder: (column) => ColumnOrderings(column),
  );
}

class $NotificationsAnnotationComposer
    extends Composer<_$NotificationsDb, Notifications> {
  $NotificationsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get seenAt =>
      $composableBuilder(column: $table.seenAt, builder: (column) => column);

  GeneratedColumn<DateTime> get actedOnAt =>
      $composableBuilder(column: $table.actedOnAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get linkedEntityId => $composableBuilder(
    column: $table.linkedEntityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get vectorClock => $composableBuilder(
    column: $table.vectorClock,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originatingHostId => $composableBuilder(
    column: $table.originatingHostId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serialized => $composableBuilder(
    column: $table.serialized,
    builder: (column) => column,
  );
}

class $NotificationsTableManager
    extends
        RootTableManager<
          _$NotificationsDb,
          Notifications,
          NotificationDbEntity,
          $NotificationsFilterComposer,
          $NotificationsOrderingComposer,
          $NotificationsAnnotationComposer,
          $NotificationsCreateCompanionBuilder,
          $NotificationsUpdateCompanionBuilder,
          (
            NotificationDbEntity,
            BaseReferences<
              _$NotificationsDb,
              Notifications,
              NotificationDbEntity
            >,
          ),
          NotificationDbEntity,
          PrefetchHooks Function()
        > {
  $NotificationsTableManager(_$NotificationsDb db, Notifications table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $NotificationsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $NotificationsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $NotificationsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> scheduledFor = const Value.absent(),
                Value<DateTime?> seenAt = const Value.absent(),
                Value<DateTime?> actedOnAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> linkedEntityId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String> vectorClock = const Value.absent(),
                Value<String> originatingHostId = const Value.absent(),
                Value<String> serialized = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                scheduledFor: scheduledFor,
                seenAt: seenAt,
                actedOnAt: actedOnAt,
                deletedAt: deletedAt,
                linkedEntityId: linkedEntityId,
                type: type,
                category: category,
                vectorClock: vectorClock,
                originatingHostId: originatingHostId,
                serialized: serialized,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                required DateTime scheduledFor,
                Value<DateTime?> seenAt = const Value.absent(),
                Value<DateTime?> actedOnAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> linkedEntityId = const Value.absent(),
                required String type,
                Value<String?> category = const Value.absent(),
                required String vectorClock,
                required String originatingHostId,
                required String serialized,
                Value<int> rowid = const Value.absent(),
              }) => NotificationsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                scheduledFor: scheduledFor,
                seenAt: seenAt,
                actedOnAt: actedOnAt,
                deletedAt: deletedAt,
                linkedEntityId: linkedEntityId,
                type: type,
                category: category,
                vectorClock: vectorClock,
                originatingHostId: originatingHostId,
                serialized: serialized,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $NotificationsProcessedTableManager =
    ProcessedTableManager<
      _$NotificationsDb,
      Notifications,
      NotificationDbEntity,
      $NotificationsFilterComposer,
      $NotificationsOrderingComposer,
      $NotificationsAnnotationComposer,
      $NotificationsCreateCompanionBuilder,
      $NotificationsUpdateCompanionBuilder,
      (
        NotificationDbEntity,
        BaseReferences<_$NotificationsDb, Notifications, NotificationDbEntity>,
      ),
      NotificationDbEntity,
      PrefetchHooks Function()
    >;

class $NotificationsDbManager {
  final _$NotificationsDb _db;
  $NotificationsDbManager(this._db);
  $NotificationsTableManager get notifications =>
      $NotificationsTableManager(_db, _db.notifications);
}
