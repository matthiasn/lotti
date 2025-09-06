// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class Journal extends Table with TableInfo<Journal, JournalDbEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Journal(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
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
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _dateFromMeta =
      const VerificationMeta('dateFrom');
  late final GeneratedColumn<DateTime> dateFrom = GeneratedColumn<DateTime>(
      'date_from', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _dateToMeta = const VerificationMeta('dateTo');
  late final GeneratedColumn<DateTime> dateTo = GeneratedColumn<DateTime>(
      'date_to', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _starredMeta =
      const VerificationMeta('starred');
  late final GeneratedColumn<bool> starred = GeneratedColumn<bool>(
      'starred', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _privateMeta =
      const VerificationMeta('private');
  late final GeneratedColumn<bool> private = GeneratedColumn<bool>(
      'private', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _taskMeta = const VerificationMeta('task');
  late final GeneratedColumn<bool> task = GeneratedColumn<bool>(
      'task', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _taskStatusMeta =
      const VerificationMeta('taskStatus');
  late final GeneratedColumn<String> taskStatus = GeneratedColumn<String>(
      'task_status', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _flagMeta = const VerificationMeta('flag');
  late final GeneratedColumn<int> flag = GeneratedColumn<int>(
      'flag', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 0',
      defaultValue: const CustomExpression('0'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _subtypeMeta =
      const VerificationMeta('subtype');
  late final GeneratedColumn<String> subtype = GeneratedColumn<String>(
      'subtype', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _serializedMeta =
      const VerificationMeta('serialized');
  late final GeneratedColumn<String> serialized = GeneratedColumn<String>(
      'serialized', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _schemaVersionMeta =
      const VerificationMeta('schemaVersion');
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
      'schema_version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 0',
      defaultValue: const CustomExpression('0'));
  static const VerificationMeta _plainTextMeta =
      const VerificationMeta('plainText');
  late final GeneratedColumn<String> plainText = GeneratedColumn<String>(
      'plain_text', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, true,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, true,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _geohashStringMeta =
      const VerificationMeta('geohashString');
  late final GeneratedColumn<String> geohashString = GeneratedColumn<String>(
      'geohash_string', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _geohashIntMeta =
      const VerificationMeta('geohashInt');
  late final GeneratedColumn<int> geohashInt = GeneratedColumn<int>(
      'geohash_int', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT \'\'',
      defaultValue: const CustomExpression('\'\''));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        createdAt,
        updatedAt,
        dateFrom,
        dateTo,
        deleted,
        starred,
        private,
        task,
        taskStatus,
        flag,
        type,
        subtype,
        serialized,
        schemaVersion,
        plainText,
        latitude,
        longitude,
        geohashString,
        geohashInt,
        category
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal';
  @override
  VerificationContext validateIntegrity(Insertable<JournalDbEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('date_from')) {
      context.handle(_dateFromMeta,
          dateFrom.isAcceptableOrUnknown(data['date_from']!, _dateFromMeta));
    } else if (isInserting) {
      context.missing(_dateFromMeta);
    }
    if (data.containsKey('date_to')) {
      context.handle(_dateToMeta,
          dateTo.isAcceptableOrUnknown(data['date_to']!, _dateToMeta));
    } else if (isInserting) {
      context.missing(_dateToMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('starred')) {
      context.handle(_starredMeta,
          starred.isAcceptableOrUnknown(data['starred']!, _starredMeta));
    }
    if (data.containsKey('private')) {
      context.handle(_privateMeta,
          private.isAcceptableOrUnknown(data['private']!, _privateMeta));
    }
    if (data.containsKey('task')) {
      context.handle(
          _taskMeta, task.isAcceptableOrUnknown(data['task']!, _taskMeta));
    }
    if (data.containsKey('task_status')) {
      context.handle(
          _taskStatusMeta,
          taskStatus.isAcceptableOrUnknown(
              data['task_status']!, _taskStatusMeta));
    }
    if (data.containsKey('flag')) {
      context.handle(
          _flagMeta, flag.isAcceptableOrUnknown(data['flag']!, _flagMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('subtype')) {
      context.handle(_subtypeMeta,
          subtype.isAcceptableOrUnknown(data['subtype']!, _subtypeMeta));
    }
    if (data.containsKey('serialized')) {
      context.handle(
          _serializedMeta,
          serialized.isAcceptableOrUnknown(
              data['serialized']!, _serializedMeta));
    } else if (isInserting) {
      context.missing(_serializedMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
          _schemaVersionMeta,
          schemaVersion.isAcceptableOrUnknown(
              data['schema_version']!, _schemaVersionMeta));
    }
    if (data.containsKey('plain_text')) {
      context.handle(_plainTextMeta,
          plainText.isAcceptableOrUnknown(data['plain_text']!, _plainTextMeta));
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    }
    if (data.containsKey('geohash_string')) {
      context.handle(
          _geohashStringMeta,
          geohashString.isAcceptableOrUnknown(
              data['geohash_string']!, _geohashStringMeta));
    }
    if (data.containsKey('geohash_int')) {
      context.handle(
          _geohashIntMeta,
          geohashInt.isAcceptableOrUnknown(
              data['geohash_int']!, _geohashIntMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JournalDbEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalDbEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      dateFrom: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date_from'])!,
      dateTo: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date_to'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      starred: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}starred'])!,
      private: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}private'])!,
      task: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}task'])!,
      taskStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_status']),
      flag: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}flag'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      subtype: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subtype']),
      serialized: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serialized'])!,
      schemaVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}schema_version'])!,
      plainText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plain_text']),
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude']),
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude']),
      geohashString: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}geohash_string']),
      geohashInt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}geohash_int']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
    );
  }

  @override
  Journal createAlias(String alias) {
    return Journal(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(id)'];
  @override
  bool get dontWriteConstraints => true;
}

class JournalDbEntity extends DataClass implements Insertable<JournalDbEntity> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime dateFrom;
  final DateTime dateTo;
  final bool deleted;
  final bool starred;
  final bool private;
  final bool task;
  final String? taskStatus;
  final int flag;
  final String type;
  final String? subtype;
  final String serialized;
  final int schemaVersion;
  final String? plainText;
  final double? latitude;
  final double? longitude;
  final String? geohashString;
  final int? geohashInt;
  final String category;
  const JournalDbEntity(
      {required this.id,
      required this.createdAt,
      required this.updatedAt,
      required this.dateFrom,
      required this.dateTo,
      required this.deleted,
      required this.starred,
      required this.private,
      required this.task,
      this.taskStatus,
      required this.flag,
      required this.type,
      this.subtype,
      required this.serialized,
      required this.schemaVersion,
      this.plainText,
      this.latitude,
      this.longitude,
      this.geohashString,
      this.geohashInt,
      required this.category});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['date_from'] = Variable<DateTime>(dateFrom);
    map['date_to'] = Variable<DateTime>(dateTo);
    map['deleted'] = Variable<bool>(deleted);
    map['starred'] = Variable<bool>(starred);
    map['private'] = Variable<bool>(private);
    map['task'] = Variable<bool>(task);
    if (!nullToAbsent || taskStatus != null) {
      map['task_status'] = Variable<String>(taskStatus);
    }
    map['flag'] = Variable<int>(flag);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || subtype != null) {
      map['subtype'] = Variable<String>(subtype);
    }
    map['serialized'] = Variable<String>(serialized);
    map['schema_version'] = Variable<int>(schemaVersion);
    if (!nullToAbsent || plainText != null) {
      map['plain_text'] = Variable<String>(plainText);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || geohashString != null) {
      map['geohash_string'] = Variable<String>(geohashString);
    }
    if (!nullToAbsent || geohashInt != null) {
      map['geohash_int'] = Variable<int>(geohashInt);
    }
    map['category'] = Variable<String>(category);
    return map;
  }

  JournalCompanion toCompanion(bool nullToAbsent) {
    return JournalCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      dateFrom: Value(dateFrom),
      dateTo: Value(dateTo),
      deleted: Value(deleted),
      starred: Value(starred),
      private: Value(private),
      task: Value(task),
      taskStatus: taskStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(taskStatus),
      flag: Value(flag),
      type: Value(type),
      subtype: subtype == null && nullToAbsent
          ? const Value.absent()
          : Value(subtype),
      serialized: Value(serialized),
      schemaVersion: Value(schemaVersion),
      plainText: plainText == null && nullToAbsent
          ? const Value.absent()
          : Value(plainText),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      geohashString: geohashString == null && nullToAbsent
          ? const Value.absent()
          : Value(geohashString),
      geohashInt: geohashInt == null && nullToAbsent
          ? const Value.absent()
          : Value(geohashInt),
      category: Value(category),
    );
  }

  factory JournalDbEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalDbEntity(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      dateFrom: serializer.fromJson<DateTime>(json['date_from']),
      dateTo: serializer.fromJson<DateTime>(json['date_to']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      starred: serializer.fromJson<bool>(json['starred']),
      private: serializer.fromJson<bool>(json['private']),
      task: serializer.fromJson<bool>(json['task']),
      taskStatus: serializer.fromJson<String?>(json['task_status']),
      flag: serializer.fromJson<int>(json['flag']),
      type: serializer.fromJson<String>(json['type']),
      subtype: serializer.fromJson<String?>(json['subtype']),
      serialized: serializer.fromJson<String>(json['serialized']),
      schemaVersion: serializer.fromJson<int>(json['schema_version']),
      plainText: serializer.fromJson<String?>(json['plain_text']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      geohashString: serializer.fromJson<String?>(json['geohash_string']),
      geohashInt: serializer.fromJson<int?>(json['geohash_int']),
      category: serializer.fromJson<String>(json['category']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'date_from': serializer.toJson<DateTime>(dateFrom),
      'date_to': serializer.toJson<DateTime>(dateTo),
      'deleted': serializer.toJson<bool>(deleted),
      'starred': serializer.toJson<bool>(starred),
      'private': serializer.toJson<bool>(private),
      'task': serializer.toJson<bool>(task),
      'task_status': serializer.toJson<String?>(taskStatus),
      'flag': serializer.toJson<int>(flag),
      'type': serializer.toJson<String>(type),
      'subtype': serializer.toJson<String?>(subtype),
      'serialized': serializer.toJson<String>(serialized),
      'schema_version': serializer.toJson<int>(schemaVersion),
      'plain_text': serializer.toJson<String?>(plainText),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'geohash_string': serializer.toJson<String?>(geohashString),
      'geohash_int': serializer.toJson<int?>(geohashInt),
      'category': serializer.toJson<String>(category),
    };
  }

  JournalDbEntity copyWith(
          {String? id,
          DateTime? createdAt,
          DateTime? updatedAt,
          DateTime? dateFrom,
          DateTime? dateTo,
          bool? deleted,
          bool? starred,
          bool? private,
          bool? task,
          Value<String?> taskStatus = const Value.absent(),
          int? flag,
          String? type,
          Value<String?> subtype = const Value.absent(),
          String? serialized,
          int? schemaVersion,
          Value<String?> plainText = const Value.absent(),
          Value<double?> latitude = const Value.absent(),
          Value<double?> longitude = const Value.absent(),
          Value<String?> geohashString = const Value.absent(),
          Value<int?> geohashInt = const Value.absent(),
          String? category}) =>
      JournalDbEntity(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        dateFrom: dateFrom ?? this.dateFrom,
        dateTo: dateTo ?? this.dateTo,
        deleted: deleted ?? this.deleted,
        starred: starred ?? this.starred,
        private: private ?? this.private,
        task: task ?? this.task,
        taskStatus: taskStatus.present ? taskStatus.value : this.taskStatus,
        flag: flag ?? this.flag,
        type: type ?? this.type,
        subtype: subtype.present ? subtype.value : this.subtype,
        serialized: serialized ?? this.serialized,
        schemaVersion: schemaVersion ?? this.schemaVersion,
        plainText: plainText.present ? plainText.value : this.plainText,
        latitude: latitude.present ? latitude.value : this.latitude,
        longitude: longitude.present ? longitude.value : this.longitude,
        geohashString:
            geohashString.present ? geohashString.value : this.geohashString,
        geohashInt: geohashInt.present ? geohashInt.value : this.geohashInt,
        category: category ?? this.category,
      );
  JournalDbEntity copyWithCompanion(JournalCompanion data) {
    return JournalDbEntity(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      dateFrom: data.dateFrom.present ? data.dateFrom.value : this.dateFrom,
      dateTo: data.dateTo.present ? data.dateTo.value : this.dateTo,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      starred: data.starred.present ? data.starred.value : this.starred,
      private: data.private.present ? data.private.value : this.private,
      task: data.task.present ? data.task.value : this.task,
      taskStatus:
          data.taskStatus.present ? data.taskStatus.value : this.taskStatus,
      flag: data.flag.present ? data.flag.value : this.flag,
      type: data.type.present ? data.type.value : this.type,
      subtype: data.subtype.present ? data.subtype.value : this.subtype,
      serialized:
          data.serialized.present ? data.serialized.value : this.serialized,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      plainText: data.plainText.present ? data.plainText.value : this.plainText,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      geohashString: data.geohashString.present
          ? data.geohashString.value
          : this.geohashString,
      geohashInt:
          data.geohashInt.present ? data.geohashInt.value : this.geohashInt,
      category: data.category.present ? data.category.value : this.category,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalDbEntity(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dateFrom: $dateFrom, ')
          ..write('dateTo: $dateTo, ')
          ..write('deleted: $deleted, ')
          ..write('starred: $starred, ')
          ..write('private: $private, ')
          ..write('task: $task, ')
          ..write('taskStatus: $taskStatus, ')
          ..write('flag: $flag, ')
          ..write('type: $type, ')
          ..write('subtype: $subtype, ')
          ..write('serialized: $serialized, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('plainText: $plainText, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('geohashString: $geohashString, ')
          ..write('geohashInt: $geohashInt, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        createdAt,
        updatedAt,
        dateFrom,
        dateTo,
        deleted,
        starred,
        private,
        task,
        taskStatus,
        flag,
        type,
        subtype,
        serialized,
        schemaVersion,
        plainText,
        latitude,
        longitude,
        geohashString,
        geohashInt,
        category
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalDbEntity &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.dateFrom == this.dateFrom &&
          other.dateTo == this.dateTo &&
          other.deleted == this.deleted &&
          other.starred == this.starred &&
          other.private == this.private &&
          other.task == this.task &&
          other.taskStatus == this.taskStatus &&
          other.flag == this.flag &&
          other.type == this.type &&
          other.subtype == this.subtype &&
          other.serialized == this.serialized &&
          other.schemaVersion == this.schemaVersion &&
          other.plainText == this.plainText &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.geohashString == this.geohashString &&
          other.geohashInt == this.geohashInt &&
          other.category == this.category);
}

class JournalCompanion extends UpdateCompanion<JournalDbEntity> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime> dateFrom;
  final Value<DateTime> dateTo;
  final Value<bool> deleted;
  final Value<bool> starred;
  final Value<bool> private;
  final Value<bool> task;
  final Value<String?> taskStatus;
  final Value<int> flag;
  final Value<String> type;
  final Value<String?> subtype;
  final Value<String> serialized;
  final Value<int> schemaVersion;
  final Value<String?> plainText;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String?> geohashString;
  final Value<int?> geohashInt;
  final Value<String> category;
  final Value<int> rowid;
  const JournalCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.dateFrom = const Value.absent(),
    this.dateTo = const Value.absent(),
    this.deleted = const Value.absent(),
    this.starred = const Value.absent(),
    this.private = const Value.absent(),
    this.task = const Value.absent(),
    this.taskStatus = const Value.absent(),
    this.flag = const Value.absent(),
    this.type = const Value.absent(),
    this.subtype = const Value.absent(),
    this.serialized = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.plainText = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.geohashString = const Value.absent(),
    this.geohashInt = const Value.absent(),
    this.category = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime dateFrom,
    required DateTime dateTo,
    this.deleted = const Value.absent(),
    this.starred = const Value.absent(),
    this.private = const Value.absent(),
    this.task = const Value.absent(),
    this.taskStatus = const Value.absent(),
    this.flag = const Value.absent(),
    required String type,
    this.subtype = const Value.absent(),
    required String serialized,
    this.schemaVersion = const Value.absent(),
    this.plainText = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.geohashString = const Value.absent(),
    this.geohashInt = const Value.absent(),
    this.category = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        dateFrom = Value(dateFrom),
        dateTo = Value(dateTo),
        type = Value(type),
        serialized = Value(serialized);
  static Insertable<JournalDbEntity> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? dateFrom,
    Expression<DateTime>? dateTo,
    Expression<bool>? deleted,
    Expression<bool>? starred,
    Expression<bool>? private,
    Expression<bool>? task,
    Expression<String>? taskStatus,
    Expression<int>? flag,
    Expression<String>? type,
    Expression<String>? subtype,
    Expression<String>? serialized,
    Expression<int>? schemaVersion,
    Expression<String>? plainText,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? geohashString,
    Expression<int>? geohashInt,
    Expression<String>? category,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (deleted != null) 'deleted': deleted,
      if (starred != null) 'starred': starred,
      if (private != null) 'private': private,
      if (task != null) 'task': task,
      if (taskStatus != null) 'task_status': taskStatus,
      if (flag != null) 'flag': flag,
      if (type != null) 'type': type,
      if (subtype != null) 'subtype': subtype,
      if (serialized != null) 'serialized': serialized,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (plainText != null) 'plain_text': plainText,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (geohashString != null) 'geohash_string': geohashString,
      if (geohashInt != null) 'geohash_int': geohashInt,
      if (category != null) 'category': category,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime>? dateFrom,
      Value<DateTime>? dateTo,
      Value<bool>? deleted,
      Value<bool>? starred,
      Value<bool>? private,
      Value<bool>? task,
      Value<String?>? taskStatus,
      Value<int>? flag,
      Value<String>? type,
      Value<String?>? subtype,
      Value<String>? serialized,
      Value<int>? schemaVersion,
      Value<String?>? plainText,
      Value<double?>? latitude,
      Value<double?>? longitude,
      Value<String?>? geohashString,
      Value<int?>? geohashInt,
      Value<String>? category,
      Value<int>? rowid}) {
    return JournalCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      deleted: deleted ?? this.deleted,
      starred: starred ?? this.starred,
      private: private ?? this.private,
      task: task ?? this.task,
      taskStatus: taskStatus ?? this.taskStatus,
      flag: flag ?? this.flag,
      type: type ?? this.type,
      subtype: subtype ?? this.subtype,
      serialized: serialized ?? this.serialized,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      plainText: plainText ?? this.plainText,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geohashString: geohashString ?? this.geohashString,
      geohashInt: geohashInt ?? this.geohashInt,
      category: category ?? this.category,
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
    if (dateFrom.present) {
      map['date_from'] = Variable<DateTime>(dateFrom.value);
    }
    if (dateTo.present) {
      map['date_to'] = Variable<DateTime>(dateTo.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (starred.present) {
      map['starred'] = Variable<bool>(starred.value);
    }
    if (private.present) {
      map['private'] = Variable<bool>(private.value);
    }
    if (task.present) {
      map['task'] = Variable<bool>(task.value);
    }
    if (taskStatus.present) {
      map['task_status'] = Variable<String>(taskStatus.value);
    }
    if (flag.present) {
      map['flag'] = Variable<int>(flag.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (subtype.present) {
      map['subtype'] = Variable<String>(subtype.value);
    }
    if (serialized.present) {
      map['serialized'] = Variable<String>(serialized.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (plainText.present) {
      map['plain_text'] = Variable<String>(plainText.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (geohashString.present) {
      map['geohash_string'] = Variable<String>(geohashString.value);
    }
    if (geohashInt.present) {
      map['geohash_int'] = Variable<int>(geohashInt.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dateFrom: $dateFrom, ')
          ..write('dateTo: $dateTo, ')
          ..write('deleted: $deleted, ')
          ..write('starred: $starred, ')
          ..write('private: $private, ')
          ..write('task: $task, ')
          ..write('taskStatus: $taskStatus, ')
          ..write('flag: $flag, ')
          ..write('type: $type, ')
          ..write('subtype: $subtype, ')
          ..write('serialized: $serialized, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('plainText: $plainText, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('geohashString: $geohashString, ')
          ..write('geohashInt: $geohashInt, ')
          ..write('category: $category, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Conflicts extends Table with TableInfo<Conflicts, Conflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Conflicts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
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
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _serializedMeta =
      const VerificationMeta('serialized');
  late final GeneratedColumn<String> serialized = GeneratedColumn<String>(
      'serialized', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _schemaVersionMeta =
      const VerificationMeta('schemaVersion');
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
      'schema_version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 0',
      defaultValue: const CustomExpression('0'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns =>
      [id, createdAt, updatedAt, serialized, schemaVersion, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conflicts';
  @override
  VerificationContext validateIntegrity(Insertable<Conflict> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('serialized')) {
      context.handle(
          _serializedMeta,
          serialized.isAcceptableOrUnknown(
              data['serialized']!, _serializedMeta));
    } else if (isInserting) {
      context.missing(_serializedMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
          _schemaVersionMeta,
          schemaVersion.isAcceptableOrUnknown(
              data['schema_version']!, _schemaVersionMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conflict(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      serialized: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serialized'])!,
      schemaVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}schema_version'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
    );
  }

  @override
  Conflicts createAlias(String alias) {
    return Conflicts(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(id)'];
  @override
  bool get dontWriteConstraints => true;
}

class Conflict extends DataClass implements Insertable<Conflict> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String serialized;
  final int schemaVersion;
  final int status;
  const Conflict(
      {required this.id,
      required this.createdAt,
      required this.updatedAt,
      required this.serialized,
      required this.schemaVersion,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['serialized'] = Variable<String>(serialized);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['status'] = Variable<int>(status);
    return map;
  }

  ConflictsCompanion toCompanion(bool nullToAbsent) {
    return ConflictsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      serialized: Value(serialized),
      schemaVersion: Value(schemaVersion),
      status: Value(status),
    );
  }

  factory Conflict.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conflict(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      serialized: serializer.fromJson<String>(json['serialized']),
      schemaVersion: serializer.fromJson<int>(json['schema_version']),
      status: serializer.fromJson<int>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'serialized': serializer.toJson<String>(serialized),
      'schema_version': serializer.toJson<int>(schemaVersion),
      'status': serializer.toJson<int>(status),
    };
  }

  Conflict copyWith(
          {String? id,
          DateTime? createdAt,
          DateTime? updatedAt,
          String? serialized,
          int? schemaVersion,
          int? status}) =>
      Conflict(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        serialized: serialized ?? this.serialized,
        schemaVersion: schemaVersion ?? this.schemaVersion,
        status: status ?? this.status,
      );
  Conflict copyWithCompanion(ConflictsCompanion data) {
    return Conflict(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serialized:
          data.serialized.present ? data.serialized.value : this.serialized,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conflict(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serialized: $serialized, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, createdAt, updatedAt, serialized, schemaVersion, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conflict &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.serialized == this.serialized &&
          other.schemaVersion == this.schemaVersion &&
          other.status == this.status);
}

class ConflictsCompanion extends UpdateCompanion<Conflict> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> serialized;
  final Value<int> schemaVersion;
  final Value<int> status;
  final Value<int> rowid;
  const ConflictsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serialized = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConflictsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String serialized,
    this.schemaVersion = const Value.absent(),
    required int status,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        serialized = Value(serialized),
        status = Value(status);
  static Insertable<Conflict> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? serialized,
    Expression<int>? schemaVersion,
    Expression<int>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serialized != null) 'serialized': serialized,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConflictsCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String>? serialized,
      Value<int>? schemaVersion,
      Value<int>? status,
      Value<int>? rowid}) {
    return ConflictsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serialized: serialized ?? this.serialized,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      status: status ?? this.status,
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
    if (serialized.present) {
      map['serialized'] = Variable<String>(serialized.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConflictsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serialized: $serialized, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class MeasurableTypes extends Table
    with TableInfo<MeasurableTypes, MeasurableDbEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MeasurableTypes(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _uniqueNameMeta =
      const VerificationMeta('uniqueName');
  late final GeneratedColumn<String> uniqueName = GeneratedColumn<String>(
      'unique_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL UNIQUE');
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _privateMeta =
      const VerificationMeta('private');
  late final GeneratedColumn<bool> private = GeneratedColumn<bool>(
      'private', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _serializedMeta =
      const VerificationMeta('serialized');
  late final GeneratedColumn<String> serialized = GeneratedColumn<String>(
      'serialized', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 0',
      defaultValue: const CustomExpression('0'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns => [
        id,
        uniqueName,
        createdAt,
        updatedAt,
        deleted,
        private,
        serialized,
        version,
        status
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'measurable_types';
  @override
  VerificationContext validateIntegrity(Insertable<MeasurableDbEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('unique_name')) {
      context.handle(
          _uniqueNameMeta,
          uniqueName.isAcceptableOrUnknown(
              data['unique_name']!, _uniqueNameMeta));
    } else if (isInserting) {
      context.missing(_uniqueNameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('private')) {
      context.handle(_privateMeta,
          private.isAcceptableOrUnknown(data['private']!, _privateMeta));
    }
    if (data.containsKey('serialized')) {
      context.handle(
          _serializedMeta,
          serialized.isAcceptableOrUnknown(
              data['serialized']!, _serializedMeta));
    } else if (isInserting) {
      context.missing(_serializedMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MeasurableDbEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MeasurableDbEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      uniqueName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unique_name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      private: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}private'])!,
      serialized: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serialized'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
    );
  }

  @override
  MeasurableTypes createAlias(String alias) {
    return MeasurableTypes(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(id)'];
  @override
  bool get dontWriteConstraints => true;
}

class MeasurableDbEntity extends DataClass
    implements Insertable<MeasurableDbEntity> {
  final String id;
  final String uniqueName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;
  final bool private;
  final String serialized;
  final int version;
  final int status;
  const MeasurableDbEntity(
      {required this.id,
      required this.uniqueName,
      required this.createdAt,
      required this.updatedAt,
      required this.deleted,
      required this.private,
      required this.serialized,
      required this.version,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['unique_name'] = Variable<String>(uniqueName);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['private'] = Variable<bool>(private);
    map['serialized'] = Variable<String>(serialized);
    map['version'] = Variable<int>(version);
    map['status'] = Variable<int>(status);
    return map;
  }

  MeasurableTypesCompanion toCompanion(bool nullToAbsent) {
    return MeasurableTypesCompanion(
      id: Value(id),
      uniqueName: Value(uniqueName),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      private: Value(private),
      serialized: Value(serialized),
      version: Value(version),
      status: Value(status),
    );
  }

  factory MeasurableDbEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MeasurableDbEntity(
      id: serializer.fromJson<String>(json['id']),
      uniqueName: serializer.fromJson<String>(json['unique_name']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      private: serializer.fromJson<bool>(json['private']),
      serialized: serializer.fromJson<String>(json['serialized']),
      version: serializer.fromJson<int>(json['version']),
      status: serializer.fromJson<int>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'unique_name': serializer.toJson<String>(uniqueName),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'private': serializer.toJson<bool>(private),
      'serialized': serializer.toJson<String>(serialized),
      'version': serializer.toJson<int>(version),
      'status': serializer.toJson<int>(status),
    };
  }

  MeasurableDbEntity copyWith(
          {String? id,
          String? uniqueName,
          DateTime? createdAt,
          DateTime? updatedAt,
          bool? deleted,
          bool? private,
          String? serialized,
          int? version,
          int? status}) =>
      MeasurableDbEntity(
        id: id ?? this.id,
        uniqueName: uniqueName ?? this.uniqueName,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        private: private ?? this.private,
        serialized: serialized ?? this.serialized,
        version: version ?? this.version,
        status: status ?? this.status,
      );
  MeasurableDbEntity copyWithCompanion(MeasurableTypesCompanion data) {
    return MeasurableDbEntity(
      id: data.id.present ? data.id.value : this.id,
      uniqueName:
          data.uniqueName.present ? data.uniqueName.value : this.uniqueName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      private: data.private.present ? data.private.value : this.private,
      serialized:
          data.serialized.present ? data.serialized.value : this.serialized,
      version: data.version.present ? data.version.value : this.version,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MeasurableDbEntity(')
          ..write('id: $id, ')
          ..write('uniqueName: $uniqueName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('private: $private, ')
          ..write('serialized: $serialized, ')
          ..write('version: $version, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, uniqueName, createdAt, updatedAt, deleted,
      private, serialized, version, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MeasurableDbEntity &&
          other.id == this.id &&
          other.uniqueName == this.uniqueName &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.private == this.private &&
          other.serialized == this.serialized &&
          other.version == this.version &&
          other.status == this.status);
}

class MeasurableTypesCompanion extends UpdateCompanion<MeasurableDbEntity> {
  final Value<String> id;
  final Value<String> uniqueName;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> private;
  final Value<String> serialized;
  final Value<int> version;
  final Value<int> status;
  final Value<int> rowid;
  const MeasurableTypesCompanion({
    this.id = const Value.absent(),
    this.uniqueName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.private = const Value.absent(),
    this.serialized = const Value.absent(),
    this.version = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeasurableTypesCompanion.insert({
    required String id,
    required String uniqueName,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.private = const Value.absent(),
    required String serialized,
    this.version = const Value.absent(),
    required int status,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        uniqueName = Value(uniqueName),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        serialized = Value(serialized),
        status = Value(status);
  static Insertable<MeasurableDbEntity> custom({
    Expression<String>? id,
    Expression<String>? uniqueName,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? private,
    Expression<String>? serialized,
    Expression<int>? version,
    Expression<int>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uniqueName != null) 'unique_name': uniqueName,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (private != null) 'private': private,
      if (serialized != null) 'serialized': serialized,
      if (version != null) 'version': version,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeasurableTypesCompanion copyWith(
      {Value<String>? id,
      Value<String>? uniqueName,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? private,
      Value<String>? serialized,
      Value<int>? version,
      Value<int>? status,
      Value<int>? rowid}) {
    return MeasurableTypesCompanion(
      id: id ?? this.id,
      uniqueName: uniqueName ?? this.uniqueName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      private: private ?? this.private,
      serialized: serialized ?? this.serialized,
      version: version ?? this.version,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (uniqueName.present) {
      map['unique_name'] = Variable<String>(uniqueName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (private.present) {
      map['private'] = Variable<bool>(private.value);
    }
    if (serialized.present) {
      map['serialized'] = Variable<String>(serialized.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeasurableTypesCompanion(')
          ..write('id: $id, ')
          ..write('uniqueName: $uniqueName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('private: $private, ')
          ..write('serialized: $serialized, ')
          ..write('version: $version, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class HabitDefinitions extends Table
    with TableInfo<HabitDefinitions, HabitDefinitionDbEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  HabitDefinitions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL UNIQUE');
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _privateMeta =
      const VerificationMeta('private');
  late final GeneratedColumn<bool> private = GeneratedColumn<bool>(
      'private', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _serializedMeta =
      const VerificationMeta('serialized');
  late final GeneratedColumn<String> serialized = GeneratedColumn<String>(
      'serialized', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
      'active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, createdAt, updatedAt, deleted, private, serialized, active];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_definitions';
  @override
  VerificationContext validateIntegrity(
      Insertable<HabitDefinitionDbEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('private')) {
      context.handle(_privateMeta,
          private.isAcceptableOrUnknown(data['private']!, _privateMeta));
    }
    if (data.containsKey('serialized')) {
      context.handle(
          _serializedMeta,
          serialized.isAcceptableOrUnknown(
              data['serialized']!, _serializedMeta));
    } else if (isInserting) {
      context.missing(_serializedMeta);
    }
    if (data.containsKey('active')) {
      context.handle(_activeMeta,
          active.isAcceptableOrUnknown(data['active']!, _activeMeta));
    } else if (isInserting) {
      context.missing(_activeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HabitDefinitionDbEntity map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitDefinitionDbEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      private: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}private'])!,
      serialized: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serialized'])!,
      active: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}active'])!,
    );
  }

  @override
  HabitDefinitions createAlias(String alias) {
    return HabitDefinitions(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(id)'];
  @override
  bool get dontWriteConstraints => true;
}

class HabitDefinitionDbEntity extends DataClass
    implements Insertable<HabitDefinitionDbEntity> {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;
  final bool private;
  final String serialized;
  final bool active;
  const HabitDefinitionDbEntity(
      {required this.id,
      required this.name,
      required this.createdAt,
      required this.updatedAt,
      required this.deleted,
      required this.private,
      required this.serialized,
      required this.active});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['private'] = Variable<bool>(private);
    map['serialized'] = Variable<String>(serialized);
    map['active'] = Variable<bool>(active);
    return map;
  }

  HabitDefinitionsCompanion toCompanion(bool nullToAbsent) {
    return HabitDefinitionsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      private: Value(private),
      serialized: Value(serialized),
      active: Value(active),
    );
  }

  factory HabitDefinitionDbEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitDefinitionDbEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      private: serializer.fromJson<bool>(json['private']),
      serialized: serializer.fromJson<String>(json['serialized']),
      active: serializer.fromJson<bool>(json['active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'private': serializer.toJson<bool>(private),
      'serialized': serializer.toJson<String>(serialized),
      'active': serializer.toJson<bool>(active),
    };
  }

  HabitDefinitionDbEntity copyWith(
          {String? id,
          String? name,
          DateTime? createdAt,
          DateTime? updatedAt,
          bool? deleted,
          bool? private,
          String? serialized,
          bool? active}) =>
      HabitDefinitionDbEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        private: private ?? this.private,
        serialized: serialized ?? this.serialized,
        active: active ?? this.active,
      );
  HabitDefinitionDbEntity copyWithCompanion(HabitDefinitionsCompanion data) {
    return HabitDefinitionDbEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      private: data.private.present ? data.private.value : this.private,
      serialized:
          data.serialized.present ? data.serialized.value : this.serialized,
      active: data.active.present ? data.active.value : this.active,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitDefinitionDbEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('private: $private, ')
          ..write('serialized: $serialized, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, createdAt, updatedAt, deleted, private, serialized, active);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitDefinitionDbEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.private == this.private &&
          other.serialized == this.serialized &&
          other.active == this.active);
}

class HabitDefinitionsCompanion
    extends UpdateCompanion<HabitDefinitionDbEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> private;
  final Value<String> serialized;
  final Value<bool> active;
  final Value<int> rowid;
  const HabitDefinitionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.private = const Value.absent(),
    this.serialized = const Value.absent(),
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitDefinitionsCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.private = const Value.absent(),
    required String serialized,
    required bool active,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        serialized = Value(serialized),
        active = Value(active);
  static Insertable<HabitDefinitionDbEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? private,
    Expression<String>? serialized,
    Expression<bool>? active,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (private != null) 'private': private,
      if (serialized != null) 'serialized': serialized,
      if (active != null) 'active': active,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitDefinitionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? private,
      Value<String>? serialized,
      Value<bool>? active,
      Value<int>? rowid}) {
    return HabitDefinitionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      private: private ?? this.private,
      serialized: serialized ?? this.serialized,
      active: active ?? this.active,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (private.present) {
      map['private'] = Variable<bool>(private.value);
    }
    if (serialized.present) {
      map['serialized'] = Variable<String>(serialized.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitDefinitionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('private: $private, ')
          ..write('serialized: $serialized, ')
          ..write('active: $active, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class CategoryDefinitions extends Table
    with TableInfo<CategoryDefinitions, CategoryDefinitionDbEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  CategoryDefinitions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL UNIQUE');
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _privateMeta =
      const VerificationMeta('private');
  late final GeneratedColumn<bool> private = GeneratedColumn<bool>(
      'private', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _serializedMeta =
      const VerificationMeta('serialized');
  late final GeneratedColumn<String> serialized = GeneratedColumn<String>(
      'serialized', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
      'active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, createdAt, updatedAt, deleted, private, serialized, active];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_definitions';
  @override
  VerificationContext validateIntegrity(
      Insertable<CategoryDefinitionDbEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('private')) {
      context.handle(_privateMeta,
          private.isAcceptableOrUnknown(data['private']!, _privateMeta));
    }
    if (data.containsKey('serialized')) {
      context.handle(
          _serializedMeta,
          serialized.isAcceptableOrUnknown(
              data['serialized']!, _serializedMeta));
    } else if (isInserting) {
      context.missing(_serializedMeta);
    }
    if (data.containsKey('active')) {
      context.handle(_activeMeta,
          active.isAcceptableOrUnknown(data['active']!, _activeMeta));
    } else if (isInserting) {
      context.missing(_activeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryDefinitionDbEntity map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryDefinitionDbEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      private: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}private'])!,
      serialized: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serialized'])!,
      active: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}active'])!,
    );
  }

  @override
  CategoryDefinitions createAlias(String alias) {
    return CategoryDefinitions(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(id)'];
  @override
  bool get dontWriteConstraints => true;
}

class CategoryDefinitionDbEntity extends DataClass
    implements Insertable<CategoryDefinitionDbEntity> {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;
  final bool private;
  final String serialized;
  final bool active;
  const CategoryDefinitionDbEntity(
      {required this.id,
      required this.name,
      required this.createdAt,
      required this.updatedAt,
      required this.deleted,
      required this.private,
      required this.serialized,
      required this.active});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['private'] = Variable<bool>(private);
    map['serialized'] = Variable<String>(serialized);
    map['active'] = Variable<bool>(active);
    return map;
  }

  CategoryDefinitionsCompanion toCompanion(bool nullToAbsent) {
    return CategoryDefinitionsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      private: Value(private),
      serialized: Value(serialized),
      active: Value(active),
    );
  }

  factory CategoryDefinitionDbEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryDefinitionDbEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      private: serializer.fromJson<bool>(json['private']),
      serialized: serializer.fromJson<String>(json['serialized']),
      active: serializer.fromJson<bool>(json['active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'private': serializer.toJson<bool>(private),
      'serialized': serializer.toJson<String>(serialized),
      'active': serializer.toJson<bool>(active),
    };
  }

  CategoryDefinitionDbEntity copyWith(
          {String? id,
          String? name,
          DateTime? createdAt,
          DateTime? updatedAt,
          bool? deleted,
          bool? private,
          String? serialized,
          bool? active}) =>
      CategoryDefinitionDbEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        private: private ?? this.private,
        serialized: serialized ?? this.serialized,
        active: active ?? this.active,
      );
  CategoryDefinitionDbEntity copyWithCompanion(
      CategoryDefinitionsCompanion data) {
    return CategoryDefinitionDbEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      private: data.private.present ? data.private.value : this.private,
      serialized:
          data.serialized.present ? data.serialized.value : this.serialized,
      active: data.active.present ? data.active.value : this.active,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryDefinitionDbEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('private: $private, ')
          ..write('serialized: $serialized, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, createdAt, updatedAt, deleted, private, serialized, active);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryDefinitionDbEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.private == this.private &&
          other.serialized == this.serialized &&
          other.active == this.active);
}

class CategoryDefinitionsCompanion
    extends UpdateCompanion<CategoryDefinitionDbEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> private;
  final Value<String> serialized;
  final Value<bool> active;
  final Value<int> rowid;
  const CategoryDefinitionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.private = const Value.absent(),
    this.serialized = const Value.absent(),
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryDefinitionsCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.private = const Value.absent(),
    required String serialized,
    required bool active,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        serialized = Value(serialized),
        active = Value(active);
  static Insertable<CategoryDefinitionDbEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? private,
    Expression<String>? serialized,
    Expression<bool>? active,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (private != null) 'private': private,
      if (serialized != null) 'serialized': serialized,
      if (active != null) 'active': active,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryDefinitionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? private,
      Value<String>? serialized,
      Value<bool>? active,
      Value<int>? rowid}) {
    return CategoryDefinitionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      private: private ?? this.private,
      serialized: serialized ?? this.serialized,
      active: active ?? this.active,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (private.present) {
      map['private'] = Variable<bool>(private.value);
    }
    if (serialized.present) {
      map['serialized'] = Variable<String>(serialized.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryDefinitionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('private: $private, ')
          ..write('serialized: $serialized, ')
          ..write('active: $active, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class DashboardDefinitions extends Table
    with TableInfo<DashboardDefinitions, DashboardDefinitionDbEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DashboardDefinitions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
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
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _lastReviewedMeta =
      const VerificationMeta('lastReviewed');
  late final GeneratedColumn<DateTime> lastReviewed = GeneratedColumn<DateTime>(
      'last_reviewed', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _privateMeta =
      const VerificationMeta('private');
  late final GeneratedColumn<bool> private = GeneratedColumn<bool>(
      'private', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _serializedMeta =
      const VerificationMeta('serialized');
  late final GeneratedColumn<String> serialized = GeneratedColumn<String>(
      'serialized', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
      'active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        createdAt,
        updatedAt,
        lastReviewed,
        deleted,
        private,
        serialized,
        active
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dashboard_definitions';
  @override
  VerificationContext validateIntegrity(
      Insertable<DashboardDefinitionDbEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_reviewed')) {
      context.handle(
          _lastReviewedMeta,
          lastReviewed.isAcceptableOrUnknown(
              data['last_reviewed']!, _lastReviewedMeta));
    } else if (isInserting) {
      context.missing(_lastReviewedMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('private')) {
      context.handle(_privateMeta,
          private.isAcceptableOrUnknown(data['private']!, _privateMeta));
    }
    if (data.containsKey('serialized')) {
      context.handle(
          _serializedMeta,
          serialized.isAcceptableOrUnknown(
              data['serialized']!, _serializedMeta));
    } else if (isInserting) {
      context.missing(_serializedMeta);
    }
    if (data.containsKey('active')) {
      context.handle(_activeMeta,
          active.isAcceptableOrUnknown(data['active']!, _activeMeta));
    } else if (isInserting) {
      context.missing(_activeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DashboardDefinitionDbEntity map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DashboardDefinitionDbEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      lastReviewed: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_reviewed'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      private: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}private'])!,
      serialized: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serialized'])!,
      active: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}active'])!,
    );
  }

  @override
  DashboardDefinitions createAlias(String alias) {
    return DashboardDefinitions(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(id)'];
  @override
  bool get dontWriteConstraints => true;
}

class DashboardDefinitionDbEntity extends DataClass
    implements Insertable<DashboardDefinitionDbEntity> {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastReviewed;
  final bool deleted;
  final bool private;
  final String serialized;
  final bool active;
  const DashboardDefinitionDbEntity(
      {required this.id,
      required this.name,
      required this.createdAt,
      required this.updatedAt,
      required this.lastReviewed,
      required this.deleted,
      required this.private,
      required this.serialized,
      required this.active});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['last_reviewed'] = Variable<DateTime>(lastReviewed);
    map['deleted'] = Variable<bool>(deleted);
    map['private'] = Variable<bool>(private);
    map['serialized'] = Variable<String>(serialized);
    map['active'] = Variable<bool>(active);
    return map;
  }

  DashboardDefinitionsCompanion toCompanion(bool nullToAbsent) {
    return DashboardDefinitionsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastReviewed: Value(lastReviewed),
      deleted: Value(deleted),
      private: Value(private),
      serialized: Value(serialized),
      active: Value(active),
    );
  }

  factory DashboardDefinitionDbEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DashboardDefinitionDbEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      lastReviewed: serializer.fromJson<DateTime>(json['last_reviewed']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      private: serializer.fromJson<bool>(json['private']),
      serialized: serializer.fromJson<String>(json['serialized']),
      active: serializer.fromJson<bool>(json['active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'last_reviewed': serializer.toJson<DateTime>(lastReviewed),
      'deleted': serializer.toJson<bool>(deleted),
      'private': serializer.toJson<bool>(private),
      'serialized': serializer.toJson<String>(serialized),
      'active': serializer.toJson<bool>(active),
    };
  }

  DashboardDefinitionDbEntity copyWith(
          {String? id,
          String? name,
          DateTime? createdAt,
          DateTime? updatedAt,
          DateTime? lastReviewed,
          bool? deleted,
          bool? private,
          String? serialized,
          bool? active}) =>
      DashboardDefinitionDbEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastReviewed: lastReviewed ?? this.lastReviewed,
        deleted: deleted ?? this.deleted,
        private: private ?? this.private,
        serialized: serialized ?? this.serialized,
        active: active ?? this.active,
      );
  DashboardDefinitionDbEntity copyWithCompanion(
      DashboardDefinitionsCompanion data) {
    return DashboardDefinitionDbEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastReviewed: data.lastReviewed.present
          ? data.lastReviewed.value
          : this.lastReviewed,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      private: data.private.present ? data.private.value : this.private,
      serialized:
          data.serialized.present ? data.serialized.value : this.serialized,
      active: data.active.present ? data.active.value : this.active,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DashboardDefinitionDbEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastReviewed: $lastReviewed, ')
          ..write('deleted: $deleted, ')
          ..write('private: $private, ')
          ..write('serialized: $serialized, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, updatedAt, lastReviewed,
      deleted, private, serialized, active);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DashboardDefinitionDbEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastReviewed == this.lastReviewed &&
          other.deleted == this.deleted &&
          other.private == this.private &&
          other.serialized == this.serialized &&
          other.active == this.active);
}

class DashboardDefinitionsCompanion
    extends UpdateCompanion<DashboardDefinitionDbEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime> lastReviewed;
  final Value<bool> deleted;
  final Value<bool> private;
  final Value<String> serialized;
  final Value<bool> active;
  final Value<int> rowid;
  const DashboardDefinitionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastReviewed = const Value.absent(),
    this.deleted = const Value.absent(),
    this.private = const Value.absent(),
    this.serialized = const Value.absent(),
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DashboardDefinitionsCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime lastReviewed,
    this.deleted = const Value.absent(),
    this.private = const Value.absent(),
    required String serialized,
    required bool active,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        lastReviewed = Value(lastReviewed),
        serialized = Value(serialized),
        active = Value(active);
  static Insertable<DashboardDefinitionDbEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastReviewed,
    Expression<bool>? deleted,
    Expression<bool>? private,
    Expression<String>? serialized,
    Expression<bool>? active,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastReviewed != null) 'last_reviewed': lastReviewed,
      if (deleted != null) 'deleted': deleted,
      if (private != null) 'private': private,
      if (serialized != null) 'serialized': serialized,
      if (active != null) 'active': active,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DashboardDefinitionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime>? lastReviewed,
      Value<bool>? deleted,
      Value<bool>? private,
      Value<String>? serialized,
      Value<bool>? active,
      Value<int>? rowid}) {
    return DashboardDefinitionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      deleted: deleted ?? this.deleted,
      private: private ?? this.private,
      serialized: serialized ?? this.serialized,
      active: active ?? this.active,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastReviewed.present) {
      map['last_reviewed'] = Variable<DateTime>(lastReviewed.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (private.present) {
      map['private'] = Variable<bool>(private.value);
    }
    if (serialized.present) {
      map['serialized'] = Variable<String>(serialized.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DashboardDefinitionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastReviewed: $lastReviewed, ')
          ..write('deleted: $deleted, ')
          ..write('private: $private, ')
          ..write('serialized: $serialized, ')
          ..write('active: $active, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ConfigFlags extends Table with TableInfo<ConfigFlags, ConfigFlag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ConfigFlags(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL UNIQUE');
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL UNIQUE');
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<bool> status = GeneratedColumn<bool>(
      'status', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  @override
  List<GeneratedColumn> get $columns => [name, description, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'config_flags';
  @override
  VerificationContext validateIntegrity(Insertable<ConfigFlag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  ConfigFlag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConfigFlag(
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}status'])!,
    );
  }

  @override
  ConfigFlags createAlias(String alias) {
    return ConfigFlags(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(name)'];
  @override
  bool get dontWriteConstraints => true;
}

class ConfigFlag extends DataClass implements Insertable<ConfigFlag> {
  final String name;
  final String description;
  final bool status;
  const ConfigFlag(
      {required this.name, required this.description, required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['status'] = Variable<bool>(status);
    return map;
  }

  ConfigFlagsCompanion toCompanion(bool nullToAbsent) {
    return ConfigFlagsCompanion(
      name: Value(name),
      description: Value(description),
      status: Value(status),
    );
  }

  factory ConfigFlag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConfigFlag(
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      status: serializer.fromJson<bool>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'status': serializer.toJson<bool>(status),
    };
  }

  ConfigFlag copyWith({String? name, String? description, bool? status}) =>
      ConfigFlag(
        name: name ?? this.name,
        description: description ?? this.description,
        status: status ?? this.status,
      );
  ConfigFlag copyWithCompanion(ConfigFlagsCompanion data) {
    return ConfigFlag(
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConfigFlag(')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, description, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigFlag &&
          other.name == this.name &&
          other.description == this.description &&
          other.status == this.status);
}

class ConfigFlagsCompanion extends UpdateCompanion<ConfigFlag> {
  final Value<String> name;
  final Value<String> description;
  final Value<bool> status;
  final Value<int> rowid;
  const ConfigFlagsCompanion({
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConfigFlagsCompanion.insert({
    required String name,
    required String description,
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : name = Value(name),
        description = Value(description);
  static Insertable<ConfigFlag> custom({
    Expression<String>? name,
    Expression<String>? description,
    Expression<bool>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConfigFlagsCompanion copyWith(
      {Value<String>? name,
      Value<String>? description,
      Value<bool>? status,
      Value<int>? rowid}) {
    return ConfigFlagsCompanion(
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<bool>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConfigFlagsCompanion(')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class TagEntities extends Table with TableInfo<TagEntities, TagDbEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TagEntities(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL UNIQUE');
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
      'tag', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _inactiveMeta =
      const VerificationMeta('inactive');
  late final GeneratedColumn<bool> inactive = GeneratedColumn<bool>(
      'inactive', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _privateMeta =
      const VerificationMeta('private');
  late final GeneratedColumn<bool> private = GeneratedColumn<bool>(
      'private', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _serializedMeta =
      const VerificationMeta('serialized');
  late final GeneratedColumn<String> serialized = GeneratedColumn<String>(
      'serialized', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns => [
        id,
        tag,
        type,
        inactive,
        private,
        createdAt,
        updatedAt,
        deleted,
        serialized
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_entities';
  @override
  VerificationContext validateIntegrity(Insertable<TagDbEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
          _tagMeta, tag.isAcceptableOrUnknown(data['tag']!, _tagMeta));
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('inactive')) {
      context.handle(_inactiveMeta,
          inactive.isAcceptableOrUnknown(data['inactive']!, _inactiveMeta));
    }
    if (data.containsKey('private')) {
      context.handle(_privateMeta,
          private.isAcceptableOrUnknown(data['private']!, _privateMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('serialized')) {
      context.handle(
          _serializedMeta,
          serialized.isAcceptableOrUnknown(
              data['serialized']!, _serializedMeta));
    } else if (isInserting) {
      context.missing(_serializedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {tag, type},
      ];
  @override
  TagDbEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagDbEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      tag: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tag'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      inactive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}inactive']),
      private: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}private'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted']),
      serialized: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serialized'])!,
    );
  }

  @override
  TagEntities createAlias(String alias) {
    return TagEntities(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints =>
      const ['PRIMARY KEY(id)', 'UNIQUE(tag, type)'];
  @override
  bool get dontWriteConstraints => true;
}

class TagDbEntity extends DataClass implements Insertable<TagDbEntity> {
  final String id;
  final String tag;
  final String type;
  final bool? inactive;
  final bool private;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool? deleted;
  final String serialized;
  const TagDbEntity(
      {required this.id,
      required this.tag,
      required this.type,
      this.inactive,
      required this.private,
      required this.createdAt,
      required this.updatedAt,
      this.deleted,
      required this.serialized});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tag'] = Variable<String>(tag);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || inactive != null) {
      map['inactive'] = Variable<bool>(inactive);
    }
    map['private'] = Variable<bool>(private);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deleted != null) {
      map['deleted'] = Variable<bool>(deleted);
    }
    map['serialized'] = Variable<String>(serialized);
    return map;
  }

  TagEntitiesCompanion toCompanion(bool nullToAbsent) {
    return TagEntitiesCompanion(
      id: Value(id),
      tag: Value(tag),
      type: Value(type),
      inactive: inactive == null && nullToAbsent
          ? const Value.absent()
          : Value(inactive),
      private: Value(private),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: deleted == null && nullToAbsent
          ? const Value.absent()
          : Value(deleted),
      serialized: Value(serialized),
    );
  }

  factory TagDbEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagDbEntity(
      id: serializer.fromJson<String>(json['id']),
      tag: serializer.fromJson<String>(json['tag']),
      type: serializer.fromJson<String>(json['type']),
      inactive: serializer.fromJson<bool?>(json['inactive']),
      private: serializer.fromJson<bool>(json['private']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      deleted: serializer.fromJson<bool?>(json['deleted']),
      serialized: serializer.fromJson<String>(json['serialized']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tag': serializer.toJson<String>(tag),
      'type': serializer.toJson<String>(type),
      'inactive': serializer.toJson<bool?>(inactive),
      'private': serializer.toJson<bool>(private),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool?>(deleted),
      'serialized': serializer.toJson<String>(serialized),
    };
  }

  TagDbEntity copyWith(
          {String? id,
          String? tag,
          String? type,
          Value<bool?> inactive = const Value.absent(),
          bool? private,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<bool?> deleted = const Value.absent(),
          String? serialized}) =>
      TagDbEntity(
        id: id ?? this.id,
        tag: tag ?? this.tag,
        type: type ?? this.type,
        inactive: inactive.present ? inactive.value : this.inactive,
        private: private ?? this.private,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted.present ? deleted.value : this.deleted,
        serialized: serialized ?? this.serialized,
      );
  TagDbEntity copyWithCompanion(TagEntitiesCompanion data) {
    return TagDbEntity(
      id: data.id.present ? data.id.value : this.id,
      tag: data.tag.present ? data.tag.value : this.tag,
      type: data.type.present ? data.type.value : this.type,
      inactive: data.inactive.present ? data.inactive.value : this.inactive,
      private: data.private.present ? data.private.value : this.private,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      serialized:
          data.serialized.present ? data.serialized.value : this.serialized,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagDbEntity(')
          ..write('id: $id, ')
          ..write('tag: $tag, ')
          ..write('type: $type, ')
          ..write('inactive: $inactive, ')
          ..write('private: $private, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('serialized: $serialized')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tag, type, inactive, private, createdAt,
      updatedAt, deleted, serialized);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagDbEntity &&
          other.id == this.id &&
          other.tag == this.tag &&
          other.type == this.type &&
          other.inactive == this.inactive &&
          other.private == this.private &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.serialized == this.serialized);
}

class TagEntitiesCompanion extends UpdateCompanion<TagDbEntity> {
  final Value<String> id;
  final Value<String> tag;
  final Value<String> type;
  final Value<bool?> inactive;
  final Value<bool> private;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool?> deleted;
  final Value<String> serialized;
  final Value<int> rowid;
  const TagEntitiesCompanion({
    this.id = const Value.absent(),
    this.tag = const Value.absent(),
    this.type = const Value.absent(),
    this.inactive = const Value.absent(),
    this.private = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.serialized = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagEntitiesCompanion.insert({
    required String id,
    required String tag,
    required String type,
    this.inactive = const Value.absent(),
    this.private = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    required String serialized,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        tag = Value(tag),
        type = Value(type),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        serialized = Value(serialized);
  static Insertable<TagDbEntity> custom({
    Expression<String>? id,
    Expression<String>? tag,
    Expression<String>? type,
    Expression<bool>? inactive,
    Expression<bool>? private,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<String>? serialized,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tag != null) 'tag': tag,
      if (type != null) 'type': type,
      if (inactive != null) 'inactive': inactive,
      if (private != null) 'private': private,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (serialized != null) 'serialized': serialized,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagEntitiesCompanion copyWith(
      {Value<String>? id,
      Value<String>? tag,
      Value<String>? type,
      Value<bool?>? inactive,
      Value<bool>? private,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<bool?>? deleted,
      Value<String>? serialized,
      Value<int>? rowid}) {
    return TagEntitiesCompanion(
      id: id ?? this.id,
      tag: tag ?? this.tag,
      type: type ?? this.type,
      inactive: inactive ?? this.inactive,
      private: private ?? this.private,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
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
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (inactive.present) {
      map['inactive'] = Variable<bool>(inactive.value);
    }
    if (private.present) {
      map['private'] = Variable<bool>(private.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
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
    return (StringBuffer('TagEntitiesCompanion(')
          ..write('id: $id, ')
          ..write('tag: $tag, ')
          ..write('type: $type, ')
          ..write('inactive: $inactive, ')
          ..write('private: $private, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('serialized: $serialized, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Tagged extends Table with TableInfo<Tagged, TaggedWith> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Tagged(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL UNIQUE');
  static const VerificationMeta _journalIdMeta =
      const VerificationMeta('journalId');
  late final GeneratedColumn<String> journalId = GeneratedColumn<String>(
      'journal_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _tagEntityIdMeta =
      const VerificationMeta('tagEntityId');
  late final GeneratedColumn<String> tagEntityId = GeneratedColumn<String>(
      'tag_entity_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns => [id, journalId, tagEntityId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tagged';
  @override
  VerificationContext validateIntegrity(Insertable<TaggedWith> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('journal_id')) {
      context.handle(_journalIdMeta,
          journalId.isAcceptableOrUnknown(data['journal_id']!, _journalIdMeta));
    } else if (isInserting) {
      context.missing(_journalIdMeta);
    }
    if (data.containsKey('tag_entity_id')) {
      context.handle(
          _tagEntityIdMeta,
          tagEntityId.isAcceptableOrUnknown(
              data['tag_entity_id']!, _tagEntityIdMeta));
    } else if (isInserting) {
      context.missing(_tagEntityIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {journalId, tagEntityId},
      ];
  @override
  TaggedWith map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaggedWith(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      journalId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}journal_id'])!,
      tagEntityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tag_entity_id'])!,
    );
  }

  @override
  Tagged createAlias(String alias) {
    return Tagged(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
        'PRIMARY KEY(id)',
        'FOREIGN KEY(journal_id)REFERENCES journal(id)ON DELETE CASCADE',
        'FOREIGN KEY(tag_entity_id)REFERENCES tag_entities(id)ON DELETE CASCADE',
        'UNIQUE(journal_id, tag_entity_id)'
      ];
  @override
  bool get dontWriteConstraints => true;
}

class TaggedWith extends DataClass implements Insertable<TaggedWith> {
  final String id;
  final String journalId;
  final String tagEntityId;
  const TaggedWith(
      {required this.id, required this.journalId, required this.tagEntityId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['journal_id'] = Variable<String>(journalId);
    map['tag_entity_id'] = Variable<String>(tagEntityId);
    return map;
  }

  TaggedCompanion toCompanion(bool nullToAbsent) {
    return TaggedCompanion(
      id: Value(id),
      journalId: Value(journalId),
      tagEntityId: Value(tagEntityId),
    );
  }

  factory TaggedWith.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaggedWith(
      id: serializer.fromJson<String>(json['id']),
      journalId: serializer.fromJson<String>(json['journal_id']),
      tagEntityId: serializer.fromJson<String>(json['tag_entity_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'journal_id': serializer.toJson<String>(journalId),
      'tag_entity_id': serializer.toJson<String>(tagEntityId),
    };
  }

  TaggedWith copyWith({String? id, String? journalId, String? tagEntityId}) =>
      TaggedWith(
        id: id ?? this.id,
        journalId: journalId ?? this.journalId,
        tagEntityId: tagEntityId ?? this.tagEntityId,
      );
  TaggedWith copyWithCompanion(TaggedCompanion data) {
    return TaggedWith(
      id: data.id.present ? data.id.value : this.id,
      journalId: data.journalId.present ? data.journalId.value : this.journalId,
      tagEntityId:
          data.tagEntityId.present ? data.tagEntityId.value : this.tagEntityId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaggedWith(')
          ..write('id: $id, ')
          ..write('journalId: $journalId, ')
          ..write('tagEntityId: $tagEntityId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, journalId, tagEntityId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaggedWith &&
          other.id == this.id &&
          other.journalId == this.journalId &&
          other.tagEntityId == this.tagEntityId);
}

class TaggedCompanion extends UpdateCompanion<TaggedWith> {
  final Value<String> id;
  final Value<String> journalId;
  final Value<String> tagEntityId;
  final Value<int> rowid;
  const TaggedCompanion({
    this.id = const Value.absent(),
    this.journalId = const Value.absent(),
    this.tagEntityId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaggedCompanion.insert({
    required String id,
    required String journalId,
    required String tagEntityId,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        journalId = Value(journalId),
        tagEntityId = Value(tagEntityId);
  static Insertable<TaggedWith> custom({
    Expression<String>? id,
    Expression<String>? journalId,
    Expression<String>? tagEntityId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (journalId != null) 'journal_id': journalId,
      if (tagEntityId != null) 'tag_entity_id': tagEntityId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaggedCompanion copyWith(
      {Value<String>? id,
      Value<String>? journalId,
      Value<String>? tagEntityId,
      Value<int>? rowid}) {
    return TaggedCompanion(
      id: id ?? this.id,
      journalId: journalId ?? this.journalId,
      tagEntityId: tagEntityId ?? this.tagEntityId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (journalId.present) {
      map['journal_id'] = Variable<String>(journalId.value);
    }
    if (tagEntityId.present) {
      map['tag_entity_id'] = Variable<String>(tagEntityId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaggedCompanion(')
          ..write('id: $id, ')
          ..write('journalId: $journalId, ')
          ..write('tagEntityId: $tagEntityId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class LinkedEntries extends Table with TableInfo<LinkedEntries, LinkedDbEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LinkedEntries(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL UNIQUE');
  static const VerificationMeta _fromIdMeta = const VerificationMeta('fromId');
  late final GeneratedColumn<String> fromId = GeneratedColumn<String>(
      'from_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _toIdMeta = const VerificationMeta('toId');
  late final GeneratedColumn<String> toId = GeneratedColumn<String>(
      'to_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _serializedMeta =
      const VerificationMeta('serialized');
  late final GeneratedColumn<String> serialized = GeneratedColumn<String>(
      'serialized', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
      'hidden', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      $customConstraints: 'DEFAULT FALSE',
      defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      $customConstraints: '');
  @override
  List<GeneratedColumn> get $columns =>
      [id, fromId, toId, type, serialized, hidden, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'linked_entries';
  @override
  VerificationContext validateIntegrity(Insertable<LinkedDbEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('from_id')) {
      context.handle(_fromIdMeta,
          fromId.isAcceptableOrUnknown(data['from_id']!, _fromIdMeta));
    } else if (isInserting) {
      context.missing(_fromIdMeta);
    }
    if (data.containsKey('to_id')) {
      context.handle(
          _toIdMeta, toId.isAcceptableOrUnknown(data['to_id']!, _toIdMeta));
    } else if (isInserting) {
      context.missing(_toIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('serialized')) {
      context.handle(
          _serializedMeta,
          serialized.isAcceptableOrUnknown(
              data['serialized']!, _serializedMeta));
    } else if (isInserting) {
      context.missing(_serializedMeta);
    }
    if (data.containsKey('hidden')) {
      context.handle(_hiddenMeta,
          hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {fromId, toId, type},
      ];
  @override
  LinkedDbEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LinkedDbEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      fromId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}from_id'])!,
      toId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}to_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      serialized: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serialized'])!,
      hidden: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}hidden']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  LinkedEntries createAlias(String alias) {
    return LinkedEntries(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints =>
      const ['PRIMARY KEY(id)', 'UNIQUE(from_id, to_id, type)'];
  @override
  bool get dontWriteConstraints => true;
}

class LinkedDbEntry extends DataClass implements Insertable<LinkedDbEntry> {
  final String id;
  final String fromId;
  final String toId;
  final String type;
  final String serialized;
  final bool? hidden;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const LinkedDbEntry(
      {required this.id,
      required this.fromId,
      required this.toId,
      required this.type,
      required this.serialized,
      this.hidden,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['from_id'] = Variable<String>(fromId);
    map['to_id'] = Variable<String>(toId);
    map['type'] = Variable<String>(type);
    map['serialized'] = Variable<String>(serialized);
    if (!nullToAbsent || hidden != null) {
      map['hidden'] = Variable<bool>(hidden);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  LinkedEntriesCompanion toCompanion(bool nullToAbsent) {
    return LinkedEntriesCompanion(
      id: Value(id),
      fromId: Value(fromId),
      toId: Value(toId),
      type: Value(type),
      serialized: Value(serialized),
      hidden:
          hidden == null && nullToAbsent ? const Value.absent() : Value(hidden),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory LinkedDbEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LinkedDbEntry(
      id: serializer.fromJson<String>(json['id']),
      fromId: serializer.fromJson<String>(json['from_id']),
      toId: serializer.fromJson<String>(json['to_id']),
      type: serializer.fromJson<String>(json['type']),
      serialized: serializer.fromJson<String>(json['serialized']),
      hidden: serializer.fromJson<bool?>(json['hidden']),
      createdAt: serializer.fromJson<DateTime?>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime?>(json['updated_at']),
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
      'serialized': serializer.toJson<String>(serialized),
      'hidden': serializer.toJson<bool?>(hidden),
      'created_at': serializer.toJson<DateTime?>(createdAt),
      'updated_at': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  LinkedDbEntry copyWith(
          {String? id,
          String? fromId,
          String? toId,
          String? type,
          String? serialized,
          Value<bool?> hidden = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      LinkedDbEntry(
        id: id ?? this.id,
        fromId: fromId ?? this.fromId,
        toId: toId ?? this.toId,
        type: type ?? this.type,
        serialized: serialized ?? this.serialized,
        hidden: hidden.present ? hidden.value : this.hidden,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  LinkedDbEntry copyWithCompanion(LinkedEntriesCompanion data) {
    return LinkedDbEntry(
      id: data.id.present ? data.id.value : this.id,
      fromId: data.fromId.present ? data.fromId.value : this.fromId,
      toId: data.toId.present ? data.toId.value : this.toId,
      type: data.type.present ? data.type.value : this.type,
      serialized:
          data.serialized.present ? data.serialized.value : this.serialized,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LinkedDbEntry(')
          ..write('id: $id, ')
          ..write('fromId: $fromId, ')
          ..write('toId: $toId, ')
          ..write('type: $type, ')
          ..write('serialized: $serialized, ')
          ..write('hidden: $hidden, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, fromId, toId, type, serialized, hidden, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LinkedDbEntry &&
          other.id == this.id &&
          other.fromId == this.fromId &&
          other.toId == this.toId &&
          other.type == this.type &&
          other.serialized == this.serialized &&
          other.hidden == this.hidden &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LinkedEntriesCompanion extends UpdateCompanion<LinkedDbEntry> {
  final Value<String> id;
  final Value<String> fromId;
  final Value<String> toId;
  final Value<String> type;
  final Value<String> serialized;
  final Value<bool?> hidden;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const LinkedEntriesCompanion({
    this.id = const Value.absent(),
    this.fromId = const Value.absent(),
    this.toId = const Value.absent(),
    this.type = const Value.absent(),
    this.serialized = const Value.absent(),
    this.hidden = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LinkedEntriesCompanion.insert({
    required String id,
    required String fromId,
    required String toId,
    required String type,
    required String serialized,
    this.hidden = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        fromId = Value(fromId),
        toId = Value(toId),
        type = Value(type),
        serialized = Value(serialized);
  static Insertable<LinkedDbEntry> custom({
    Expression<String>? id,
    Expression<String>? fromId,
    Expression<String>? toId,
    Expression<String>? type,
    Expression<String>? serialized,
    Expression<bool>? hidden,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fromId != null) 'from_id': fromId,
      if (toId != null) 'to_id': toId,
      if (type != null) 'type': type,
      if (serialized != null) 'serialized': serialized,
      if (hidden != null) 'hidden': hidden,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LinkedEntriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? fromId,
      Value<String>? toId,
      Value<String>? type,
      Value<String>? serialized,
      Value<bool?>? hidden,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<int>? rowid}) {
    return LinkedEntriesCompanion(
      id: id ?? this.id,
      fromId: fromId ?? this.fromId,
      toId: toId ?? this.toId,
      type: type ?? this.type,
      serialized: serialized ?? this.serialized,
      hidden: hidden ?? this.hidden,
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
    if (fromId.present) {
      map['from_id'] = Variable<String>(fromId.value);
    }
    if (toId.present) {
      map['to_id'] = Variable<String>(toId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (serialized.present) {
      map['serialized'] = Variable<String>(serialized.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
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
    return (StringBuffer('LinkedEntriesCompanion(')
          ..write('id: $id, ')
          ..write('fromId: $fromId, ')
          ..write('toId: $toId, ')
          ..write('type: $type, ')
          ..write('serialized: $serialized, ')
          ..write('hidden: $hidden, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$JournalDb extends GeneratedDatabase {
  _$JournalDb(QueryExecutor e) : super(e);
  _$JournalDb.connect(DatabaseConnection c) : super.connect(c);
  $JournalDbManager get managers => $JournalDbManager(this);
  late final Journal journal = Journal(this);
  late final Index idxJournalDateFromAsc = Index('idx_journal_date_from_asc',
      'CREATE INDEX idx_journal_date_from_asc ON journal (date_from ASC)');
  late final Index idxJournalDateFromDesc = Index('idx_journal_date_from_desc',
      'CREATE INDEX idx_journal_date_from_desc ON journal (date_from DESC)');
  late final Index idxJournalDateToAsc = Index('idx_journal_date_to_asc',
      'CREATE INDEX idx_journal_date_to_asc ON journal (date_to ASC)');
  late final Index idxJournalDateToDesc = Index('idx_journal_date_to_desc',
      'CREATE INDEX idx_journal_date_to_desc ON journal (date_to DESC)');
  late final Index idxJournalTab = Index('idx_journal_tab',
      'CREATE INDEX idx_journal_tab ON journal (type COLLATE BINARY ASC, starred COLLATE BINARY ASC, flag COLLATE BINARY ASC, private COLLATE BINARY ASC, date_from COLLATE BINARY DESC)');
  late final Index idxJournalTasks = Index('idx_journal_tasks',
      'CREATE INDEX idx_journal_tasks ON journal (type COLLATE BINARY ASC, task_status COLLATE BINARY ASC, category COLLATE BINARY ASC, date_from COLLATE BINARY DESC)');
  late final Index idxJournalTypeSubtype = Index('idx_journal_type_subtype',
      'CREATE INDEX idx_journal_type_subtype ON journal (type COLLATE BINARY ASC, subtype COLLATE BINARY ASC, category COLLATE BINARY ASC, date_from COLLATE BINARY DESC)');
  late final Conflicts conflicts = Conflicts(this);
  late final MeasurableTypes measurableTypes = MeasurableTypes(this);
  late final HabitDefinitions habitDefinitions = HabitDefinitions(this);
  late final Index idxHabitDefinitionsId = Index('idx_habit_definitions_id',
      'CREATE INDEX idx_habit_definitions_id ON habit_definitions (id)');
  late final Index idxHabitDefinitionsName = Index('idx_habit_definitions_name',
      'CREATE INDEX idx_habit_definitions_name ON habit_definitions (name)');
  late final Index idxHabitDefinitionsPrivate = Index(
      'idx_habit_definitions_private',
      'CREATE INDEX idx_habit_definitions_private ON habit_definitions (private)');
  late final CategoryDefinitions categoryDefinitions =
      CategoryDefinitions(this);
  late final Index idxCategoryDefinitionsId = Index(
      'idx_category_definitions_id',
      'CREATE INDEX idx_category_definitions_id ON category_definitions (id)');
  late final Index idxCategoryDefinitionsName = Index(
      'idx_category_definitions_name',
      'CREATE INDEX idx_category_definitions_name ON category_definitions (name)');
  late final Index idxCategoryDefinitionsPrivate = Index(
      'idx_category_definitions_private',
      'CREATE INDEX idx_category_definitions_private ON category_definitions (private)');
  late final DashboardDefinitions dashboardDefinitions =
      DashboardDefinitions(this);
  late final Index idxDashboardDefinitionsId = Index(
      'idx_dashboard_definitions_id',
      'CREATE INDEX idx_dashboard_definitions_id ON dashboard_definitions (id)');
  late final Index idxDashboardDefinitionsName = Index(
      'idx_dashboard_definitions_name',
      'CREATE INDEX idx_dashboard_definitions_name ON dashboard_definitions (name)');
  late final Index idxDashboardDefinitionsPrivate = Index(
      'idx_dashboard_definitions_private',
      'CREATE INDEX idx_dashboard_definitions_private ON dashboard_definitions (private)');
  late final ConfigFlags configFlags = ConfigFlags(this);
  late final TagEntities tagEntities = TagEntities(this);
  late final Index idxTagEntitiesId = Index('idx_tag_entities_id',
      'CREATE INDEX idx_tag_entities_id ON tag_entities (id)');
  late final Index idxTagEntitiesTag = Index('idx_tag_entities_tag',
      'CREATE INDEX idx_tag_entities_tag ON tag_entities (tag)');
  late final Index idxTagEntitiesType = Index('idx_tag_entities_type',
      'CREATE INDEX idx_tag_entities_type ON tag_entities (type)');
  late final Index idxTagEntitiesPrivate = Index('idx_tag_entities_private',
      'CREATE INDEX idx_tag_entities_private ON tag_entities (private)');
  late final Index idxTagEntitiesInactive = Index('idx_tag_entities_inactive',
      'CREATE INDEX idx_tag_entities_inactive ON tag_entities (inactive)');
  late final Tagged tagged = Tagged(this);
  late final Index idxTaggedJournalId = Index('idx_tagged_journal_id',
      'CREATE INDEX idx_tagged_journal_id ON tagged (journal_id)');
  late final Index idxTaggedTagEntityId = Index('idx_tagged_tag_entity_id',
      'CREATE INDEX idx_tagged_tag_entity_id ON tagged (tag_entity_id)');
  late final LinkedEntries linkedEntries = LinkedEntries(this);
  late final Index idxLinkedEntriesFromId = Index('idx_linked_entries_from_id',
      'CREATE INDEX idx_linked_entries_from_id ON linked_entries (from_id)');
  late final Index idxLinkedEntriesToId = Index('idx_linked_entries_to_id',
      'CREATE INDEX idx_linked_entries_to_id ON linked_entries (to_id)');
  late final Index idxLinkedEntriesType = Index('idx_linked_entries_type',
      'CREATE INDEX idx_linked_entries_type ON linked_entries (type)');
  late final Index idxLinkedEntriesHidden = Index('idx_linked_entries_hidden',
      'CREATE INDEX idx_linked_entries_hidden ON linked_entries (hidden)');
  late final Index idxLinkedEntriesFromIdHidden = Index(
      'idx_linked_entries_from_id_hidden',
      'CREATE INDEX idx_linked_entries_from_id_hidden ON linked_entries (from_id COLLATE BINARY ASC, hidden COLLATE BINARY ASC)');
  late final Index idxLinkedEntriesToIdHidden = Index(
      'idx_linked_entries_to_id_hidden',
      'CREATE INDEX idx_linked_entries_to_id_hidden ON linked_entries (from_id COLLATE BINARY ASC, hidden COLLATE BINARY ASC)');
  Selectable<ConfigFlag> listConfigFlags() {
    return customSelect('SELECT * FROM config_flags',
        variables: [],
        readsFrom: {
          configFlags,
        }).asyncMap(configFlags.mapFromRow);
  }

  Selectable<ConfigFlag> configFlagByName(String name) {
    return customSelect('SELECT * FROM config_flags WHERE name = ?1',
        variables: [
          Variable<String>(name)
        ],
        readsFrom: {
          configFlags,
        }).asyncMap(configFlags.mapFromRow);
  }

  Selectable<JournalDbEntity> filteredJournal(
      List<String> types,
      List<bool> starredStatuses,
      List<bool> privateStatuses,
      List<int> flaggedStatuses,
      int limit,
      int offset) {
    var $arrayStartIndex = 3;
    final expandedtypes = $expandVar($arrayStartIndex, types.length);
    $arrayStartIndex += types.length;
    final expandedstarredStatuses =
        $expandVar($arrayStartIndex, starredStatuses.length);
    $arrayStartIndex += starredStatuses.length;
    final expandedprivateStatuses =
        $expandVar($arrayStartIndex, privateStatuses.length);
    $arrayStartIndex += privateStatuses.length;
    final expandedflaggedStatuses =
        $expandVar($arrayStartIndex, flaggedStatuses.length);
    $arrayStartIndex += flaggedStatuses.length;
    return customSelect(
        'SELECT * FROM journal WHERE type IN ($expandedtypes) AND deleted = FALSE AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND starred IN ($expandedstarredStatuses) AND private IN ($expandedprivateStatuses) AND flag IN ($expandedflaggedStatuses) ORDER BY date_from DESC LIMIT ?1 OFFSET ?2',
        variables: [
          Variable<int>(limit),
          Variable<int>(offset),
          for (var $ in types) Variable<String>($),
          for (var $ in starredStatuses) Variable<bool>($),
          for (var $ in privateStatuses) Variable<bool>($),
          for (var $ in flaggedStatuses) Variable<int>($)
        ],
        readsFrom: {
          journal,
          configFlags,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> filteredJournalByCategories(
      List<String> types,
      List<bool> starredStatuses,
      List<bool> privateStatuses,
      List<int> flaggedStatuses,
      List<String> categories,
      int limit,
      int offset) {
    var $arrayStartIndex = 3;
    final expandedtypes = $expandVar($arrayStartIndex, types.length);
    $arrayStartIndex += types.length;
    final expandedstarredStatuses =
        $expandVar($arrayStartIndex, starredStatuses.length);
    $arrayStartIndex += starredStatuses.length;
    final expandedprivateStatuses =
        $expandVar($arrayStartIndex, privateStatuses.length);
    $arrayStartIndex += privateStatuses.length;
    final expandedflaggedStatuses =
        $expandVar($arrayStartIndex, flaggedStatuses.length);
    $arrayStartIndex += flaggedStatuses.length;
    final expandedcategories = $expandVar($arrayStartIndex, categories.length);
    $arrayStartIndex += categories.length;
    return customSelect(
        'SELECT * FROM journal WHERE type IN ($expandedtypes) AND deleted = FALSE AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND starred IN ($expandedstarredStatuses) AND private IN ($expandedprivateStatuses) AND flag IN ($expandedflaggedStatuses) AND category IN ($expandedcategories) ORDER BY date_from DESC LIMIT ?1 OFFSET ?2',
        variables: [
          Variable<int>(limit),
          Variable<int>(offset),
          for (var $ in types) Variable<String>($),
          for (var $ in starredStatuses) Variable<bool>($),
          for (var $ in privateStatuses) Variable<bool>($),
          for (var $ in flaggedStatuses) Variable<int>($),
          for (var $ in categories) Variable<String>($)
        ],
        readsFrom: {
          journal,
          configFlags,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<String> filteredJournalIds(
      List<String> types,
      List<bool> starredStatuses,
      List<bool> privateStatuses,
      List<int> flaggedStatuses,
      int limit,
      int offset) {
    var $arrayStartIndex = 3;
    final expandedtypes = $expandVar($arrayStartIndex, types.length);
    $arrayStartIndex += types.length;
    final expandedstarredStatuses =
        $expandVar($arrayStartIndex, starredStatuses.length);
    $arrayStartIndex += starredStatuses.length;
    final expandedprivateStatuses =
        $expandVar($arrayStartIndex, privateStatuses.length);
    $arrayStartIndex += privateStatuses.length;
    final expandedflaggedStatuses =
        $expandVar($arrayStartIndex, flaggedStatuses.length);
    $arrayStartIndex += flaggedStatuses.length;
    return customSelect(
        'SELECT id FROM journal WHERE type IN ($expandedtypes) AND deleted = FALSE AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND starred IN ($expandedstarredStatuses) AND private IN ($expandedprivateStatuses) AND flag IN ($expandedflaggedStatuses) ORDER BY date_from DESC LIMIT ?1 OFFSET ?2',
        variables: [
          Variable<int>(limit),
          Variable<int>(offset),
          for (var $ in types) Variable<String>($),
          for (var $ in starredStatuses) Variable<bool>($),
          for (var $ in privateStatuses) Variable<bool>($),
          for (var $ in flaggedStatuses) Variable<int>($)
        ],
        readsFrom: {
          journal,
          configFlags,
        }).map((QueryRow row) => row.read<String>('id'));
  }

  Selectable<String> filteredJournalIds2(
      List<String> types,
      List<String> ids,
      List<bool> starredStatuses,
      List<bool> privateStatuses,
      List<int> flaggedStatuses,
      int limit,
      int offset) {
    var $arrayStartIndex = 3;
    final expandedtypes = $expandVar($arrayStartIndex, types.length);
    $arrayStartIndex += types.length;
    final expandedids = $expandVar($arrayStartIndex, ids.length);
    $arrayStartIndex += ids.length;
    final expandedstarredStatuses =
        $expandVar($arrayStartIndex, starredStatuses.length);
    $arrayStartIndex += starredStatuses.length;
    final expandedprivateStatuses =
        $expandVar($arrayStartIndex, privateStatuses.length);
    $arrayStartIndex += privateStatuses.length;
    final expandedflaggedStatuses =
        $expandVar($arrayStartIndex, flaggedStatuses.length);
    $arrayStartIndex += flaggedStatuses.length;
    return customSelect(
        'SELECT id FROM journal WHERE type IN ($expandedtypes) AND deleted = FALSE AND id IN ($expandedids) AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND starred IN ($expandedstarredStatuses) AND private IN ($expandedprivateStatuses) AND flag IN ($expandedflaggedStatuses) ORDER BY date_from DESC LIMIT ?1 OFFSET ?2',
        variables: [
          Variable<int>(limit),
          Variable<int>(offset),
          for (var $ in types) Variable<String>($),
          for (var $ in ids) Variable<String>($),
          for (var $ in starredStatuses) Variable<bool>($),
          for (var $ in privateStatuses) Variable<bool>($),
          for (var $ in flaggedStatuses) Variable<int>($)
        ],
        readsFrom: {
          journal,
          configFlags,
        }).map((QueryRow row) => row.read<String>('id'));
  }

  Selectable<JournalDbEntity> filteredByTagJournal(
      List<String> types,
      List<String> ids,
      List<bool> starredStatuses,
      List<bool> privateStatuses,
      List<int> flaggedStatuses,
      int limit,
      int offset) {
    var $arrayStartIndex = 3;
    final expandedtypes = $expandVar($arrayStartIndex, types.length);
    $arrayStartIndex += types.length;
    final expandedids = $expandVar($arrayStartIndex, ids.length);
    $arrayStartIndex += ids.length;
    final expandedstarredStatuses =
        $expandVar($arrayStartIndex, starredStatuses.length);
    $arrayStartIndex += starredStatuses.length;
    final expandedprivateStatuses =
        $expandVar($arrayStartIndex, privateStatuses.length);
    $arrayStartIndex += privateStatuses.length;
    final expandedflaggedStatuses =
        $expandVar($arrayStartIndex, flaggedStatuses.length);
    $arrayStartIndex += flaggedStatuses.length;
    return customSelect(
        'SELECT * FROM journal WHERE type IN ($expandedtypes) AND deleted = FALSE AND id IN ($expandedids) AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND starred IN ($expandedstarredStatuses) AND private IN ($expandedprivateStatuses) AND flag IN ($expandedflaggedStatuses) ORDER BY date_from DESC LIMIT ?1 OFFSET ?2',
        variables: [
          Variable<int>(limit),
          Variable<int>(offset),
          for (var $ in types) Variable<String>($),
          for (var $ in ids) Variable<String>($),
          for (var $ in starredStatuses) Variable<bool>($),
          for (var $ in privateStatuses) Variable<bool>($),
          for (var $ in flaggedStatuses) Variable<int>($)
        ],
        readsFrom: {
          journal,
          configFlags,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> filteredByTaggedWithId(
      String tagId, DateTime rangeStart, DateTime rangeEnd, int limit) {
    return customSelect(
        'SELECT * FROM journal WHERE deleted = FALSE AND id IN (SELECT journal_id FROM tagged WHERE tag_entity_id = ?1) AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND date_from >= ?2 AND date_to <= ?3 ORDER BY date_from DESC LIMIT ?4',
        variables: [
          Variable<String>(tagId),
          Variable<DateTime>(rangeStart),
          Variable<DateTime>(rangeEnd),
          Variable<int>(limit)
        ],
        readsFrom: {
          journal,
          tagged,
          configFlags,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> filteredByTaggedWithIds(
      List<String> tagIds, DateTime rangeStart, DateTime rangeEnd, int limit) {
    var $arrayStartIndex = 4;
    final expandedtagIds = $expandVar($arrayStartIndex, tagIds.length);
    $arrayStartIndex += tagIds.length;
    return customSelect(
        'SELECT * FROM journal WHERE deleted = FALSE AND id IN (SELECT journal_id FROM tagged WHERE tag_entity_id IN ($expandedtagIds)) AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND date_from >= ?1 AND date_to <= ?2 ORDER BY date_from DESC LIMIT ?3',
        variables: [
          Variable<DateTime>(rangeStart),
          Variable<DateTime>(rangeEnd),
          Variable<int>(limit),
          for (var $ in tagIds) Variable<String>($)
        ],
        readsFrom: {
          journal,
          tagged,
          configFlags,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> sortedCalenderEntriesInRange(
      DateTime rangeStart, DateTime rangeEnd) {
    return customSelect(
        'SELECT * FROM journal WHERE type IN (\'JournalEntry\', \'WorkoutEntry\') AND deleted = FALSE AND date_from >= ?1 AND date_to <= ?2 ORDER BY date_from DESC',
        variables: [
          Variable<DateTime>(rangeStart),
          Variable<DateTime>(rangeEnd)
        ],
        readsFrom: {
          journal,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> filteredByTagMatch(
      String match, DateTime rangeStart, DateTime rangeEnd) {
    return customSelect(
        'SELECT * FROM journal WHERE deleted = FALSE AND id IN (SELECT journal_id FROM tagged WHERE tag_entity_id IN (SELECT id FROM tag_entities WHERE tag LIKE ?1 AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND deleted = FALSE)) AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND date_from >= ?2 AND date_to <= ?3 ORDER BY date_from DESC',
        variables: [
          Variable<String>(match),
          Variable<DateTime>(rangeStart),
          Variable<DateTime>(rangeEnd)
        ],
        readsFrom: {
          journal,
          tagged,
          tagEntities,
          configFlags,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> filteredTasks(
      List<String> types,
      List<bool> starredStatuses,
      List<String?> taskStatuses,
      List<String> categories,
      int limit,
      int offset) {
    var $arrayStartIndex = 3;
    final expandedtypes = $expandVar($arrayStartIndex, types.length);
    $arrayStartIndex += types.length;
    final expandedstarredStatuses =
        $expandVar($arrayStartIndex, starredStatuses.length);
    $arrayStartIndex += starredStatuses.length;
    final expandedtaskStatuses =
        $expandVar($arrayStartIndex, taskStatuses.length);
    $arrayStartIndex += taskStatuses.length;
    final expandedcategories = $expandVar($arrayStartIndex, categories.length);
    $arrayStartIndex += categories.length;
    return customSelect(
        'SELECT * FROM journal WHERE type IN ($expandedtypes) AND deleted = FALSE AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND starred IN ($expandedstarredStatuses) AND task = 1 AND task_status IN ($expandedtaskStatuses) AND category IN ($expandedcategories) ORDER BY date_from DESC LIMIT ?1 OFFSET ?2',
        variables: [
          Variable<int>(limit),
          Variable<int>(offset),
          for (var $ in types) Variable<String>($),
          for (var $ in starredStatuses) Variable<bool>($),
          for (var $ in taskStatuses) Variable<String>($),
          for (var $ in categories) Variable<String>($)
        ],
        readsFrom: {
          journal,
          configFlags,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> filteredTasks2(
      List<String> types,
      List<String> ids,
      List<bool> starredStatuses,
      List<String?> taskStatuses,
      List<String> categories,
      int limit,
      int offset) {
    var $arrayStartIndex = 3;
    final expandedtypes = $expandVar($arrayStartIndex, types.length);
    $arrayStartIndex += types.length;
    final expandedids = $expandVar($arrayStartIndex, ids.length);
    $arrayStartIndex += ids.length;
    final expandedstarredStatuses =
        $expandVar($arrayStartIndex, starredStatuses.length);
    $arrayStartIndex += starredStatuses.length;
    final expandedtaskStatuses =
        $expandVar($arrayStartIndex, taskStatuses.length);
    $arrayStartIndex += taskStatuses.length;
    final expandedcategories = $expandVar($arrayStartIndex, categories.length);
    $arrayStartIndex += categories.length;
    return customSelect(
        'SELECT * FROM journal WHERE type IN ($expandedtypes) AND deleted = FALSE AND id IN ($expandedids) AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND starred IN ($expandedstarredStatuses) AND task = 1 AND task_status IN ($expandedtaskStatuses) AND category IN ($expandedcategories) ORDER BY date_from DESC LIMIT ?1 OFFSET ?2',
        variables: [
          Variable<int>(limit),
          Variable<int>(offset),
          for (var $ in types) Variable<String>($),
          for (var $ in ids) Variable<String>($),
          for (var $ in starredStatuses) Variable<bool>($),
          for (var $ in taskStatuses) Variable<String>($),
          for (var $ in categories) Variable<String>($)
        ],
        readsFrom: {
          journal,
          configFlags,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<String> filteredTaskIds(
      List<String> types,
      List<bool> starredStatuses,
      List<String?> taskStatuses,
      int limit,
      int offset) {
    var $arrayStartIndex = 3;
    final expandedtypes = $expandVar($arrayStartIndex, types.length);
    $arrayStartIndex += types.length;
    final expandedstarredStatuses =
        $expandVar($arrayStartIndex, starredStatuses.length);
    $arrayStartIndex += starredStatuses.length;
    final expandedtaskStatuses =
        $expandVar($arrayStartIndex, taskStatuses.length);
    $arrayStartIndex += taskStatuses.length;
    return customSelect(
        'SELECT id FROM journal WHERE type IN ($expandedtypes) AND deleted = FALSE AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND starred IN ($expandedstarredStatuses) AND task = 1 AND task_status IN ($expandedtaskStatuses) ORDER BY date_from DESC LIMIT ?1 OFFSET ?2',
        variables: [
          Variable<int>(limit),
          Variable<int>(offset),
          for (var $ in types) Variable<String>($),
          for (var $ in starredStatuses) Variable<bool>($),
          for (var $ in taskStatuses) Variable<String>($)
        ],
        readsFrom: {
          journal,
          configFlags,
        }).map((QueryRow row) => row.read<String>('id'));
  }

  Selectable<String> filteredTaskIds2(
      List<String> types,
      List<String> ids,
      List<bool> starredStatuses,
      List<String?> taskStatuses,
      int limit,
      int offset) {
    var $arrayStartIndex = 3;
    final expandedtypes = $expandVar($arrayStartIndex, types.length);
    $arrayStartIndex += types.length;
    final expandedids = $expandVar($arrayStartIndex, ids.length);
    $arrayStartIndex += ids.length;
    final expandedstarredStatuses =
        $expandVar($arrayStartIndex, starredStatuses.length);
    $arrayStartIndex += starredStatuses.length;
    final expandedtaskStatuses =
        $expandVar($arrayStartIndex, taskStatuses.length);
    $arrayStartIndex += taskStatuses.length;
    return customSelect(
        'SELECT id FROM journal WHERE type IN ($expandedtypes) AND deleted = FALSE AND id IN ($expandedids) AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND starred IN ($expandedstarredStatuses) AND task = 1 AND task_status IN ($expandedtaskStatuses) ORDER BY date_from DESC LIMIT ?1 OFFSET ?2',
        variables: [
          Variable<int>(limit),
          Variable<int>(offset),
          for (var $ in types) Variable<String>($),
          for (var $ in ids) Variable<String>($),
          for (var $ in starredStatuses) Variable<bool>($),
          for (var $ in taskStatuses) Variable<String>($)
        ],
        readsFrom: {
          journal,
          configFlags,
        }).map((QueryRow row) => row.read<String>('id'));
  }

  Selectable<JournalDbEntity> orderedJournal(int limit, int offset) {
    return customSelect(
        'SELECT * FROM journal WHERE deleted = FALSE ORDER BY date_from DESC LIMIT ?1 OFFSET ?2',
        variables: [
          Variable<int>(limit),
          Variable<int>(offset)
        ],
        readsFrom: {
          journal,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> orderedJournalInterval(
      DateTime start, DateTime end, int limit, int offset) {
    return customSelect(
        'SELECT * FROM journal WHERE deleted = FALSE AND updated_at > ?1 AND updated_at < ?2 ORDER BY date_from DESC LIMIT ?3 OFFSET ?4',
        variables: [
          Variable<DateTime>(start),
          Variable<DateTime>(end),
          Variable<int>(limit),
          Variable<int>(offset)
        ],
        readsFrom: {
          journal,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> orderedAudioEntries(int limit, int offset) {
    return customSelect(
        'SELECT * FROM journal WHERE type = \'JournalAudio\' AND deleted = FALSE ORDER BY date_from DESC LIMIT ?1 OFFSET ?2',
        variables: [
          Variable<int>(limit),
          Variable<int>(offset)
        ],
        readsFrom: {
          journal,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> entriesFlaggedImport(int limit) {
    return customSelect(
        'SELECT * FROM journal WHERE deleted = FALSE AND flag = 1 ORDER BY date_from DESC LIMIT ?1',
        variables: [
          Variable<int>(limit)
        ],
        readsFrom: {
          journal,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<Conflict> conflictsByStatus(int status, int limit) {
    return customSelect(
        'SELECT * FROM conflicts WHERE status = ?1 ORDER BY created_at DESC LIMIT ?2',
        variables: [
          Variable<int>(status),
          Variable<int>(limit)
        ],
        readsFrom: {
          conflicts,
        }).asyncMap(conflicts.mapFromRow);
  }

  Selectable<Conflict> conflictsById(String id) {
    return customSelect(
        'SELECT * FROM conflicts WHERE id = ?1 ORDER BY created_at DESC',
        variables: [
          Variable<String>(id)
        ],
        readsFrom: {
          conflicts,
        }).asyncMap(conflicts.mapFromRow);
  }

  Selectable<MeasurableDbEntity> activeMeasurableTypes() {
    return customSelect(
        'SELECT * FROM measurable_types WHERE deleted = FALSE AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\'))',
        variables: [],
        readsFrom: {
          measurableTypes,
          configFlags,
        }).asyncMap(measurableTypes.mapFromRow);
  }

  Selectable<MeasurableDbEntity> measurableTypeById(String id) {
    return customSelect(
        'SELECT * FROM measurable_types WHERE deleted = FALSE AND id = ?1 AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\'))',
        variables: [
          Variable<String>(id)
        ],
        readsFrom: {
          measurableTypes,
          configFlags,
        }).asyncMap(measurableTypes.mapFromRow);
  }

  Selectable<JournalDbEntity> measurementsByType(
      String? subtype, DateTime rangeStart, DateTime rangeEnd) {
    return customSelect(
        'SELECT * FROM journal WHERE type = \'MeasurementEntry\' AND subtype = ?1 AND date_from >= ?2 AND date_to <= ?3 AND deleted = FALSE ORDER BY date_from DESC',
        variables: [
          Variable<String>(subtype),
          Variable<DateTime>(rangeStart),
          Variable<DateTime>(rangeEnd)
        ],
        readsFrom: {
          journal,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> habitCompletionsByHabitId(
      String? habitId, DateTime rangeStart, DateTime rangeEnd) {
    return customSelect(
        'SELECT * FROM journal WHERE type = \'HabitCompletionEntry\' AND subtype = ?1 AND date_from >= ?2 AND date_to <= ?3 AND deleted = FALSE ORDER BY date_from DESC',
        variables: [
          Variable<String>(habitId),
          Variable<DateTime>(rangeStart),
          Variable<DateTime>(rangeEnd)
        ],
        readsFrom: {
          journal,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> habitCompletionsInRange(DateTime rangeStart) {
    return customSelect(
        'SELECT * FROM journal WHERE type = \'HabitCompletionEntry\' AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND date_from >= ?1 AND deleted = FALSE ORDER BY date_from ASC',
        variables: [
          Variable<DateTime>(rangeStart)
        ],
        readsFrom: {
          journal,
          configFlags,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> quantitativeByType(
      String? subtype, DateTime rangeStart, DateTime rangeEnd) {
    return customSelect(
        'SELECT * FROM journal WHERE type = \'QuantitativeEntry\' AND subtype = ?1 AND date_from >= ?2 AND date_to <= ?3 AND deleted = FALSE ORDER BY date_from DESC',
        variables: [
          Variable<String>(subtype),
          Variable<DateTime>(rangeStart),
          Variable<DateTime>(rangeEnd)
        ],
        readsFrom: {
          journal,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> latestQuantByType(String? subtype) {
    return customSelect(
        'SELECT * FROM journal WHERE type = \'QuantitativeEntry\' AND subtype = ?1 AND deleted = FALSE ORDER BY date_from DESC LIMIT 1',
        variables: [
          Variable<String>(subtype)
        ],
        readsFrom: {
          journal,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> workouts(DateTime rangeStart, DateTime rangeEnd) {
    return customSelect(
        'SELECT * FROM journal WHERE type = \'WorkoutEntry\' AND date_from >= ?1 AND date_to <= ?2 AND deleted = FALSE ORDER BY date_from DESC',
        variables: [
          Variable<DateTime>(rangeStart),
          Variable<DateTime>(rangeEnd)
        ],
        readsFrom: {
          journal,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> findLatestWorkout() {
    return customSelect(
        'SELECT * FROM journal WHERE type = \'WorkoutEntry\' AND deleted = FALSE ORDER BY date_to DESC LIMIT 1',
        variables: [],
        readsFrom: {
          journal,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> surveysByType(
      String subtype, DateTime rangeStart, DateTime rangeEnd) {
    return customSelect(
        'SELECT * FROM journal WHERE type = \'SurveyEntry\' AND subtype LIKE ?1 AND date_from >= ?2 AND date_to <= ?3 AND deleted = FALSE ORDER BY date_from DESC',
        variables: [
          Variable<String>(subtype),
          Variable<DateTime>(rangeStart),
          Variable<DateTime>(rangeEnd)
        ],
        readsFrom: {
          journal,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<int> countJournalEntries() {
    return customSelect(
        'SELECT COUNT(*) AS _c0 FROM journal WHERE deleted = FALSE',
        variables: [],
        readsFrom: {
          journal,
        }).map((QueryRow row) => row.read<int>('_c0'));
  }

  Selectable<int> countImportFlagEntries() {
    return customSelect(
        'SELECT COUNT(*) AS _c0 FROM journal WHERE deleted = FALSE AND flag = 1',
        variables: [],
        readsFrom: {
          journal,
        }).map((QueryRow row) => row.read<int>('_c0'));
  }

  Selectable<int> countInProgressTasks(List<String?> taskStatuses) {
    var $arrayStartIndex = 1;
    final expandedtaskStatuses =
        $expandVar($arrayStartIndex, taskStatuses.length);
    $arrayStartIndex += taskStatuses.length;
    return customSelect(
        'SELECT COUNT(*) AS _c0 FROM journal WHERE deleted = FALSE AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND task = 1 AND task_status IN ($expandedtaskStatuses)',
        variables: [
          for (var $ in taskStatuses) Variable<String>($)
        ],
        readsFrom: {
          journal,
          configFlags,
        }).map((QueryRow row) => row.read<int>('_c0'));
  }

  Selectable<TagDbEntity> allTagEntities() {
    return customSelect(
        'SELECT * FROM tag_entities WHERE private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND deleted = FALSE ORDER BY tag COLLATE NOCASE',
        variables: [],
        readsFrom: {
          tagEntities,
          configFlags,
        }).asyncMap(tagEntities.mapFromRow);
  }

  Selectable<DashboardDefinitionDbEntity> allDashboards() {
    return customSelect(
        'SELECT * FROM dashboard_definitions WHERE private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND deleted = FALSE ORDER BY name COLLATE NOCASE',
        variables: [],
        readsFrom: {
          dashboardDefinitions,
          configFlags,
        }).asyncMap(dashboardDefinitions.mapFromRow);
  }

  Selectable<DashboardDefinitionDbEntity> dashboardById(String id) {
    return customSelect(
        'SELECT * FROM dashboard_definitions WHERE private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND id = ?1 AND deleted = FALSE',
        variables: [
          Variable<String>(id)
        ],
        readsFrom: {
          dashboardDefinitions,
          configFlags,
        }).asyncMap(dashboardDefinitions.mapFromRow);
  }

  Selectable<HabitDefinitionDbEntity> allHabitDefinitions() {
    return customSelect(
        'SELECT * FROM habit_definitions WHERE private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND deleted = FALSE',
        variables: [],
        readsFrom: {
          habitDefinitions,
          configFlags,
        }).asyncMap(habitDefinitions.mapFromRow);
  }

  Selectable<HabitDefinitionDbEntity> habitById(String id) {
    return customSelect(
        'SELECT * FROM habit_definitions WHERE deleted = FALSE AND id = ?1 AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\'))',
        variables: [
          Variable<String>(id)
        ],
        readsFrom: {
          habitDefinitions,
          configFlags,
        }).asyncMap(habitDefinitions.mapFromRow);
  }

  Selectable<CategoryDefinitionDbEntity> allCategoryDefinitions() {
    return customSelect(
        'SELECT * FROM category_definitions WHERE private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND deleted = FALSE ORDER BY name COLLATE NOCASE',
        variables: [],
        readsFrom: {
          categoryDefinitions,
          configFlags,
        }).asyncMap(categoryDefinitions.mapFromRow);
  }

  Selectable<CategoryDefinitionDbEntity> categoryById(String id) {
    return customSelect(
        'SELECT * FROM category_definitions WHERE deleted = FALSE AND id = ?1 AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\'))',
        variables: [
          Variable<String>(id)
        ],
        readsFrom: {
          categoryDefinitions,
          configFlags,
        }).asyncMap(categoryDefinitions.mapFromRow);
  }

  Selectable<TagDbEntity> matchingTagEntities(
      String match, bool? inactive, int limit) {
    return customSelect(
        'SELECT * FROM tag_entities WHERE tag LIKE ?1 AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) AND inactive IN (0, ?2) AND deleted = FALSE LIMIT ?3',
        variables: [
          Variable<String>(match),
          Variable<bool>(inactive),
          Variable<int>(limit)
        ],
        readsFrom: {
          tagEntities,
          configFlags,
        }).asyncMap(tagEntities.mapFromRow);
  }

  Future<int> deleteTaggedForId(String id) {
    return customUpdate(
      'DELETE FROM tagged WHERE journal_id = ?1',
      variables: [Variable<String>(id)],
      updates: {tagged},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> purgeDeletedDashboards() {
    return customUpdate(
      'DELETE FROM dashboard_definitions WHERE deleted = TRUE',
      variables: [],
      updates: {dashboardDefinitions},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> purgeDeletedMeasurables() {
    return customUpdate(
      'DELETE FROM measurable_types WHERE deleted = TRUE',
      variables: [],
      updates: {measurableTypes},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> purgeDeletedTagEntities() {
    return customUpdate(
      'DELETE FROM tag_entities WHERE deleted = TRUE',
      variables: [],
      updates: {tagEntities},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> purgeDeletedJournalEntities() {
    return customUpdate(
      'DELETE FROM journal WHERE deleted = TRUE',
      variables: [],
      updates: {journal},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> deleteTagged() {
    return customUpdate(
      'DELETE FROM tagged',
      variables: [],
      updates: {tagged},
      updateKind: UpdateKind.delete,
    );
  }

  Selectable<String> entryIdsForTagId(String tagId) {
    return customSelect(
        'SELECT journal_id FROM tagged WHERE tag_entity_id = ?1',
        variables: [
          Variable<String>(tagId)
        ],
        readsFrom: {
          tagged,
        }).map((QueryRow row) => row.read<String>('journal_id'));
  }

  Selectable<int> countTagged() {
    return customSelect('SELECT COUNT(*) AS _c0 FROM tagged',
        variables: [],
        readsFrom: {
          tagged,
        }).map((QueryRow row) => row.read<int>('_c0'));
  }

  Selectable<JournalDbEntity> linkedJournalEntities(String fromId) {
    return customSelect(
        'SELECT * FROM journal WHERE deleted = FALSE AND id IN (SELECT to_id FROM linked_entries WHERE from_id = ?1) AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) ORDER BY date_from DESC',
        variables: [
          Variable<String>(fromId)
        ],
        readsFrom: {
          journal,
          linkedEntries,
          configFlags,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<String> journalEntityIdsByDateFromDesc(List<String> ids) {
    var $arrayStartIndex = 1;
    final expandedids = $expandVar($arrayStartIndex, ids.length);
    $arrayStartIndex += ids.length;
    return customSelect(
        'SELECT id FROM journal WHERE deleted = FALSE AND id IN ($expandedids) AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) ORDER BY date_from DESC',
        variables: [
          for (var $ in ids) Variable<String>($)
        ],
        readsFrom: {
          journal,
          configFlags,
        }).map((QueryRow row) => row.read<String>('id'));
  }

  Selectable<LinkedDbEntry> linksForIds(List<String> toIds) {
    var $arrayStartIndex = 1;
    final expandedtoIds = $expandVar($arrayStartIndex, toIds.length);
    $arrayStartIndex += toIds.length;
    return customSelect(
        'SELECT * FROM linked_entries WHERE to_id IN ($expandedtoIds)',
        variables: [
          for (var $ in toIds) Variable<String>($)
        ],
        readsFrom: {
          linkedEntries,
        }).asyncMap(linkedEntries.mapFromRow);
  }

  Selectable<LinkedDbEntry> linksFromIds(List<String> fromIds) {
    var $arrayStartIndex = 1;
    final expandedfromIds = $expandVar($arrayStartIndex, fromIds.length);
    $arrayStartIndex += fromIds.length;
    return customSelect(
        'SELECT * FROM linked_entries WHERE from_id IN ($expandedfromIds)',
        variables: [
          for (var $ in fromIds) Variable<String>($)
        ],
        readsFrom: {
          linkedEntries,
        }).asyncMap(linkedEntries.mapFromRow);
  }

  Selectable<JournalDbEntity> entriesForIds(List<String> ids) {
    var $arrayStartIndex = 1;
    final expandedids = $expandVar($arrayStartIndex, ids.length);
    $arrayStartIndex += ids.length;
    return customSelect('SELECT * FROM journal WHERE id IN ($expandedids)',
        variables: [
          for (var $ in ids) Variable<String>($)
        ],
        readsFrom: {
          journal,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<JournalDbEntity> journalEntitiesByIds(List<String> ids) {
    var $arrayStartIndex = 1;
    final expandedids = $expandVar($arrayStartIndex, ids.length);
    $arrayStartIndex += ids.length;
    return customSelect(
        'SELECT * FROM journal WHERE deleted = FALSE AND id IN ($expandedids) AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) ORDER BY date_from DESC',
        variables: [
          for (var $ in ids) Variable<String>($)
        ],
        readsFrom: {
          journal,
          configFlags,
        }).asyncMap(journal.mapFromRow);
  }

  Selectable<String> linkedJournalEntityIds(String fromId, List<bool?> hidden) {
    var $arrayStartIndex = 2;
    final expandedhidden = $expandVar($arrayStartIndex, hidden.length);
    $arrayStartIndex += hidden.length;
    return customSelect(
        'SELECT to_id FROM linked_entries WHERE from_id = ?1 AND hidden IN ($expandedhidden)',
        variables: [
          Variable<String>(fromId),
          for (var $ in hidden) Variable<bool>($)
        ],
        readsFrom: {
          linkedEntries,
        }).map((QueryRow row) => row.read<String>('to_id'));
  }

  Selectable<LinkedDbEntry> linksFromId(String fromId, List<bool?> hidden) {
    var $arrayStartIndex = 2;
    final expandedhidden = $expandVar($arrayStartIndex, hidden.length);
    $arrayStartIndex += hidden.length;
    return customSelect(
        'SELECT * FROM linked_entries WHERE from_id = ?1 AND hidden IN ($expandedhidden) ORDER BY created_at DESC',
        variables: [
          Variable<String>(fromId),
          for (var $ in hidden) Variable<bool>($)
        ],
        readsFrom: {
          linkedEntries,
        }).asyncMap(linkedEntries.mapFromRow);
  }

  Selectable<JournalDbEntity> linkedToJournalEntities(String toId) {
    return customSelect(
        'SELECT * FROM journal WHERE deleted = FALSE AND id IN (SELECT from_id FROM linked_entries WHERE to_id = ?1) AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) ORDER BY date_from DESC',
        variables: [
          Variable<String>(toId)
        ],
        readsFrom: {
          journal,
          linkedEntries,
          configFlags,
        }).asyncMap(journal.mapFromRow);
  }

  Future<int> deleteLink(String fromId, String toId) {
    return customUpdate(
      'DELETE FROM linked_entries WHERE from_id = ?1 AND to_id = ?2',
      variables: [Variable<String>(fromId), Variable<String>(toId)],
      updates: {linkedEntries},
      updateKind: UpdateKind.delete,
    );
  }

  Selectable<JournalDbEntity> workEntriesInDateRange(List<String> types,
      List<String> categoryIds, DateTime startDate, DateTime endDate) {
    var $arrayStartIndex = 3;
    final expandedtypes = $expandVar($arrayStartIndex, types.length);
    $arrayStartIndex += types.length;
    final expandedcategoryIds =
        $expandVar($arrayStartIndex, categoryIds.length);
    $arrayStartIndex += categoryIds.length;
    return customSelect(
        'SELECT * FROM journal WHERE deleted = FALSE AND type IN ($expandedtypes) AND category IN ($expandedcategoryIds) AND date_from >= ?1 AND date_from <= ?2 AND(type = \'JournalAudio\' OR(type = \'JournalEntry\' AND(julianday(date_to) - julianday(date_from))* 24 * 3600 >= 15))AND private IN (0, (SELECT status FROM config_flags WHERE name = \'private\')) ORDER BY date_from DESC',
        variables: [
          Variable<DateTime>(startDate),
          Variable<DateTime>(endDate),
          for (var $ in types) Variable<String>($),
          for (var $ in categoryIds) Variable<String>($)
        ],
        readsFrom: {
          journal,
          configFlags,
        }).asyncMap(journal.mapFromRow);
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        journal,
        idxJournalDateFromAsc,
        idxJournalDateFromDesc,
        idxJournalDateToAsc,
        idxJournalDateToDesc,
        idxJournalTab,
        idxJournalTasks,
        idxJournalTypeSubtype,
        conflicts,
        measurableTypes,
        habitDefinitions,
        idxHabitDefinitionsId,
        idxHabitDefinitionsName,
        idxHabitDefinitionsPrivate,
        categoryDefinitions,
        idxCategoryDefinitionsId,
        idxCategoryDefinitionsName,
        idxCategoryDefinitionsPrivate,
        dashboardDefinitions,
        idxDashboardDefinitionsId,
        idxDashboardDefinitionsName,
        idxDashboardDefinitionsPrivate,
        configFlags,
        tagEntities,
        idxTagEntitiesId,
        idxTagEntitiesTag,
        idxTagEntitiesType,
        idxTagEntitiesPrivate,
        idxTagEntitiesInactive,
        tagged,
        idxTaggedJournalId,
        idxTaggedTagEntityId,
        linkedEntries,
        idxLinkedEntriesFromId,
        idxLinkedEntriesToId,
        idxLinkedEntriesType,
        idxLinkedEntriesHidden,
        idxLinkedEntriesFromIdHidden,
        idxLinkedEntriesToIdHidden
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('journal',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('tagged', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('tag_entities',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('tagged', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $JournalCreateCompanionBuilder = JournalCompanion Function({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
  required DateTime dateFrom,
  required DateTime dateTo,
  Value<bool> deleted,
  Value<bool> starred,
  Value<bool> private,
  Value<bool> task,
  Value<String?> taskStatus,
  Value<int> flag,
  required String type,
  Value<String?> subtype,
  required String serialized,
  Value<int> schemaVersion,
  Value<String?> plainText,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String?> geohashString,
  Value<int?> geohashInt,
  Value<String> category,
  Value<int> rowid,
});
typedef $JournalUpdateCompanionBuilder = JournalCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime> dateFrom,
  Value<DateTime> dateTo,
  Value<bool> deleted,
  Value<bool> starred,
  Value<bool> private,
  Value<bool> task,
  Value<String?> taskStatus,
  Value<int> flag,
  Value<String> type,
  Value<String?> subtype,
  Value<String> serialized,
  Value<int> schemaVersion,
  Value<String?> plainText,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String?> geohashString,
  Value<int?> geohashInt,
  Value<String> category,
  Value<int> rowid,
});

class $JournalFilterComposer extends Composer<_$JournalDb, Journal> {
  $JournalFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dateFrom => $composableBuilder(
      column: $table.dateFrom, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dateTo => $composableBuilder(
      column: $table.dateTo, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get starred => $composableBuilder(
      column: $table.starred, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get private => $composableBuilder(
      column: $table.private, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get task => $composableBuilder(
      column: $table.task, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskStatus => $composableBuilder(
      column: $table.taskStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get flag => $composableBuilder(
      column: $table.flag, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subtype => $composableBuilder(
      column: $table.subtype, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get plainText => $composableBuilder(
      column: $table.plainText, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get geohashString => $composableBuilder(
      column: $table.geohashString, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get geohashInt => $composableBuilder(
      column: $table.geohashInt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));
}

class $JournalOrderingComposer extends Composer<_$JournalDb, Journal> {
  $JournalOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dateFrom => $composableBuilder(
      column: $table.dateFrom, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dateTo => $composableBuilder(
      column: $table.dateTo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get starred => $composableBuilder(
      column: $table.starred, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get private => $composableBuilder(
      column: $table.private, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get task => $composableBuilder(
      column: $table.task, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskStatus => $composableBuilder(
      column: $table.taskStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get flag => $composableBuilder(
      column: $table.flag, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subtype => $composableBuilder(
      column: $table.subtype, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plainText => $composableBuilder(
      column: $table.plainText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get geohashString => $composableBuilder(
      column: $table.geohashString,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get geohashInt => $composableBuilder(
      column: $table.geohashInt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));
}

class $JournalAnnotationComposer extends Composer<_$JournalDb, Journal> {
  $JournalAnnotationComposer({
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

  GeneratedColumn<DateTime> get dateFrom =>
      $composableBuilder(column: $table.dateFrom, builder: (column) => column);

  GeneratedColumn<DateTime> get dateTo =>
      $composableBuilder(column: $table.dateTo, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<bool> get private =>
      $composableBuilder(column: $table.private, builder: (column) => column);

  GeneratedColumn<bool> get task =>
      $composableBuilder(column: $table.task, builder: (column) => column);

  GeneratedColumn<String> get taskStatus => $composableBuilder(
      column: $table.taskStatus, builder: (column) => column);

  GeneratedColumn<int> get flag =>
      $composableBuilder(column: $table.flag, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get subtype =>
      $composableBuilder(column: $table.subtype, builder: (column) => column);

  GeneratedColumn<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion, builder: (column) => column);

  GeneratedColumn<String> get plainText =>
      $composableBuilder(column: $table.plainText, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get geohashString => $composableBuilder(
      column: $table.geohashString, builder: (column) => column);

  GeneratedColumn<int> get geohashInt => $composableBuilder(
      column: $table.geohashInt, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);
}

class $JournalTableManager extends RootTableManager<
    _$JournalDb,
    Journal,
    JournalDbEntity,
    $JournalFilterComposer,
    $JournalOrderingComposer,
    $JournalAnnotationComposer,
    $JournalCreateCompanionBuilder,
    $JournalUpdateCompanionBuilder,
    (JournalDbEntity, BaseReferences<_$JournalDb, Journal, JournalDbEntity>),
    JournalDbEntity,
    PrefetchHooks Function()> {
  $JournalTableManager(_$JournalDb db, Journal table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $JournalFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $JournalOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $JournalAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime> dateFrom = const Value.absent(),
            Value<DateTime> dateTo = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> starred = const Value.absent(),
            Value<bool> private = const Value.absent(),
            Value<bool> task = const Value.absent(),
            Value<String?> taskStatus = const Value.absent(),
            Value<int> flag = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> subtype = const Value.absent(),
            Value<String> serialized = const Value.absent(),
            Value<int> schemaVersion = const Value.absent(),
            Value<String?> plainText = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<String?> geohashString = const Value.absent(),
            Value<int?> geohashInt = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JournalCompanion(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            dateFrom: dateFrom,
            dateTo: dateTo,
            deleted: deleted,
            starred: starred,
            private: private,
            task: task,
            taskStatus: taskStatus,
            flag: flag,
            type: type,
            subtype: subtype,
            serialized: serialized,
            schemaVersion: schemaVersion,
            plainText: plainText,
            latitude: latitude,
            longitude: longitude,
            geohashString: geohashString,
            geohashInt: geohashInt,
            category: category,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdAt,
            required DateTime updatedAt,
            required DateTime dateFrom,
            required DateTime dateTo,
            Value<bool> deleted = const Value.absent(),
            Value<bool> starred = const Value.absent(),
            Value<bool> private = const Value.absent(),
            Value<bool> task = const Value.absent(),
            Value<String?> taskStatus = const Value.absent(),
            Value<int> flag = const Value.absent(),
            required String type,
            Value<String?> subtype = const Value.absent(),
            required String serialized,
            Value<int> schemaVersion = const Value.absent(),
            Value<String?> plainText = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<String?> geohashString = const Value.absent(),
            Value<int?> geohashInt = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JournalCompanion.insert(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            dateFrom: dateFrom,
            dateTo: dateTo,
            deleted: deleted,
            starred: starred,
            private: private,
            task: task,
            taskStatus: taskStatus,
            flag: flag,
            type: type,
            subtype: subtype,
            serialized: serialized,
            schemaVersion: schemaVersion,
            plainText: plainText,
            latitude: latitude,
            longitude: longitude,
            geohashString: geohashString,
            geohashInt: geohashInt,
            category: category,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $JournalProcessedTableManager = ProcessedTableManager<
    _$JournalDb,
    Journal,
    JournalDbEntity,
    $JournalFilterComposer,
    $JournalOrderingComposer,
    $JournalAnnotationComposer,
    $JournalCreateCompanionBuilder,
    $JournalUpdateCompanionBuilder,
    (JournalDbEntity, BaseReferences<_$JournalDb, Journal, JournalDbEntity>),
    JournalDbEntity,
    PrefetchHooks Function()>;
typedef $ConflictsCreateCompanionBuilder = ConflictsCompanion Function({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
  required String serialized,
  Value<int> schemaVersion,
  required int status,
  Value<int> rowid,
});
typedef $ConflictsUpdateCompanionBuilder = ConflictsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String> serialized,
  Value<int> schemaVersion,
  Value<int> status,
  Value<int> rowid,
});

class $ConflictsFilterComposer extends Composer<_$JournalDb, Conflicts> {
  $ConflictsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));
}

class $ConflictsOrderingComposer extends Composer<_$JournalDb, Conflicts> {
  $ConflictsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));
}

class $ConflictsAnnotationComposer extends Composer<_$JournalDb, Conflicts> {
  $ConflictsAnnotationComposer({
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

  GeneratedColumn<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $ConflictsTableManager extends RootTableManager<
    _$JournalDb,
    Conflicts,
    Conflict,
    $ConflictsFilterComposer,
    $ConflictsOrderingComposer,
    $ConflictsAnnotationComposer,
    $ConflictsCreateCompanionBuilder,
    $ConflictsUpdateCompanionBuilder,
    (Conflict, BaseReferences<_$JournalDb, Conflicts, Conflict>),
    Conflict,
    PrefetchHooks Function()> {
  $ConflictsTableManager(_$JournalDb db, Conflicts table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ConflictsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ConflictsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ConflictsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String> serialized = const Value.absent(),
            Value<int> schemaVersion = const Value.absent(),
            Value<int> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConflictsCompanion(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            serialized: serialized,
            schemaVersion: schemaVersion,
            status: status,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdAt,
            required DateTime updatedAt,
            required String serialized,
            Value<int> schemaVersion = const Value.absent(),
            required int status,
            Value<int> rowid = const Value.absent(),
          }) =>
              ConflictsCompanion.insert(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            serialized: serialized,
            schemaVersion: schemaVersion,
            status: status,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $ConflictsProcessedTableManager = ProcessedTableManager<
    _$JournalDb,
    Conflicts,
    Conflict,
    $ConflictsFilterComposer,
    $ConflictsOrderingComposer,
    $ConflictsAnnotationComposer,
    $ConflictsCreateCompanionBuilder,
    $ConflictsUpdateCompanionBuilder,
    (Conflict, BaseReferences<_$JournalDb, Conflicts, Conflict>),
    Conflict,
    PrefetchHooks Function()>;
typedef $MeasurableTypesCreateCompanionBuilder = MeasurableTypesCompanion
    Function({
  required String id,
  required String uniqueName,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<bool> deleted,
  Value<bool> private,
  required String serialized,
  Value<int> version,
  required int status,
  Value<int> rowid,
});
typedef $MeasurableTypesUpdateCompanionBuilder = MeasurableTypesCompanion
    Function({
  Value<String> id,
  Value<String> uniqueName,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> private,
  Value<String> serialized,
  Value<int> version,
  Value<int> status,
  Value<int> rowid,
});

class $MeasurableTypesFilterComposer
    extends Composer<_$JournalDb, MeasurableTypes> {
  $MeasurableTypesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uniqueName => $composableBuilder(
      column: $table.uniqueName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get private => $composableBuilder(
      column: $table.private, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));
}

class $MeasurableTypesOrderingComposer
    extends Composer<_$JournalDb, MeasurableTypes> {
  $MeasurableTypesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uniqueName => $composableBuilder(
      column: $table.uniqueName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get private => $composableBuilder(
      column: $table.private, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));
}

class $MeasurableTypesAnnotationComposer
    extends Composer<_$JournalDb, MeasurableTypes> {
  $MeasurableTypesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uniqueName => $composableBuilder(
      column: $table.uniqueName, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get private =>
      $composableBuilder(column: $table.private, builder: (column) => column);

  GeneratedColumn<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $MeasurableTypesTableManager extends RootTableManager<
    _$JournalDb,
    MeasurableTypes,
    MeasurableDbEntity,
    $MeasurableTypesFilterComposer,
    $MeasurableTypesOrderingComposer,
    $MeasurableTypesAnnotationComposer,
    $MeasurableTypesCreateCompanionBuilder,
    $MeasurableTypesUpdateCompanionBuilder,
    (
      MeasurableDbEntity,
      BaseReferences<_$JournalDb, MeasurableTypes, MeasurableDbEntity>
    ),
    MeasurableDbEntity,
    PrefetchHooks Function()> {
  $MeasurableTypesTableManager(_$JournalDb db, MeasurableTypes table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MeasurableTypesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MeasurableTypesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MeasurableTypesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> uniqueName = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> private = const Value.absent(),
            Value<String> serialized = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<int> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MeasurableTypesCompanion(
            id: id,
            uniqueName: uniqueName,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deleted: deleted,
            private: private,
            serialized: serialized,
            version: version,
            status: status,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String uniqueName,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> private = const Value.absent(),
            required String serialized,
            Value<int> version = const Value.absent(),
            required int status,
            Value<int> rowid = const Value.absent(),
          }) =>
              MeasurableTypesCompanion.insert(
            id: id,
            uniqueName: uniqueName,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deleted: deleted,
            private: private,
            serialized: serialized,
            version: version,
            status: status,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $MeasurableTypesProcessedTableManager = ProcessedTableManager<
    _$JournalDb,
    MeasurableTypes,
    MeasurableDbEntity,
    $MeasurableTypesFilterComposer,
    $MeasurableTypesOrderingComposer,
    $MeasurableTypesAnnotationComposer,
    $MeasurableTypesCreateCompanionBuilder,
    $MeasurableTypesUpdateCompanionBuilder,
    (
      MeasurableDbEntity,
      BaseReferences<_$JournalDb, MeasurableTypes, MeasurableDbEntity>
    ),
    MeasurableDbEntity,
    PrefetchHooks Function()>;
typedef $HabitDefinitionsCreateCompanionBuilder = HabitDefinitionsCompanion
    Function({
  required String id,
  required String name,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<bool> deleted,
  Value<bool> private,
  required String serialized,
  required bool active,
  Value<int> rowid,
});
typedef $HabitDefinitionsUpdateCompanionBuilder = HabitDefinitionsCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> private,
  Value<String> serialized,
  Value<bool> active,
  Value<int> rowid,
});

class $HabitDefinitionsFilterComposer
    extends Composer<_$JournalDb, HabitDefinitions> {
  $HabitDefinitionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get private => $composableBuilder(
      column: $table.private, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnFilters(column));
}

class $HabitDefinitionsOrderingComposer
    extends Composer<_$JournalDb, HabitDefinitions> {
  $HabitDefinitionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get private => $composableBuilder(
      column: $table.private, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnOrderings(column));
}

class $HabitDefinitionsAnnotationComposer
    extends Composer<_$JournalDb, HabitDefinitions> {
  $HabitDefinitionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get private =>
      $composableBuilder(column: $table.private, builder: (column) => column);

  GeneratedColumn<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);
}

class $HabitDefinitionsTableManager extends RootTableManager<
    _$JournalDb,
    HabitDefinitions,
    HabitDefinitionDbEntity,
    $HabitDefinitionsFilterComposer,
    $HabitDefinitionsOrderingComposer,
    $HabitDefinitionsAnnotationComposer,
    $HabitDefinitionsCreateCompanionBuilder,
    $HabitDefinitionsUpdateCompanionBuilder,
    (
      HabitDefinitionDbEntity,
      BaseReferences<_$JournalDb, HabitDefinitions, HabitDefinitionDbEntity>
    ),
    HabitDefinitionDbEntity,
    PrefetchHooks Function()> {
  $HabitDefinitionsTableManager(_$JournalDb db, HabitDefinitions table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $HabitDefinitionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $HabitDefinitionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $HabitDefinitionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> private = const Value.absent(),
            Value<String> serialized = const Value.absent(),
            Value<bool> active = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HabitDefinitionsCompanion(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deleted: deleted,
            private: private,
            serialized: serialized,
            active: active,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> private = const Value.absent(),
            required String serialized,
            required bool active,
            Value<int> rowid = const Value.absent(),
          }) =>
              HabitDefinitionsCompanion.insert(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deleted: deleted,
            private: private,
            serialized: serialized,
            active: active,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $HabitDefinitionsProcessedTableManager = ProcessedTableManager<
    _$JournalDb,
    HabitDefinitions,
    HabitDefinitionDbEntity,
    $HabitDefinitionsFilterComposer,
    $HabitDefinitionsOrderingComposer,
    $HabitDefinitionsAnnotationComposer,
    $HabitDefinitionsCreateCompanionBuilder,
    $HabitDefinitionsUpdateCompanionBuilder,
    (
      HabitDefinitionDbEntity,
      BaseReferences<_$JournalDb, HabitDefinitions, HabitDefinitionDbEntity>
    ),
    HabitDefinitionDbEntity,
    PrefetchHooks Function()>;
typedef $CategoryDefinitionsCreateCompanionBuilder
    = CategoryDefinitionsCompanion Function({
  required String id,
  required String name,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<bool> deleted,
  Value<bool> private,
  required String serialized,
  required bool active,
  Value<int> rowid,
});
typedef $CategoryDefinitionsUpdateCompanionBuilder
    = CategoryDefinitionsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> private,
  Value<String> serialized,
  Value<bool> active,
  Value<int> rowid,
});

class $CategoryDefinitionsFilterComposer
    extends Composer<_$JournalDb, CategoryDefinitions> {
  $CategoryDefinitionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get private => $composableBuilder(
      column: $table.private, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnFilters(column));
}

class $CategoryDefinitionsOrderingComposer
    extends Composer<_$JournalDb, CategoryDefinitions> {
  $CategoryDefinitionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get private => $composableBuilder(
      column: $table.private, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnOrderings(column));
}

class $CategoryDefinitionsAnnotationComposer
    extends Composer<_$JournalDb, CategoryDefinitions> {
  $CategoryDefinitionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get private =>
      $composableBuilder(column: $table.private, builder: (column) => column);

  GeneratedColumn<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);
}

class $CategoryDefinitionsTableManager extends RootTableManager<
    _$JournalDb,
    CategoryDefinitions,
    CategoryDefinitionDbEntity,
    $CategoryDefinitionsFilterComposer,
    $CategoryDefinitionsOrderingComposer,
    $CategoryDefinitionsAnnotationComposer,
    $CategoryDefinitionsCreateCompanionBuilder,
    $CategoryDefinitionsUpdateCompanionBuilder,
    (
      CategoryDefinitionDbEntity,
      BaseReferences<_$JournalDb, CategoryDefinitions,
          CategoryDefinitionDbEntity>
    ),
    CategoryDefinitionDbEntity,
    PrefetchHooks Function()> {
  $CategoryDefinitionsTableManager(_$JournalDb db, CategoryDefinitions table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $CategoryDefinitionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $CategoryDefinitionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $CategoryDefinitionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> private = const Value.absent(),
            Value<String> serialized = const Value.absent(),
            Value<bool> active = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoryDefinitionsCompanion(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deleted: deleted,
            private: private,
            serialized: serialized,
            active: active,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> private = const Value.absent(),
            required String serialized,
            required bool active,
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoryDefinitionsCompanion.insert(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deleted: deleted,
            private: private,
            serialized: serialized,
            active: active,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $CategoryDefinitionsProcessedTableManager = ProcessedTableManager<
    _$JournalDb,
    CategoryDefinitions,
    CategoryDefinitionDbEntity,
    $CategoryDefinitionsFilterComposer,
    $CategoryDefinitionsOrderingComposer,
    $CategoryDefinitionsAnnotationComposer,
    $CategoryDefinitionsCreateCompanionBuilder,
    $CategoryDefinitionsUpdateCompanionBuilder,
    (
      CategoryDefinitionDbEntity,
      BaseReferences<_$JournalDb, CategoryDefinitions,
          CategoryDefinitionDbEntity>
    ),
    CategoryDefinitionDbEntity,
    PrefetchHooks Function()>;
typedef $DashboardDefinitionsCreateCompanionBuilder
    = DashboardDefinitionsCompanion Function({
  required String id,
  required String name,
  required DateTime createdAt,
  required DateTime updatedAt,
  required DateTime lastReviewed,
  Value<bool> deleted,
  Value<bool> private,
  required String serialized,
  required bool active,
  Value<int> rowid,
});
typedef $DashboardDefinitionsUpdateCompanionBuilder
    = DashboardDefinitionsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime> lastReviewed,
  Value<bool> deleted,
  Value<bool> private,
  Value<String> serialized,
  Value<bool> active,
  Value<int> rowid,
});

class $DashboardDefinitionsFilterComposer
    extends Composer<_$JournalDb, DashboardDefinitions> {
  $DashboardDefinitionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastReviewed => $composableBuilder(
      column: $table.lastReviewed, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get private => $composableBuilder(
      column: $table.private, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnFilters(column));
}

class $DashboardDefinitionsOrderingComposer
    extends Composer<_$JournalDb, DashboardDefinitions> {
  $DashboardDefinitionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastReviewed => $composableBuilder(
      column: $table.lastReviewed,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get private => $composableBuilder(
      column: $table.private, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnOrderings(column));
}

class $DashboardDefinitionsAnnotationComposer
    extends Composer<_$JournalDb, DashboardDefinitions> {
  $DashboardDefinitionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReviewed => $composableBuilder(
      column: $table.lastReviewed, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get private =>
      $composableBuilder(column: $table.private, builder: (column) => column);

  GeneratedColumn<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);
}

class $DashboardDefinitionsTableManager extends RootTableManager<
    _$JournalDb,
    DashboardDefinitions,
    DashboardDefinitionDbEntity,
    $DashboardDefinitionsFilterComposer,
    $DashboardDefinitionsOrderingComposer,
    $DashboardDefinitionsAnnotationComposer,
    $DashboardDefinitionsCreateCompanionBuilder,
    $DashboardDefinitionsUpdateCompanionBuilder,
    (
      DashboardDefinitionDbEntity,
      BaseReferences<_$JournalDb, DashboardDefinitions,
          DashboardDefinitionDbEntity>
    ),
    DashboardDefinitionDbEntity,
    PrefetchHooks Function()> {
  $DashboardDefinitionsTableManager(_$JournalDb db, DashboardDefinitions table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DashboardDefinitionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DashboardDefinitionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DashboardDefinitionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime> lastReviewed = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> private = const Value.absent(),
            Value<String> serialized = const Value.absent(),
            Value<bool> active = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DashboardDefinitionsCompanion(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastReviewed: lastReviewed,
            deleted: deleted,
            private: private,
            serialized: serialized,
            active: active,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required DateTime createdAt,
            required DateTime updatedAt,
            required DateTime lastReviewed,
            Value<bool> deleted = const Value.absent(),
            Value<bool> private = const Value.absent(),
            required String serialized,
            required bool active,
            Value<int> rowid = const Value.absent(),
          }) =>
              DashboardDefinitionsCompanion.insert(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastReviewed: lastReviewed,
            deleted: deleted,
            private: private,
            serialized: serialized,
            active: active,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $DashboardDefinitionsProcessedTableManager = ProcessedTableManager<
    _$JournalDb,
    DashboardDefinitions,
    DashboardDefinitionDbEntity,
    $DashboardDefinitionsFilterComposer,
    $DashboardDefinitionsOrderingComposer,
    $DashboardDefinitionsAnnotationComposer,
    $DashboardDefinitionsCreateCompanionBuilder,
    $DashboardDefinitionsUpdateCompanionBuilder,
    (
      DashboardDefinitionDbEntity,
      BaseReferences<_$JournalDb, DashboardDefinitions,
          DashboardDefinitionDbEntity>
    ),
    DashboardDefinitionDbEntity,
    PrefetchHooks Function()>;
typedef $ConfigFlagsCreateCompanionBuilder = ConfigFlagsCompanion Function({
  required String name,
  required String description,
  Value<bool> status,
  Value<int> rowid,
});
typedef $ConfigFlagsUpdateCompanionBuilder = ConfigFlagsCompanion Function({
  Value<String> name,
  Value<String> description,
  Value<bool> status,
  Value<int> rowid,
});

class $ConfigFlagsFilterComposer extends Composer<_$JournalDb, ConfigFlags> {
  $ConfigFlagsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));
}

class $ConfigFlagsOrderingComposer extends Composer<_$JournalDb, ConfigFlags> {
  $ConfigFlagsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));
}

class $ConfigFlagsAnnotationComposer
    extends Composer<_$JournalDb, ConfigFlags> {
  $ConfigFlagsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<bool> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $ConfigFlagsTableManager extends RootTableManager<
    _$JournalDb,
    ConfigFlags,
    ConfigFlag,
    $ConfigFlagsFilterComposer,
    $ConfigFlagsOrderingComposer,
    $ConfigFlagsAnnotationComposer,
    $ConfigFlagsCreateCompanionBuilder,
    $ConfigFlagsUpdateCompanionBuilder,
    (ConfigFlag, BaseReferences<_$JournalDb, ConfigFlags, ConfigFlag>),
    ConfigFlag,
    PrefetchHooks Function()> {
  $ConfigFlagsTableManager(_$JournalDb db, ConfigFlags table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ConfigFlagsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ConfigFlagsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ConfigFlagsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> name = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<bool> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConfigFlagsCompanion(
            name: name,
            description: description,
            status: status,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String name,
            required String description,
            Value<bool> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConfigFlagsCompanion.insert(
            name: name,
            description: description,
            status: status,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $ConfigFlagsProcessedTableManager = ProcessedTableManager<
    _$JournalDb,
    ConfigFlags,
    ConfigFlag,
    $ConfigFlagsFilterComposer,
    $ConfigFlagsOrderingComposer,
    $ConfigFlagsAnnotationComposer,
    $ConfigFlagsCreateCompanionBuilder,
    $ConfigFlagsUpdateCompanionBuilder,
    (ConfigFlag, BaseReferences<_$JournalDb, ConfigFlags, ConfigFlag>),
    ConfigFlag,
    PrefetchHooks Function()>;
typedef $TagEntitiesCreateCompanionBuilder = TagEntitiesCompanion Function({
  required String id,
  required String tag,
  required String type,
  Value<bool?> inactive,
  Value<bool> private,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<bool?> deleted,
  required String serialized,
  Value<int> rowid,
});
typedef $TagEntitiesUpdateCompanionBuilder = TagEntitiesCompanion Function({
  Value<String> id,
  Value<String> tag,
  Value<String> type,
  Value<bool?> inactive,
  Value<bool> private,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool?> deleted,
  Value<String> serialized,
  Value<int> rowid,
});

class $TagEntitiesFilterComposer extends Composer<_$JournalDb, TagEntities> {
  $TagEntitiesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tag => $composableBuilder(
      column: $table.tag, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get inactive => $composableBuilder(
      column: $table.inactive, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get private => $composableBuilder(
      column: $table.private, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnFilters(column));
}

class $TagEntitiesOrderingComposer extends Composer<_$JournalDb, TagEntities> {
  $TagEntitiesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tag => $composableBuilder(
      column: $table.tag, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get inactive => $composableBuilder(
      column: $table.inactive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get private => $composableBuilder(
      column: $table.private, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnOrderings(column));
}

class $TagEntitiesAnnotationComposer
    extends Composer<_$JournalDb, TagEntities> {
  $TagEntitiesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<bool> get inactive =>
      $composableBuilder(column: $table.inactive, builder: (column) => column);

  GeneratedColumn<bool> get private =>
      $composableBuilder(column: $table.private, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => column);
}

class $TagEntitiesTableManager extends RootTableManager<
    _$JournalDb,
    TagEntities,
    TagDbEntity,
    $TagEntitiesFilterComposer,
    $TagEntitiesOrderingComposer,
    $TagEntitiesAnnotationComposer,
    $TagEntitiesCreateCompanionBuilder,
    $TagEntitiesUpdateCompanionBuilder,
    (TagDbEntity, BaseReferences<_$JournalDb, TagEntities, TagDbEntity>),
    TagDbEntity,
    PrefetchHooks Function()> {
  $TagEntitiesTableManager(_$JournalDb db, TagEntities table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $TagEntitiesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $TagEntitiesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $TagEntitiesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> tag = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<bool?> inactive = const Value.absent(),
            Value<bool> private = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool?> deleted = const Value.absent(),
            Value<String> serialized = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TagEntitiesCompanion(
            id: id,
            tag: tag,
            type: type,
            inactive: inactive,
            private: private,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deleted: deleted,
            serialized: serialized,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String tag,
            required String type,
            Value<bool?> inactive = const Value.absent(),
            Value<bool> private = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<bool?> deleted = const Value.absent(),
            required String serialized,
            Value<int> rowid = const Value.absent(),
          }) =>
              TagEntitiesCompanion.insert(
            id: id,
            tag: tag,
            type: type,
            inactive: inactive,
            private: private,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deleted: deleted,
            serialized: serialized,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $TagEntitiesProcessedTableManager = ProcessedTableManager<
    _$JournalDb,
    TagEntities,
    TagDbEntity,
    $TagEntitiesFilterComposer,
    $TagEntitiesOrderingComposer,
    $TagEntitiesAnnotationComposer,
    $TagEntitiesCreateCompanionBuilder,
    $TagEntitiesUpdateCompanionBuilder,
    (TagDbEntity, BaseReferences<_$JournalDb, TagEntities, TagDbEntity>),
    TagDbEntity,
    PrefetchHooks Function()>;
typedef $TaggedCreateCompanionBuilder = TaggedCompanion Function({
  required String id,
  required String journalId,
  required String tagEntityId,
  Value<int> rowid,
});
typedef $TaggedUpdateCompanionBuilder = TaggedCompanion Function({
  Value<String> id,
  Value<String> journalId,
  Value<String> tagEntityId,
  Value<int> rowid,
});

class $TaggedFilterComposer extends Composer<_$JournalDb, Tagged> {
  $TaggedFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get journalId => $composableBuilder(
      column: $table.journalId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagEntityId => $composableBuilder(
      column: $table.tagEntityId, builder: (column) => ColumnFilters(column));
}

class $TaggedOrderingComposer extends Composer<_$JournalDb, Tagged> {
  $TaggedOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get journalId => $composableBuilder(
      column: $table.journalId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagEntityId => $composableBuilder(
      column: $table.tagEntityId, builder: (column) => ColumnOrderings(column));
}

class $TaggedAnnotationComposer extends Composer<_$JournalDb, Tagged> {
  $TaggedAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get journalId =>
      $composableBuilder(column: $table.journalId, builder: (column) => column);

  GeneratedColumn<String> get tagEntityId => $composableBuilder(
      column: $table.tagEntityId, builder: (column) => column);
}

class $TaggedTableManager extends RootTableManager<
    _$JournalDb,
    Tagged,
    TaggedWith,
    $TaggedFilterComposer,
    $TaggedOrderingComposer,
    $TaggedAnnotationComposer,
    $TaggedCreateCompanionBuilder,
    $TaggedUpdateCompanionBuilder,
    (TaggedWith, BaseReferences<_$JournalDb, Tagged, TaggedWith>),
    TaggedWith,
    PrefetchHooks Function()> {
  $TaggedTableManager(_$JournalDb db, Tagged table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $TaggedFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $TaggedOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $TaggedAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> journalId = const Value.absent(),
            Value<String> tagEntityId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TaggedCompanion(
            id: id,
            journalId: journalId,
            tagEntityId: tagEntityId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String journalId,
            required String tagEntityId,
            Value<int> rowid = const Value.absent(),
          }) =>
              TaggedCompanion.insert(
            id: id,
            journalId: journalId,
            tagEntityId: tagEntityId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $TaggedProcessedTableManager = ProcessedTableManager<
    _$JournalDb,
    Tagged,
    TaggedWith,
    $TaggedFilterComposer,
    $TaggedOrderingComposer,
    $TaggedAnnotationComposer,
    $TaggedCreateCompanionBuilder,
    $TaggedUpdateCompanionBuilder,
    (TaggedWith, BaseReferences<_$JournalDb, Tagged, TaggedWith>),
    TaggedWith,
    PrefetchHooks Function()>;
typedef $LinkedEntriesCreateCompanionBuilder = LinkedEntriesCompanion Function({
  required String id,
  required String fromId,
  required String toId,
  required String type,
  required String serialized,
  Value<bool?> hidden,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});
typedef $LinkedEntriesUpdateCompanionBuilder = LinkedEntriesCompanion Function({
  Value<String> id,
  Value<String> fromId,
  Value<String> toId,
  Value<String> type,
  Value<String> serialized,
  Value<bool?> hidden,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});

class $LinkedEntriesFilterComposer
    extends Composer<_$JournalDb, LinkedEntries> {
  $LinkedEntriesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fromId => $composableBuilder(
      column: $table.fromId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toId => $composableBuilder(
      column: $table.toId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hidden => $composableBuilder(
      column: $table.hidden, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $LinkedEntriesOrderingComposer
    extends Composer<_$JournalDb, LinkedEntries> {
  $LinkedEntriesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fromId => $composableBuilder(
      column: $table.fromId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toId => $composableBuilder(
      column: $table.toId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hidden => $composableBuilder(
      column: $table.hidden, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $LinkedEntriesAnnotationComposer
    extends Composer<_$JournalDb, LinkedEntries> {
  $LinkedEntriesAnnotationComposer({
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

  GeneratedColumn<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $LinkedEntriesTableManager extends RootTableManager<
    _$JournalDb,
    LinkedEntries,
    LinkedDbEntry,
    $LinkedEntriesFilterComposer,
    $LinkedEntriesOrderingComposer,
    $LinkedEntriesAnnotationComposer,
    $LinkedEntriesCreateCompanionBuilder,
    $LinkedEntriesUpdateCompanionBuilder,
    (LinkedDbEntry, BaseReferences<_$JournalDb, LinkedEntries, LinkedDbEntry>),
    LinkedDbEntry,
    PrefetchHooks Function()> {
  $LinkedEntriesTableManager(_$JournalDb db, LinkedEntries table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $LinkedEntriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $LinkedEntriesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $LinkedEntriesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> fromId = const Value.absent(),
            Value<String> toId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> serialized = const Value.absent(),
            Value<bool?> hidden = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LinkedEntriesCompanion(
            id: id,
            fromId: fromId,
            toId: toId,
            type: type,
            serialized: serialized,
            hidden: hidden,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String fromId,
            required String toId,
            required String type,
            required String serialized,
            Value<bool?> hidden = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LinkedEntriesCompanion.insert(
            id: id,
            fromId: fromId,
            toId: toId,
            type: type,
            serialized: serialized,
            hidden: hidden,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $LinkedEntriesProcessedTableManager = ProcessedTableManager<
    _$JournalDb,
    LinkedEntries,
    LinkedDbEntry,
    $LinkedEntriesFilterComposer,
    $LinkedEntriesOrderingComposer,
    $LinkedEntriesAnnotationComposer,
    $LinkedEntriesCreateCompanionBuilder,
    $LinkedEntriesUpdateCompanionBuilder,
    (LinkedDbEntry, BaseReferences<_$JournalDb, LinkedEntries, LinkedDbEntry>),
    LinkedDbEntry,
    PrefetchHooks Function()>;

class $JournalDbManager {
  final _$JournalDb _db;
  $JournalDbManager(this._db);
  $JournalTableManager get journal => $JournalTableManager(_db, _db.journal);
  $ConflictsTableManager get conflicts =>
      $ConflictsTableManager(_db, _db.conflicts);
  $MeasurableTypesTableManager get measurableTypes =>
      $MeasurableTypesTableManager(_db, _db.measurableTypes);
  $HabitDefinitionsTableManager get habitDefinitions =>
      $HabitDefinitionsTableManager(_db, _db.habitDefinitions);
  $CategoryDefinitionsTableManager get categoryDefinitions =>
      $CategoryDefinitionsTableManager(_db, _db.categoryDefinitions);
  $DashboardDefinitionsTableManager get dashboardDefinitions =>
      $DashboardDefinitionsTableManager(_db, _db.dashboardDefinitions);
  $ConfigFlagsTableManager get configFlags =>
      $ConfigFlagsTableManager(_db, _db.configFlags);
  $TagEntitiesTableManager get tagEntities =>
      $TagEntitiesTableManager(_db, _db.tagEntities);
  $TaggedTableManager get tagged => $TaggedTableManager(_db, _db.tagged);
  $LinkedEntriesTableManager get linkedEntries =>
      $LinkedEntriesTableManager(_db, _db.linkedEntries);
}
