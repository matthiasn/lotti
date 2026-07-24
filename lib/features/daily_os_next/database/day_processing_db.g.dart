// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_processing_db.dart';

// ignore_for_file: type=lint
class DayProcessingJobs extends Table
    with TableInfo<DayProcessingJobs, DayProcessingJobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DayProcessingJobs(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _dayIdMeta = const VerificationMeta('dayId');
  late final GeneratedColumn<String> dayId = GeneratedColumn<String>(
    'day_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _runKeysMeta = const VerificationMeta(
    'runKeys',
  );
  late final GeneratedColumn<String> runKeys = GeneratedColumn<String>(
    'run_keys',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _requestedAtMeta = const VerificationMeta(
    'requestedAt',
  );
  late final GeneratedColumn<int> requestedAt = GeneratedColumn<int>(
    'requested_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  late final GeneratedColumn<int> nextAttemptAt = GeneratedColumn<int>(
    'next_attempt_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  late final GeneratedColumn<int> generation = GeneratedColumn<int>(
    'generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _claimTokenMeta = const VerificationMeta(
    'claimToken',
  );
  late final GeneratedColumn<String> claimToken = GeneratedColumn<String>(
    'claim_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _leaseUntilMeta = const VerificationMeta(
    'leaseUntil',
  );
  late final GeneratedColumn<int> leaseUntil = GeneratedColumn<int>(
    'lease_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _retryNotBeforeMeta = const VerificationMeta(
    'retryNotBefore',
  );
  late final GeneratedColumn<int> retryNotBefore = GeneratedColumn<int>(
    'retry_not_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _lastFailureClassMeta = const VerificationMeta(
    'lastFailureClass',
  );
  late final GeneratedColumn<String> lastFailureClass = GeneratedColumn<String>(
    'last_failure_class',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
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
  static const VerificationMeta _resultTranscriptMeta = const VerificationMeta(
    'resultTranscript',
  );
  late final GeneratedColumn<String> resultTranscript = GeneratedColumn<String>(
    'result_transcript',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _resultEntityIdMeta = const VerificationMeta(
    'resultEntityId',
  );
  late final GeneratedColumn<String> resultEntityId = GeneratedColumn<String>(
    'result_entity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    status,
    kind,
    dayId,
    payload,
    runKeys,
    createdAt,
    updatedAt,
    requestedAt,
    nextAttemptAt,
    attempts,
    generation,
    claimToken,
    leaseUntil,
    retryNotBefore,
    lastFailureClass,
    lastError,
    resultTranscript,
    resultEntityId,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_processing_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayProcessingJobRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('day_id')) {
      context.handle(
        _dayIdMeta,
        dayId.isAcceptableOrUnknown(data['day_id']!, _dayIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dayIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('run_keys')) {
      context.handle(
        _runKeysMeta,
        runKeys.isAcceptableOrUnknown(data['run_keys']!, _runKeysMeta),
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
    if (data.containsKey('requested_at')) {
      context.handle(
        _requestedAtMeta,
        requestedAt.isAcceptableOrUnknown(
          data['requested_at']!,
          _requestedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestedAtMeta);
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    }
    if (data.containsKey('claim_token')) {
      context.handle(
        _claimTokenMeta,
        claimToken.isAcceptableOrUnknown(data['claim_token']!, _claimTokenMeta),
      );
    }
    if (data.containsKey('lease_until')) {
      context.handle(
        _leaseUntilMeta,
        leaseUntil.isAcceptableOrUnknown(data['lease_until']!, _leaseUntilMeta),
      );
    }
    if (data.containsKey('retry_not_before')) {
      context.handle(
        _retryNotBeforeMeta,
        retryNotBefore.isAcceptableOrUnknown(
          data['retry_not_before']!,
          _retryNotBeforeMeta,
        ),
      );
    }
    if (data.containsKey('last_failure_class')) {
      context.handle(
        _lastFailureClassMeta,
        lastFailureClass.isAcceptableOrUnknown(
          data['last_failure_class']!,
          _lastFailureClassMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('result_transcript')) {
      context.handle(
        _resultTranscriptMeta,
        resultTranscript.isAcceptableOrUnknown(
          data['result_transcript']!,
          _resultTranscriptMeta,
        ),
      );
    }
    if (data.containsKey('result_entity_id')) {
      context.handle(
        _resultEntityIdMeta,
        resultEntityId.isAcceptableOrUnknown(
          data['result_entity_id']!,
          _resultEntityIdMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DayProcessingJobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayProcessingJobRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      dayId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      runKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_keys'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      requestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}requested_at'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_attempt_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generation'],
      )!,
      claimToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}claim_token'],
      ),
      leaseUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lease_until'],
      ),
      retryNotBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_not_before'],
      ),
      lastFailureClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_failure_class'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      resultTranscript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_transcript'],
      ),
      resultEntityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_entity_id'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  DayProcessingJobs createAlias(String alias) {
    return DayProcessingJobs(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DayProcessingJobRow extends DataClass
    implements Insertable<DayProcessingJobRow> {
  /// Deterministic per intent (`transcribe_<sessionId>`, `parse_<captureId>`,
  /// `draft_<dayId>`, `refine_<dayId>_<suffix>`), so enqueue is an idempotent
  /// upsert and the file migration cannot duplicate a job.
  final String id;

  /// DayProcessingJobStatus.name. Text rather than an enum index so the set
  /// stays readable in the partial indexes below and survives reordering.
  final String status;

  /// DayProcessingJobKind.name.
  final String kind;
  final String dayId;

  /// DayProcessingPayload.toJson() for `kind`.
  final String payload;

  /// JSON array of wake run keys, newest last. NULL when none recorded.
  final String? runKeys;
  final int createdAt;
  final int updatedAt;

  /// When the work this row currently represents was requested; moves forward
  /// on re-arm and is the artifact baseline for agent jobs.
  final int requestedAt;
  final int nextAttemptAt;
  final int attempts;
  final int generation;

  /// Claim fencing. A claimed mutation must present the current token, so a
  /// worker whose claim was revoked cannot write over the terminal state.
  final String? claimToken;
  final int? leaseUntil;

  /// Hard retry boundary from a provider `Retry-After`.
  final int? retryNotBefore;
  final String? lastFailureClass;
  final String? lastError;

  /// Provider output staged before the journal side effect, so a local commit
  /// failure retries without repeating inference.
  final String? resultTranscript;

  /// Agent-job output id: the DayPlanEntity id for drafts, ChangeSet for
  /// refines.
  final String? resultEntityId;
  final int? completedAt;
  const DayProcessingJobRow({
    required this.id,
    required this.status,
    required this.kind,
    required this.dayId,
    required this.payload,
    this.runKeys,
    required this.createdAt,
    required this.updatedAt,
    required this.requestedAt,
    required this.nextAttemptAt,
    required this.attempts,
    required this.generation,
    this.claimToken,
    this.leaseUntil,
    this.retryNotBefore,
    this.lastFailureClass,
    this.lastError,
    this.resultTranscript,
    this.resultEntityId,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['status'] = Variable<String>(status);
    map['kind'] = Variable<String>(kind);
    map['day_id'] = Variable<String>(dayId);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || runKeys != null) {
      map['run_keys'] = Variable<String>(runKeys);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['requested_at'] = Variable<int>(requestedAt);
    map['next_attempt_at'] = Variable<int>(nextAttemptAt);
    map['attempts'] = Variable<int>(attempts);
    map['generation'] = Variable<int>(generation);
    if (!nullToAbsent || claimToken != null) {
      map['claim_token'] = Variable<String>(claimToken);
    }
    if (!nullToAbsent || leaseUntil != null) {
      map['lease_until'] = Variable<int>(leaseUntil);
    }
    if (!nullToAbsent || retryNotBefore != null) {
      map['retry_not_before'] = Variable<int>(retryNotBefore);
    }
    if (!nullToAbsent || lastFailureClass != null) {
      map['last_failure_class'] = Variable<String>(lastFailureClass);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || resultTranscript != null) {
      map['result_transcript'] = Variable<String>(resultTranscript);
    }
    if (!nullToAbsent || resultEntityId != null) {
      map['result_entity_id'] = Variable<String>(resultEntityId);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    return map;
  }

  DayProcessingJobsCompanion toCompanion(bool nullToAbsent) {
    return DayProcessingJobsCompanion(
      id: Value(id),
      status: Value(status),
      kind: Value(kind),
      dayId: Value(dayId),
      payload: Value(payload),
      runKeys: runKeys == null && nullToAbsent
          ? const Value.absent()
          : Value(runKeys),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      requestedAt: Value(requestedAt),
      nextAttemptAt: Value(nextAttemptAt),
      attempts: Value(attempts),
      generation: Value(generation),
      claimToken: claimToken == null && nullToAbsent
          ? const Value.absent()
          : Value(claimToken),
      leaseUntil: leaseUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseUntil),
      retryNotBefore: retryNotBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(retryNotBefore),
      lastFailureClass: lastFailureClass == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFailureClass),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      resultTranscript: resultTranscript == null && nullToAbsent
          ? const Value.absent()
          : Value(resultTranscript),
      resultEntityId: resultEntityId == null && nullToAbsent
          ? const Value.absent()
          : Value(resultEntityId),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory DayProcessingJobRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayProcessingJobRow(
      id: serializer.fromJson<String>(json['id']),
      status: serializer.fromJson<String>(json['status']),
      kind: serializer.fromJson<String>(json['kind']),
      dayId: serializer.fromJson<String>(json['day_id']),
      payload: serializer.fromJson<String>(json['payload']),
      runKeys: serializer.fromJson<String?>(json['run_keys']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      requestedAt: serializer.fromJson<int>(json['requested_at']),
      nextAttemptAt: serializer.fromJson<int>(json['next_attempt_at']),
      attempts: serializer.fromJson<int>(json['attempts']),
      generation: serializer.fromJson<int>(json['generation']),
      claimToken: serializer.fromJson<String?>(json['claim_token']),
      leaseUntil: serializer.fromJson<int?>(json['lease_until']),
      retryNotBefore: serializer.fromJson<int?>(json['retry_not_before']),
      lastFailureClass: serializer.fromJson<String?>(
        json['last_failure_class'],
      ),
      lastError: serializer.fromJson<String?>(json['last_error']),
      resultTranscript: serializer.fromJson<String?>(json['result_transcript']),
      resultEntityId: serializer.fromJson<String?>(json['result_entity_id']),
      completedAt: serializer.fromJson<int?>(json['completed_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'status': serializer.toJson<String>(status),
      'kind': serializer.toJson<String>(kind),
      'day_id': serializer.toJson<String>(dayId),
      'payload': serializer.toJson<String>(payload),
      'run_keys': serializer.toJson<String?>(runKeys),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'requested_at': serializer.toJson<int>(requestedAt),
      'next_attempt_at': serializer.toJson<int>(nextAttemptAt),
      'attempts': serializer.toJson<int>(attempts),
      'generation': serializer.toJson<int>(generation),
      'claim_token': serializer.toJson<String?>(claimToken),
      'lease_until': serializer.toJson<int?>(leaseUntil),
      'retry_not_before': serializer.toJson<int?>(retryNotBefore),
      'last_failure_class': serializer.toJson<String?>(lastFailureClass),
      'last_error': serializer.toJson<String?>(lastError),
      'result_transcript': serializer.toJson<String?>(resultTranscript),
      'result_entity_id': serializer.toJson<String?>(resultEntityId),
      'completed_at': serializer.toJson<int?>(completedAt),
    };
  }

  DayProcessingJobRow copyWith({
    String? id,
    String? status,
    String? kind,
    String? dayId,
    String? payload,
    Value<String?> runKeys = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    int? requestedAt,
    int? nextAttemptAt,
    int? attempts,
    int? generation,
    Value<String?> claimToken = const Value.absent(),
    Value<int?> leaseUntil = const Value.absent(),
    Value<int?> retryNotBefore = const Value.absent(),
    Value<String?> lastFailureClass = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    Value<String?> resultTranscript = const Value.absent(),
    Value<String?> resultEntityId = const Value.absent(),
    Value<int?> completedAt = const Value.absent(),
  }) => DayProcessingJobRow(
    id: id ?? this.id,
    status: status ?? this.status,
    kind: kind ?? this.kind,
    dayId: dayId ?? this.dayId,
    payload: payload ?? this.payload,
    runKeys: runKeys.present ? runKeys.value : this.runKeys,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    requestedAt: requestedAt ?? this.requestedAt,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    attempts: attempts ?? this.attempts,
    generation: generation ?? this.generation,
    claimToken: claimToken.present ? claimToken.value : this.claimToken,
    leaseUntil: leaseUntil.present ? leaseUntil.value : this.leaseUntil,
    retryNotBefore: retryNotBefore.present
        ? retryNotBefore.value
        : this.retryNotBefore,
    lastFailureClass: lastFailureClass.present
        ? lastFailureClass.value
        : this.lastFailureClass,
    lastError: lastError.present ? lastError.value : this.lastError,
    resultTranscript: resultTranscript.present
        ? resultTranscript.value
        : this.resultTranscript,
    resultEntityId: resultEntityId.present
        ? resultEntityId.value
        : this.resultEntityId,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DayProcessingJobRow copyWithCompanion(DayProcessingJobsCompanion data) {
    return DayProcessingJobRow(
      id: data.id.present ? data.id.value : this.id,
      status: data.status.present ? data.status.value : this.status,
      kind: data.kind.present ? data.kind.value : this.kind,
      dayId: data.dayId.present ? data.dayId.value : this.dayId,
      payload: data.payload.present ? data.payload.value : this.payload,
      runKeys: data.runKeys.present ? data.runKeys.value : this.runKeys,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      requestedAt: data.requestedAt.present
          ? data.requestedAt.value
          : this.requestedAt,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
      claimToken: data.claimToken.present
          ? data.claimToken.value
          : this.claimToken,
      leaseUntil: data.leaseUntil.present
          ? data.leaseUntil.value
          : this.leaseUntil,
      retryNotBefore: data.retryNotBefore.present
          ? data.retryNotBefore.value
          : this.retryNotBefore,
      lastFailureClass: data.lastFailureClass.present
          ? data.lastFailureClass.value
          : this.lastFailureClass,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      resultTranscript: data.resultTranscript.present
          ? data.resultTranscript.value
          : this.resultTranscript,
      resultEntityId: data.resultEntityId.present
          ? data.resultEntityId.value
          : this.resultEntityId,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayProcessingJobRow(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('kind: $kind, ')
          ..write('dayId: $dayId, ')
          ..write('payload: $payload, ')
          ..write('runKeys: $runKeys, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('requestedAt: $requestedAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('attempts: $attempts, ')
          ..write('generation: $generation, ')
          ..write('claimToken: $claimToken, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('retryNotBefore: $retryNotBefore, ')
          ..write('lastFailureClass: $lastFailureClass, ')
          ..write('lastError: $lastError, ')
          ..write('resultTranscript: $resultTranscript, ')
          ..write('resultEntityId: $resultEntityId, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    status,
    kind,
    dayId,
    payload,
    runKeys,
    createdAt,
    updatedAt,
    requestedAt,
    nextAttemptAt,
    attempts,
    generation,
    claimToken,
    leaseUntil,
    retryNotBefore,
    lastFailureClass,
    lastError,
    resultTranscript,
    resultEntityId,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayProcessingJobRow &&
          other.id == this.id &&
          other.status == this.status &&
          other.kind == this.kind &&
          other.dayId == this.dayId &&
          other.payload == this.payload &&
          other.runKeys == this.runKeys &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.requestedAt == this.requestedAt &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.attempts == this.attempts &&
          other.generation == this.generation &&
          other.claimToken == this.claimToken &&
          other.leaseUntil == this.leaseUntil &&
          other.retryNotBefore == this.retryNotBefore &&
          other.lastFailureClass == this.lastFailureClass &&
          other.lastError == this.lastError &&
          other.resultTranscript == this.resultTranscript &&
          other.resultEntityId == this.resultEntityId &&
          other.completedAt == this.completedAt);
}

class DayProcessingJobsCompanion extends UpdateCompanion<DayProcessingJobRow> {
  final Value<String> id;
  final Value<String> status;
  final Value<String> kind;
  final Value<String> dayId;
  final Value<String> payload;
  final Value<String?> runKeys;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> requestedAt;
  final Value<int> nextAttemptAt;
  final Value<int> attempts;
  final Value<int> generation;
  final Value<String?> claimToken;
  final Value<int?> leaseUntil;
  final Value<int?> retryNotBefore;
  final Value<String?> lastFailureClass;
  final Value<String?> lastError;
  final Value<String?> resultTranscript;
  final Value<String?> resultEntityId;
  final Value<int?> completedAt;
  final Value<int> rowid;
  const DayProcessingJobsCompanion({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.kind = const Value.absent(),
    this.dayId = const Value.absent(),
    this.payload = const Value.absent(),
    this.runKeys = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.requestedAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.generation = const Value.absent(),
    this.claimToken = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.retryNotBefore = const Value.absent(),
    this.lastFailureClass = const Value.absent(),
    this.lastError = const Value.absent(),
    this.resultTranscript = const Value.absent(),
    this.resultEntityId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayProcessingJobsCompanion.insert({
    required String id,
    required String status,
    required String kind,
    required String dayId,
    required String payload,
    this.runKeys = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    required int requestedAt,
    required int nextAttemptAt,
    this.attempts = const Value.absent(),
    this.generation = const Value.absent(),
    this.claimToken = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.retryNotBefore = const Value.absent(),
    this.lastFailureClass = const Value.absent(),
    this.lastError = const Value.absent(),
    this.resultTranscript = const Value.absent(),
    this.resultEntityId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       status = Value(status),
       kind = Value(kind),
       dayId = Value(dayId),
       payload = Value(payload),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       requestedAt = Value(requestedAt),
       nextAttemptAt = Value(nextAttemptAt);
  static Insertable<DayProcessingJobRow> custom({
    Expression<String>? id,
    Expression<String>? status,
    Expression<String>? kind,
    Expression<String>? dayId,
    Expression<String>? payload,
    Expression<String>? runKeys,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? requestedAt,
    Expression<int>? nextAttemptAt,
    Expression<int>? attempts,
    Expression<int>? generation,
    Expression<String>? claimToken,
    Expression<int>? leaseUntil,
    Expression<int>? retryNotBefore,
    Expression<String>? lastFailureClass,
    Expression<String>? lastError,
    Expression<String>? resultTranscript,
    Expression<String>? resultEntityId,
    Expression<int>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (status != null) 'status': status,
      if (kind != null) 'kind': kind,
      if (dayId != null) 'day_id': dayId,
      if (payload != null) 'payload': payload,
      if (runKeys != null) 'run_keys': runKeys,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (requestedAt != null) 'requested_at': requestedAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (attempts != null) 'attempts': attempts,
      if (generation != null) 'generation': generation,
      if (claimToken != null) 'claim_token': claimToken,
      if (leaseUntil != null) 'lease_until': leaseUntil,
      if (retryNotBefore != null) 'retry_not_before': retryNotBefore,
      if (lastFailureClass != null) 'last_failure_class': lastFailureClass,
      if (lastError != null) 'last_error': lastError,
      if (resultTranscript != null) 'result_transcript': resultTranscript,
      if (resultEntityId != null) 'result_entity_id': resultEntityId,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayProcessingJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? status,
    Value<String>? kind,
    Value<String>? dayId,
    Value<String>? payload,
    Value<String?>? runKeys,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? requestedAt,
    Value<int>? nextAttemptAt,
    Value<int>? attempts,
    Value<int>? generation,
    Value<String?>? claimToken,
    Value<int?>? leaseUntil,
    Value<int?>? retryNotBefore,
    Value<String?>? lastFailureClass,
    Value<String?>? lastError,
    Value<String?>? resultTranscript,
    Value<String?>? resultEntityId,
    Value<int?>? completedAt,
    Value<int>? rowid,
  }) {
    return DayProcessingJobsCompanion(
      id: id ?? this.id,
      status: status ?? this.status,
      kind: kind ?? this.kind,
      dayId: dayId ?? this.dayId,
      payload: payload ?? this.payload,
      runKeys: runKeys ?? this.runKeys,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      requestedAt: requestedAt ?? this.requestedAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      attempts: attempts ?? this.attempts,
      generation: generation ?? this.generation,
      claimToken: claimToken ?? this.claimToken,
      leaseUntil: leaseUntil ?? this.leaseUntil,
      retryNotBefore: retryNotBefore ?? this.retryNotBefore,
      lastFailureClass: lastFailureClass ?? this.lastFailureClass,
      lastError: lastError ?? this.lastError,
      resultTranscript: resultTranscript ?? this.resultTranscript,
      resultEntityId: resultEntityId ?? this.resultEntityId,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (dayId.present) {
      map['day_id'] = Variable<String>(dayId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (runKeys.present) {
      map['run_keys'] = Variable<String>(runKeys.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (requestedAt.present) {
      map['requested_at'] = Variable<int>(requestedAt.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<int>(nextAttemptAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (generation.present) {
      map['generation'] = Variable<int>(generation.value);
    }
    if (claimToken.present) {
      map['claim_token'] = Variable<String>(claimToken.value);
    }
    if (leaseUntil.present) {
      map['lease_until'] = Variable<int>(leaseUntil.value);
    }
    if (retryNotBefore.present) {
      map['retry_not_before'] = Variable<int>(retryNotBefore.value);
    }
    if (lastFailureClass.present) {
      map['last_failure_class'] = Variable<String>(lastFailureClass.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (resultTranscript.present) {
      map['result_transcript'] = Variable<String>(resultTranscript.value);
    }
    if (resultEntityId.present) {
      map['result_entity_id'] = Variable<String>(resultEntityId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayProcessingJobsCompanion(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('kind: $kind, ')
          ..write('dayId: $dayId, ')
          ..write('payload: $payload, ')
          ..write('runKeys: $runKeys, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('requestedAt: $requestedAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('attempts: $attempts, ')
          ..write('generation: $generation, ')
          ..write('claimToken: $claimToken, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('retryNotBefore: $retryNotBefore, ')
          ..write('lastFailureClass: $lastFailureClass, ')
          ..write('lastError: $lastError, ')
          ..write('resultTranscript: $resultTranscript, ')
          ..write('resultEntityId: $resultEntityId, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class DayProcessingMigrations extends Table
    with TableInfo<DayProcessingMigrations, DayProcessingMigrationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DayProcessingMigrations(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _migrationKeyMeta = const VerificationMeta(
    'migrationKey',
  );
  late final GeneratedColumn<String> migrationKey = GeneratedColumn<String>(
    'migration_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [migrationKey, completedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_processing_migrations';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayProcessingMigrationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('migration_key')) {
      context.handle(
        _migrationKeyMeta,
        migrationKey.isAcceptableOrUnknown(
          data['migration_key']!,
          _migrationKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_migrationKeyMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {migrationKey};
  @override
  DayProcessingMigrationRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayProcessingMigrationRow(
      migrationKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}migration_key'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  DayProcessingMigrations createAlias(String alias) {
    return DayProcessingMigrations(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DayProcessingMigrationRow extends DataClass
    implements Insertable<DayProcessingMigrationRow> {
  final String migrationKey;
  final int completedAt;
  const DayProcessingMigrationRow({
    required this.migrationKey,
    required this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['migration_key'] = Variable<String>(migrationKey);
    map['completed_at'] = Variable<int>(completedAt);
    return map;
  }

  DayProcessingMigrationsCompanion toCompanion(bool nullToAbsent) {
    return DayProcessingMigrationsCompanion(
      migrationKey: Value(migrationKey),
      completedAt: Value(completedAt),
    );
  }

  factory DayProcessingMigrationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayProcessingMigrationRow(
      migrationKey: serializer.fromJson<String>(json['migration_key']),
      completedAt: serializer.fromJson<int>(json['completed_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'migration_key': serializer.toJson<String>(migrationKey),
      'completed_at': serializer.toJson<int>(completedAt),
    };
  }

  DayProcessingMigrationRow copyWith({
    String? migrationKey,
    int? completedAt,
  }) => DayProcessingMigrationRow(
    migrationKey: migrationKey ?? this.migrationKey,
    completedAt: completedAt ?? this.completedAt,
  );
  DayProcessingMigrationRow copyWithCompanion(
    DayProcessingMigrationsCompanion data,
  ) {
    return DayProcessingMigrationRow(
      migrationKey: data.migrationKey.present
          ? data.migrationKey.value
          : this.migrationKey,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayProcessingMigrationRow(')
          ..write('migrationKey: $migrationKey, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(migrationKey, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayProcessingMigrationRow &&
          other.migrationKey == this.migrationKey &&
          other.completedAt == this.completedAt);
}

class DayProcessingMigrationsCompanion
    extends UpdateCompanion<DayProcessingMigrationRow> {
  final Value<String> migrationKey;
  final Value<int> completedAt;
  final Value<int> rowid;
  const DayProcessingMigrationsCompanion({
    this.migrationKey = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayProcessingMigrationsCompanion.insert({
    required String migrationKey,
    required int completedAt,
    this.rowid = const Value.absent(),
  }) : migrationKey = Value(migrationKey),
       completedAt = Value(completedAt);
  static Insertable<DayProcessingMigrationRow> custom({
    Expression<String>? migrationKey,
    Expression<int>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (migrationKey != null) 'migration_key': migrationKey,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayProcessingMigrationsCompanion copyWith({
    Value<String>? migrationKey,
    Value<int>? completedAt,
    Value<int>? rowid,
  }) {
    return DayProcessingMigrationsCompanion(
      migrationKey: migrationKey ?? this.migrationKey,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (migrationKey.present) {
      map['migration_key'] = Variable<String>(migrationKey.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayProcessingMigrationsCompanion(')
          ..write('migrationKey: $migrationKey, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DayProcessingDb extends GeneratedDatabase {
  _$DayProcessingDb(QueryExecutor e) : super(e);
  _$DayProcessingDb.connect(DatabaseConnection c) : super.connect(c);
  $DayProcessingDbManager get managers => $DayProcessingDbManager(this);
  late final DayProcessingJobs dayProcessingJobs = DayProcessingJobs(this);
  late final Index idxDayProcessingJobsPending = Index(
    'idx_day_processing_jobs_pending',
    'CREATE INDEX idx_day_processing_jobs_pending ON day_processing_jobs (created_at, id) WHERE status NOT IN (\'succeeded\', \'cancelled\')',
  );
  late final Index idxDayProcessingJobsDay = Index(
    'idx_day_processing_jobs_day',
    'CREATE INDEX idx_day_processing_jobs_day ON day_processing_jobs (day_id, kind, created_at)',
  );
  late final Index idxDayProcessingJobsRetention = Index(
    'idx_day_processing_jobs_retention',
    'CREATE INDEX idx_day_processing_jobs_retention ON day_processing_jobs (completed_at) WHERE status IN (\'succeeded\', \'cancelled\')',
  );
  late final DayProcessingMigrations dayProcessingMigrations =
      DayProcessingMigrations(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dayProcessingJobs,
    idxDayProcessingJobsPending,
    idxDayProcessingJobsDay,
    idxDayProcessingJobsRetention,
    dayProcessingMigrations,
  ];
}

typedef $DayProcessingJobsCreateCompanionBuilder =
    DayProcessingJobsCompanion Function({
      required String id,
      required String status,
      required String kind,
      required String dayId,
      required String payload,
      Value<String?> runKeys,
      required int createdAt,
      required int updatedAt,
      required int requestedAt,
      required int nextAttemptAt,
      Value<int> attempts,
      Value<int> generation,
      Value<String?> claimToken,
      Value<int?> leaseUntil,
      Value<int?> retryNotBefore,
      Value<String?> lastFailureClass,
      Value<String?> lastError,
      Value<String?> resultTranscript,
      Value<String?> resultEntityId,
      Value<int?> completedAt,
      Value<int> rowid,
    });
typedef $DayProcessingJobsUpdateCompanionBuilder =
    DayProcessingJobsCompanion Function({
      Value<String> id,
      Value<String> status,
      Value<String> kind,
      Value<String> dayId,
      Value<String> payload,
      Value<String?> runKeys,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> requestedAt,
      Value<int> nextAttemptAt,
      Value<int> attempts,
      Value<int> generation,
      Value<String?> claimToken,
      Value<int?> leaseUntil,
      Value<int?> retryNotBefore,
      Value<String?> lastFailureClass,
      Value<String?> lastError,
      Value<String?> resultTranscript,
      Value<String?> resultEntityId,
      Value<int?> completedAt,
      Value<int> rowid,
    });

class $DayProcessingJobsFilterComposer
    extends Composer<_$DayProcessingDb, DayProcessingJobs> {
  $DayProcessingJobsFilterComposer({
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayId => $composableBuilder(
    column: $table.dayId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runKeys => $composableBuilder(
    column: $table.runKeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get claimToken => $composableBuilder(
    column: $table.claimToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryNotBefore => $composableBuilder(
    column: $table.retryNotBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastFailureClass => $composableBuilder(
    column: $table.lastFailureClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultTranscript => $composableBuilder(
    column: $table.resultTranscript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultEntityId => $composableBuilder(
    column: $table.resultEntityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $DayProcessingJobsOrderingComposer
    extends Composer<_$DayProcessingDb, DayProcessingJobs> {
  $DayProcessingJobsOrderingComposer({
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayId => $composableBuilder(
    column: $table.dayId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runKeys => $composableBuilder(
    column: $table.runKeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get claimToken => $composableBuilder(
    column: $table.claimToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryNotBefore => $composableBuilder(
    column: $table.retryNotBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastFailureClass => $composableBuilder(
    column: $table.lastFailureClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultTranscript => $composableBuilder(
    column: $table.resultTranscript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultEntityId => $composableBuilder(
    column: $table.resultEntityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $DayProcessingJobsAnnotationComposer
    extends Composer<_$DayProcessingDb, DayProcessingJobs> {
  $DayProcessingJobsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get dayId =>
      $composableBuilder(column: $table.dayId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get runKeys =>
      $composableBuilder(column: $table.runKeys, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get claimToken => $composableBuilder(
    column: $table.claimToken,
    builder: (column) => column,
  );

  GeneratedColumn<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryNotBefore => $composableBuilder(
    column: $table.retryNotBefore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastFailureClass => $composableBuilder(
    column: $table.lastFailureClass,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get resultTranscript => $composableBuilder(
    column: $table.resultTranscript,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultEntityId => $composableBuilder(
    column: $table.resultEntityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $DayProcessingJobsTableManager
    extends
        RootTableManager<
          _$DayProcessingDb,
          DayProcessingJobs,
          DayProcessingJobRow,
          $DayProcessingJobsFilterComposer,
          $DayProcessingJobsOrderingComposer,
          $DayProcessingJobsAnnotationComposer,
          $DayProcessingJobsCreateCompanionBuilder,
          $DayProcessingJobsUpdateCompanionBuilder,
          (
            DayProcessingJobRow,
            BaseReferences<
              _$DayProcessingDb,
              DayProcessingJobs,
              DayProcessingJobRow
            >,
          ),
          DayProcessingJobRow,
          PrefetchHooks Function()
        > {
  $DayProcessingJobsTableManager(_$DayProcessingDb db, DayProcessingJobs table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DayProcessingJobsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DayProcessingJobsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DayProcessingJobsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> dayId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String?> runKeys = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> requestedAt = const Value.absent(),
                Value<int> nextAttemptAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<String?> claimToken = const Value.absent(),
                Value<int?> leaseUntil = const Value.absent(),
                Value<int?> retryNotBefore = const Value.absent(),
                Value<String?> lastFailureClass = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> resultTranscript = const Value.absent(),
                Value<String?> resultEntityId = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayProcessingJobsCompanion(
                id: id,
                status: status,
                kind: kind,
                dayId: dayId,
                payload: payload,
                runKeys: runKeys,
                createdAt: createdAt,
                updatedAt: updatedAt,
                requestedAt: requestedAt,
                nextAttemptAt: nextAttemptAt,
                attempts: attempts,
                generation: generation,
                claimToken: claimToken,
                leaseUntil: leaseUntil,
                retryNotBefore: retryNotBefore,
                lastFailureClass: lastFailureClass,
                lastError: lastError,
                resultTranscript: resultTranscript,
                resultEntityId: resultEntityId,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String status,
                required String kind,
                required String dayId,
                required String payload,
                Value<String?> runKeys = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                required int requestedAt,
                required int nextAttemptAt,
                Value<int> attempts = const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<String?> claimToken = const Value.absent(),
                Value<int?> leaseUntil = const Value.absent(),
                Value<int?> retryNotBefore = const Value.absent(),
                Value<String?> lastFailureClass = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> resultTranscript = const Value.absent(),
                Value<String?> resultEntityId = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayProcessingJobsCompanion.insert(
                id: id,
                status: status,
                kind: kind,
                dayId: dayId,
                payload: payload,
                runKeys: runKeys,
                createdAt: createdAt,
                updatedAt: updatedAt,
                requestedAt: requestedAt,
                nextAttemptAt: nextAttemptAt,
                attempts: attempts,
                generation: generation,
                claimToken: claimToken,
                leaseUntil: leaseUntil,
                retryNotBefore: retryNotBefore,
                lastFailureClass: lastFailureClass,
                lastError: lastError,
                resultTranscript: resultTranscript,
                resultEntityId: resultEntityId,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $DayProcessingJobsProcessedTableManager =
    ProcessedTableManager<
      _$DayProcessingDb,
      DayProcessingJobs,
      DayProcessingJobRow,
      $DayProcessingJobsFilterComposer,
      $DayProcessingJobsOrderingComposer,
      $DayProcessingJobsAnnotationComposer,
      $DayProcessingJobsCreateCompanionBuilder,
      $DayProcessingJobsUpdateCompanionBuilder,
      (
        DayProcessingJobRow,
        BaseReferences<
          _$DayProcessingDb,
          DayProcessingJobs,
          DayProcessingJobRow
        >,
      ),
      DayProcessingJobRow,
      PrefetchHooks Function()
    >;
typedef $DayProcessingMigrationsCreateCompanionBuilder =
    DayProcessingMigrationsCompanion Function({
      required String migrationKey,
      required int completedAt,
      Value<int> rowid,
    });
typedef $DayProcessingMigrationsUpdateCompanionBuilder =
    DayProcessingMigrationsCompanion Function({
      Value<String> migrationKey,
      Value<int> completedAt,
      Value<int> rowid,
    });

class $DayProcessingMigrationsFilterComposer
    extends Composer<_$DayProcessingDb, DayProcessingMigrations> {
  $DayProcessingMigrationsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get migrationKey => $composableBuilder(
    column: $table.migrationKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $DayProcessingMigrationsOrderingComposer
    extends Composer<_$DayProcessingDb, DayProcessingMigrations> {
  $DayProcessingMigrationsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get migrationKey => $composableBuilder(
    column: $table.migrationKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $DayProcessingMigrationsAnnotationComposer
    extends Composer<_$DayProcessingDb, DayProcessingMigrations> {
  $DayProcessingMigrationsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get migrationKey => $composableBuilder(
    column: $table.migrationKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $DayProcessingMigrationsTableManager
    extends
        RootTableManager<
          _$DayProcessingDb,
          DayProcessingMigrations,
          DayProcessingMigrationRow,
          $DayProcessingMigrationsFilterComposer,
          $DayProcessingMigrationsOrderingComposer,
          $DayProcessingMigrationsAnnotationComposer,
          $DayProcessingMigrationsCreateCompanionBuilder,
          $DayProcessingMigrationsUpdateCompanionBuilder,
          (
            DayProcessingMigrationRow,
            BaseReferences<
              _$DayProcessingDb,
              DayProcessingMigrations,
              DayProcessingMigrationRow
            >,
          ),
          DayProcessingMigrationRow,
          PrefetchHooks Function()
        > {
  $DayProcessingMigrationsTableManager(
    _$DayProcessingDb db,
    DayProcessingMigrations table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DayProcessingMigrationsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DayProcessingMigrationsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DayProcessingMigrationsAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> migrationKey = const Value.absent(),
                Value<int> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayProcessingMigrationsCompanion(
                migrationKey: migrationKey,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String migrationKey,
                required int completedAt,
                Value<int> rowid = const Value.absent(),
              }) => DayProcessingMigrationsCompanion.insert(
                migrationKey: migrationKey,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $DayProcessingMigrationsProcessedTableManager =
    ProcessedTableManager<
      _$DayProcessingDb,
      DayProcessingMigrations,
      DayProcessingMigrationRow,
      $DayProcessingMigrationsFilterComposer,
      $DayProcessingMigrationsOrderingComposer,
      $DayProcessingMigrationsAnnotationComposer,
      $DayProcessingMigrationsCreateCompanionBuilder,
      $DayProcessingMigrationsUpdateCompanionBuilder,
      (
        DayProcessingMigrationRow,
        BaseReferences<
          _$DayProcessingDb,
          DayProcessingMigrations,
          DayProcessingMigrationRow
        >,
      ),
      DayProcessingMigrationRow,
      PrefetchHooks Function()
    >;

class $DayProcessingDbManager {
  final _$DayProcessingDb _db;
  $DayProcessingDbManager(this._db);
  $DayProcessingJobsTableManager get dayProcessingJobs =>
      $DayProcessingJobsTableManager(_db, _db.dayProcessingJobs);
  $DayProcessingMigrationsTableManager get dayProcessingMigrations =>
      $DayProcessingMigrationsTableManager(_db, _db.dayProcessingMigrations);
}
