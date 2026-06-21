// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_metrics_db.dart';

// ignore_for_file: type=lint
class OnboardingEvents extends Table
    with TableInfo<OnboardingEvents, OnboardingEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  OnboardingEvents(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _eventNameMeta = const VerificationMeta(
    'eventName',
  );
  late final GeneratedColumn<String> eventName = GeneratedColumn<String>(
    'event_name',
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
  static const VerificationMeta _dayBucketMeta = const VerificationMeta(
    'dayBucket',
  );
  late final GeneratedColumn<int> dayBucket = GeneratedColumn<int>(
    'day_bucket',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _valueBucketMeta = const VerificationMeta(
    'valueBucket',
  );
  late final GeneratedColumn<int> valueBucket = GeneratedColumn<int>(
    'value_bucket',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventName,
    createdAt,
    dayBucket,
    platform,
    provider,
    reason,
    valueBucket,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'onboarding_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<OnboardingEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_name')) {
      context.handle(
        _eventNameMeta,
        eventName.isAcceptableOrUnknown(data['event_name']!, _eventNameMeta),
      );
    } else if (isInserting) {
      context.missing(_eventNameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('day_bucket')) {
      context.handle(
        _dayBucketMeta,
        dayBucket.isAcceptableOrUnknown(data['day_bucket']!, _dayBucketMeta),
      );
    } else if (isInserting) {
      context.missing(_dayBucketMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('value_bucket')) {
      context.handle(
        _valueBucketMeta,
        valueBucket.isAcceptableOrUnknown(
          data['value_bucket']!,
          _valueBucketMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OnboardingEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OnboardingEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      dayBucket: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_bucket'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      ),
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      ),
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      valueBucket: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value_bucket'],
      ),
    );
  }

  @override
  OnboardingEvents createAlias(String alias) {
    return OnboardingEvents(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(id)'];
  @override
  bool get dontWriteConstraints => true;
}

class OnboardingEventRow extends DataClass
    implements Insertable<OnboardingEventRow> {
  final String id;
  final String eventName;
  final DateTime createdAt;

  /// Whole days since the Unix epoch in UTC; used for active-day grouping so
  /// the funnel does not depend on local-time wall clocks.
  final int dayBucket;

  /// Low-cardinality dimensions, all optional. Never free text from the user.
  final String? platform;
  final String? provider;
  final String? reason;

  /// A pre-bucketed numeric (e.g. duration bucket), never a raw measurement.
  final int? valueBucket;
  const OnboardingEventRow({
    required this.id,
    required this.eventName,
    required this.createdAt,
    required this.dayBucket,
    this.platform,
    this.provider,
    this.reason,
    this.valueBucket,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_name'] = Variable<String>(eventName);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['day_bucket'] = Variable<int>(dayBucket);
    if (!nullToAbsent || platform != null) {
      map['platform'] = Variable<String>(platform);
    }
    if (!nullToAbsent || provider != null) {
      map['provider'] = Variable<String>(provider);
    }
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    if (!nullToAbsent || valueBucket != null) {
      map['value_bucket'] = Variable<int>(valueBucket);
    }
    return map;
  }

  OnboardingEventsCompanion toCompanion(bool nullToAbsent) {
    return OnboardingEventsCompanion(
      id: Value(id),
      eventName: Value(eventName),
      createdAt: Value(createdAt),
      dayBucket: Value(dayBucket),
      platform: platform == null && nullToAbsent
          ? const Value.absent()
          : Value(platform),
      provider: provider == null && nullToAbsent
          ? const Value.absent()
          : Value(provider),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      valueBucket: valueBucket == null && nullToAbsent
          ? const Value.absent()
          : Value(valueBucket),
    );
  }

  factory OnboardingEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnboardingEventRow(
      id: serializer.fromJson<String>(json['id']),
      eventName: serializer.fromJson<String>(json['event_name']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      dayBucket: serializer.fromJson<int>(json['day_bucket']),
      platform: serializer.fromJson<String?>(json['platform']),
      provider: serializer.fromJson<String?>(json['provider']),
      reason: serializer.fromJson<String?>(json['reason']),
      valueBucket: serializer.fromJson<int?>(json['value_bucket']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'event_name': serializer.toJson<String>(eventName),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'day_bucket': serializer.toJson<int>(dayBucket),
      'platform': serializer.toJson<String?>(platform),
      'provider': serializer.toJson<String?>(provider),
      'reason': serializer.toJson<String?>(reason),
      'value_bucket': serializer.toJson<int?>(valueBucket),
    };
  }

  OnboardingEventRow copyWith({
    String? id,
    String? eventName,
    DateTime? createdAt,
    int? dayBucket,
    Value<String?> platform = const Value.absent(),
    Value<String?> provider = const Value.absent(),
    Value<String?> reason = const Value.absent(),
    Value<int?> valueBucket = const Value.absent(),
  }) => OnboardingEventRow(
    id: id ?? this.id,
    eventName: eventName ?? this.eventName,
    createdAt: createdAt ?? this.createdAt,
    dayBucket: dayBucket ?? this.dayBucket,
    platform: platform.present ? platform.value : this.platform,
    provider: provider.present ? provider.value : this.provider,
    reason: reason.present ? reason.value : this.reason,
    valueBucket: valueBucket.present ? valueBucket.value : this.valueBucket,
  );
  OnboardingEventRow copyWithCompanion(OnboardingEventsCompanion data) {
    return OnboardingEventRow(
      id: data.id.present ? data.id.value : this.id,
      eventName: data.eventName.present ? data.eventName.value : this.eventName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      dayBucket: data.dayBucket.present ? data.dayBucket.value : this.dayBucket,
      platform: data.platform.present ? data.platform.value : this.platform,
      provider: data.provider.present ? data.provider.value : this.provider,
      reason: data.reason.present ? data.reason.value : this.reason,
      valueBucket: data.valueBucket.present
          ? data.valueBucket.value
          : this.valueBucket,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingEventRow(')
          ..write('id: $id, ')
          ..write('eventName: $eventName, ')
          ..write('createdAt: $createdAt, ')
          ..write('dayBucket: $dayBucket, ')
          ..write('platform: $platform, ')
          ..write('provider: $provider, ')
          ..write('reason: $reason, ')
          ..write('valueBucket: $valueBucket')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventName,
    createdAt,
    dayBucket,
    platform,
    provider,
    reason,
    valueBucket,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnboardingEventRow &&
          other.id == this.id &&
          other.eventName == this.eventName &&
          other.createdAt == this.createdAt &&
          other.dayBucket == this.dayBucket &&
          other.platform == this.platform &&
          other.provider == this.provider &&
          other.reason == this.reason &&
          other.valueBucket == this.valueBucket);
}

class OnboardingEventsCompanion extends UpdateCompanion<OnboardingEventRow> {
  final Value<String> id;
  final Value<String> eventName;
  final Value<DateTime> createdAt;
  final Value<int> dayBucket;
  final Value<String?> platform;
  final Value<String?> provider;
  final Value<String?> reason;
  final Value<int?> valueBucket;
  final Value<int> rowid;
  const OnboardingEventsCompanion({
    this.id = const Value.absent(),
    this.eventName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.dayBucket = const Value.absent(),
    this.platform = const Value.absent(),
    this.provider = const Value.absent(),
    this.reason = const Value.absent(),
    this.valueBucket = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OnboardingEventsCompanion.insert({
    required String id,
    required String eventName,
    required DateTime createdAt,
    required int dayBucket,
    this.platform = const Value.absent(),
    this.provider = const Value.absent(),
    this.reason = const Value.absent(),
    this.valueBucket = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventName = Value(eventName),
       createdAt = Value(createdAt),
       dayBucket = Value(dayBucket);
  static Insertable<OnboardingEventRow> custom({
    Expression<String>? id,
    Expression<String>? eventName,
    Expression<DateTime>? createdAt,
    Expression<int>? dayBucket,
    Expression<String>? platform,
    Expression<String>? provider,
    Expression<String>? reason,
    Expression<int>? valueBucket,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventName != null) 'event_name': eventName,
      if (createdAt != null) 'created_at': createdAt,
      if (dayBucket != null) 'day_bucket': dayBucket,
      if (platform != null) 'platform': platform,
      if (provider != null) 'provider': provider,
      if (reason != null) 'reason': reason,
      if (valueBucket != null) 'value_bucket': valueBucket,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OnboardingEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? eventName,
    Value<DateTime>? createdAt,
    Value<int>? dayBucket,
    Value<String?>? platform,
    Value<String?>? provider,
    Value<String?>? reason,
    Value<int?>? valueBucket,
    Value<int>? rowid,
  }) {
    return OnboardingEventsCompanion(
      id: id ?? this.id,
      eventName: eventName ?? this.eventName,
      createdAt: createdAt ?? this.createdAt,
      dayBucket: dayBucket ?? this.dayBucket,
      platform: platform ?? this.platform,
      provider: provider ?? this.provider,
      reason: reason ?? this.reason,
      valueBucket: valueBucket ?? this.valueBucket,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventName.present) {
      map['event_name'] = Variable<String>(eventName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (dayBucket.present) {
      map['day_bucket'] = Variable<int>(dayBucket.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (valueBucket.present) {
      map['value_bucket'] = Variable<int>(valueBucket.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingEventsCompanion(')
          ..write('id: $id, ')
          ..write('eventName: $eventName, ')
          ..write('createdAt: $createdAt, ')
          ..write('dayBucket: $dayBucket, ')
          ..write('platform: $platform, ')
          ..write('provider: $provider, ')
          ..write('reason: $reason, ')
          ..write('valueBucket: $valueBucket, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$OnboardingMetricsDb extends GeneratedDatabase {
  _$OnboardingMetricsDb(QueryExecutor e) : super(e);
  _$OnboardingMetricsDb.connect(DatabaseConnection c) : super.connect(c);
  $OnboardingMetricsDbManager get managers => $OnboardingMetricsDbManager(this);
  late final OnboardingEvents onboardingEvents = OnboardingEvents(this);
  late final Index idxOnboardingEventsName = Index(
    'idx_onboarding_events_name',
    'CREATE INDEX idx_onboarding_events_name ON onboarding_events (event_name)',
  );
  late final Index idxOnboardingEventsDay = Index(
    'idx_onboarding_events_day',
    'CREATE INDEX idx_onboarding_events_day ON onboarding_events (day_bucket)',
  );
  Selectable<OnboardingEventRow> allOnboardingEvents() {
    return customSelect(
      'SELECT * FROM onboarding_events ORDER BY created_at ASC, id ASC',
      variables: [],
      readsFrom: {onboardingEvents},
    ).asyncMap(onboardingEvents.mapFromRow);
  }

  Selectable<CountOnboardingEventsByNameResult> countOnboardingEventsByName() {
    return customSelect(
      'SELECT event_name, COUNT(*) AS cnt FROM onboarding_events GROUP BY event_name',
      variables: [],
      readsFrom: {onboardingEvents},
    ).map(
      (QueryRow row) => CountOnboardingEventsByNameResult(
        eventName: row.read<String>('event_name'),
        cnt: row.read<int>('cnt'),
      ),
    );
  }

  Selectable<DateTime?> firstOnboardingEventTime(String eventName) {
    return customSelect(
      'SELECT MIN(created_at) AS ts FROM onboarding_events WHERE event_name = ?1',
      variables: [Variable<String>(eventName)],
      readsFrom: {onboardingEvents},
    ).map((QueryRow row) => row.readNullable<DateTime>('ts'));
  }

  Selectable<int> distinctActiveDayBuckets() {
    return customSelect(
      'SELECT DISTINCT day_bucket FROM onboarding_events ORDER BY day_bucket ASC',
      variables: [],
      readsFrom: {onboardingEvents},
    ).map((QueryRow row) => row.read<int>('day_bucket'));
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    onboardingEvents,
    idxOnboardingEventsName,
    idxOnboardingEventsDay,
  ];
}

typedef $OnboardingEventsCreateCompanionBuilder =
    OnboardingEventsCompanion Function({
      required String id,
      required String eventName,
      required DateTime createdAt,
      required int dayBucket,
      Value<String?> platform,
      Value<String?> provider,
      Value<String?> reason,
      Value<int?> valueBucket,
      Value<int> rowid,
    });
typedef $OnboardingEventsUpdateCompanionBuilder =
    OnboardingEventsCompanion Function({
      Value<String> id,
      Value<String> eventName,
      Value<DateTime> createdAt,
      Value<int> dayBucket,
      Value<String?> platform,
      Value<String?> provider,
      Value<String?> reason,
      Value<int?> valueBucket,
      Value<int> rowid,
    });

class $OnboardingEventsFilterComposer
    extends Composer<_$OnboardingMetricsDb, OnboardingEvents> {
  $OnboardingEventsFilterComposer({
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

  ColumnFilters<String> get eventName => $composableBuilder(
    column: $table.eventName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayBucket => $composableBuilder(
    column: $table.dayBucket,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get valueBucket => $composableBuilder(
    column: $table.valueBucket,
    builder: (column) => ColumnFilters(column),
  );
}

class $OnboardingEventsOrderingComposer
    extends Composer<_$OnboardingMetricsDb, OnboardingEvents> {
  $OnboardingEventsOrderingComposer({
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

  ColumnOrderings<String> get eventName => $composableBuilder(
    column: $table.eventName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayBucket => $composableBuilder(
    column: $table.dayBucket,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get valueBucket => $composableBuilder(
    column: $table.valueBucket,
    builder: (column) => ColumnOrderings(column),
  );
}

class $OnboardingEventsAnnotationComposer
    extends Composer<_$OnboardingMetricsDb, OnboardingEvents> {
  $OnboardingEventsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventName =>
      $composableBuilder(column: $table.eventName, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get dayBucket =>
      $composableBuilder(column: $table.dayBucket, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<int> get valueBucket => $composableBuilder(
    column: $table.valueBucket,
    builder: (column) => column,
  );
}

class $OnboardingEventsTableManager
    extends
        RootTableManager<
          _$OnboardingMetricsDb,
          OnboardingEvents,
          OnboardingEventRow,
          $OnboardingEventsFilterComposer,
          $OnboardingEventsOrderingComposer,
          $OnboardingEventsAnnotationComposer,
          $OnboardingEventsCreateCompanionBuilder,
          $OnboardingEventsUpdateCompanionBuilder,
          (
            OnboardingEventRow,
            BaseReferences<
              _$OnboardingMetricsDb,
              OnboardingEvents,
              OnboardingEventRow
            >,
          ),
          OnboardingEventRow,
          PrefetchHooks Function()
        > {
  $OnboardingEventsTableManager(
    _$OnboardingMetricsDb db,
    OnboardingEvents table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $OnboardingEventsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $OnboardingEventsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $OnboardingEventsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> dayBucket = const Value.absent(),
                Value<String?> platform = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<int?> valueBucket = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OnboardingEventsCompanion(
                id: id,
                eventName: eventName,
                createdAt: createdAt,
                dayBucket: dayBucket,
                platform: platform,
                provider: provider,
                reason: reason,
                valueBucket: valueBucket,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventName,
                required DateTime createdAt,
                required int dayBucket,
                Value<String?> platform = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<int?> valueBucket = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OnboardingEventsCompanion.insert(
                id: id,
                eventName: eventName,
                createdAt: createdAt,
                dayBucket: dayBucket,
                platform: platform,
                provider: provider,
                reason: reason,
                valueBucket: valueBucket,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $OnboardingEventsProcessedTableManager =
    ProcessedTableManager<
      _$OnboardingMetricsDb,
      OnboardingEvents,
      OnboardingEventRow,
      $OnboardingEventsFilterComposer,
      $OnboardingEventsOrderingComposer,
      $OnboardingEventsAnnotationComposer,
      $OnboardingEventsCreateCompanionBuilder,
      $OnboardingEventsUpdateCompanionBuilder,
      (
        OnboardingEventRow,
        BaseReferences<
          _$OnboardingMetricsDb,
          OnboardingEvents,
          OnboardingEventRow
        >,
      ),
      OnboardingEventRow,
      PrefetchHooks Function()
    >;

class $OnboardingMetricsDbManager {
  final _$OnboardingMetricsDb _db;
  $OnboardingMetricsDbManager(this._db);
  $OnboardingEventsTableManager get onboardingEvents =>
      $OnboardingEventsTableManager(_db, _db.onboardingEvents);
}

class CountOnboardingEventsByNameResult {
  final String eventName;
  final int cnt;
  CountOnboardingEventsByNameResult({
    required this.eventName,
    required this.cnt,
  });
}
