// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_db.dart';

// ignore_for_file: type=lint
class Settings extends Table with TableInfo<Settings, SettingsItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Settings(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _configKeyMeta =
      const VerificationMeta('configKey');
  late final GeneratedColumn<String> configKey = GeneratedColumn<String>(
      'config_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL UNIQUE');
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns => [configKey, value, updatedAt];
  @override
  String get aliasedName => _alias ?? 'settings';
  @override
  String get actualTableName => 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<SettingsItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('config_key')) {
      context.handle(_configKeyMeta,
          configKey.isAcceptableOrUnknown(data['config_key']!, _configKeyMeta));
    } else if (isInserting) {
      context.missing(_configKeyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {configKey};
  @override
  SettingsItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsItem(
      configKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}config_key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  Settings createAlias(String alias) {
    return Settings(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(config_key)'];
  @override
  bool get dontWriteConstraints => true;
}

class SettingsItem extends DataClass implements Insertable<SettingsItem> {
  final String configKey;
  final String value;
  final DateTime updatedAt;
  const SettingsItem(
      {required this.configKey, required this.value, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['config_key'] = Variable<String>(configKey);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      configKey: Value(configKey),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory SettingsItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsItem(
      configKey: serializer.fromJson<String>(json['config_key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'config_key': serializer.toJson<String>(configKey),
      'value': serializer.toJson<String>(value),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SettingsItem copyWith(
          {String? configKey, String? value, DateTime? updatedAt}) =>
      SettingsItem(
        configKey: configKey ?? this.configKey,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  @override
  String toString() {
    return (StringBuffer('SettingsItem(')
          ..write('configKey: $configKey, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(configKey, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsItem &&
          other.configKey == this.configKey &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SettingsCompanion extends UpdateCompanion<SettingsItem> {
  final Value<String> configKey;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SettingsCompanion({
    this.configKey = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String configKey,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : configKey = Value(configKey),
        value = Value(value),
        updatedAt = Value(updatedAt);
  static Insertable<SettingsItem> custom({
    Expression<String>? configKey,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (configKey != null) 'config_key': configKey,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? configKey,
      Value<String>? value,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SettingsCompanion(
      configKey: configKey ?? this.configKey,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (configKey.present) {
      map['config_key'] = Variable<String>(configKey.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
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
    return (StringBuffer('SettingsCompanion(')
          ..write('configKey: $configKey, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SettingsDb extends GeneratedDatabase {
  _$SettingsDb(QueryExecutor e) : super(e);
  _$SettingsDb.connect(DatabaseConnection c) : super.connect(c);
  late final Settings settings = Settings(this);
  Selectable<SettingsItem> settingsItemByKey(String configKey) {
    return customSelect('SELECT * FROM settings WHERE config_key = ?1',
        variables: [
          Variable<String>(configKey)
        ],
        readsFrom: {
          settings,
        }).asyncMap(settings.mapFromRow);
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [settings];
}
