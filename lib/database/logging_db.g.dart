// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logging_db.dart';

// ignore_for_file: type=lint
class LogEntries extends Table with TableInfo<LogEntries, LogEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LogEntries(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _domainMeta = const VerificationMeta('domain');
  late final GeneratedColumn<String> domain = GeneratedColumn<String>(
      'domain', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _subDomainMeta =
      const VerificationMeta('subDomain');
  late final GeneratedColumn<String> subDomain = GeneratedColumn<String>(
      'sub_domain', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
      'level', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _messageMeta =
      const VerificationMeta('message');
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
      'message', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _stacktraceMeta =
      const VerificationMeta('stacktrace');
  late final GeneratedColumn<String> stacktrace = GeneratedColumn<String>(
      'stacktrace', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
      'data', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  @override
  List<GeneratedColumn> get $columns => [
        id,
        createdAt,
        domain,
        subDomain,
        type,
        level,
        message,
        stacktrace,
        data
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'log_entries';
  @override
  VerificationContext validateIntegrity(Insertable<LogEntry> instance,
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
    if (data.containsKey('domain')) {
      context.handle(_domainMeta,
          domain.isAcceptableOrUnknown(data['domain']!, _domainMeta));
    } else if (isInserting) {
      context.missing(_domainMeta);
    }
    if (data.containsKey('sub_domain')) {
      context.handle(_subDomainMeta,
          subDomain.isAcceptableOrUnknown(data['sub_domain']!, _subDomainMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
          _levelMeta, level.isAcceptableOrUnknown(data['level']!, _levelMeta));
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('message')) {
      context.handle(_messageMeta,
          message.isAcceptableOrUnknown(data['message']!, _messageMeta));
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('stacktrace')) {
      context.handle(
          _stacktraceMeta,
          stacktrace.isAcceptableOrUnknown(
              data['stacktrace']!, _stacktraceMeta));
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LogEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LogEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
      domain: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}domain'])!,
      subDomain: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sub_domain']),
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      level: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}level'])!,
      message: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message'])!,
      stacktrace: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stacktrace']),
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data']),
    );
  }

  @override
  LogEntries createAlias(String alias) {
    return LogEntries(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(id)'];
  @override
  bool get dontWriteConstraints => true;
}

class LogEntry extends DataClass implements Insertable<LogEntry> {
  final String id;
  final String createdAt;
  final String domain;
  final String? subDomain;
  final String type;
  final String level;
  final String message;
  final String? stacktrace;
  final String? data;
  const LogEntry(
      {required this.id,
      required this.createdAt,
      required this.domain,
      this.subDomain,
      required this.type,
      required this.level,
      required this.message,
      this.stacktrace,
      this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<String>(createdAt);
    map['domain'] = Variable<String>(domain);
    if (!nullToAbsent || subDomain != null) {
      map['sub_domain'] = Variable<String>(subDomain);
    }
    map['type'] = Variable<String>(type);
    map['level'] = Variable<String>(level);
    map['message'] = Variable<String>(message);
    if (!nullToAbsent || stacktrace != null) {
      map['stacktrace'] = Variable<String>(stacktrace);
    }
    if (!nullToAbsent || data != null) {
      map['data'] = Variable<String>(data);
    }
    return map;
  }

  LogEntriesCompanion toCompanion(bool nullToAbsent) {
    return LogEntriesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      domain: Value(domain),
      subDomain: subDomain == null && nullToAbsent
          ? const Value.absent()
          : Value(subDomain),
      type: Value(type),
      level: Value(level),
      message: Value(message),
      stacktrace: stacktrace == null && nullToAbsent
          ? const Value.absent()
          : Value(stacktrace),
      data: data == null && nullToAbsent ? const Value.absent() : Value(data),
    );
  }

  factory LogEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LogEntry(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<String>(json['created_at']),
      domain: serializer.fromJson<String>(json['domain']),
      subDomain: serializer.fromJson<String?>(json['sub_domain']),
      type: serializer.fromJson<String>(json['type']),
      level: serializer.fromJson<String>(json['level']),
      message: serializer.fromJson<String>(json['message']),
      stacktrace: serializer.fromJson<String?>(json['stacktrace']),
      data: serializer.fromJson<String?>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'created_at': serializer.toJson<String>(createdAt),
      'domain': serializer.toJson<String>(domain),
      'sub_domain': serializer.toJson<String?>(subDomain),
      'type': serializer.toJson<String>(type),
      'level': serializer.toJson<String>(level),
      'message': serializer.toJson<String>(message),
      'stacktrace': serializer.toJson<String?>(stacktrace),
      'data': serializer.toJson<String?>(data),
    };
  }

  LogEntry copyWith(
          {String? id,
          String? createdAt,
          String? domain,
          Value<String?> subDomain = const Value.absent(),
          String? type,
          String? level,
          String? message,
          Value<String?> stacktrace = const Value.absent(),
          Value<String?> data = const Value.absent()}) =>
      LogEntry(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        domain: domain ?? this.domain,
        subDomain: subDomain.present ? subDomain.value : this.subDomain,
        type: type ?? this.type,
        level: level ?? this.level,
        message: message ?? this.message,
        stacktrace: stacktrace.present ? stacktrace.value : this.stacktrace,
        data: data.present ? data.value : this.data,
      );
  LogEntry copyWithCompanion(LogEntriesCompanion data) {
    return LogEntry(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      domain: data.domain.present ? data.domain.value : this.domain,
      subDomain: data.subDomain.present ? data.subDomain.value : this.subDomain,
      type: data.type.present ? data.type.value : this.type,
      level: data.level.present ? data.level.value : this.level,
      message: data.message.present ? data.message.value : this.message,
      stacktrace:
          data.stacktrace.present ? data.stacktrace.value : this.stacktrace,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LogEntry(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('domain: $domain, ')
          ..write('subDomain: $subDomain, ')
          ..write('type: $type, ')
          ..write('level: $level, ')
          ..write('message: $message, ')
          ..write('stacktrace: $stacktrace, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, createdAt, domain, subDomain, type, level, message, stacktrace, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LogEntry &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.domain == this.domain &&
          other.subDomain == this.subDomain &&
          other.type == this.type &&
          other.level == this.level &&
          other.message == this.message &&
          other.stacktrace == this.stacktrace &&
          other.data == this.data);
}

class LogEntriesCompanion extends UpdateCompanion<LogEntry> {
  final Value<String> id;
  final Value<String> createdAt;
  final Value<String> domain;
  final Value<String?> subDomain;
  final Value<String> type;
  final Value<String> level;
  final Value<String> message;
  final Value<String?> stacktrace;
  final Value<String?> data;
  final Value<int> rowid;
  const LogEntriesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.domain = const Value.absent(),
    this.subDomain = const Value.absent(),
    this.type = const Value.absent(),
    this.level = const Value.absent(),
    this.message = const Value.absent(),
    this.stacktrace = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LogEntriesCompanion.insert({
    required String id,
    required String createdAt,
    required String domain,
    this.subDomain = const Value.absent(),
    required String type,
    required String level,
    required String message,
    this.stacktrace = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdAt = Value(createdAt),
        domain = Value(domain),
        type = Value(type),
        level = Value(level),
        message = Value(message);
  static Insertable<LogEntry> custom({
    Expression<String>? id,
    Expression<String>? createdAt,
    Expression<String>? domain,
    Expression<String>? subDomain,
    Expression<String>? type,
    Expression<String>? level,
    Expression<String>? message,
    Expression<String>? stacktrace,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (domain != null) 'domain': domain,
      if (subDomain != null) 'sub_domain': subDomain,
      if (type != null) 'type': type,
      if (level != null) 'level': level,
      if (message != null) 'message': message,
      if (stacktrace != null) 'stacktrace': stacktrace,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LogEntriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? createdAt,
      Value<String>? domain,
      Value<String?>? subDomain,
      Value<String>? type,
      Value<String>? level,
      Value<String>? message,
      Value<String?>? stacktrace,
      Value<String?>? data,
      Value<int>? rowid}) {
    return LogEntriesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      domain: domain ?? this.domain,
      subDomain: subDomain ?? this.subDomain,
      type: type ?? this.type,
      level: level ?? this.level,
      message: message ?? this.message,
      stacktrace: stacktrace ?? this.stacktrace,
      data: data ?? this.data,
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
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (domain.present) {
      map['domain'] = Variable<String>(domain.value);
    }
    if (subDomain.present) {
      map['sub_domain'] = Variable<String>(subDomain.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (stacktrace.present) {
      map['stacktrace'] = Variable<String>(stacktrace.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('domain: $domain, ')
          ..write('subDomain: $subDomain, ')
          ..write('type: $type, ')
          ..write('level: $level, ')
          ..write('message: $message, ')
          ..write('stacktrace: $stacktrace, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LoggingDb extends GeneratedDatabase {
  _$LoggingDb(QueryExecutor e) : super(e);
  _$LoggingDb.connect(DatabaseConnection c) : super.connect(c);
  $LoggingDbManager get managers => $LoggingDbManager(this);
  late final LogEntries logEntries = LogEntries(this);
  late final Index logEntriesCreatedAt = Index('log_entries_created_at',
      'CREATE INDEX log_entries_created_at ON log_entries (created_at)');
  late final Index logEntriesLevel = Index('log_entries_level',
      'CREATE INDEX log_entries_level ON log_entries (level)');
  late final Index logEntriesDomain = Index('log_entries_domain',
      'CREATE INDEX log_entries_domain ON log_entries (domain)');
  late final Index logEntriesSubDomain = Index('log_entries_sub_domain',
      'CREATE INDEX log_entries_sub_domain ON log_entries (sub_domain)');
  Selectable<LogEntry> allLogEntries(int limit) {
    return customSelect(
        'SELECT * FROM log_entries ORDER BY created_at DESC LIMIT ?1',
        variables: [
          Variable<int>(limit)
        ],
        readsFrom: {
          logEntries,
        }).asyncMap(logEntries.mapFromRow);
  }

  Selectable<LogEntry> filteredByLevel(List<String> levels, int limit) {
    var $arrayStartIndex = 2;
    final expandedlevels = $expandVar($arrayStartIndex, levels.length);
    $arrayStartIndex += levels.length;
    return customSelect(
        'SELECT * FROM log_entries WHERE level IN ($expandedlevels) ORDER BY created_at DESC LIMIT ?1',
        variables: [
          Variable<int>(limit),
          for (var $ in levels) Variable<String>($)
        ],
        readsFrom: {
          logEntries,
        }).asyncMap(logEntries.mapFromRow);
  }

  Selectable<LogEntry> logEntryById(String id) {
    return customSelect('SELECT * FROM log_entries WHERE id = ?1', variables: [
      Variable<String>(id)
    ], readsFrom: {
      logEntries,
    }).asyncMap(logEntries.mapFromRow);
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        logEntries,
        logEntriesCreatedAt,
        logEntriesLevel,
        logEntriesDomain,
        logEntriesSubDomain
      ];
}

typedef $LogEntriesCreateCompanionBuilder = LogEntriesCompanion Function({
  required String id,
  required String createdAt,
  required String domain,
  Value<String?> subDomain,
  required String type,
  required String level,
  required String message,
  Value<String?> stacktrace,
  Value<String?> data,
  Value<int> rowid,
});
typedef $LogEntriesUpdateCompanionBuilder = LogEntriesCompanion Function({
  Value<String> id,
  Value<String> createdAt,
  Value<String> domain,
  Value<String?> subDomain,
  Value<String> type,
  Value<String> level,
  Value<String> message,
  Value<String?> stacktrace,
  Value<String?> data,
  Value<int> rowid,
});

class $LogEntriesTableManager extends RootTableManager<
    _$LoggingDb,
    LogEntries,
    LogEntry,
    $LogEntriesFilterComposer,
    $LogEntriesOrderingComposer,
    $LogEntriesCreateCompanionBuilder,
    $LogEntriesUpdateCompanionBuilder> {
  $LogEntriesTableManager(_$LoggingDb db, LogEntries table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $LogEntriesFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $LogEntriesOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<String> domain = const Value.absent(),
            Value<String?> subDomain = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> level = const Value.absent(),
            Value<String> message = const Value.absent(),
            Value<String?> stacktrace = const Value.absent(),
            Value<String?> data = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LogEntriesCompanion(
            id: id,
            createdAt: createdAt,
            domain: domain,
            subDomain: subDomain,
            type: type,
            level: level,
            message: message,
            stacktrace: stacktrace,
            data: data,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String createdAt,
            required String domain,
            Value<String?> subDomain = const Value.absent(),
            required String type,
            required String level,
            required String message,
            Value<String?> stacktrace = const Value.absent(),
            Value<String?> data = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LogEntriesCompanion.insert(
            id: id,
            createdAt: createdAt,
            domain: domain,
            subDomain: subDomain,
            type: type,
            level: level,
            message: message,
            stacktrace: stacktrace,
            data: data,
            rowid: rowid,
          ),
        ));
}

class $LogEntriesFilterComposer
    extends FilterComposer<_$LoggingDb, LogEntries> {
  $LogEntriesFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get domain => $state.composableBuilder(
      column: $state.table.domain,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get subDomain => $state.composableBuilder(
      column: $state.table.subDomain,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get type => $state.composableBuilder(
      column: $state.table.type,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get level => $state.composableBuilder(
      column: $state.table.level,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get message => $state.composableBuilder(
      column: $state.table.message,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get stacktrace => $state.composableBuilder(
      column: $state.table.stacktrace,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get data => $state.composableBuilder(
      column: $state.table.data,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $LogEntriesOrderingComposer
    extends OrderingComposer<_$LoggingDb, LogEntries> {
  $LogEntriesOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get domain => $state.composableBuilder(
      column: $state.table.domain,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get subDomain => $state.composableBuilder(
      column: $state.table.subDomain,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get type => $state.composableBuilder(
      column: $state.table.type,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get level => $state.composableBuilder(
      column: $state.table.level,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get message => $state.composableBuilder(
      column: $state.table.message,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get stacktrace => $state.composableBuilder(
      column: $state.table.stacktrace,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get data => $state.composableBuilder(
      column: $state.table.data,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $LoggingDbManager {
  final _$LoggingDb _db;
  $LoggingDbManager(this._db);
  $LogEntriesTableManager get logEntries =>
      $LogEntriesTableManager(_db, _db.logEntries);
}
