// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fts5_db.dart';

// ignore_for_file: type=lint
class JournalFts extends Table
    with
        TableInfo<JournalFts, JournalFt>,
        VirtualTableInfo<JournalFts, JournalFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  JournalFts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _plainTextMeta =
      const VerificationMeta('plainText');
  late final GeneratedColumn<String> plainText = GeneratedColumn<String>(
      'plain_text', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: '');
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: '');
  static const VerificationMeta _summaryMeta =
      const VerificationMeta('summary');
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
      'summary', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: '');
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: '');
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: '');
  @override
  List<GeneratedColumn> get $columns => [plainText, title, summary, tags, uuid];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_fts';
  @override
  VerificationContext validateIntegrity(Insertable<JournalFt> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('plain_text')) {
      context.handle(_plainTextMeta,
          plainText.isAcceptableOrUnknown(data['plain_text']!, _plainTextMeta));
    } else if (isInserting) {
      context.missing(_plainTextMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(_summaryMeta,
          summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta));
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    } else if (isInserting) {
      context.missing(_tagsMeta);
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  JournalFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalFt(
      plainText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plain_text'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      summary: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}summary'])!,
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
    );
  }

  @override
  JournalFts createAlias(String alias) {
    return JournalFts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs => 'fts5(plain_text, title, summary, tags, uuid)';
}

