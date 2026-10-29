// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fts5_db.dart';

// ignore_for_file: type=lint
class SearchDoc extends Table with TableInfo<SearchDoc, SearchDocRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SearchDoc(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
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
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _privateMeta = const VerificationMeta(
    'private',
  );
  late final GeneratedColumn<bool> private = GeneratedColumn<bool>(
    'private',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT FALSE',
    defaultValue: const CustomExpression('FALSE'),
  );
  static const VerificationMeta _dateFromMeta = const VerificationMeta(
    'dateFrom',
  );
  late final GeneratedColumn<int> dateFrom = GeneratedColumn<int>(
    'date_from',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityId,
    type,
    categoryId,
    private,
    dateFrom,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_doc';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchDocRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('private')) {
      context.handle(
        _privateMeta,
        private.isAcceptableOrUnknown(data['private']!, _privateMeta),
      );
    }
    if (data.containsKey('date_from')) {
      context.handle(
        _dateFromMeta,
        dateFrom.isAcceptableOrUnknown(data['date_from']!, _dateFromMeta),
      );
    } else if (isInserting) {
      context.missing(_dateFromMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchDocRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchDocRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      private: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}private'],
      )!,
      dateFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date_from'],
      )!,
    );
  }

  @override
  SearchDoc createAlias(String alias) {
    return SearchDoc(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SearchDocRow extends DataClass implements Insertable<SearchDocRow> {
  final int id;
  final String entityId;
  final String type;
  final String categoryId;
  final bool private;
  final int dateFrom;
  const SearchDocRow({
    required this.id,
    required this.entityId,
    required this.type,
    required this.categoryId,
    required this.private,
    required this.dateFrom,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_id'] = Variable<String>(entityId);
    map['type'] = Variable<String>(type);
    map['category_id'] = Variable<String>(categoryId);
    map['private'] = Variable<bool>(private);
    map['date_from'] = Variable<int>(dateFrom);
    return map;
  }

  SearchDocCompanion toCompanion(bool nullToAbsent) {
    return SearchDocCompanion(
      id: Value(id),
      entityId: Value(entityId),
      type: Value(type),
      categoryId: Value(categoryId),
      private: Value(private),
      dateFrom: Value(dateFrom),
    );
  }

  factory SearchDocRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchDocRow(
      id: serializer.fromJson<int>(json['id']),
      entityId: serializer.fromJson<String>(json['entity_id']),
      type: serializer.fromJson<String>(json['type']),
      categoryId: serializer.fromJson<String>(json['category_id']),
      private: serializer.fromJson<bool>(json['private']),
      dateFrom: serializer.fromJson<int>(json['date_from']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entity_id': serializer.toJson<String>(entityId),
      'type': serializer.toJson<String>(type),
      'category_id': serializer.toJson<String>(categoryId),
      'private': serializer.toJson<bool>(private),
      'date_from': serializer.toJson<int>(dateFrom),
    };
  }

  SearchDocRow copyWith({
    int? id,
    String? entityId,
    String? type,
    String? categoryId,
    bool? private,
    int? dateFrom,
  }) => SearchDocRow(
    id: id ?? this.id,
    entityId: entityId ?? this.entityId,
    type: type ?? this.type,
    categoryId: categoryId ?? this.categoryId,
    private: private ?? this.private,
    dateFrom: dateFrom ?? this.dateFrom,
  );
  SearchDocRow copyWithCompanion(SearchDocCompanion data) {
    return SearchDocRow(
      id: data.id.present ? data.id.value : this.id,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      type: data.type.present ? data.type.value : this.type,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      private: data.private.present ? data.private.value : this.private,
      dateFrom: data.dateFrom.present ? data.dateFrom.value : this.dateFrom,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchDocRow(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('type: $type, ')
          ..write('categoryId: $categoryId, ')
          ..write('private: $private, ')
          ..write('dateFrom: $dateFrom')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, entityId, type, categoryId, private, dateFrom);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchDocRow &&
          other.id == this.id &&
          other.entityId == this.entityId &&
          other.type == this.type &&
          other.categoryId == this.categoryId &&
          other.private == this.private &&
          other.dateFrom == this.dateFrom);
}

class SearchDocCompanion extends UpdateCompanion<SearchDocRow> {
  final Value<int> id;
  final Value<String> entityId;
  final Value<String> type;
  final Value<String> categoryId;
  final Value<bool> private;
  final Value<int> dateFrom;
  const SearchDocCompanion({
    this.id = const Value.absent(),
    this.entityId = const Value.absent(),
    this.type = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.private = const Value.absent(),
    this.dateFrom = const Value.absent(),
  });
  SearchDocCompanion.insert({
    this.id = const Value.absent(),
    required String entityId,
    required String type,
    this.categoryId = const Value.absent(),
    this.private = const Value.absent(),
    required int dateFrom,
  }) : entityId = Value(entityId),
       type = Value(type),
       dateFrom = Value(dateFrom);
  static Insertable<SearchDocRow> custom({
    Expression<int>? id,
    Expression<String>? entityId,
    Expression<String>? type,
    Expression<String>? categoryId,
    Expression<bool>? private,
    Expression<int>? dateFrom,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityId != null) 'entity_id': entityId,
      if (type != null) 'type': type,
      if (categoryId != null) 'category_id': categoryId,
      if (private != null) 'private': private,
      if (dateFrom != null) 'date_from': dateFrom,
    });
  }

  SearchDocCompanion copyWith({
    Value<int>? id,
    Value<String>? entityId,
    Value<String>? type,
    Value<String>? categoryId,
    Value<bool>? private,
    Value<int>? dateFrom,
  }) {
    return SearchDocCompanion(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      private: private ?? this.private,
      dateFrom: dateFrom ?? this.dateFrom,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (private.present) {
      map['private'] = Variable<bool>(private.value);
    }
    if (dateFrom.present) {
      map['date_from'] = Variable<int>(dateFrom.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchDocCompanion(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('type: $type, ')
          ..write('categoryId: $categoryId, ')
          ..write('private: $private, ')
          ..write('dateFrom: $dateFrom')
          ..write(')'))
        .toString();
  }
}

class SearchFts extends Table
    with TableInfo<SearchFts, SearchFt>, VirtualTableInfo<SearchFts, SearchFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SearchFts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _extraMeta = const VerificationMeta('extra');
  late final GeneratedColumn<String> extra = GeneratedColumn<String>(
    'extra',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [title, body, extra];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('extra')) {
      context.handle(
        _extraMeta,
        extra.isAcceptableOrUnknown(data['extra']!, _extraMeta),
      );
    } else if (isInserting) {
      context.missing(_extraMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  SearchFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchFt(
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      extra: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra'],
      )!,
    );
  }

  @override
  SearchFts createAlias(String alias) {
    return SearchFts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(title, body, extra, tokenize = \'unicode61 remove_diacritics 2\', prefix = \'2 3\')';
}

class SearchFt extends DataClass implements Insertable<SearchFt> {
  final String title;
  final String body;
  final String extra;
  const SearchFt({
    required this.title,
    required this.body,
    required this.extra,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['extra'] = Variable<String>(extra);
    return map;
  }

  SearchFtsCompanion toCompanion(bool nullToAbsent) {
    return SearchFtsCompanion(
      title: Value(title),
      body: Value(body),
      extra: Value(extra),
    );
  }

  factory SearchFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchFt(
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      extra: serializer.fromJson<String>(json['extra']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'extra': serializer.toJson<String>(extra),
    };
  }

  SearchFt copyWith({String? title, String? body, String? extra}) => SearchFt(
    title: title ?? this.title,
    body: body ?? this.body,
    extra: extra ?? this.extra,
  );
  SearchFt copyWithCompanion(SearchFtsCompanion data) {
    return SearchFt(
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      extra: data.extra.present ? data.extra.value : this.extra,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchFt(')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('extra: $extra')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(title, body, extra);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchFt &&
          other.title == this.title &&
          other.body == this.body &&
          other.extra == this.extra);
}

class SearchFtsCompanion extends UpdateCompanion<SearchFt> {
  final Value<String> title;
  final Value<String> body;
  final Value<String> extra;
  final Value<int> rowid;
  const SearchFtsCompanion({
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.extra = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchFtsCompanion.insert({
    required String title,
    required String body,
    required String extra,
    this.rowid = const Value.absent(),
  }) : title = Value(title),
       body = Value(body),
       extra = Value(extra);
  static Insertable<SearchFt> custom({
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? extra,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (extra != null) 'extra': extra,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchFtsCompanion copyWith({
    Value<String>? title,
    Value<String>? body,
    Value<String>? extra,
    Value<int>? rowid,
  }) {
    return SearchFtsCompanion(
      title: title ?? this.title,
      body: body ?? this.body,
      extra: extra ?? this.extra,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (extra.present) {
      map['extra'] = Variable<String>(extra.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchFtsCompanion(')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('extra: $extra, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SearchIndexState extends Table
    with TableInfo<SearchIndexState, SearchIndexStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SearchIndexState(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _intValueMeta = const VerificationMeta(
    'intValue',
  );
  late final GeneratedColumn<int> intValue = GeneratedColumn<int>(
    'int_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [name, intValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_index_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchIndexStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('int_value')) {
      context.handle(
        _intValueMeta,
        intValue.isAcceptableOrUnknown(data['int_value']!, _intValueMeta),
      );
    } else if (isInserting) {
      context.missing(_intValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  SearchIndexStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchIndexStateData(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      intValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}int_value'],
      )!,
    );
  }

  @override
  SearchIndexState createAlias(String alias) {
    return SearchIndexState(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SearchIndexStateData extends DataClass
    implements Insertable<SearchIndexStateData> {
  final String name;
  final int intValue;
  const SearchIndexStateData({required this.name, required this.intValue});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['int_value'] = Variable<int>(intValue);
    return map;
  }

  SearchIndexStateCompanion toCompanion(bool nullToAbsent) {
    return SearchIndexStateCompanion(
      name: Value(name),
      intValue: Value(intValue),
    );
  }

  factory SearchIndexStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchIndexStateData(
      name: serializer.fromJson<String>(json['name']),
      intValue: serializer.fromJson<int>(json['int_value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'int_value': serializer.toJson<int>(intValue),
    };
  }

  SearchIndexStateData copyWith({String? name, int? intValue}) =>
      SearchIndexStateData(
        name: name ?? this.name,
        intValue: intValue ?? this.intValue,
      );
  SearchIndexStateData copyWithCompanion(SearchIndexStateCompanion data) {
    return SearchIndexStateData(
      name: data.name.present ? data.name.value : this.name,
      intValue: data.intValue.present ? data.intValue.value : this.intValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchIndexStateData(')
          ..write('name: $name, ')
          ..write('intValue: $intValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, intValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchIndexStateData &&
          other.name == this.name &&
          other.intValue == this.intValue);
}

class SearchIndexStateCompanion extends UpdateCompanion<SearchIndexStateData> {
  final Value<String> name;
  final Value<int> intValue;
  final Value<int> rowid;
  const SearchIndexStateCompanion({
    this.name = const Value.absent(),
    this.intValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchIndexStateCompanion.insert({
    required String name,
    required int intValue,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       intValue = Value(intValue);
  static Insertable<SearchIndexStateData> custom({
    Expression<String>? name,
    Expression<int>? intValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (intValue != null) 'int_value': intValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchIndexStateCompanion copyWith({
    Value<String>? name,
    Value<int>? intValue,
    Value<int>? rowid,
  }) {
    return SearchIndexStateCompanion(
      name: name ?? this.name,
      intValue: intValue ?? this.intValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (intValue.present) {
      map['int_value'] = Variable<int>(intValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchIndexStateCompanion(')
          ..write('name: $name, ')
          ..write('intValue: $intValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$Fts5Db extends GeneratedDatabase {
  _$Fts5Db(QueryExecutor e) : super(e);
  _$Fts5Db.connect(DatabaseConnection c) : super.connect(c);
  $Fts5DbManager get managers => $Fts5DbManager(this);
  late final SearchDoc searchDoc = SearchDoc(this);
  late final Index idxSearchDocTypeCategory = Index(
    'idx_search_doc_type_category',
    'CREATE INDEX idx_search_doc_type_category ON search_doc (type, category_id)',
  );
  late final SearchFts searchFts = SearchFts(this);
  late final SearchIndexState searchIndexState = SearchIndexState(this);
  Selectable<SearchDocRow> searchDocByEntityId(String entityId) {
    return customSelect(
      'SELECT * FROM search_doc WHERE entity_id = ?1',
      variables: [Variable<String>(entityId)],
      readsFrom: {searchDoc},
    ).asyncMap(searchDoc.mapFromRow);
  }

  Future<int> deleteSearchText(int rowId) {
    return customUpdate(
      'DELETE FROM search_fts WHERE "rowid" = ?1',
      variables: [Variable<int>(rowId)],
      updates: {searchFts},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> deleteSearchDoc(int rowId) {
    return customUpdate(
      'DELETE FROM search_doc WHERE id = ?1',
      variables: [Variable<int>(rowId)],
      updates: {searchDoc},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> insertSearchText(
    int rowId,
    String title,
    String body,
    String extra,
  ) {
    return customInsert(
      'INSERT INTO search_fts ("rowid", title, body, extra) VALUES (?1, ?2, ?3, ?4)',
      variables: [
        Variable<int>(rowId),
        Variable<String>(title),
        Variable<String>(body),
        Variable<String>(extra),
      ],
      updates: {searchFts},
    );
  }

  Selectable<int> indexStateValue(String name) {
    return customSelect(
      'SELECT int_value FROM search_index_state WHERE name = ?1',
      variables: [Variable<String>(name)],
      readsFrom: {searchIndexState},
    ).map((QueryRow row) => row.read<int>('int_value'));
  }

  Future<int> setIndexStateValue(String name, int intValue) {
    return customInsert(
      'INSERT OR REPLACE INTO search_index_state (name, int_value) VALUES (?1, ?2)',
      variables: [Variable<String>(name), Variable<int>(intValue)],
      updates: {searchIndexState},
    );
  }

  Future<int> clearIndexStateValue(String name) {
    return customUpdate(
      'DELETE FROM search_index_state WHERE name = ?1',
      variables: [Variable<String>(name)],
      updates: {searchIndexState},
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    searchDoc,
    idxSearchDocTypeCategory,
    searchFts,
    searchIndexState,
  ];
}

typedef $SearchDocCreateCompanionBuilder =
    SearchDocCompanion Function({
      Value<int> id,
      required String entityId,
      required String type,
      Value<String> categoryId,
      Value<bool> private,
      required int dateFrom,
    });
typedef $SearchDocUpdateCompanionBuilder =
    SearchDocCompanion Function({
      Value<int> id,
      Value<String> entityId,
      Value<String> type,
      Value<String> categoryId,
      Value<bool> private,
      Value<int> dateFrom,
    });

class $SearchDocFilterComposer extends Composer<_$Fts5Db, SearchDoc> {
  $SearchDocFilterComposer({
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

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get private => $composableBuilder(
    column: $table.private,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dateFrom => $composableBuilder(
    column: $table.dateFrom,
    builder: (column) => ColumnFilters(column),
  );
}

class $SearchDocOrderingComposer extends Composer<_$Fts5Db, SearchDoc> {
  $SearchDocOrderingComposer({
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

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get private => $composableBuilder(
    column: $table.private,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dateFrom => $composableBuilder(
    column: $table.dateFrom,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SearchDocAnnotationComposer extends Composer<_$Fts5Db, SearchDoc> {
  $SearchDocAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get private =>
      $composableBuilder(column: $table.private, builder: (column) => column);

  GeneratedColumn<int> get dateFrom =>
      $composableBuilder(column: $table.dateFrom, builder: (column) => column);
}

class $SearchDocTableManager
    extends
        RootTableManager<
          _$Fts5Db,
          SearchDoc,
          SearchDocRow,
          $SearchDocFilterComposer,
          $SearchDocOrderingComposer,
          $SearchDocAnnotationComposer,
          $SearchDocCreateCompanionBuilder,
          $SearchDocUpdateCompanionBuilder,
          (SearchDocRow, BaseReferences<_$Fts5Db, SearchDoc, SearchDocRow>),
          SearchDocRow,
          PrefetchHooks Function()
        > {
  $SearchDocTableManager(_$Fts5Db db, SearchDoc table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SearchDocFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SearchDocOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SearchDocAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<bool> private = const Value.absent(),
                Value<int> dateFrom = const Value.absent(),
              }) => SearchDocCompanion(
                id: id,
                entityId: entityId,
                type: type,
                categoryId: categoryId,
                private: private,
                dateFrom: dateFrom,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityId,
                required String type,
                Value<String> categoryId = const Value.absent(),
                Value<bool> private = const Value.absent(),
                required int dateFrom,
              }) => SearchDocCompanion.insert(
                id: id,
                entityId: entityId,
                type: type,
                categoryId: categoryId,
                private: private,
                dateFrom: dateFrom,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SearchDocProcessedTableManager =
    ProcessedTableManager<
      _$Fts5Db,
      SearchDoc,
      SearchDocRow,
      $SearchDocFilterComposer,
      $SearchDocOrderingComposer,
      $SearchDocAnnotationComposer,
      $SearchDocCreateCompanionBuilder,
      $SearchDocUpdateCompanionBuilder,
      (SearchDocRow, BaseReferences<_$Fts5Db, SearchDoc, SearchDocRow>),
      SearchDocRow,
      PrefetchHooks Function()
    >;
typedef $SearchFtsCreateCompanionBuilder =
    SearchFtsCompanion Function({
      required String title,
      required String body,
      required String extra,
      Value<int> rowid,
    });
typedef $SearchFtsUpdateCompanionBuilder =
    SearchFtsCompanion Function({
      Value<String> title,
      Value<String> body,
      Value<String> extra,
      Value<int> rowid,
    });

class $SearchFtsFilterComposer extends Composer<_$Fts5Db, SearchFts> {
  $SearchFtsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnFilters(column),
  );
}

class $SearchFtsOrderingComposer extends Composer<_$Fts5Db, SearchFts> {
  $SearchFtsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SearchFtsAnnotationComposer extends Composer<_$Fts5Db, SearchFts> {
  $SearchFtsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get extra =>
      $composableBuilder(column: $table.extra, builder: (column) => column);
}

class $SearchFtsTableManager
    extends
        RootTableManager<
          _$Fts5Db,
          SearchFts,
          SearchFt,
          $SearchFtsFilterComposer,
          $SearchFtsOrderingComposer,
          $SearchFtsAnnotationComposer,
          $SearchFtsCreateCompanionBuilder,
          $SearchFtsUpdateCompanionBuilder,
          (SearchFt, BaseReferences<_$Fts5Db, SearchFts, SearchFt>),
          SearchFt,
          PrefetchHooks Function()
        > {
  $SearchFtsTableManager(_$Fts5Db db, SearchFts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SearchFtsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SearchFtsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SearchFtsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> extra = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchFtsCompanion(
                title: title,
                body: body,
                extra: extra,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String title,
                required String body,
                required String extra,
                Value<int> rowid = const Value.absent(),
              }) => SearchFtsCompanion.insert(
                title: title,
                body: body,
                extra: extra,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SearchFtsProcessedTableManager =
    ProcessedTableManager<
      _$Fts5Db,
      SearchFts,
      SearchFt,
      $SearchFtsFilterComposer,
      $SearchFtsOrderingComposer,
      $SearchFtsAnnotationComposer,
      $SearchFtsCreateCompanionBuilder,
      $SearchFtsUpdateCompanionBuilder,
      (SearchFt, BaseReferences<_$Fts5Db, SearchFts, SearchFt>),
      SearchFt,
      PrefetchHooks Function()
    >;
typedef $SearchIndexStateCreateCompanionBuilder =
    SearchIndexStateCompanion Function({
      required String name,
      required int intValue,
      Value<int> rowid,
    });
typedef $SearchIndexStateUpdateCompanionBuilder =
    SearchIndexStateCompanion Function({
      Value<String> name,
      Value<int> intValue,
      Value<int> rowid,
    });

class $SearchIndexStateFilterComposer
    extends Composer<_$Fts5Db, SearchIndexState> {
  $SearchIndexStateFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intValue => $composableBuilder(
    column: $table.intValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $SearchIndexStateOrderingComposer
    extends Composer<_$Fts5Db, SearchIndexState> {
  $SearchIndexStateOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intValue => $composableBuilder(
    column: $table.intValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SearchIndexStateAnnotationComposer
    extends Composer<_$Fts5Db, SearchIndexState> {
  $SearchIndexStateAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get intValue =>
      $composableBuilder(column: $table.intValue, builder: (column) => column);
}

class $SearchIndexStateTableManager
    extends
        RootTableManager<
          _$Fts5Db,
          SearchIndexState,
          SearchIndexStateData,
          $SearchIndexStateFilterComposer,
          $SearchIndexStateOrderingComposer,
          $SearchIndexStateAnnotationComposer,
          $SearchIndexStateCreateCompanionBuilder,
          $SearchIndexStateUpdateCompanionBuilder,
          (
            SearchIndexStateData,
            BaseReferences<_$Fts5Db, SearchIndexState, SearchIndexStateData>,
          ),
          SearchIndexStateData,
          PrefetchHooks Function()
        > {
  $SearchIndexStateTableManager(_$Fts5Db db, SearchIndexState table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SearchIndexStateFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SearchIndexStateOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SearchIndexStateAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> name = const Value.absent(),
                Value<int> intValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchIndexStateCompanion(
                name: name,
                intValue: intValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String name,
                required int intValue,
                Value<int> rowid = const Value.absent(),
              }) => SearchIndexStateCompanion.insert(
                name: name,
                intValue: intValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SearchIndexStateProcessedTableManager =
    ProcessedTableManager<
      _$Fts5Db,
      SearchIndexState,
      SearchIndexStateData,
      $SearchIndexStateFilterComposer,
      $SearchIndexStateOrderingComposer,
      $SearchIndexStateAnnotationComposer,
      $SearchIndexStateCreateCompanionBuilder,
      $SearchIndexStateUpdateCompanionBuilder,
      (
        SearchIndexStateData,
        BaseReferences<_$Fts5Db, SearchIndexState, SearchIndexStateData>,
      ),
      SearchIndexStateData,
      PrefetchHooks Function()
    >;

class $Fts5DbManager {
  final _$Fts5Db _db;
  $Fts5DbManager(this._db);
  $SearchDocTableManager get searchDoc =>
      $SearchDocTableManager(_db, _db.searchDoc);
  $SearchFtsTableManager get searchFts =>
      $SearchFtsTableManager(_db, _db.searchFts);
  $SearchIndexStateTableManager get searchIndexState =>
      $SearchIndexStateTableManager(_db, _db.searchIndexState);
}
