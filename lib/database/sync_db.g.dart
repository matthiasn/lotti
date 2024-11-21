// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_db.dart';

// ignore_for_file: type=lint
class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: Constant(DateTime.now()));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: Constant(DateTime.now()));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: Constant(OutboxStatus.pending.index));
  static const VerificationMeta _retriesMeta =
      const VerificationMeta('retries');
  @override
  late final GeneratedColumn<int> retries = GeneratedColumn<int>(
      'retries', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _messageMeta =
      const VerificationMeta('message');
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
      'message', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subjectMeta =
      const VerificationMeta('subject');
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
      'subject', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, createdAt, updatedAt, status, retries, message, subject, filePath];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('retries')) {
      context.handle(_retriesMeta,
          retries.isAcceptableOrUnknown(data['retries']!, _retriesMeta));
    }
    if (data.containsKey('message')) {
      context.handle(_messageMeta,
          message.isAcceptableOrUnknown(data['message']!, _messageMeta));
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(_subjectMeta,
          subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta));
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
      retries: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retries'])!,
      message: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message'])!,
      subject: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path']),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxItem extends DataClass implements Insertable<OutboxItem> {
  final int id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int status;
  final int retries;
  final String message;
  final String subject;
  final String? filePath;
  const OutboxItem(
      {required this.id,
      required this.createdAt,
      required this.updatedAt,
      required this.status,
      required this.retries,
      required this.message,
      required this.subject,
      this.filePath});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['status'] = Variable<int>(status);
    map['retries'] = Variable<int>(retries);
    map['message'] = Variable<String>(message);
    map['subject'] = Variable<String>(subject);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      status: Value(status),
      retries: Value(retries),
      message: Value(message),
      subject: Value(subject),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
    );
  }

  factory OutboxItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxItem(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      status: serializer.fromJson<int>(json['status']),
      retries: serializer.fromJson<int>(json['retries']),
      message: serializer.fromJson<String>(json['message']),
      subject: serializer.fromJson<String>(json['subject']),
      filePath: serializer.fromJson<String?>(json['filePath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'status': serializer.toJson<int>(status),
      'retries': serializer.toJson<int>(retries),
      'message': serializer.toJson<String>(message),
      'subject': serializer.toJson<String>(subject),
      'filePath': serializer.toJson<String?>(filePath),
    };
  }

  OutboxItem copyWith(
          {int? id,
          DateTime? createdAt,
          DateTime? updatedAt,
          int? status,
          int? retries,
          String? message,
          String? subject,
          Value<String?> filePath = const Value.absent()}) =>
      OutboxItem(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        status: status ?? this.status,
        retries: retries ?? this.retries,
        message: message ?? this.message,
        subject: subject ?? this.subject,
        filePath: filePath.present ? filePath.value : this.filePath,
      );
  OutboxItem copyWithCompanion(OutboxCompanion data) {
    return OutboxItem(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      retries: data.retries.present ? data.retries.value : this.retries,
      message: data.message.present ? data.message.value : this.message,
      subject: data.subject.present ? data.subject.value : this.subject,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxItem(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('retries: $retries, ')
          ..write('message: $message, ')
          ..write('subject: $subject, ')
          ..write('filePath: $filePath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, createdAt, updatedAt, status, retries, message, subject, filePath);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxItem &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.retries == this.retries &&
          other.message == this.message &&
          other.subject == this.subject &&
          other.filePath == this.filePath);
}

class OutboxCompanion extends UpdateCompanion<OutboxItem> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> status;
  final Value<int> retries;
  final Value<String> message;
  final Value<String> subject;
  final Value<String?> filePath;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.retries = const Value.absent(),
    this.message = const Value.absent(),
    this.subject = const Value.absent(),
    this.filePath = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.retries = const Value.absent(),
    required String message,
    required String subject,
    this.filePath = const Value.absent(),
  })  : message = Value(message),
        subject = Value(subject);
  static Insertable<OutboxItem> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? status,
    Expression<int>? retries,
    Expression<String>? message,
    Expression<String>? subject,
    Expression<String>? filePath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (retries != null) 'retries': retries,
      if (message != null) 'message': message,
      if (subject != null) 'subject': subject,
      if (filePath != null) 'file_path': filePath,
    });
  }

  OutboxCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? status,
      Value<int>? retries,
      Value<String>? message,
      Value<String>? subject,
      Value<String?>? filePath}) {
    return OutboxCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      retries: retries ?? this.retries,
      message: message ?? this.message,
      subject: subject ?? this.subject,
      filePath: filePath ?? this.filePath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (retries.present) {
      map['retries'] = Variable<int>(retries.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('retries: $retries, ')
          ..write('message: $message, ')
          ..write('subject: $subject, ')
          ..write('filePath: $filePath')
          ..write(')'))
        .toString();
  }
}

abstract class _$SyncDatabase extends GeneratedDatabase {
  _$SyncDatabase(QueryExecutor e) : super(e);
  _$SyncDatabase.connect(DatabaseConnection c) : super.connect(c);
  $SyncDatabaseManager get managers => $SyncDatabaseManager(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [outbox];
}

typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> status,
  Value<int> retries,
  required String message,
  required String subject,
  Value<String?> filePath,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> status,
  Value<int> retries,
  Value<String> message,
  Value<String> subject,
  Value<String?> filePath,
});

class $$OutboxTableFilterComposer
    extends Composer<_$SyncDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retries => $composableBuilder(
      column: $table.retries, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get message => $composableBuilder(
      column: $table.message, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));
}

class $$OutboxTableOrderingComposer
    extends Composer<_$SyncDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retries => $composableBuilder(
      column: $table.retries, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get message => $composableBuilder(
      column: $table.message, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$SyncDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retries =>
      $composableBuilder(column: $table.retries, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);
}

class $$OutboxTableTableManager extends RootTableManager<
    _$SyncDatabase,
    $OutboxTable,
    OutboxItem,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxItem, BaseReferences<_$SyncDatabase, $OutboxTable, OutboxItem>),
    OutboxItem,
    PrefetchHooks Function()> {
  $$OutboxTableTableManager(_$SyncDatabase db, $OutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> status = const Value.absent(),
            Value<int> retries = const Value.absent(),
            Value<String> message = const Value.absent(),
            Value<String> subject = const Value.absent(),
            Value<String?> filePath = const Value.absent(),
          }) =>
              OutboxCompanion(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            status: status,
            retries: retries,
            message: message,
            subject: subject,
            filePath: filePath,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> status = const Value.absent(),
            Value<int> retries = const Value.absent(),
            required String message,
            required String subject,
            Value<String?> filePath = const Value.absent(),
          }) =>
              OutboxCompanion.insert(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            status: status,
            retries: retries,
            message: message,
            subject: subject,
            filePath: filePath,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxTableProcessedTableManager = ProcessedTableManager<
    _$SyncDatabase,
    $OutboxTable,
    OutboxItem,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxItem, BaseReferences<_$SyncDatabase, $OutboxTable, OutboxItem>),
    OutboxItem,
    PrefetchHooks Function()>;

class $SyncDatabaseManager {
  final _$SyncDatabase _db;
  $SyncDatabaseManager(this._db);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
}