class JournalFt extends DataClass implements Insertable<JournalFt> {
  final String plainText;
  final String title;
  final String summary;
  final String tags;
  final String uuid;
  const JournalFt(
      {required this.plainText,
      required this.title,
      required this.summary,
      required this.tags,
      required this.uuid});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['plain_text'] = Variable<String>(plainText);
    map['title'] = Variable<String>(title);
    map['summary'] = Variable<String>(summary);
    map['tags'] = Variable<String>(tags);
    map['uuid'] = Variable<String>(uuid);
    return map;
  }

  JournalFtsCompanion toCompanion(bool nullToAbsent) {
    return JournalFtsCompanion(
      plainText: Value(plainText),
      title: Value(title),
      summary: Value(summary),
      tags: Value(tags),
      uuid: Value(uuid),
    );
  }

  factory JournalFt.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalFt(
      plainText: serializer.fromJson<String>(json['plain_text']),
      title: serializer.fromJson<String>(json['title']),
      summary: serializer.fromJson<String>(json['summary']),
      tags: serializer.fromJson<String>(json['tags']),
      uuid: serializer.fromJson<String>(json['uuid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'plain_text': serializer.toJson<String>(plainText),
      'title': serializer.toJson<String>(title),
      'summary': serializer.toJson<String>(summary),
      'tags': serializer.toJson<String>(tags),
      'uuid': serializer.toJson<String>(uuid),
    };
  }

  JournalFt copyWith(
          {String? plainText,
          String? title,
          String? summary,
          String? tags,
          String? uuid}) =>
      JournalFt(
        plainText: plainText ?? this.plainText,
        title: title ?? this.title,
        summary: summary ?? this.summary,
        tags: tags ?? this.tags,
        uuid: uuid ?? this.uuid,
      );
  JournalFt copyWithCompanion(JournalFtsCompanion data) {
    return JournalFt(
      plainText: data.plainText.present ? data.plainText.value : this.plainText,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      tags: data.tags.present ? data.tags.value : this.tags,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalFt(')
          ..write('plainText: $plainText, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('tags: $tags, ')
          ..write('uuid: $uuid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(plainText, title, summary, tags, uuid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalFt &&
          other.plainText == this.plainText &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.tags == this.tags &&
          other.uuid == this.uuid);
}

class JournalFtsCompanion extends UpdateCompanion<JournalFt> {
  final Value<String> plainText;
  final Value<String> title;
  final Value<String> summary;
  final Value<String> tags;
  final Value<String> uuid;
  final Value<int> rowid;
  const JournalFtsCompanion({
    this.plainText = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.tags = const Value.absent(),
    this.uuid = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalFtsCompanion.insert({
    required String plainText,
    required String title,
    required String summary,
    required String tags,
    required String uuid,
    this.rowid = const Value.absent(),
  })  : plainText = Value(plainText),
        title = Value(title),
        summary = Value(summary),
        tags = Value(tags),
        uuid = Value(uuid);
  static Insertable<JournalFt> custom({
    Expression<String>? plainText,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? tags,
    Expression<String>? uuid,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (plainText != null) 'plain_text': plainText,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (tags != null) 'tags': tags,
      if (uuid != null) 'uuid': uuid,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalFtsCompanion copyWith(
      {Value<String>? plainText,
      Value<String>? title,
      Value<String>? summary,
      Value<String>? tags,
      Value<String>? uuid,
      Value<int>? rowid}) {
    return JournalFtsCompanion(
      plainText: plainText ?? this.plainText,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      uuid: uuid ?? this.uuid,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (plainText.present) {
      map['plain_text'] = Variable<String>(plainText.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalFtsCompanion(')
          ..write('plainText: $plainText, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('tags: $tags, ')
          ..write('uuid: $uuid, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$Fts5Db extends GeneratedDatabase {
  _$Fts5Db(QueryExecutor e) : super(e);
  _$Fts5Db.connect(DatabaseConnection c) : super.connect(c);
  $Fts5DbManager get managers => $Fts5DbManager(this);
  late final JournalFts journalFts = JournalFts(this);
  Future<int> insertJournalEntry(String plainText, String title, String summary,
      String tags, String uuid) {
    return customInsert(
      'INSERT INTO journal_fts (plain_text, title, summary, tags, uuid) VALUES (?1, ?2, ?3, ?4, ?5)',
      variables: [
        Variable<String>(plainText),
        Variable<String>(title),
        Variable<String>(summary),
        Variable<String>(tags),
        Variable<String>(uuid)
      ],
      updates: {journalFts},
    );
  }

  Selectable<String> findMatching(String query) {
    return customSelect(
        'SELECT uuid FROM journal_fts WHERE journal_fts MATCH ?1',
        variables: [
          Variable<String>(query)
        ],
        readsFrom: {
          journalFts,
        }).map((QueryRow row) => row.read<String>('uuid'));
  }

  Future<int> deleteEntry(String uuid) {
    return customUpdate(
      'DELETE FROM journal_fts WHERE journal_fts MATCH ?1',
      variables: [Variable<String>(uuid)],
      updates: {journalFts},
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [journalFts];
}

typedef $JournalFtsCreateCompanionBuilder = JournalFtsCompanion Function({
  required String plainText,
  required String title,
  required String summary,
  required String tags,
  required String uuid,
  Value<int> rowid,
});
typedef $JournalFtsUpdateCompanionBuilder = JournalFtsCompanion Function({
  Value<String> plainText,
  Value<String> title,
  Value<String> summary,
  Value<String> tags,
  Value<String> uuid,
  Value<int> rowid,
});

class $JournalFtsTableManager extends RootTableManager<
    _$Fts5Db,
    JournalFts,
    JournalFt,
    $JournalFtsFilterComposer,
    $JournalFtsOrderingComposer,
    $JournalFtsCreateCompanionBuilder,
    $JournalFtsUpdateCompanionBuilder> {
  $JournalFtsTableManager(_$Fts5Db db, JournalFts table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $JournalFtsFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $JournalFtsOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> plainText = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> summary = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JournalFtsCompanion(
            plainText: plainText,
            title: title,
            summary: summary,
            tags: tags,
            uuid: uuid,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String plainText,
            required String title,
            required String summary,
            required String tags,
            required String uuid,
            Value<int> rowid = const Value.absent(),
          }) =>
              JournalFtsCompanion.insert(
            plainText: plainText,
            title: title,
            summary: summary,
            tags: tags,
            uuid: uuid,
            rowid: rowid,
          ),
        ));
}

class $JournalFtsFilterComposer extends FilterComposer<_$Fts5Db, JournalFts> {
  $JournalFtsFilterComposer(super.$state);
  ColumnFilters<String> get plainText => $state.composableBuilder(
      column: $state.table.plainText,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get summary => $state.composableBuilder(
      column: $state.table.summary,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get tags => $state.composableBuilder(
      column: $state.table.tags,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get uuid => $state.composableBuilder(
      column: $state.table.uuid,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $JournalFtsOrderingComposer
    extends OrderingComposer<_$Fts5Db, JournalFts> {
  $JournalFtsOrderingComposer(super.$state);
  ColumnOrderings<String> get plainText => $state.composableBuilder(
      column: $state.table.plainText,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get summary => $state.composableBuilder(
      column: $state.table.summary,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get tags => $state.composableBuilder(
      column: $state.table.tags,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get uuid => $state.composableBuilder(
      column: $state.table.uuid,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $Fts5DbManager {
  final _$Fts5Db _db;
  $Fts5DbManager(this._db);
  $JournalFtsTableManager get journalFts =>
      $JournalFtsTableManager(_db, _db.journalFts);
}
