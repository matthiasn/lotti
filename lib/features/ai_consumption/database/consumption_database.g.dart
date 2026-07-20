// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consumption_database.dart';

// ignore_for_file: type=lint
class ConsumptionEvents extends Table
    with TableInfo<ConsumptionEvents, ConsumptionEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ConsumptionEvents(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
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
  static const VerificationMeta _attributionIdMeta = const VerificationMeta(
    'attributionId',
  );
  late final GeneratedColumn<String> attributionId = GeneratedColumn<String>(
    'attribution_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _wakeRunKeyMeta = const VerificationMeta(
    'wakeRunKey',
  );
  late final GeneratedColumn<String> wakeRunKey = GeneratedColumn<String>(
    'wake_run_key',
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
  static const VerificationMeta _turnIndexMeta = const VerificationMeta(
    'turnIndex',
  );
  late final GeneratedColumn<int> turnIndex = GeneratedColumn<int>(
    'turn_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _promptIdMeta = const VerificationMeta(
    'promptId',
  );
  late final GeneratedColumn<String> promptId = GeneratedColumn<String>(
    'prompt_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _skillIdMeta = const VerificationMeta(
    'skillId',
  );
  late final GeneratedColumn<String> skillId = GeneratedColumn<String>(
    'skill_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _configIdMeta = const VerificationMeta(
    'configId',
  );
  late final GeneratedColumn<String> configId = GeneratedColumn<String>(
    'config_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _providerTypeMeta = const VerificationMeta(
    'providerType',
  );
  late final GeneratedColumn<String> providerType = GeneratedColumn<String>(
    'provider_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _providerModelIdMeta = const VerificationMeta(
    'providerModelId',
  );
  late final GeneratedColumn<String> providerModelId = GeneratedColumn<String>(
    'provider_model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _responseTypeMeta = const VerificationMeta(
    'responseType',
  );
  late final GeneratedColumn<String> responseType = GeneratedColumn<String>(
    'response_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _inputTokensMeta = const VerificationMeta(
    'inputTokens',
  );
  late final GeneratedColumn<int> inputTokens = GeneratedColumn<int>(
    'input_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _outputTokensMeta = const VerificationMeta(
    'outputTokens',
  );
  late final GeneratedColumn<int> outputTokens = GeneratedColumn<int>(
    'output_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _cachedInputTokensMeta = const VerificationMeta(
    'cachedInputTokens',
  );
  late final GeneratedColumn<int> cachedInputTokens = GeneratedColumn<int>(
    'cached_input_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _thoughtsTokensMeta = const VerificationMeta(
    'thoughtsTokens',
  );
  late final GeneratedColumn<int> thoughtsTokens = GeneratedColumn<int>(
    'thoughts_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _totalTokensMeta = const VerificationMeta(
    'totalTokens',
  );
  late final GeneratedColumn<int> totalTokens = GeneratedColumn<int>(
    'total_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _creditsMeta = const VerificationMeta(
    'credits',
  );
  late final GeneratedColumn<double> credits = GeneratedColumn<double>(
    'credits',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _energyKwhMeta = const VerificationMeta(
    'energyKwh',
  );
  late final GeneratedColumn<double> energyKwh = GeneratedColumn<double>(
    'energy_kwh',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _carbonGCo2Meta = const VerificationMeta(
    'carbonGCo2',
  );
  late final GeneratedColumn<double> carbonGCo2 = GeneratedColumn<double>(
    'carbon_g_co2',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _waterLitersMeta = const VerificationMeta(
    'waterLiters',
  );
  late final GeneratedColumn<double> waterLiters = GeneratedColumn<double>(
    'water_liters',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _renewablePercentMeta = const VerificationMeta(
    'renewablePercent',
  );
  late final GeneratedColumn<double> renewablePercent = GeneratedColumn<double>(
    'renewable_percent',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _pueMeta = const VerificationMeta('pue');
  late final GeneratedColumn<double> pue = GeneratedColumn<double>(
    'pue',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dataCenterMeta = const VerificationMeta(
    'dataCenter',
  );
  late final GeneratedColumn<String> dataCenter = GeneratedColumn<String>(
    'data_center',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _upstreamProviderIdMeta =
      const VerificationMeta('upstreamProviderId');
  late final GeneratedColumn<String> upstreamProviderId =
      GeneratedColumn<String>(
        'upstream_provider_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
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
    parentId,
    createdAt,
    attributionId,
    taskId,
    categoryId,
    entryId,
    agentId,
    wakeRunKey,
    threadId,
    turnIndex,
    promptId,
    skillId,
    configId,
    providerType,
    modelId,
    providerModelId,
    responseType,
    durationMs,
    inputTokens,
    outputTokens,
    cachedInputTokens,
    thoughtsTokens,
    totalTokens,
    credits,
    energyKwh,
    carbonGCo2,
    waterLiters,
    renewablePercent,
    pue,
    dataCenter,
    upstreamProviderId,
    serialized,
    schemaVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'consumption_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConsumptionEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
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
    if (data.containsKey('attribution_id')) {
      context.handle(
        _attributionIdMeta,
        attributionId.isAcceptableOrUnknown(
          data['attribution_id']!,
          _attributionIdMeta,
        ),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    }
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    }
    if (data.containsKey('wake_run_key')) {
      context.handle(
        _wakeRunKeyMeta,
        wakeRunKey.isAcceptableOrUnknown(
          data['wake_run_key']!,
          _wakeRunKeyMeta,
        ),
      );
    }
    if (data.containsKey('thread_id')) {
      context.handle(
        _threadIdMeta,
        threadId.isAcceptableOrUnknown(data['thread_id']!, _threadIdMeta),
      );
    }
    if (data.containsKey('turn_index')) {
      context.handle(
        _turnIndexMeta,
        turnIndex.isAcceptableOrUnknown(data['turn_index']!, _turnIndexMeta),
      );
    }
    if (data.containsKey('prompt_id')) {
      context.handle(
        _promptIdMeta,
        promptId.isAcceptableOrUnknown(data['prompt_id']!, _promptIdMeta),
      );
    }
    if (data.containsKey('skill_id')) {
      context.handle(
        _skillIdMeta,
        skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta),
      );
    }
    if (data.containsKey('config_id')) {
      context.handle(
        _configIdMeta,
        configId.isAcceptableOrUnknown(data['config_id']!, _configIdMeta),
      );
    }
    if (data.containsKey('provider_type')) {
      context.handle(
        _providerTypeMeta,
        providerType.isAcceptableOrUnknown(
          data['provider_type']!,
          _providerTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerTypeMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    }
    if (data.containsKey('provider_model_id')) {
      context.handle(
        _providerModelIdMeta,
        providerModelId.isAcceptableOrUnknown(
          data['provider_model_id']!,
          _providerModelIdMeta,
        ),
      );
    }
    if (data.containsKey('response_type')) {
      context.handle(
        _responseTypeMeta,
        responseType.isAcceptableOrUnknown(
          data['response_type']!,
          _responseTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_responseTypeMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('input_tokens')) {
      context.handle(
        _inputTokensMeta,
        inputTokens.isAcceptableOrUnknown(
          data['input_tokens']!,
          _inputTokensMeta,
        ),
      );
    }
    if (data.containsKey('output_tokens')) {
      context.handle(
        _outputTokensMeta,
        outputTokens.isAcceptableOrUnknown(
          data['output_tokens']!,
          _outputTokensMeta,
        ),
      );
    }
    if (data.containsKey('cached_input_tokens')) {
      context.handle(
        _cachedInputTokensMeta,
        cachedInputTokens.isAcceptableOrUnknown(
          data['cached_input_tokens']!,
          _cachedInputTokensMeta,
        ),
      );
    }
    if (data.containsKey('thoughts_tokens')) {
      context.handle(
        _thoughtsTokensMeta,
        thoughtsTokens.isAcceptableOrUnknown(
          data['thoughts_tokens']!,
          _thoughtsTokensMeta,
        ),
      );
    }
    if (data.containsKey('total_tokens')) {
      context.handle(
        _totalTokensMeta,
        totalTokens.isAcceptableOrUnknown(
          data['total_tokens']!,
          _totalTokensMeta,
        ),
      );
    }
    if (data.containsKey('credits')) {
      context.handle(
        _creditsMeta,
        credits.isAcceptableOrUnknown(data['credits']!, _creditsMeta),
      );
    }
    if (data.containsKey('energy_kwh')) {
      context.handle(
        _energyKwhMeta,
        energyKwh.isAcceptableOrUnknown(data['energy_kwh']!, _energyKwhMeta),
      );
    }
    if (data.containsKey('carbon_g_co2')) {
      context.handle(
        _carbonGCo2Meta,
        carbonGCo2.isAcceptableOrUnknown(
          data['carbon_g_co2']!,
          _carbonGCo2Meta,
        ),
      );
    }
    if (data.containsKey('water_liters')) {
      context.handle(
        _waterLitersMeta,
        waterLiters.isAcceptableOrUnknown(
          data['water_liters']!,
          _waterLitersMeta,
        ),
      );
    }
    if (data.containsKey('renewable_percent')) {
      context.handle(
        _renewablePercentMeta,
        renewablePercent.isAcceptableOrUnknown(
          data['renewable_percent']!,
          _renewablePercentMeta,
        ),
      );
    }
    if (data.containsKey('pue')) {
      context.handle(
        _pueMeta,
        pue.isAcceptableOrUnknown(data['pue']!, _pueMeta),
      );
    }
    if (data.containsKey('data_center')) {
      context.handle(
        _dataCenterMeta,
        dataCenter.isAcceptableOrUnknown(data['data_center']!, _dataCenterMeta),
      );
    }
    if (data.containsKey('upstream_provider_id')) {
      context.handle(
        _upstreamProviderIdMeta,
        upstreamProviderId.isAcceptableOrUnknown(
          data['upstream_provider_id']!,
          _upstreamProviderIdMeta,
        ),
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
  ConsumptionEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConsumptionEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attributionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attribution_id'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      ),
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      ),
      wakeRunKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wake_run_key'],
      ),
      threadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_id'],
      ),
      turnIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}turn_index'],
      ),
      promptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt_id'],
      ),
      skillId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill_id'],
      ),
      configId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_id'],
      ),
      providerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_type'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      ),
      providerModelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_model_id'],
      ),
      responseType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_type'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      inputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_tokens'],
      ),
      outputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_tokens'],
      ),
      cachedInputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_input_tokens'],
      ),
      thoughtsTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}thoughts_tokens'],
      ),
      totalTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_tokens'],
      ),
      credits: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}credits'],
      ),
      energyKwh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}energy_kwh'],
      ),
      carbonGCo2: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbon_g_co2'],
      ),
      waterLiters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}water_liters'],
      ),
      renewablePercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}renewable_percent'],
      ),
      pue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pue'],
      ),
      dataCenter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_center'],
      ),
      upstreamProviderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upstream_provider_id'],
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
  ConsumptionEvents createAlias(String alias) {
    return ConsumptionEvents(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ConsumptionEvent extends DataClass
    implements Insertable<ConsumptionEvent> {
  final String id;
  final String? parentId;
  final DateTime createdAt;

  /// Logical work attribution. Nullable so schema-v1 rows remain valid.
  final String? attributionId;

  /// Denormalized owners (snapshot at call time)
  final String? taskId;
  final String? categoryId;
  final String? entryId;
  final String? agentId;
  final String? wakeRunKey;
  final String? threadId;
  final int? turnIndex;
  final String? promptId;
  final String? skillId;
  final String? configId;

  /// Provider / model / discriminator
  final String providerType;
  final String? modelId;
  final String? providerModelId;
  final String responseType;
  final int? durationMs;

  /// Token metrics
  final int? inputTokens;
  final int? outputTokens;
  final int? cachedInputTokens;
  final int? thoughtsTokens;
  final int? totalTokens;

  /// Cost + environmental impact (all nullable — only Melious reports impact)
  final double? credits;
  final double? energyKwh;
  final double? carbonGCo2;
  final double? waterLiters;
  final double? renewablePercent;
  final double? pue;
  final String? dataCenter;
  final String? upstreamProviderId;
  final String serialized;
  final int schemaVersion;
  const ConsumptionEvent({
    required this.id,
    this.parentId,
    required this.createdAt,
    this.attributionId,
    this.taskId,
    this.categoryId,
    this.entryId,
    this.agentId,
    this.wakeRunKey,
    this.threadId,
    this.turnIndex,
    this.promptId,
    this.skillId,
    this.configId,
    required this.providerType,
    this.modelId,
    this.providerModelId,
    required this.responseType,
    this.durationMs,
    this.inputTokens,
    this.outputTokens,
    this.cachedInputTokens,
    this.thoughtsTokens,
    this.totalTokens,
    this.credits,
    this.energyKwh,
    this.carbonGCo2,
    this.waterLiters,
    this.renewablePercent,
    this.pue,
    this.dataCenter,
    this.upstreamProviderId,
    required this.serialized,
    required this.schemaVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || attributionId != null) {
      map['attribution_id'] = Variable<String>(attributionId);
    }
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || entryId != null) {
      map['entry_id'] = Variable<String>(entryId);
    }
    if (!nullToAbsent || agentId != null) {
      map['agent_id'] = Variable<String>(agentId);
    }
    if (!nullToAbsent || wakeRunKey != null) {
      map['wake_run_key'] = Variable<String>(wakeRunKey);
    }
    if (!nullToAbsent || threadId != null) {
      map['thread_id'] = Variable<String>(threadId);
    }
    if (!nullToAbsent || turnIndex != null) {
      map['turn_index'] = Variable<int>(turnIndex);
    }
    if (!nullToAbsent || promptId != null) {
      map['prompt_id'] = Variable<String>(promptId);
    }
    if (!nullToAbsent || skillId != null) {
      map['skill_id'] = Variable<String>(skillId);
    }
    if (!nullToAbsent || configId != null) {
      map['config_id'] = Variable<String>(configId);
    }
    map['provider_type'] = Variable<String>(providerType);
    if (!nullToAbsent || modelId != null) {
      map['model_id'] = Variable<String>(modelId);
    }
    if (!nullToAbsent || providerModelId != null) {
      map['provider_model_id'] = Variable<String>(providerModelId);
    }
    map['response_type'] = Variable<String>(responseType);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || inputTokens != null) {
      map['input_tokens'] = Variable<int>(inputTokens);
    }
    if (!nullToAbsent || outputTokens != null) {
      map['output_tokens'] = Variable<int>(outputTokens);
    }
    if (!nullToAbsent || cachedInputTokens != null) {
      map['cached_input_tokens'] = Variable<int>(cachedInputTokens);
    }
    if (!nullToAbsent || thoughtsTokens != null) {
      map['thoughts_tokens'] = Variable<int>(thoughtsTokens);
    }
    if (!nullToAbsent || totalTokens != null) {
      map['total_tokens'] = Variable<int>(totalTokens);
    }
    if (!nullToAbsent || credits != null) {
      map['credits'] = Variable<double>(credits);
    }
    if (!nullToAbsent || energyKwh != null) {
      map['energy_kwh'] = Variable<double>(energyKwh);
    }
    if (!nullToAbsent || carbonGCo2 != null) {
      map['carbon_g_co2'] = Variable<double>(carbonGCo2);
    }
    if (!nullToAbsent || waterLiters != null) {
      map['water_liters'] = Variable<double>(waterLiters);
    }
    if (!nullToAbsent || renewablePercent != null) {
      map['renewable_percent'] = Variable<double>(renewablePercent);
    }
    if (!nullToAbsent || pue != null) {
      map['pue'] = Variable<double>(pue);
    }
    if (!nullToAbsent || dataCenter != null) {
      map['data_center'] = Variable<String>(dataCenter);
    }
    if (!nullToAbsent || upstreamProviderId != null) {
      map['upstream_provider_id'] = Variable<String>(upstreamProviderId);
    }
    map['serialized'] = Variable<String>(serialized);
    map['schema_version'] = Variable<int>(schemaVersion);
    return map;
  }

  ConsumptionEventsCompanion toCompanion(bool nullToAbsent) {
    return ConsumptionEventsCompanion(
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      createdAt: Value(createdAt),
      attributionId: attributionId == null && nullToAbsent
          ? const Value.absent()
          : Value(attributionId),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      entryId: entryId == null && nullToAbsent
          ? const Value.absent()
          : Value(entryId),
      agentId: agentId == null && nullToAbsent
          ? const Value.absent()
          : Value(agentId),
      wakeRunKey: wakeRunKey == null && nullToAbsent
          ? const Value.absent()
          : Value(wakeRunKey),
      threadId: threadId == null && nullToAbsent
          ? const Value.absent()
          : Value(threadId),
      turnIndex: turnIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(turnIndex),
      promptId: promptId == null && nullToAbsent
          ? const Value.absent()
          : Value(promptId),
      skillId: skillId == null && nullToAbsent
          ? const Value.absent()
          : Value(skillId),
      configId: configId == null && nullToAbsent
          ? const Value.absent()
          : Value(configId),
      providerType: Value(providerType),
      modelId: modelId == null && nullToAbsent
          ? const Value.absent()
          : Value(modelId),
      providerModelId: providerModelId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerModelId),
      responseType: Value(responseType),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      inputTokens: inputTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(inputTokens),
      outputTokens: outputTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(outputTokens),
      cachedInputTokens: cachedInputTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(cachedInputTokens),
      thoughtsTokens: thoughtsTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(thoughtsTokens),
      totalTokens: totalTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(totalTokens),
      credits: credits == null && nullToAbsent
          ? const Value.absent()
          : Value(credits),
      energyKwh: energyKwh == null && nullToAbsent
          ? const Value.absent()
          : Value(energyKwh),
      carbonGCo2: carbonGCo2 == null && nullToAbsent
          ? const Value.absent()
          : Value(carbonGCo2),
      waterLiters: waterLiters == null && nullToAbsent
          ? const Value.absent()
          : Value(waterLiters),
      renewablePercent: renewablePercent == null && nullToAbsent
          ? const Value.absent()
          : Value(renewablePercent),
      pue: pue == null && nullToAbsent ? const Value.absent() : Value(pue),
      dataCenter: dataCenter == null && nullToAbsent
          ? const Value.absent()
          : Value(dataCenter),
      upstreamProviderId: upstreamProviderId == null && nullToAbsent
          ? const Value.absent()
          : Value(upstreamProviderId),
      serialized: Value(serialized),
      schemaVersion: Value(schemaVersion),
    );
  }

  factory ConsumptionEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConsumptionEvent(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parent_id']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      attributionId: serializer.fromJson<String?>(json['attribution_id']),
      taskId: serializer.fromJson<String?>(json['task_id']),
      categoryId: serializer.fromJson<String?>(json['category_id']),
      entryId: serializer.fromJson<String?>(json['entry_id']),
      agentId: serializer.fromJson<String?>(json['agent_id']),
      wakeRunKey: serializer.fromJson<String?>(json['wake_run_key']),
      threadId: serializer.fromJson<String?>(json['thread_id']),
      turnIndex: serializer.fromJson<int?>(json['turn_index']),
      promptId: serializer.fromJson<String?>(json['prompt_id']),
      skillId: serializer.fromJson<String?>(json['skill_id']),
      configId: serializer.fromJson<String?>(json['config_id']),
      providerType: serializer.fromJson<String>(json['provider_type']),
      modelId: serializer.fromJson<String?>(json['model_id']),
      providerModelId: serializer.fromJson<String?>(json['provider_model_id']),
      responseType: serializer.fromJson<String>(json['response_type']),
      durationMs: serializer.fromJson<int?>(json['duration_ms']),
      inputTokens: serializer.fromJson<int?>(json['input_tokens']),
      outputTokens: serializer.fromJson<int?>(json['output_tokens']),
      cachedInputTokens: serializer.fromJson<int?>(json['cached_input_tokens']),
      thoughtsTokens: serializer.fromJson<int?>(json['thoughts_tokens']),
      totalTokens: serializer.fromJson<int?>(json['total_tokens']),
      credits: serializer.fromJson<double?>(json['credits']),
      energyKwh: serializer.fromJson<double?>(json['energy_kwh']),
      carbonGCo2: serializer.fromJson<double?>(json['carbon_g_co2']),
      waterLiters: serializer.fromJson<double?>(json['water_liters']),
      renewablePercent: serializer.fromJson<double?>(json['renewable_percent']),
      pue: serializer.fromJson<double?>(json['pue']),
      dataCenter: serializer.fromJson<String?>(json['data_center']),
      upstreamProviderId: serializer.fromJson<String?>(
        json['upstream_provider_id'],
      ),
      serialized: serializer.fromJson<String>(json['serialized']),
      schemaVersion: serializer.fromJson<int>(json['schema_version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parent_id': serializer.toJson<String?>(parentId),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'attribution_id': serializer.toJson<String?>(attributionId),
      'task_id': serializer.toJson<String?>(taskId),
      'category_id': serializer.toJson<String?>(categoryId),
      'entry_id': serializer.toJson<String?>(entryId),
      'agent_id': serializer.toJson<String?>(agentId),
      'wake_run_key': serializer.toJson<String?>(wakeRunKey),
      'thread_id': serializer.toJson<String?>(threadId),
      'turn_index': serializer.toJson<int?>(turnIndex),
      'prompt_id': serializer.toJson<String?>(promptId),
      'skill_id': serializer.toJson<String?>(skillId),
      'config_id': serializer.toJson<String?>(configId),
      'provider_type': serializer.toJson<String>(providerType),
      'model_id': serializer.toJson<String?>(modelId),
      'provider_model_id': serializer.toJson<String?>(providerModelId),
      'response_type': serializer.toJson<String>(responseType),
      'duration_ms': serializer.toJson<int?>(durationMs),
      'input_tokens': serializer.toJson<int?>(inputTokens),
      'output_tokens': serializer.toJson<int?>(outputTokens),
      'cached_input_tokens': serializer.toJson<int?>(cachedInputTokens),
      'thoughts_tokens': serializer.toJson<int?>(thoughtsTokens),
      'total_tokens': serializer.toJson<int?>(totalTokens),
      'credits': serializer.toJson<double?>(credits),
      'energy_kwh': serializer.toJson<double?>(energyKwh),
      'carbon_g_co2': serializer.toJson<double?>(carbonGCo2),
      'water_liters': serializer.toJson<double?>(waterLiters),
      'renewable_percent': serializer.toJson<double?>(renewablePercent),
      'pue': serializer.toJson<double?>(pue),
      'data_center': serializer.toJson<String?>(dataCenter),
      'upstream_provider_id': serializer.toJson<String?>(upstreamProviderId),
      'serialized': serializer.toJson<String>(serialized),
      'schema_version': serializer.toJson<int>(schemaVersion),
    };
  }

  ConsumptionEvent copyWith({
    String? id,
    Value<String?> parentId = const Value.absent(),
    DateTime? createdAt,
    Value<String?> attributionId = const Value.absent(),
    Value<String?> taskId = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<String?> entryId = const Value.absent(),
    Value<String?> agentId = const Value.absent(),
    Value<String?> wakeRunKey = const Value.absent(),
    Value<String?> threadId = const Value.absent(),
    Value<int?> turnIndex = const Value.absent(),
    Value<String?> promptId = const Value.absent(),
    Value<String?> skillId = const Value.absent(),
    Value<String?> configId = const Value.absent(),
    String? providerType,
    Value<String?> modelId = const Value.absent(),
    Value<String?> providerModelId = const Value.absent(),
    String? responseType,
    Value<int?> durationMs = const Value.absent(),
    Value<int?> inputTokens = const Value.absent(),
    Value<int?> outputTokens = const Value.absent(),
    Value<int?> cachedInputTokens = const Value.absent(),
    Value<int?> thoughtsTokens = const Value.absent(),
    Value<int?> totalTokens = const Value.absent(),
    Value<double?> credits = const Value.absent(),
    Value<double?> energyKwh = const Value.absent(),
    Value<double?> carbonGCo2 = const Value.absent(),
    Value<double?> waterLiters = const Value.absent(),
    Value<double?> renewablePercent = const Value.absent(),
    Value<double?> pue = const Value.absent(),
    Value<String?> dataCenter = const Value.absent(),
    Value<String?> upstreamProviderId = const Value.absent(),
    String? serialized,
    int? schemaVersion,
  }) => ConsumptionEvent(
    id: id ?? this.id,
    parentId: parentId.present ? parentId.value : this.parentId,
    createdAt: createdAt ?? this.createdAt,
    attributionId: attributionId.present
        ? attributionId.value
        : this.attributionId,
    taskId: taskId.present ? taskId.value : this.taskId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    entryId: entryId.present ? entryId.value : this.entryId,
    agentId: agentId.present ? agentId.value : this.agentId,
    wakeRunKey: wakeRunKey.present ? wakeRunKey.value : this.wakeRunKey,
    threadId: threadId.present ? threadId.value : this.threadId,
    turnIndex: turnIndex.present ? turnIndex.value : this.turnIndex,
    promptId: promptId.present ? promptId.value : this.promptId,
    skillId: skillId.present ? skillId.value : this.skillId,
    configId: configId.present ? configId.value : this.configId,
    providerType: providerType ?? this.providerType,
    modelId: modelId.present ? modelId.value : this.modelId,
    providerModelId: providerModelId.present
        ? providerModelId.value
        : this.providerModelId,
    responseType: responseType ?? this.responseType,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    inputTokens: inputTokens.present ? inputTokens.value : this.inputTokens,
    outputTokens: outputTokens.present ? outputTokens.value : this.outputTokens,
    cachedInputTokens: cachedInputTokens.present
        ? cachedInputTokens.value
        : this.cachedInputTokens,
    thoughtsTokens: thoughtsTokens.present
        ? thoughtsTokens.value
        : this.thoughtsTokens,
    totalTokens: totalTokens.present ? totalTokens.value : this.totalTokens,
    credits: credits.present ? credits.value : this.credits,
    energyKwh: energyKwh.present ? energyKwh.value : this.energyKwh,
    carbonGCo2: carbonGCo2.present ? carbonGCo2.value : this.carbonGCo2,
    waterLiters: waterLiters.present ? waterLiters.value : this.waterLiters,
    renewablePercent: renewablePercent.present
        ? renewablePercent.value
        : this.renewablePercent,
    pue: pue.present ? pue.value : this.pue,
    dataCenter: dataCenter.present ? dataCenter.value : this.dataCenter,
    upstreamProviderId: upstreamProviderId.present
        ? upstreamProviderId.value
        : this.upstreamProviderId,
    serialized: serialized ?? this.serialized,
    schemaVersion: schemaVersion ?? this.schemaVersion,
  );
  ConsumptionEvent copyWithCompanion(ConsumptionEventsCompanion data) {
    return ConsumptionEvent(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attributionId: data.attributionId.present
          ? data.attributionId.value
          : this.attributionId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      wakeRunKey: data.wakeRunKey.present
          ? data.wakeRunKey.value
          : this.wakeRunKey,
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
      turnIndex: data.turnIndex.present ? data.turnIndex.value : this.turnIndex,
      promptId: data.promptId.present ? data.promptId.value : this.promptId,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      configId: data.configId.present ? data.configId.value : this.configId,
      providerType: data.providerType.present
          ? data.providerType.value
          : this.providerType,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      providerModelId: data.providerModelId.present
          ? data.providerModelId.value
          : this.providerModelId,
      responseType: data.responseType.present
          ? data.responseType.value
          : this.responseType,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      inputTokens: data.inputTokens.present
          ? data.inputTokens.value
          : this.inputTokens,
      outputTokens: data.outputTokens.present
          ? data.outputTokens.value
          : this.outputTokens,
      cachedInputTokens: data.cachedInputTokens.present
          ? data.cachedInputTokens.value
          : this.cachedInputTokens,
      thoughtsTokens: data.thoughtsTokens.present
          ? data.thoughtsTokens.value
          : this.thoughtsTokens,
      totalTokens: data.totalTokens.present
          ? data.totalTokens.value
          : this.totalTokens,
      credits: data.credits.present ? data.credits.value : this.credits,
      energyKwh: data.energyKwh.present ? data.energyKwh.value : this.energyKwh,
      carbonGCo2: data.carbonGCo2.present
          ? data.carbonGCo2.value
          : this.carbonGCo2,
      waterLiters: data.waterLiters.present
          ? data.waterLiters.value
          : this.waterLiters,
      renewablePercent: data.renewablePercent.present
          ? data.renewablePercent.value
          : this.renewablePercent,
      pue: data.pue.present ? data.pue.value : this.pue,
      dataCenter: data.dataCenter.present
          ? data.dataCenter.value
          : this.dataCenter,
      upstreamProviderId: data.upstreamProviderId.present
          ? data.upstreamProviderId.value
          : this.upstreamProviderId,
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
    return (StringBuffer('ConsumptionEvent(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('attributionId: $attributionId, ')
          ..write('taskId: $taskId, ')
          ..write('categoryId: $categoryId, ')
          ..write('entryId: $entryId, ')
          ..write('agentId: $agentId, ')
          ..write('wakeRunKey: $wakeRunKey, ')
          ..write('threadId: $threadId, ')
          ..write('turnIndex: $turnIndex, ')
          ..write('promptId: $promptId, ')
          ..write('skillId: $skillId, ')
          ..write('configId: $configId, ')
          ..write('providerType: $providerType, ')
          ..write('modelId: $modelId, ')
          ..write('providerModelId: $providerModelId, ')
          ..write('responseType: $responseType, ')
          ..write('durationMs: $durationMs, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('cachedInputTokens: $cachedInputTokens, ')
          ..write('thoughtsTokens: $thoughtsTokens, ')
          ..write('totalTokens: $totalTokens, ')
          ..write('credits: $credits, ')
          ..write('energyKwh: $energyKwh, ')
          ..write('carbonGCo2: $carbonGCo2, ')
          ..write('waterLiters: $waterLiters, ')
          ..write('renewablePercent: $renewablePercent, ')
          ..write('pue: $pue, ')
          ..write('dataCenter: $dataCenter, ')
          ..write('upstreamProviderId: $upstreamProviderId, ')
          ..write('serialized: $serialized, ')
          ..write('schemaVersion: $schemaVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    parentId,
    createdAt,
    attributionId,
    taskId,
    categoryId,
    entryId,
    agentId,
    wakeRunKey,
    threadId,
    turnIndex,
    promptId,
    skillId,
    configId,
    providerType,
    modelId,
    providerModelId,
    responseType,
    durationMs,
    inputTokens,
    outputTokens,
    cachedInputTokens,
    thoughtsTokens,
    totalTokens,
    credits,
    energyKwh,
    carbonGCo2,
    waterLiters,
    renewablePercent,
    pue,
    dataCenter,
    upstreamProviderId,
    serialized,
    schemaVersion,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConsumptionEvent &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.createdAt == this.createdAt &&
          other.attributionId == this.attributionId &&
          other.taskId == this.taskId &&
          other.categoryId == this.categoryId &&
          other.entryId == this.entryId &&
          other.agentId == this.agentId &&
          other.wakeRunKey == this.wakeRunKey &&
          other.threadId == this.threadId &&
          other.turnIndex == this.turnIndex &&
          other.promptId == this.promptId &&
          other.skillId == this.skillId &&
          other.configId == this.configId &&
          other.providerType == this.providerType &&
          other.modelId == this.modelId &&
          other.providerModelId == this.providerModelId &&
          other.responseType == this.responseType &&
          other.durationMs == this.durationMs &&
          other.inputTokens == this.inputTokens &&
          other.outputTokens == this.outputTokens &&
          other.cachedInputTokens == this.cachedInputTokens &&
          other.thoughtsTokens == this.thoughtsTokens &&
          other.totalTokens == this.totalTokens &&
          other.credits == this.credits &&
          other.energyKwh == this.energyKwh &&
          other.carbonGCo2 == this.carbonGCo2 &&
          other.waterLiters == this.waterLiters &&
          other.renewablePercent == this.renewablePercent &&
          other.pue == this.pue &&
          other.dataCenter == this.dataCenter &&
          other.upstreamProviderId == this.upstreamProviderId &&
          other.serialized == this.serialized &&
          other.schemaVersion == this.schemaVersion);
}

class ConsumptionEventsCompanion extends UpdateCompanion<ConsumptionEvent> {
  final Value<String> id;
  final Value<String?> parentId;
  final Value<DateTime> createdAt;
  final Value<String?> attributionId;
  final Value<String?> taskId;
  final Value<String?> categoryId;
  final Value<String?> entryId;
  final Value<String?> agentId;
  final Value<String?> wakeRunKey;
  final Value<String?> threadId;
  final Value<int?> turnIndex;
  final Value<String?> promptId;
  final Value<String?> skillId;
  final Value<String?> configId;
  final Value<String> providerType;
  final Value<String?> modelId;
  final Value<String?> providerModelId;
  final Value<String> responseType;
  final Value<int?> durationMs;
  final Value<int?> inputTokens;
  final Value<int?> outputTokens;
  final Value<int?> cachedInputTokens;
  final Value<int?> thoughtsTokens;
  final Value<int?> totalTokens;
  final Value<double?> credits;
  final Value<double?> energyKwh;
  final Value<double?> carbonGCo2;
  final Value<double?> waterLiters;
  final Value<double?> renewablePercent;
  final Value<double?> pue;
  final Value<String?> dataCenter;
  final Value<String?> upstreamProviderId;
  final Value<String> serialized;
  final Value<int> schemaVersion;
  final Value<int> rowid;
  const ConsumptionEventsCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attributionId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.entryId = const Value.absent(),
    this.agentId = const Value.absent(),
    this.wakeRunKey = const Value.absent(),
    this.threadId = const Value.absent(),
    this.turnIndex = const Value.absent(),
    this.promptId = const Value.absent(),
    this.skillId = const Value.absent(),
    this.configId = const Value.absent(),
    this.providerType = const Value.absent(),
    this.modelId = const Value.absent(),
    this.providerModelId = const Value.absent(),
    this.responseType = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.cachedInputTokens = const Value.absent(),
    this.thoughtsTokens = const Value.absent(),
    this.totalTokens = const Value.absent(),
    this.credits = const Value.absent(),
    this.energyKwh = const Value.absent(),
    this.carbonGCo2 = const Value.absent(),
    this.waterLiters = const Value.absent(),
    this.renewablePercent = const Value.absent(),
    this.pue = const Value.absent(),
    this.dataCenter = const Value.absent(),
    this.upstreamProviderId = const Value.absent(),
    this.serialized = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConsumptionEventsCompanion.insert({
    required String id,
    this.parentId = const Value.absent(),
    required DateTime createdAt,
    this.attributionId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.entryId = const Value.absent(),
    this.agentId = const Value.absent(),
    this.wakeRunKey = const Value.absent(),
    this.threadId = const Value.absent(),
    this.turnIndex = const Value.absent(),
    this.promptId = const Value.absent(),
    this.skillId = const Value.absent(),
    this.configId = const Value.absent(),
    required String providerType,
    this.modelId = const Value.absent(),
    this.providerModelId = const Value.absent(),
    required String responseType,
    this.durationMs = const Value.absent(),
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.cachedInputTokens = const Value.absent(),
    this.thoughtsTokens = const Value.absent(),
    this.totalTokens = const Value.absent(),
    this.credits = const Value.absent(),
    this.energyKwh = const Value.absent(),
    this.carbonGCo2 = const Value.absent(),
    this.waterLiters = const Value.absent(),
    this.renewablePercent = const Value.absent(),
    this.pue = const Value.absent(),
    this.dataCenter = const Value.absent(),
    this.upstreamProviderId = const Value.absent(),
    required String serialized,
    this.schemaVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       providerType = Value(providerType),
       responseType = Value(responseType),
       serialized = Value(serialized);
  static Insertable<ConsumptionEvent> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<DateTime>? createdAt,
    Expression<String>? attributionId,
    Expression<String>? taskId,
    Expression<String>? categoryId,
    Expression<String>? entryId,
    Expression<String>? agentId,
    Expression<String>? wakeRunKey,
    Expression<String>? threadId,
    Expression<int>? turnIndex,
    Expression<String>? promptId,
    Expression<String>? skillId,
    Expression<String>? configId,
    Expression<String>? providerType,
    Expression<String>? modelId,
    Expression<String>? providerModelId,
    Expression<String>? responseType,
    Expression<int>? durationMs,
    Expression<int>? inputTokens,
    Expression<int>? outputTokens,
    Expression<int>? cachedInputTokens,
    Expression<int>? thoughtsTokens,
    Expression<int>? totalTokens,
    Expression<double>? credits,
    Expression<double>? energyKwh,
    Expression<double>? carbonGCo2,
    Expression<double>? waterLiters,
    Expression<double>? renewablePercent,
    Expression<double>? pue,
    Expression<String>? dataCenter,
    Expression<String>? upstreamProviderId,
    Expression<String>? serialized,
    Expression<int>? schemaVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (createdAt != null) 'created_at': createdAt,
      if (attributionId != null) 'attribution_id': attributionId,
      if (taskId != null) 'task_id': taskId,
      if (categoryId != null) 'category_id': categoryId,
      if (entryId != null) 'entry_id': entryId,
      if (agentId != null) 'agent_id': agentId,
      if (wakeRunKey != null) 'wake_run_key': wakeRunKey,
      if (threadId != null) 'thread_id': threadId,
      if (turnIndex != null) 'turn_index': turnIndex,
      if (promptId != null) 'prompt_id': promptId,
      if (skillId != null) 'skill_id': skillId,
      if (configId != null) 'config_id': configId,
      if (providerType != null) 'provider_type': providerType,
      if (modelId != null) 'model_id': modelId,
      if (providerModelId != null) 'provider_model_id': providerModelId,
      if (responseType != null) 'response_type': responseType,
      if (durationMs != null) 'duration_ms': durationMs,
      if (inputTokens != null) 'input_tokens': inputTokens,
      if (outputTokens != null) 'output_tokens': outputTokens,
      if (cachedInputTokens != null) 'cached_input_tokens': cachedInputTokens,
      if (thoughtsTokens != null) 'thoughts_tokens': thoughtsTokens,
      if (totalTokens != null) 'total_tokens': totalTokens,
      if (credits != null) 'credits': credits,
      if (energyKwh != null) 'energy_kwh': energyKwh,
      if (carbonGCo2 != null) 'carbon_g_co2': carbonGCo2,
      if (waterLiters != null) 'water_liters': waterLiters,
      if (renewablePercent != null) 'renewable_percent': renewablePercent,
      if (pue != null) 'pue': pue,
      if (dataCenter != null) 'data_center': dataCenter,
      if (upstreamProviderId != null)
        'upstream_provider_id': upstreamProviderId,
      if (serialized != null) 'serialized': serialized,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConsumptionEventsCompanion copyWith({
    Value<String>? id,
    Value<String?>? parentId,
    Value<DateTime>? createdAt,
    Value<String?>? attributionId,
    Value<String?>? taskId,
    Value<String?>? categoryId,
    Value<String?>? entryId,
    Value<String?>? agentId,
    Value<String?>? wakeRunKey,
    Value<String?>? threadId,
    Value<int?>? turnIndex,
    Value<String?>? promptId,
    Value<String?>? skillId,
    Value<String?>? configId,
    Value<String>? providerType,
    Value<String?>? modelId,
    Value<String?>? providerModelId,
    Value<String>? responseType,
    Value<int?>? durationMs,
    Value<int?>? inputTokens,
    Value<int?>? outputTokens,
    Value<int?>? cachedInputTokens,
    Value<int?>? thoughtsTokens,
    Value<int?>? totalTokens,
    Value<double?>? credits,
    Value<double?>? energyKwh,
    Value<double?>? carbonGCo2,
    Value<double?>? waterLiters,
    Value<double?>? renewablePercent,
    Value<double?>? pue,
    Value<String?>? dataCenter,
    Value<String?>? upstreamProviderId,
    Value<String>? serialized,
    Value<int>? schemaVersion,
    Value<int>? rowid,
  }) {
    return ConsumptionEventsCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      attributionId: attributionId ?? this.attributionId,
      taskId: taskId ?? this.taskId,
      categoryId: categoryId ?? this.categoryId,
      entryId: entryId ?? this.entryId,
      agentId: agentId ?? this.agentId,
      wakeRunKey: wakeRunKey ?? this.wakeRunKey,
      threadId: threadId ?? this.threadId,
      turnIndex: turnIndex ?? this.turnIndex,
      promptId: promptId ?? this.promptId,
      skillId: skillId ?? this.skillId,
      configId: configId ?? this.configId,
      providerType: providerType ?? this.providerType,
      modelId: modelId ?? this.modelId,
      providerModelId: providerModelId ?? this.providerModelId,
      responseType: responseType ?? this.responseType,
      durationMs: durationMs ?? this.durationMs,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      cachedInputTokens: cachedInputTokens ?? this.cachedInputTokens,
      thoughtsTokens: thoughtsTokens ?? this.thoughtsTokens,
      totalTokens: totalTokens ?? this.totalTokens,
      credits: credits ?? this.credits,
      energyKwh: energyKwh ?? this.energyKwh,
      carbonGCo2: carbonGCo2 ?? this.carbonGCo2,
      waterLiters: waterLiters ?? this.waterLiters,
      renewablePercent: renewablePercent ?? this.renewablePercent,
      pue: pue ?? this.pue,
      dataCenter: dataCenter ?? this.dataCenter,
      upstreamProviderId: upstreamProviderId ?? this.upstreamProviderId,
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
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attributionId.present) {
      map['attribution_id'] = Variable<String>(attributionId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (wakeRunKey.present) {
      map['wake_run_key'] = Variable<String>(wakeRunKey.value);
    }
    if (threadId.present) {
      map['thread_id'] = Variable<String>(threadId.value);
    }
    if (turnIndex.present) {
      map['turn_index'] = Variable<int>(turnIndex.value);
    }
    if (promptId.present) {
      map['prompt_id'] = Variable<String>(promptId.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<String>(skillId.value);
    }
    if (configId.present) {
      map['config_id'] = Variable<String>(configId.value);
    }
    if (providerType.present) {
      map['provider_type'] = Variable<String>(providerType.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (providerModelId.present) {
      map['provider_model_id'] = Variable<String>(providerModelId.value);
    }
    if (responseType.present) {
      map['response_type'] = Variable<String>(responseType.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (inputTokens.present) {
      map['input_tokens'] = Variable<int>(inputTokens.value);
    }
    if (outputTokens.present) {
      map['output_tokens'] = Variable<int>(outputTokens.value);
    }
    if (cachedInputTokens.present) {
      map['cached_input_tokens'] = Variable<int>(cachedInputTokens.value);
    }
    if (thoughtsTokens.present) {
      map['thoughts_tokens'] = Variable<int>(thoughtsTokens.value);
    }
    if (totalTokens.present) {
      map['total_tokens'] = Variable<int>(totalTokens.value);
    }
    if (credits.present) {
      map['credits'] = Variable<double>(credits.value);
    }
    if (energyKwh.present) {
      map['energy_kwh'] = Variable<double>(energyKwh.value);
    }
    if (carbonGCo2.present) {
      map['carbon_g_co2'] = Variable<double>(carbonGCo2.value);
    }
    if (waterLiters.present) {
      map['water_liters'] = Variable<double>(waterLiters.value);
    }
    if (renewablePercent.present) {
      map['renewable_percent'] = Variable<double>(renewablePercent.value);
    }
    if (pue.present) {
      map['pue'] = Variable<double>(pue.value);
    }
    if (dataCenter.present) {
      map['data_center'] = Variable<String>(dataCenter.value);
    }
    if (upstreamProviderId.present) {
      map['upstream_provider_id'] = Variable<String>(upstreamProviderId.value);
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
    return (StringBuffer('ConsumptionEventsCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('attributionId: $attributionId, ')
          ..write('taskId: $taskId, ')
          ..write('categoryId: $categoryId, ')
          ..write('entryId: $entryId, ')
          ..write('agentId: $agentId, ')
          ..write('wakeRunKey: $wakeRunKey, ')
          ..write('threadId: $threadId, ')
          ..write('turnIndex: $turnIndex, ')
          ..write('promptId: $promptId, ')
          ..write('skillId: $skillId, ')
          ..write('configId: $configId, ')
          ..write('providerType: $providerType, ')
          ..write('modelId: $modelId, ')
          ..write('providerModelId: $providerModelId, ')
          ..write('responseType: $responseType, ')
          ..write('durationMs: $durationMs, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('cachedInputTokens: $cachedInputTokens, ')
          ..write('thoughtsTokens: $thoughtsTokens, ')
          ..write('totalTokens: $totalTokens, ')
          ..write('credits: $credits, ')
          ..write('energyKwh: $energyKwh, ')
          ..write('carbonGCo2: $carbonGCo2, ')
          ..write('waterLiters: $waterLiters, ')
          ..write('renewablePercent: $renewablePercent, ')
          ..write('pue: $pue, ')
          ..write('dataCenter: $dataCenter, ')
          ..write('upstreamProviderId: $upstreamProviderId, ')
          ..write('serialized: $serialized, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AiWorkAttributions extends Table
    with TableInfo<AiWorkAttributions, AiWorkAttribution> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AiWorkAttributions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _workTypeMeta = const VerificationMeta(
    'workType',
  );
  late final GeneratedColumn<String> workType = GeneratedColumn<String>(
    'work_type',
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
  static const VerificationMeta _initiatorTypeMeta = const VerificationMeta(
    'initiatorType',
  );
  late final GeneratedColumn<String> initiatorType = GeneratedColumn<String>(
    'initiator_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _initiatorIdMeta = const VerificationMeta(
    'initiatorId',
  );
  late final GeneratedColumn<String> initiatorId = GeneratedColumn<String>(
    'initiator_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _initiatorDisplayNameMeta =
      const VerificationMeta('initiatorDisplayName');
  late final GeneratedColumn<String> initiatorDisplayName =
      GeneratedColumn<String>(
        'initiator_display_name',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      );
  static const VerificationMeta _triggerTypeMeta = const VerificationMeta(
    'triggerType',
  );
  late final GeneratedColumn<String> triggerType = GeneratedColumn<String>(
    'trigger_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _parentAttributionIdMeta =
      const VerificationMeta('parentAttributionId');
  late final GeneratedColumn<String> parentAttributionId =
      GeneratedColumn<String>(
        'parent_attribution_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _primaryOutputTypeMeta = const VerificationMeta(
    'primaryOutputType',
  );
  late final GeneratedColumn<String> primaryOutputType =
      GeneratedColumn<String>(
        'primary_output_type',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _primaryOutputIdMeta = const VerificationMeta(
    'primaryOutputId',
  );
  late final GeneratedColumn<String> primaryOutputId = GeneratedColumn<String>(
    'primary_output_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _primaryOutputSubIdMeta =
      const VerificationMeta('primaryOutputSubId');
  late final GeneratedColumn<String> primaryOutputSubId =
      GeneratedColumn<String>(
        'primary_output_sub_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
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
    workType,
    status,
    initiatorType,
    initiatorId,
    initiatorDisplayName,
    triggerType,
    startedAt,
    completedAt,
    parentAttributionId,
    taskId,
    categoryId,
    primaryOutputType,
    primaryOutputId,
    primaryOutputSubId,
    serialized,
    schemaVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_work_attributions';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiWorkAttribution> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('work_type')) {
      context.handle(
        _workTypeMeta,
        workType.isAcceptableOrUnknown(data['work_type']!, _workTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_workTypeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('initiator_type')) {
      context.handle(
        _initiatorTypeMeta,
        initiatorType.isAcceptableOrUnknown(
          data['initiator_type']!,
          _initiatorTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_initiatorTypeMeta);
    }
    if (data.containsKey('initiator_id')) {
      context.handle(
        _initiatorIdMeta,
        initiatorId.isAcceptableOrUnknown(
          data['initiator_id']!,
          _initiatorIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_initiatorIdMeta);
    }
    if (data.containsKey('initiator_display_name')) {
      context.handle(
        _initiatorDisplayNameMeta,
        initiatorDisplayName.isAcceptableOrUnknown(
          data['initiator_display_name']!,
          _initiatorDisplayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_initiatorDisplayNameMeta);
    }
    if (data.containsKey('trigger_type')) {
      context.handle(
        _triggerTypeMeta,
        triggerType.isAcceptableOrUnknown(
          data['trigger_type']!,
          _triggerTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_triggerTypeMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('parent_attribution_id')) {
      context.handle(
        _parentAttributionIdMeta,
        parentAttributionId.isAcceptableOrUnknown(
          data['parent_attribution_id']!,
          _parentAttributionIdMeta,
        ),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('primary_output_type')) {
      context.handle(
        _primaryOutputTypeMeta,
        primaryOutputType.isAcceptableOrUnknown(
          data['primary_output_type']!,
          _primaryOutputTypeMeta,
        ),
      );
    }
    if (data.containsKey('primary_output_id')) {
      context.handle(
        _primaryOutputIdMeta,
        primaryOutputId.isAcceptableOrUnknown(
          data['primary_output_id']!,
          _primaryOutputIdMeta,
        ),
      );
    }
    if (data.containsKey('primary_output_sub_id')) {
      context.handle(
        _primaryOutputSubIdMeta,
        primaryOutputSubId.isAcceptableOrUnknown(
          data['primary_output_sub_id']!,
          _primaryOutputSubIdMeta,
        ),
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
  AiWorkAttribution map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiWorkAttribution(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      workType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      initiatorType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}initiator_type'],
      )!,
      initiatorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}initiator_id'],
      )!,
      initiatorDisplayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}initiator_display_name'],
      )!,
      triggerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger_type'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
      parentAttributionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_attribution_id'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      primaryOutputType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_output_type'],
      ),
      primaryOutputId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_output_id'],
      ),
      primaryOutputSubId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_output_sub_id'],
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
  AiWorkAttributions createAlias(String alias) {
    return AiWorkAttributions(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class AiWorkAttribution extends DataClass
    implements Insertable<AiWorkAttribution> {
  final String id;
  final String workType;
  final String status;
  final String initiatorType;
  final String initiatorId;
  final String initiatorDisplayName;
  final String triggerType;
  final DateTime startedAt;
  final DateTime completedAt;
  final String? parentAttributionId;
  final String? taskId;
  final String? categoryId;
  final String? primaryOutputType;
  final String? primaryOutputId;
  final String? primaryOutputSubId;
  final String serialized;
  final int schemaVersion;
  const AiWorkAttribution({
    required this.id,
    required this.workType,
    required this.status,
    required this.initiatorType,
    required this.initiatorId,
    required this.initiatorDisplayName,
    required this.triggerType,
    required this.startedAt,
    required this.completedAt,
    this.parentAttributionId,
    this.taskId,
    this.categoryId,
    this.primaryOutputType,
    this.primaryOutputId,
    this.primaryOutputSubId,
    required this.serialized,
    required this.schemaVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['work_type'] = Variable<String>(workType);
    map['status'] = Variable<String>(status);
    map['initiator_type'] = Variable<String>(initiatorType);
    map['initiator_id'] = Variable<String>(initiatorId);
    map['initiator_display_name'] = Variable<String>(initiatorDisplayName);
    map['trigger_type'] = Variable<String>(triggerType);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['completed_at'] = Variable<DateTime>(completedAt);
    if (!nullToAbsent || parentAttributionId != null) {
      map['parent_attribution_id'] = Variable<String>(parentAttributionId);
    }
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || primaryOutputType != null) {
      map['primary_output_type'] = Variable<String>(primaryOutputType);
    }
    if (!nullToAbsent || primaryOutputId != null) {
      map['primary_output_id'] = Variable<String>(primaryOutputId);
    }
    if (!nullToAbsent || primaryOutputSubId != null) {
      map['primary_output_sub_id'] = Variable<String>(primaryOutputSubId);
    }
    map['serialized'] = Variable<String>(serialized);
    map['schema_version'] = Variable<int>(schemaVersion);
    return map;
  }

  AiWorkAttributionsCompanion toCompanion(bool nullToAbsent) {
    return AiWorkAttributionsCompanion(
      id: Value(id),
      workType: Value(workType),
      status: Value(status),
      initiatorType: Value(initiatorType),
      initiatorId: Value(initiatorId),
      initiatorDisplayName: Value(initiatorDisplayName),
      triggerType: Value(triggerType),
      startedAt: Value(startedAt),
      completedAt: Value(completedAt),
      parentAttributionId: parentAttributionId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentAttributionId),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      primaryOutputType: primaryOutputType == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryOutputType),
      primaryOutputId: primaryOutputId == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryOutputId),
      primaryOutputSubId: primaryOutputSubId == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryOutputSubId),
      serialized: Value(serialized),
      schemaVersion: Value(schemaVersion),
    );
  }

  factory AiWorkAttribution.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiWorkAttribution(
      id: serializer.fromJson<String>(json['id']),
      workType: serializer.fromJson<String>(json['work_type']),
      status: serializer.fromJson<String>(json['status']),
      initiatorType: serializer.fromJson<String>(json['initiator_type']),
      initiatorId: serializer.fromJson<String>(json['initiator_id']),
      initiatorDisplayName: serializer.fromJson<String>(
        json['initiator_display_name'],
      ),
      triggerType: serializer.fromJson<String>(json['trigger_type']),
      startedAt: serializer.fromJson<DateTime>(json['started_at']),
      completedAt: serializer.fromJson<DateTime>(json['completed_at']),
      parentAttributionId: serializer.fromJson<String?>(
        json['parent_attribution_id'],
      ),
      taskId: serializer.fromJson<String?>(json['task_id']),
      categoryId: serializer.fromJson<String?>(json['category_id']),
      primaryOutputType: serializer.fromJson<String?>(
        json['primary_output_type'],
      ),
      primaryOutputId: serializer.fromJson<String?>(json['primary_output_id']),
      primaryOutputSubId: serializer.fromJson<String?>(
        json['primary_output_sub_id'],
      ),
      serialized: serializer.fromJson<String>(json['serialized']),
      schemaVersion: serializer.fromJson<int>(json['schema_version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'work_type': serializer.toJson<String>(workType),
      'status': serializer.toJson<String>(status),
      'initiator_type': serializer.toJson<String>(initiatorType),
      'initiator_id': serializer.toJson<String>(initiatorId),
      'initiator_display_name': serializer.toJson<String>(initiatorDisplayName),
      'trigger_type': serializer.toJson<String>(triggerType),
      'started_at': serializer.toJson<DateTime>(startedAt),
      'completed_at': serializer.toJson<DateTime>(completedAt),
      'parent_attribution_id': serializer.toJson<String?>(parentAttributionId),
      'task_id': serializer.toJson<String?>(taskId),
      'category_id': serializer.toJson<String?>(categoryId),
      'primary_output_type': serializer.toJson<String?>(primaryOutputType),
      'primary_output_id': serializer.toJson<String?>(primaryOutputId),
      'primary_output_sub_id': serializer.toJson<String?>(primaryOutputSubId),
      'serialized': serializer.toJson<String>(serialized),
      'schema_version': serializer.toJson<int>(schemaVersion),
    };
  }

  AiWorkAttribution copyWith({
    String? id,
    String? workType,
    String? status,
    String? initiatorType,
    String? initiatorId,
    String? initiatorDisplayName,
    String? triggerType,
    DateTime? startedAt,
    DateTime? completedAt,
    Value<String?> parentAttributionId = const Value.absent(),
    Value<String?> taskId = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<String?> primaryOutputType = const Value.absent(),
    Value<String?> primaryOutputId = const Value.absent(),
    Value<String?> primaryOutputSubId = const Value.absent(),
    String? serialized,
    int? schemaVersion,
  }) => AiWorkAttribution(
    id: id ?? this.id,
    workType: workType ?? this.workType,
    status: status ?? this.status,
    initiatorType: initiatorType ?? this.initiatorType,
    initiatorId: initiatorId ?? this.initiatorId,
    initiatorDisplayName: initiatorDisplayName ?? this.initiatorDisplayName,
    triggerType: triggerType ?? this.triggerType,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    parentAttributionId: parentAttributionId.present
        ? parentAttributionId.value
        : this.parentAttributionId,
    taskId: taskId.present ? taskId.value : this.taskId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    primaryOutputType: primaryOutputType.present
        ? primaryOutputType.value
        : this.primaryOutputType,
    primaryOutputId: primaryOutputId.present
        ? primaryOutputId.value
        : this.primaryOutputId,
    primaryOutputSubId: primaryOutputSubId.present
        ? primaryOutputSubId.value
        : this.primaryOutputSubId,
    serialized: serialized ?? this.serialized,
    schemaVersion: schemaVersion ?? this.schemaVersion,
  );
  AiWorkAttribution copyWithCompanion(AiWorkAttributionsCompanion data) {
    return AiWorkAttribution(
      id: data.id.present ? data.id.value : this.id,
      workType: data.workType.present ? data.workType.value : this.workType,
      status: data.status.present ? data.status.value : this.status,
      initiatorType: data.initiatorType.present
          ? data.initiatorType.value
          : this.initiatorType,
      initiatorId: data.initiatorId.present
          ? data.initiatorId.value
          : this.initiatorId,
      initiatorDisplayName: data.initiatorDisplayName.present
          ? data.initiatorDisplayName.value
          : this.initiatorDisplayName,
      triggerType: data.triggerType.present
          ? data.triggerType.value
          : this.triggerType,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      parentAttributionId: data.parentAttributionId.present
          ? data.parentAttributionId.value
          : this.parentAttributionId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      primaryOutputType: data.primaryOutputType.present
          ? data.primaryOutputType.value
          : this.primaryOutputType,
      primaryOutputId: data.primaryOutputId.present
          ? data.primaryOutputId.value
          : this.primaryOutputId,
      primaryOutputSubId: data.primaryOutputSubId.present
          ? data.primaryOutputSubId.value
          : this.primaryOutputSubId,
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
    return (StringBuffer('AiWorkAttribution(')
          ..write('id: $id, ')
          ..write('workType: $workType, ')
          ..write('status: $status, ')
          ..write('initiatorType: $initiatorType, ')
          ..write('initiatorId: $initiatorId, ')
          ..write('initiatorDisplayName: $initiatorDisplayName, ')
          ..write('triggerType: $triggerType, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('parentAttributionId: $parentAttributionId, ')
          ..write('taskId: $taskId, ')
          ..write('categoryId: $categoryId, ')
          ..write('primaryOutputType: $primaryOutputType, ')
          ..write('primaryOutputId: $primaryOutputId, ')
          ..write('primaryOutputSubId: $primaryOutputSubId, ')
          ..write('serialized: $serialized, ')
          ..write('schemaVersion: $schemaVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workType,
    status,
    initiatorType,
    initiatorId,
    initiatorDisplayName,
    triggerType,
    startedAt,
    completedAt,
    parentAttributionId,
    taskId,
    categoryId,
    primaryOutputType,
    primaryOutputId,
    primaryOutputSubId,
    serialized,
    schemaVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiWorkAttribution &&
          other.id == this.id &&
          other.workType == this.workType &&
          other.status == this.status &&
          other.initiatorType == this.initiatorType &&
          other.initiatorId == this.initiatorId &&
          other.initiatorDisplayName == this.initiatorDisplayName &&
          other.triggerType == this.triggerType &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.parentAttributionId == this.parentAttributionId &&
          other.taskId == this.taskId &&
          other.categoryId == this.categoryId &&
          other.primaryOutputType == this.primaryOutputType &&
          other.primaryOutputId == this.primaryOutputId &&
          other.primaryOutputSubId == this.primaryOutputSubId &&
          other.serialized == this.serialized &&
          other.schemaVersion == this.schemaVersion);
}

class AiWorkAttributionsCompanion extends UpdateCompanion<AiWorkAttribution> {
  final Value<String> id;
  final Value<String> workType;
  final Value<String> status;
  final Value<String> initiatorType;
  final Value<String> initiatorId;
  final Value<String> initiatorDisplayName;
  final Value<String> triggerType;
  final Value<DateTime> startedAt;
  final Value<DateTime> completedAt;
  final Value<String?> parentAttributionId;
  final Value<String?> taskId;
  final Value<String?> categoryId;
  final Value<String?> primaryOutputType;
  final Value<String?> primaryOutputId;
  final Value<String?> primaryOutputSubId;
  final Value<String> serialized;
  final Value<int> schemaVersion;
  final Value<int> rowid;
  const AiWorkAttributionsCompanion({
    this.id = const Value.absent(),
    this.workType = const Value.absent(),
    this.status = const Value.absent(),
    this.initiatorType = const Value.absent(),
    this.initiatorId = const Value.absent(),
    this.initiatorDisplayName = const Value.absent(),
    this.triggerType = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.parentAttributionId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.primaryOutputType = const Value.absent(),
    this.primaryOutputId = const Value.absent(),
    this.primaryOutputSubId = const Value.absent(),
    this.serialized = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiWorkAttributionsCompanion.insert({
    required String id,
    required String workType,
    required String status,
    required String initiatorType,
    required String initiatorId,
    required String initiatorDisplayName,
    required String triggerType,
    required DateTime startedAt,
    required DateTime completedAt,
    this.parentAttributionId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.primaryOutputType = const Value.absent(),
    this.primaryOutputId = const Value.absent(),
    this.primaryOutputSubId = const Value.absent(),
    required String serialized,
    this.schemaVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       workType = Value(workType),
       status = Value(status),
       initiatorType = Value(initiatorType),
       initiatorId = Value(initiatorId),
       initiatorDisplayName = Value(initiatorDisplayName),
       triggerType = Value(triggerType),
       startedAt = Value(startedAt),
       completedAt = Value(completedAt),
       serialized = Value(serialized);
  static Insertable<AiWorkAttribution> custom({
    Expression<String>? id,
    Expression<String>? workType,
    Expression<String>? status,
    Expression<String>? initiatorType,
    Expression<String>? initiatorId,
    Expression<String>? initiatorDisplayName,
    Expression<String>? triggerType,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<String>? parentAttributionId,
    Expression<String>? taskId,
    Expression<String>? categoryId,
    Expression<String>? primaryOutputType,
    Expression<String>? primaryOutputId,
    Expression<String>? primaryOutputSubId,
    Expression<String>? serialized,
    Expression<int>? schemaVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workType != null) 'work_type': workType,
      if (status != null) 'status': status,
      if (initiatorType != null) 'initiator_type': initiatorType,
      if (initiatorId != null) 'initiator_id': initiatorId,
      if (initiatorDisplayName != null)
        'initiator_display_name': initiatorDisplayName,
      if (triggerType != null) 'trigger_type': triggerType,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (parentAttributionId != null)
        'parent_attribution_id': parentAttributionId,
      if (taskId != null) 'task_id': taskId,
      if (categoryId != null) 'category_id': categoryId,
      if (primaryOutputType != null) 'primary_output_type': primaryOutputType,
      if (primaryOutputId != null) 'primary_output_id': primaryOutputId,
      if (primaryOutputSubId != null)
        'primary_output_sub_id': primaryOutputSubId,
      if (serialized != null) 'serialized': serialized,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiWorkAttributionsCompanion copyWith({
    Value<String>? id,
    Value<String>? workType,
    Value<String>? status,
    Value<String>? initiatorType,
    Value<String>? initiatorId,
    Value<String>? initiatorDisplayName,
    Value<String>? triggerType,
    Value<DateTime>? startedAt,
    Value<DateTime>? completedAt,
    Value<String?>? parentAttributionId,
    Value<String?>? taskId,
    Value<String?>? categoryId,
    Value<String?>? primaryOutputType,
    Value<String?>? primaryOutputId,
    Value<String?>? primaryOutputSubId,
    Value<String>? serialized,
    Value<int>? schemaVersion,
    Value<int>? rowid,
  }) {
    return AiWorkAttributionsCompanion(
      id: id ?? this.id,
      workType: workType ?? this.workType,
      status: status ?? this.status,
      initiatorType: initiatorType ?? this.initiatorType,
      initiatorId: initiatorId ?? this.initiatorId,
      initiatorDisplayName: initiatorDisplayName ?? this.initiatorDisplayName,
      triggerType: triggerType ?? this.triggerType,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      parentAttributionId: parentAttributionId ?? this.parentAttributionId,
      taskId: taskId ?? this.taskId,
      categoryId: categoryId ?? this.categoryId,
      primaryOutputType: primaryOutputType ?? this.primaryOutputType,
      primaryOutputId: primaryOutputId ?? this.primaryOutputId,
      primaryOutputSubId: primaryOutputSubId ?? this.primaryOutputSubId,
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
    if (workType.present) {
      map['work_type'] = Variable<String>(workType.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (initiatorType.present) {
      map['initiator_type'] = Variable<String>(initiatorType.value);
    }
    if (initiatorId.present) {
      map['initiator_id'] = Variable<String>(initiatorId.value);
    }
    if (initiatorDisplayName.present) {
      map['initiator_display_name'] = Variable<String>(
        initiatorDisplayName.value,
      );
    }
    if (triggerType.present) {
      map['trigger_type'] = Variable<String>(triggerType.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (parentAttributionId.present) {
      map['parent_attribution_id'] = Variable<String>(
        parentAttributionId.value,
      );
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (primaryOutputType.present) {
      map['primary_output_type'] = Variable<String>(primaryOutputType.value);
    }
    if (primaryOutputId.present) {
      map['primary_output_id'] = Variable<String>(primaryOutputId.value);
    }
    if (primaryOutputSubId.present) {
      map['primary_output_sub_id'] = Variable<String>(primaryOutputSubId.value);
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
    return (StringBuffer('AiWorkAttributionsCompanion(')
          ..write('id: $id, ')
          ..write('workType: $workType, ')
          ..write('status: $status, ')
          ..write('initiatorType: $initiatorType, ')
          ..write('initiatorId: $initiatorId, ')
          ..write('initiatorDisplayName: $initiatorDisplayName, ')
          ..write('triggerType: $triggerType, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('parentAttributionId: $parentAttributionId, ')
          ..write('taskId: $taskId, ')
          ..write('categoryId: $categoryId, ')
          ..write('primaryOutputType: $primaryOutputType, ')
          ..write('primaryOutputId: $primaryOutputId, ')
          ..write('primaryOutputSubId: $primaryOutputSubId, ')
          ..write('serialized: $serialized, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ConsumptionDatabase extends GeneratedDatabase {
  _$ConsumptionDatabase(QueryExecutor e) : super(e);
  _$ConsumptionDatabase.connect(DatabaseConnection c) : super.connect(c);
  $ConsumptionDatabaseManager get managers => $ConsumptionDatabaseManager(this);
  late final ConsumptionEvents consumptionEvents = ConsumptionEvents(this);
  late final Index idxConsumptionTaskCreated = Index(
    'idx_consumption_task_created',
    'CREATE INDEX idx_consumption_task_created ON consumption_events (task_id, created_at) WHERE task_id IS NOT NULL',
  );
  late final Index idxConsumptionCategoryCreated = Index(
    'idx_consumption_category_created',
    'CREATE INDEX idx_consumption_category_created ON consumption_events (category_id, created_at)',
  );
  late final Index idxConsumptionCreated = Index(
    'idx_consumption_created',
    'CREATE INDEX idx_consumption_created ON consumption_events (created_at)',
  );
  late final Index idxConsumptionAttribution = Index(
    'idx_consumption_attribution',
    'CREATE INDEX idx_consumption_attribution ON consumption_events (attribution_id, created_at) WHERE attribution_id IS NOT NULL',
  );
  late final AiWorkAttributions aiWorkAttributions = AiWorkAttributions(this);
  late final Index idxAttributionOutput = Index(
    'idx_attribution_output',
    'CREATE INDEX idx_attribution_output ON ai_work_attributions (primary_output_type, primary_output_id, primary_output_sub_id)',
  );
  late final Index idxAttributionTaskCreated = Index(
    'idx_attribution_task_created',
    'CREATE INDEX idx_attribution_task_created ON ai_work_attributions (task_id, completed_at) WHERE task_id IS NOT NULL',
  );
  late final Index idxAttributionActorCreated = Index(
    'idx_attribution_actor_created',
    'CREATE INDEX idx_attribution_actor_created ON ai_work_attributions (initiator_id, completed_at)',
  );
  late final Index idxAttributionTypeCreated = Index(
    'idx_attribution_type_created',
    'CREATE INDEX idx_attribution_type_created ON ai_work_attributions (work_type, completed_at)',
  );
  Selectable<ConsumptionEvent> getConsumptionEventById(String id) {
    return customSelect(
      'SELECT * FROM consumption_events WHERE id = ?1',
      variables: [Variable<String>(id)],
      readsFrom: {consumptionEvents},
    ).asyncMap(consumptionEvents.mapFromRow);
  }

  Selectable<String?> getConsumptionEventVectorClockById(String id) {
    return customSelect(
      'SELECT json_extract(serialized, \'\$.vectorClock\') AS vector_clock FROM consumption_events WHERE id = ?1',
      variables: [Variable<String>(id)],
      readsFrom: {consumptionEvents},
    ).map((QueryRow row) => row.readNullable<String>('vector_clock'));
  }

  Selectable<ConsumptionEvent> getConsumptionEventsWithNullVectorClock() {
    return customSelect(
      'SELECT * FROM consumption_events WHERE json_extract(serialized, \'\$.vectorClock\') IS NULL ORDER BY created_at ASC',
      variables: [],
      readsFrom: {consumptionEvents},
    ).asyncMap(consumptionEvents.mapFromRow);
  }

  Selectable<SumConsumptionByTaskResult> sumConsumptionByTask(String? taskId) {
    return customSelect(
      'SELECT COUNT(*) AS call_count, COUNT(energy_kwh) AS impact_call_count, CAST(COALESCE(SUM(input_tokens), 0) AS INT) AS input_tokens, CAST(COALESCE(SUM(output_tokens), 0) AS INT) AS output_tokens, CAST(COALESCE(SUM(cached_input_tokens), 0) AS INT) AS cached_input_tokens, CAST(COALESCE(SUM(thoughts_tokens), 0) AS INT) AS thoughts_tokens, CAST(COALESCE(SUM(total_tokens), 0) AS INT) AS total_tokens, COALESCE(SUM(credits), 0.0) AS credits, COALESCE(SUM(energy_kwh), 0.0) AS energy_kwh, COALESCE(SUM(carbon_g_co2), 0.0) AS carbon_g_co2, COALESCE(SUM(water_liters), 0.0) AS water_liters FROM consumption_events WHERE task_id = ?1',
      variables: [Variable<String>(taskId)],
      readsFrom: {consumptionEvents},
    ).map(
      (QueryRow row) => SumConsumptionByTaskResult(
        callCount: row.read<int>('call_count'),
        impactCallCount: row.read<int>('impact_call_count'),
        inputTokens: row.read<int>('input_tokens'),
        outputTokens: row.read<int>('output_tokens'),
        cachedInputTokens: row.read<int>('cached_input_tokens'),
        thoughtsTokens: row.read<int>('thoughts_tokens'),
        totalTokens: row.read<int>('total_tokens'),
        credits: row.read<double>('credits'),
        energyKwh: row.read<double>('energy_kwh'),
        carbonGCo2: row.read<double>('carbon_g_co2'),
        waterLiters: row.read<double>('water_liters'),
      ),
    );
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    consumptionEvents,
    idxConsumptionTaskCreated,
    idxConsumptionCategoryCreated,
    idxConsumptionCreated,
    idxConsumptionAttribution,
    aiWorkAttributions,
    idxAttributionOutput,
    idxAttributionTaskCreated,
    idxAttributionActorCreated,
    idxAttributionTypeCreated,
  ];
}

typedef $ConsumptionEventsCreateCompanionBuilder =
    ConsumptionEventsCompanion Function({
      required String id,
      Value<String?> parentId,
      required DateTime createdAt,
      Value<String?> attributionId,
      Value<String?> taskId,
      Value<String?> categoryId,
      Value<String?> entryId,
      Value<String?> agentId,
      Value<String?> wakeRunKey,
      Value<String?> threadId,
      Value<int?> turnIndex,
      Value<String?> promptId,
      Value<String?> skillId,
      Value<String?> configId,
      required String providerType,
      Value<String?> modelId,
      Value<String?> providerModelId,
      required String responseType,
      Value<int?> durationMs,
      Value<int?> inputTokens,
      Value<int?> outputTokens,
      Value<int?> cachedInputTokens,
      Value<int?> thoughtsTokens,
      Value<int?> totalTokens,
      Value<double?> credits,
      Value<double?> energyKwh,
      Value<double?> carbonGCo2,
      Value<double?> waterLiters,
      Value<double?> renewablePercent,
      Value<double?> pue,
      Value<String?> dataCenter,
      Value<String?> upstreamProviderId,
      required String serialized,
      Value<int> schemaVersion,
      Value<int> rowid,
    });
typedef $ConsumptionEventsUpdateCompanionBuilder =
    ConsumptionEventsCompanion Function({
      Value<String> id,
      Value<String?> parentId,
      Value<DateTime> createdAt,
      Value<String?> attributionId,
      Value<String?> taskId,
      Value<String?> categoryId,
      Value<String?> entryId,
      Value<String?> agentId,
      Value<String?> wakeRunKey,
      Value<String?> threadId,
      Value<int?> turnIndex,
      Value<String?> promptId,
      Value<String?> skillId,
      Value<String?> configId,
      Value<String> providerType,
      Value<String?> modelId,
      Value<String?> providerModelId,
      Value<String> responseType,
      Value<int?> durationMs,
      Value<int?> inputTokens,
      Value<int?> outputTokens,
      Value<int?> cachedInputTokens,
      Value<int?> thoughtsTokens,
      Value<int?> totalTokens,
      Value<double?> credits,
      Value<double?> energyKwh,
      Value<double?> carbonGCo2,
      Value<double?> waterLiters,
      Value<double?> renewablePercent,
      Value<double?> pue,
      Value<String?> dataCenter,
      Value<String?> upstreamProviderId,
      Value<String> serialized,
      Value<int> schemaVersion,
      Value<int> rowid,
    });

class $ConsumptionEventsFilterComposer
    extends Composer<_$ConsumptionDatabase, ConsumptionEvents> {
  $ConsumptionEventsFilterComposer({
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

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attributionId => $composableBuilder(
    column: $table.attributionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wakeRunKey => $composableBuilder(
    column: $table.wakeRunKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get threadId => $composableBuilder(
    column: $table.threadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get turnIndex => $composableBuilder(
    column: $table.turnIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promptId => $composableBuilder(
    column: $table.promptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configId => $composableBuilder(
    column: $table.configId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerModelId => $composableBuilder(
    column: $table.providerModelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responseType => $composableBuilder(
    column: $table.responseType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedInputTokens => $composableBuilder(
    column: $table.cachedInputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get thoughtsTokens => $composableBuilder(
    column: $table.thoughtsTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalTokens => $composableBuilder(
    column: $table.totalTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get credits => $composableBuilder(
    column: $table.credits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get energyKwh => $composableBuilder(
    column: $table.energyKwh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbonGCo2 => $composableBuilder(
    column: $table.carbonGCo2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get waterLiters => $composableBuilder(
    column: $table.waterLiters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get renewablePercent => $composableBuilder(
    column: $table.renewablePercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pue => $composableBuilder(
    column: $table.pue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataCenter => $composableBuilder(
    column: $table.dataCenter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get upstreamProviderId => $composableBuilder(
    column: $table.upstreamProviderId,
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

class $ConsumptionEventsOrderingComposer
    extends Composer<_$ConsumptionDatabase, ConsumptionEvents> {
  $ConsumptionEventsOrderingComposer({
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

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attributionId => $composableBuilder(
    column: $table.attributionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wakeRunKey => $composableBuilder(
    column: $table.wakeRunKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get threadId => $composableBuilder(
    column: $table.threadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get turnIndex => $composableBuilder(
    column: $table.turnIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promptId => $composableBuilder(
    column: $table.promptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configId => $composableBuilder(
    column: $table.configId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerModelId => $composableBuilder(
    column: $table.providerModelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responseType => $composableBuilder(
    column: $table.responseType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedInputTokens => $composableBuilder(
    column: $table.cachedInputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get thoughtsTokens => $composableBuilder(
    column: $table.thoughtsTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalTokens => $composableBuilder(
    column: $table.totalTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get credits => $composableBuilder(
    column: $table.credits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get energyKwh => $composableBuilder(
    column: $table.energyKwh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbonGCo2 => $composableBuilder(
    column: $table.carbonGCo2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get waterLiters => $composableBuilder(
    column: $table.waterLiters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get renewablePercent => $composableBuilder(
    column: $table.renewablePercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pue => $composableBuilder(
    column: $table.pue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataCenter => $composableBuilder(
    column: $table.dataCenter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get upstreamProviderId => $composableBuilder(
    column: $table.upstreamProviderId,
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

class $ConsumptionEventsAnnotationComposer
    extends Composer<_$ConsumptionDatabase, ConsumptionEvents> {
  $ConsumptionEventsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get attributionId => $composableBuilder(
    column: $table.attributionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get wakeRunKey => $composableBuilder(
    column: $table.wakeRunKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get threadId =>
      $composableBuilder(column: $table.threadId, builder: (column) => column);

  GeneratedColumn<int> get turnIndex =>
      $composableBuilder(column: $table.turnIndex, builder: (column) => column);

  GeneratedColumn<String> get promptId =>
      $composableBuilder(column: $table.promptId, builder: (column) => column);

  GeneratedColumn<String> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<String> get configId =>
      $composableBuilder(column: $table.configId, builder: (column) => column);

  GeneratedColumn<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<String> get providerModelId => $composableBuilder(
    column: $table.providerModelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get responseType => $composableBuilder(
    column: $table.responseType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedInputTokens => $composableBuilder(
    column: $table.cachedInputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get thoughtsTokens => $composableBuilder(
    column: $table.thoughtsTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalTokens => $composableBuilder(
    column: $table.totalTokens,
    builder: (column) => column,
  );

  GeneratedColumn<double> get credits =>
      $composableBuilder(column: $table.credits, builder: (column) => column);

  GeneratedColumn<double> get energyKwh =>
      $composableBuilder(column: $table.energyKwh, builder: (column) => column);

  GeneratedColumn<double> get carbonGCo2 => $composableBuilder(
    column: $table.carbonGCo2,
    builder: (column) => column,
  );

  GeneratedColumn<double> get waterLiters => $composableBuilder(
    column: $table.waterLiters,
    builder: (column) => column,
  );

  GeneratedColumn<double> get renewablePercent => $composableBuilder(
    column: $table.renewablePercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pue =>
      $composableBuilder(column: $table.pue, builder: (column) => column);

  GeneratedColumn<String> get dataCenter => $composableBuilder(
    column: $table.dataCenter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get upstreamProviderId => $composableBuilder(
    column: $table.upstreamProviderId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serialized => $composableBuilder(
    column: $table.serialized,
    builder: (column) => column,
  );

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );
}

class $ConsumptionEventsTableManager
    extends
        RootTableManager<
          _$ConsumptionDatabase,
          ConsumptionEvents,
          ConsumptionEvent,
          $ConsumptionEventsFilterComposer,
          $ConsumptionEventsOrderingComposer,
          $ConsumptionEventsAnnotationComposer,
          $ConsumptionEventsCreateCompanionBuilder,
          $ConsumptionEventsUpdateCompanionBuilder,
          (
            ConsumptionEvent,
            BaseReferences<
              _$ConsumptionDatabase,
              ConsumptionEvents,
              ConsumptionEvent
            >,
          ),
          ConsumptionEvent,
          PrefetchHooks Function()
        > {
  $ConsumptionEventsTableManager(
    _$ConsumptionDatabase db,
    ConsumptionEvents table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ConsumptionEventsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ConsumptionEventsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ConsumptionEventsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> attributionId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> entryId = const Value.absent(),
                Value<String?> agentId = const Value.absent(),
                Value<String?> wakeRunKey = const Value.absent(),
                Value<String?> threadId = const Value.absent(),
                Value<int?> turnIndex = const Value.absent(),
                Value<String?> promptId = const Value.absent(),
                Value<String?> skillId = const Value.absent(),
                Value<String?> configId = const Value.absent(),
                Value<String> providerType = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                Value<String?> providerModelId = const Value.absent(),
                Value<String> responseType = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> inputTokens = const Value.absent(),
                Value<int?> outputTokens = const Value.absent(),
                Value<int?> cachedInputTokens = const Value.absent(),
                Value<int?> thoughtsTokens = const Value.absent(),
                Value<int?> totalTokens = const Value.absent(),
                Value<double?> credits = const Value.absent(),
                Value<double?> energyKwh = const Value.absent(),
                Value<double?> carbonGCo2 = const Value.absent(),
                Value<double?> waterLiters = const Value.absent(),
                Value<double?> renewablePercent = const Value.absent(),
                Value<double?> pue = const Value.absent(),
                Value<String?> dataCenter = const Value.absent(),
                Value<String?> upstreamProviderId = const Value.absent(),
                Value<String> serialized = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConsumptionEventsCompanion(
                id: id,
                parentId: parentId,
                createdAt: createdAt,
                attributionId: attributionId,
                taskId: taskId,
                categoryId: categoryId,
                entryId: entryId,
                agentId: agentId,
                wakeRunKey: wakeRunKey,
                threadId: threadId,
                turnIndex: turnIndex,
                promptId: promptId,
                skillId: skillId,
                configId: configId,
                providerType: providerType,
                modelId: modelId,
                providerModelId: providerModelId,
                responseType: responseType,
                durationMs: durationMs,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cachedInputTokens: cachedInputTokens,
                thoughtsTokens: thoughtsTokens,
                totalTokens: totalTokens,
                credits: credits,
                energyKwh: energyKwh,
                carbonGCo2: carbonGCo2,
                waterLiters: waterLiters,
                renewablePercent: renewablePercent,
                pue: pue,
                dataCenter: dataCenter,
                upstreamProviderId: upstreamProviderId,
                serialized: serialized,
                schemaVersion: schemaVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> parentId = const Value.absent(),
                required DateTime createdAt,
                Value<String?> attributionId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> entryId = const Value.absent(),
                Value<String?> agentId = const Value.absent(),
                Value<String?> wakeRunKey = const Value.absent(),
                Value<String?> threadId = const Value.absent(),
                Value<int?> turnIndex = const Value.absent(),
                Value<String?> promptId = const Value.absent(),
                Value<String?> skillId = const Value.absent(),
                Value<String?> configId = const Value.absent(),
                required String providerType,
                Value<String?> modelId = const Value.absent(),
                Value<String?> providerModelId = const Value.absent(),
                required String responseType,
                Value<int?> durationMs = const Value.absent(),
                Value<int?> inputTokens = const Value.absent(),
                Value<int?> outputTokens = const Value.absent(),
                Value<int?> cachedInputTokens = const Value.absent(),
                Value<int?> thoughtsTokens = const Value.absent(),
                Value<int?> totalTokens = const Value.absent(),
                Value<double?> credits = const Value.absent(),
                Value<double?> energyKwh = const Value.absent(),
                Value<double?> carbonGCo2 = const Value.absent(),
                Value<double?> waterLiters = const Value.absent(),
                Value<double?> renewablePercent = const Value.absent(),
                Value<double?> pue = const Value.absent(),
                Value<String?> dataCenter = const Value.absent(),
                Value<String?> upstreamProviderId = const Value.absent(),
                required String serialized,
                Value<int> schemaVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConsumptionEventsCompanion.insert(
                id: id,
                parentId: parentId,
                createdAt: createdAt,
                attributionId: attributionId,
                taskId: taskId,
                categoryId: categoryId,
                entryId: entryId,
                agentId: agentId,
                wakeRunKey: wakeRunKey,
                threadId: threadId,
                turnIndex: turnIndex,
                promptId: promptId,
                skillId: skillId,
                configId: configId,
                providerType: providerType,
                modelId: modelId,
                providerModelId: providerModelId,
                responseType: responseType,
                durationMs: durationMs,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cachedInputTokens: cachedInputTokens,
                thoughtsTokens: thoughtsTokens,
                totalTokens: totalTokens,
                credits: credits,
                energyKwh: energyKwh,
                carbonGCo2: carbonGCo2,
                waterLiters: waterLiters,
                renewablePercent: renewablePercent,
                pue: pue,
                dataCenter: dataCenter,
                upstreamProviderId: upstreamProviderId,
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

typedef $ConsumptionEventsProcessedTableManager =
    ProcessedTableManager<
      _$ConsumptionDatabase,
      ConsumptionEvents,
      ConsumptionEvent,
      $ConsumptionEventsFilterComposer,
      $ConsumptionEventsOrderingComposer,
      $ConsumptionEventsAnnotationComposer,
      $ConsumptionEventsCreateCompanionBuilder,
      $ConsumptionEventsUpdateCompanionBuilder,
      (
        ConsumptionEvent,
        BaseReferences<
          _$ConsumptionDatabase,
          ConsumptionEvents,
          ConsumptionEvent
        >,
      ),
      ConsumptionEvent,
      PrefetchHooks Function()
    >;
typedef $AiWorkAttributionsCreateCompanionBuilder =
    AiWorkAttributionsCompanion Function({
      required String id,
      required String workType,
      required String status,
      required String initiatorType,
      required String initiatorId,
      required String initiatorDisplayName,
      required String triggerType,
      required DateTime startedAt,
      required DateTime completedAt,
      Value<String?> parentAttributionId,
      Value<String?> taskId,
      Value<String?> categoryId,
      Value<String?> primaryOutputType,
      Value<String?> primaryOutputId,
      Value<String?> primaryOutputSubId,
      required String serialized,
      Value<int> schemaVersion,
      Value<int> rowid,
    });
typedef $AiWorkAttributionsUpdateCompanionBuilder =
    AiWorkAttributionsCompanion Function({
      Value<String> id,
      Value<String> workType,
      Value<String> status,
      Value<String> initiatorType,
      Value<String> initiatorId,
      Value<String> initiatorDisplayName,
      Value<String> triggerType,
      Value<DateTime> startedAt,
      Value<DateTime> completedAt,
      Value<String?> parentAttributionId,
      Value<String?> taskId,
      Value<String?> categoryId,
      Value<String?> primaryOutputType,
      Value<String?> primaryOutputId,
      Value<String?> primaryOutputSubId,
      Value<String> serialized,
      Value<int> schemaVersion,
      Value<int> rowid,
    });

class $AiWorkAttributionsFilterComposer
    extends Composer<_$ConsumptionDatabase, AiWorkAttributions> {
  $AiWorkAttributionsFilterComposer({
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

  ColumnFilters<String> get workType => $composableBuilder(
    column: $table.workType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get initiatorType => $composableBuilder(
    column: $table.initiatorType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get initiatorId => $composableBuilder(
    column: $table.initiatorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get initiatorDisplayName => $composableBuilder(
    column: $table.initiatorDisplayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggerType => $composableBuilder(
    column: $table.triggerType,
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

  ColumnFilters<String> get parentAttributionId => $composableBuilder(
    column: $table.parentAttributionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryOutputType => $composableBuilder(
    column: $table.primaryOutputType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryOutputId => $composableBuilder(
    column: $table.primaryOutputId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryOutputSubId => $composableBuilder(
    column: $table.primaryOutputSubId,
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

class $AiWorkAttributionsOrderingComposer
    extends Composer<_$ConsumptionDatabase, AiWorkAttributions> {
  $AiWorkAttributionsOrderingComposer({
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

  ColumnOrderings<String> get workType => $composableBuilder(
    column: $table.workType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get initiatorType => $composableBuilder(
    column: $table.initiatorType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get initiatorId => $composableBuilder(
    column: $table.initiatorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get initiatorDisplayName => $composableBuilder(
    column: $table.initiatorDisplayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggerType => $composableBuilder(
    column: $table.triggerType,
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

  ColumnOrderings<String> get parentAttributionId => $composableBuilder(
    column: $table.parentAttributionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryOutputType => $composableBuilder(
    column: $table.primaryOutputType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryOutputId => $composableBuilder(
    column: $table.primaryOutputId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryOutputSubId => $composableBuilder(
    column: $table.primaryOutputSubId,
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

class $AiWorkAttributionsAnnotationComposer
    extends Composer<_$ConsumptionDatabase, AiWorkAttributions> {
  $AiWorkAttributionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workType =>
      $composableBuilder(column: $table.workType, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get initiatorType => $composableBuilder(
    column: $table.initiatorType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get initiatorId => $composableBuilder(
    column: $table.initiatorId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get initiatorDisplayName => $composableBuilder(
    column: $table.initiatorDisplayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get triggerType => $composableBuilder(
    column: $table.triggerType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentAttributionId => $composableBuilder(
    column: $table.parentAttributionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get primaryOutputType => $composableBuilder(
    column: $table.primaryOutputType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get primaryOutputId => $composableBuilder(
    column: $table.primaryOutputId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get primaryOutputSubId => $composableBuilder(
    column: $table.primaryOutputSubId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serialized => $composableBuilder(
    column: $table.serialized,
    builder: (column) => column,
  );

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );
}

class $AiWorkAttributionsTableManager
    extends
        RootTableManager<
          _$ConsumptionDatabase,
          AiWorkAttributions,
          AiWorkAttribution,
          $AiWorkAttributionsFilterComposer,
          $AiWorkAttributionsOrderingComposer,
          $AiWorkAttributionsAnnotationComposer,
          $AiWorkAttributionsCreateCompanionBuilder,
          $AiWorkAttributionsUpdateCompanionBuilder,
          (
            AiWorkAttribution,
            BaseReferences<
              _$ConsumptionDatabase,
              AiWorkAttributions,
              AiWorkAttribution
            >,
          ),
          AiWorkAttribution,
          PrefetchHooks Function()
        > {
  $AiWorkAttributionsTableManager(
    _$ConsumptionDatabase db,
    AiWorkAttributions table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AiWorkAttributionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AiWorkAttributionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AiWorkAttributionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> workType = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> initiatorType = const Value.absent(),
                Value<String> initiatorId = const Value.absent(),
                Value<String> initiatorDisplayName = const Value.absent(),
                Value<String> triggerType = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<String?> parentAttributionId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> primaryOutputType = const Value.absent(),
                Value<String?> primaryOutputId = const Value.absent(),
                Value<String?> primaryOutputSubId = const Value.absent(),
                Value<String> serialized = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiWorkAttributionsCompanion(
                id: id,
                workType: workType,
                status: status,
                initiatorType: initiatorType,
                initiatorId: initiatorId,
                initiatorDisplayName: initiatorDisplayName,
                triggerType: triggerType,
                startedAt: startedAt,
                completedAt: completedAt,
                parentAttributionId: parentAttributionId,
                taskId: taskId,
                categoryId: categoryId,
                primaryOutputType: primaryOutputType,
                primaryOutputId: primaryOutputId,
                primaryOutputSubId: primaryOutputSubId,
                serialized: serialized,
                schemaVersion: schemaVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String workType,
                required String status,
                required String initiatorType,
                required String initiatorId,
                required String initiatorDisplayName,
                required String triggerType,
                required DateTime startedAt,
                required DateTime completedAt,
                Value<String?> parentAttributionId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> primaryOutputType = const Value.absent(),
                Value<String?> primaryOutputId = const Value.absent(),
                Value<String?> primaryOutputSubId = const Value.absent(),
                required String serialized,
                Value<int> schemaVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiWorkAttributionsCompanion.insert(
                id: id,
                workType: workType,
                status: status,
                initiatorType: initiatorType,
                initiatorId: initiatorId,
                initiatorDisplayName: initiatorDisplayName,
                triggerType: triggerType,
                startedAt: startedAt,
                completedAt: completedAt,
                parentAttributionId: parentAttributionId,
                taskId: taskId,
                categoryId: categoryId,
                primaryOutputType: primaryOutputType,
                primaryOutputId: primaryOutputId,
                primaryOutputSubId: primaryOutputSubId,
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

typedef $AiWorkAttributionsProcessedTableManager =
    ProcessedTableManager<
      _$ConsumptionDatabase,
      AiWorkAttributions,
      AiWorkAttribution,
      $AiWorkAttributionsFilterComposer,
      $AiWorkAttributionsOrderingComposer,
      $AiWorkAttributionsAnnotationComposer,
      $AiWorkAttributionsCreateCompanionBuilder,
      $AiWorkAttributionsUpdateCompanionBuilder,
      (
        AiWorkAttribution,
        BaseReferences<
          _$ConsumptionDatabase,
          AiWorkAttributions,
          AiWorkAttribution
        >,
      ),
      AiWorkAttribution,
      PrefetchHooks Function()
    >;

class $ConsumptionDatabaseManager {
  final _$ConsumptionDatabase _db;
  $ConsumptionDatabaseManager(this._db);
  $ConsumptionEventsTableManager get consumptionEvents =>
      $ConsumptionEventsTableManager(_db, _db.consumptionEvents);
  $AiWorkAttributionsTableManager get aiWorkAttributions =>
      $AiWorkAttributionsTableManager(_db, _db.aiWorkAttributions);
}

class SumConsumptionByTaskResult {
  final int callCount;
  final int impactCallCount;
  final int inputTokens;
  final int outputTokens;
  final int cachedInputTokens;
  final int thoughtsTokens;
  final int totalTokens;
  final double credits;
  final double energyKwh;
  final double carbonGCo2;
  final double waterLiters;
  SumConsumptionByTaskResult({
    required this.callCount,
    required this.impactCallCount,
    required this.inputTokens,
    required this.outputTokens,
    required this.cachedInputTokens,
    required this.thoughtsTokens,
    required this.totalTokens,
    required this.credits,
    required this.energyKwh,
    required this.carbonGCo2,
    required this.waterLiters,
  });
}
