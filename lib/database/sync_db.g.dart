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
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(OutboxStatus.pending.index),
  );
  static const VerificationMeta _retriesMeta = const VerificationMeta(
    'retries',
  );
  @override
  late final GeneratedColumn<int> retries = GeneratedColumn<int>(
    'retries',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outboxEntryIdMeta = const VerificationMeta(
    'outboxEntryId',
  );
  @override
  late final GeneratedColumn<String> outboxEntryId = GeneratedColumn<String>(
    'outbox_entry_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadSizeMeta = const VerificationMeta(
    'payloadSize',
  );
  @override
  late final GeneratedColumn<int> payloadSize = GeneratedColumn<int>(
    'payload_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(OutboxPriority.low.index),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    status,
    retries,
    message,
    subject,
    filePath,
    outboxEntryId,
    payloadSize,
    priority,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('retries')) {
      context.handle(
        _retriesMeta,
        retries.isAcceptableOrUnknown(data['retries']!, _retriesMeta),
      );
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('outbox_entry_id')) {
      context.handle(
        _outboxEntryIdMeta,
        outboxEntryId.isAcceptableOrUnknown(
          data['outbox_entry_id']!,
          _outboxEntryIdMeta,
        ),
      );
    }
    if (data.containsKey('payload_size')) {
      context.handle(
        _payloadSizeMeta,
        payloadSize.isAcceptableOrUnknown(
          data['payload_size']!,
          _payloadSizeMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
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
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      retries: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retries'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      outboxEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outbox_entry_id'],
      ),
      payloadSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payload_size'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
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

  /// The journal entry or link ID for deduplication.
  /// When a pending item exists for the same entry, new updates can be merged
  /// to avoid sending redundant messages for rapidly-updated entries.
  final String? outboxEntryId;

  /// Total payload size in bytes (attachment file size + JSON message size).
  /// Recorded at enqueue time for volume tracking and visualization.
  final int? payloadSize;

  /// Sync priority: 0=high (user), 1=normal (agent/system), 2=low (bulk resync).
  /// Entries are processed in priority order (ASC), then by creation date.
  final int priority;
  const OutboxItem({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.retries,
    required this.message,
    required this.subject,
    this.filePath,
    this.outboxEntryId,
    this.payloadSize,
    required this.priority,
  });
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
    if (!nullToAbsent || outboxEntryId != null) {
      map['outbox_entry_id'] = Variable<String>(outboxEntryId);
    }
    if (!nullToAbsent || payloadSize != null) {
      map['payload_size'] = Variable<int>(payloadSize);
    }
    map['priority'] = Variable<int>(priority);
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
      outboxEntryId: outboxEntryId == null && nullToAbsent
          ? const Value.absent()
          : Value(outboxEntryId),
      payloadSize: payloadSize == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadSize),
      priority: Value(priority),
    );
  }

  factory OutboxItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
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
      outboxEntryId: serializer.fromJson<String?>(json['outboxEntryId']),
      payloadSize: serializer.fromJson<int?>(json['payloadSize']),
      priority: serializer.fromJson<int>(json['priority']),
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
      'outboxEntryId': serializer.toJson<String?>(outboxEntryId),
      'payloadSize': serializer.toJson<int?>(payloadSize),
      'priority': serializer.toJson<int>(priority),
    };
  }

  OutboxItem copyWith({
    int? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? status,
    int? retries,
    String? message,
    String? subject,
    Value<String?> filePath = const Value.absent(),
    Value<String?> outboxEntryId = const Value.absent(),
    Value<int?> payloadSize = const Value.absent(),
    int? priority,
  }) => OutboxItem(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    status: status ?? this.status,
    retries: retries ?? this.retries,
    message: message ?? this.message,
    subject: subject ?? this.subject,
    filePath: filePath.present ? filePath.value : this.filePath,
    outboxEntryId: outboxEntryId.present
        ? outboxEntryId.value
        : this.outboxEntryId,
    payloadSize: payloadSize.present ? payloadSize.value : this.payloadSize,
    priority: priority ?? this.priority,
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
      outboxEntryId: data.outboxEntryId.present
          ? data.outboxEntryId.value
          : this.outboxEntryId,
      payloadSize: data.payloadSize.present
          ? data.payloadSize.value
          : this.payloadSize,
      priority: data.priority.present ? data.priority.value : this.priority,
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
          ..write('filePath: $filePath, ')
          ..write('outboxEntryId: $outboxEntryId, ')
          ..write('payloadSize: $payloadSize, ')
          ..write('priority: $priority')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    status,
    retries,
    message,
    subject,
    filePath,
    outboxEntryId,
    payloadSize,
    priority,
  );
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
          other.filePath == this.filePath &&
          other.outboxEntryId == this.outboxEntryId &&
          other.payloadSize == this.payloadSize &&
          other.priority == this.priority);
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
  final Value<String?> outboxEntryId;
  final Value<int?> payloadSize;
  final Value<int> priority;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.retries = const Value.absent(),
    this.message = const Value.absent(),
    this.subject = const Value.absent(),
    this.filePath = const Value.absent(),
    this.outboxEntryId = const Value.absent(),
    this.payloadSize = const Value.absent(),
    this.priority = const Value.absent(),
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
    this.outboxEntryId = const Value.absent(),
    this.payloadSize = const Value.absent(),
    this.priority = const Value.absent(),
  }) : message = Value(message),
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
    Expression<String>? outboxEntryId,
    Expression<int>? payloadSize,
    Expression<int>? priority,
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
      if (outboxEntryId != null) 'outbox_entry_id': outboxEntryId,
      if (payloadSize != null) 'payload_size': payloadSize,
      if (priority != null) 'priority': priority,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? status,
    Value<int>? retries,
    Value<String>? message,
    Value<String>? subject,
    Value<String?>? filePath,
    Value<String?>? outboxEntryId,
    Value<int?>? payloadSize,
    Value<int>? priority,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      retries: retries ?? this.retries,
      message: message ?? this.message,
      subject: subject ?? this.subject,
      filePath: filePath ?? this.filePath,
      outboxEntryId: outboxEntryId ?? this.outboxEntryId,
      payloadSize: payloadSize ?? this.payloadSize,
      priority: priority ?? this.priority,
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
    if (outboxEntryId.present) {
      map['outbox_entry_id'] = Variable<String>(outboxEntryId.value);
    }
    if (payloadSize.present) {
      map['payload_size'] = Variable<int>(payloadSize.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
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
          ..write('filePath: $filePath, ')
          ..write('outboxEntryId: $outboxEntryId, ')
          ..write('payloadSize: $payloadSize, ')
          ..write('priority: $priority')
          ..write(')'))
        .toString();
  }
}

class $SyncSequenceLogTable extends SyncSequenceLog
    with TableInfo<$SyncSequenceLogTable, SyncSequenceLogItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncSequenceLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hostIdMeta = const VerificationMeta('hostId');
  @override
  late final GeneratedColumn<String> hostId = GeneratedColumn<String>(
    'host_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _counterMeta = const VerificationMeta(
    'counter',
  );
  @override
  late final GeneratedColumn<int> counter = GeneratedColumn<int>(
    'counter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadTypeMeta = const VerificationMeta(
    'payloadType',
  );
  @override
  late final GeneratedColumn<int> payloadType = GeneratedColumn<int>(
    'payload_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(SyncSequencePayloadType.journalEntity.index),
  );
  static const VerificationMeta _originatingHostIdMeta = const VerificationMeta(
    'originatingHostId',
  );
  @override
  late final GeneratedColumn<String> originatingHostId =
      GeneratedColumn<String>(
        'originating_host_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(SyncSequenceStatus.received.index),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestCountMeta = const VerificationMeta(
    'requestCount',
  );
  @override
  late final GeneratedColumn<int> requestCount = GeneratedColumn<int>(
    'request_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastRequestedAtMeta = const VerificationMeta(
    'lastRequestedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastRequestedAt =
      GeneratedColumn<DateTime>(
        'last_requested_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _jsonPathMeta = const VerificationMeta(
    'jsonPath',
  );
  @override
  late final GeneratedColumn<String> jsonPath = GeneratedColumn<String>(
    'json_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    hostId,
    counter,
    entryId,
    payloadType,
    originatingHostId,
    status,
    createdAt,
    updatedAt,
    requestCount,
    lastRequestedAt,
    jsonPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_sequence_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncSequenceLogItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('host_id')) {
      context.handle(
        _hostIdMeta,
        hostId.isAcceptableOrUnknown(data['host_id']!, _hostIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hostIdMeta);
    }
    if (data.containsKey('counter')) {
      context.handle(
        _counterMeta,
        counter.isAcceptableOrUnknown(data['counter']!, _counterMeta),
      );
    } else if (isInserting) {
      context.missing(_counterMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    }
    if (data.containsKey('payload_type')) {
      context.handle(
        _payloadTypeMeta,
        payloadType.isAcceptableOrUnknown(
          data['payload_type']!,
          _payloadTypeMeta,
        ),
      );
    }
    if (data.containsKey('originating_host_id')) {
      context.handle(
        _originatingHostIdMeta,
        originatingHostId.isAcceptableOrUnknown(
          data['originating_host_id']!,
          _originatingHostIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
    if (data.containsKey('request_count')) {
      context.handle(
        _requestCountMeta,
        requestCount.isAcceptableOrUnknown(
          data['request_count']!,
          _requestCountMeta,
        ),
      );
    }
    if (data.containsKey('last_requested_at')) {
      context.handle(
        _lastRequestedAtMeta,
        lastRequestedAt.isAcceptableOrUnknown(
          data['last_requested_at']!,
          _lastRequestedAtMeta,
        ),
      );
    }
    if (data.containsKey('json_path')) {
      context.handle(
        _jsonPathMeta,
        jsonPath.isAcceptableOrUnknown(data['json_path']!, _jsonPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {hostId, counter};
  @override
  SyncSequenceLogItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncSequenceLogItem(
      hostId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_id'],
      )!,
      counter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}counter'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      ),
      payloadType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payload_type'],
      )!,
      originatingHostId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}originating_host_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      requestCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}request_count'],
      )!,
      lastRequestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_requested_at'],
      ),
      jsonPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json_path'],
      ),
    );
  }

  @override
  $SyncSequenceLogTable createAlias(String alias) {
    return $SyncSequenceLogTable(attachedDatabase, alias);
  }
}

class SyncSequenceLogItem extends DataClass
    implements Insertable<SyncSequenceLogItem> {
  /// The host UUID whose counter this record tracks
  final String hostId;

  /// The monotonic counter for that host
  final int counter;

  /// The payload ID (journal entry ID or entry link ID).
  /// Null if the payload is missing/unknown.
  final String? entryId;

  /// What kind of payload [entryId] refers to.
  final int payloadType;

  /// The host UUID that sent the message which informed us about this record.
  /// For received entries, this is the sender. For gaps detected from VCs,
  /// this is the host whose message contained the VC that revealed the gap.
  final String? originatingHostId;

  /// Status of this sequence entry (received, missing, requested, etc.)
  final int status;

  /// When this log entry was created
  final DateTime createdAt;

  /// When this log entry was last updated
  final DateTime updatedAt;

  /// Number of backfill requests sent for this entry
  final int requestCount;

  /// When a backfill request was last sent for this entry
  final DateTime? lastRequestedAt;

  /// The documents-directory-relative path to the entry's JSON file.
  /// Stored so the backfill sweep can delete zombie files for any payload
  /// type, not just agent entities/links whose paths are derivable from ID.
  final String? jsonPath;
  const SyncSequenceLogItem({
    required this.hostId,
    required this.counter,
    this.entryId,
    required this.payloadType,
    this.originatingHostId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.requestCount,
    this.lastRequestedAt,
    this.jsonPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['host_id'] = Variable<String>(hostId);
    map['counter'] = Variable<int>(counter);
    if (!nullToAbsent || entryId != null) {
      map['entry_id'] = Variable<String>(entryId);
    }
    map['payload_type'] = Variable<int>(payloadType);
    if (!nullToAbsent || originatingHostId != null) {
      map['originating_host_id'] = Variable<String>(originatingHostId);
    }
    map['status'] = Variable<int>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['request_count'] = Variable<int>(requestCount);
    if (!nullToAbsent || lastRequestedAt != null) {
      map['last_requested_at'] = Variable<DateTime>(lastRequestedAt);
    }
    if (!nullToAbsent || jsonPath != null) {
      map['json_path'] = Variable<String>(jsonPath);
    }
    return map;
  }

  SyncSequenceLogCompanion toCompanion(bool nullToAbsent) {
    return SyncSequenceLogCompanion(
      hostId: Value(hostId),
      counter: Value(counter),
      entryId: entryId == null && nullToAbsent
          ? const Value.absent()
          : Value(entryId),
      payloadType: Value(payloadType),
      originatingHostId: originatingHostId == null && nullToAbsent
          ? const Value.absent()
          : Value(originatingHostId),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      requestCount: Value(requestCount),
      lastRequestedAt: lastRequestedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRequestedAt),
      jsonPath: jsonPath == null && nullToAbsent
          ? const Value.absent()
          : Value(jsonPath),
    );
  }

  factory SyncSequenceLogItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncSequenceLogItem(
      hostId: serializer.fromJson<String>(json['hostId']),
      counter: serializer.fromJson<int>(json['counter']),
      entryId: serializer.fromJson<String?>(json['entryId']),
      payloadType: serializer.fromJson<int>(json['payloadType']),
      originatingHostId: serializer.fromJson<String?>(
        json['originatingHostId'],
      ),
      status: serializer.fromJson<int>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      requestCount: serializer.fromJson<int>(json['requestCount']),
      lastRequestedAt: serializer.fromJson<DateTime?>(json['lastRequestedAt']),
      jsonPath: serializer.fromJson<String?>(json['jsonPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hostId': serializer.toJson<String>(hostId),
      'counter': serializer.toJson<int>(counter),
      'entryId': serializer.toJson<String?>(entryId),
      'payloadType': serializer.toJson<int>(payloadType),
      'originatingHostId': serializer.toJson<String?>(originatingHostId),
      'status': serializer.toJson<int>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'requestCount': serializer.toJson<int>(requestCount),
      'lastRequestedAt': serializer.toJson<DateTime?>(lastRequestedAt),
      'jsonPath': serializer.toJson<String?>(jsonPath),
    };
  }

  SyncSequenceLogItem copyWith({
    String? hostId,
    int? counter,
    Value<String?> entryId = const Value.absent(),
    int? payloadType,
    Value<String?> originatingHostId = const Value.absent(),
    int? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? requestCount,
    Value<DateTime?> lastRequestedAt = const Value.absent(),
    Value<String?> jsonPath = const Value.absent(),
  }) => SyncSequenceLogItem(
    hostId: hostId ?? this.hostId,
    counter: counter ?? this.counter,
    entryId: entryId.present ? entryId.value : this.entryId,
    payloadType: payloadType ?? this.payloadType,
    originatingHostId: originatingHostId.present
        ? originatingHostId.value
        : this.originatingHostId,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    requestCount: requestCount ?? this.requestCount,
    lastRequestedAt: lastRequestedAt.present
        ? lastRequestedAt.value
        : this.lastRequestedAt,
    jsonPath: jsonPath.present ? jsonPath.value : this.jsonPath,
  );
  SyncSequenceLogItem copyWithCompanion(SyncSequenceLogCompanion data) {
    return SyncSequenceLogItem(
      hostId: data.hostId.present ? data.hostId.value : this.hostId,
      counter: data.counter.present ? data.counter.value : this.counter,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      payloadType: data.payloadType.present
          ? data.payloadType.value
          : this.payloadType,
      originatingHostId: data.originatingHostId.present
          ? data.originatingHostId.value
          : this.originatingHostId,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      requestCount: data.requestCount.present
          ? data.requestCount.value
          : this.requestCount,
      lastRequestedAt: data.lastRequestedAt.present
          ? data.lastRequestedAt.value
          : this.lastRequestedAt,
      jsonPath: data.jsonPath.present ? data.jsonPath.value : this.jsonPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncSequenceLogItem(')
          ..write('hostId: $hostId, ')
          ..write('counter: $counter, ')
          ..write('entryId: $entryId, ')
          ..write('payloadType: $payloadType, ')
          ..write('originatingHostId: $originatingHostId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('requestCount: $requestCount, ')
          ..write('lastRequestedAt: $lastRequestedAt, ')
          ..write('jsonPath: $jsonPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    hostId,
    counter,
    entryId,
    payloadType,
    originatingHostId,
    status,
    createdAt,
    updatedAt,
    requestCount,
    lastRequestedAt,
    jsonPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncSequenceLogItem &&
          other.hostId == this.hostId &&
          other.counter == this.counter &&
          other.entryId == this.entryId &&
          other.payloadType == this.payloadType &&
          other.originatingHostId == this.originatingHostId &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.requestCount == this.requestCount &&
          other.lastRequestedAt == this.lastRequestedAt &&
          other.jsonPath == this.jsonPath);
}

class SyncSequenceLogCompanion extends UpdateCompanion<SyncSequenceLogItem> {
  final Value<String> hostId;
  final Value<int> counter;
  final Value<String?> entryId;
  final Value<int> payloadType;
  final Value<String?> originatingHostId;
  final Value<int> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> requestCount;
  final Value<DateTime?> lastRequestedAt;
  final Value<String?> jsonPath;
  final Value<int> rowid;
  const SyncSequenceLogCompanion({
    this.hostId = const Value.absent(),
    this.counter = const Value.absent(),
    this.entryId = const Value.absent(),
    this.payloadType = const Value.absent(),
    this.originatingHostId = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.requestCount = const Value.absent(),
    this.lastRequestedAt = const Value.absent(),
    this.jsonPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncSequenceLogCompanion.insert({
    required String hostId,
    required int counter,
    this.entryId = const Value.absent(),
    this.payloadType = const Value.absent(),
    this.originatingHostId = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.requestCount = const Value.absent(),
    this.lastRequestedAt = const Value.absent(),
    this.jsonPath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : hostId = Value(hostId),
       counter = Value(counter),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SyncSequenceLogItem> custom({
    Expression<String>? hostId,
    Expression<int>? counter,
    Expression<String>? entryId,
    Expression<int>? payloadType,
    Expression<String>? originatingHostId,
    Expression<int>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? requestCount,
    Expression<DateTime>? lastRequestedAt,
    Expression<String>? jsonPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hostId != null) 'host_id': hostId,
      if (counter != null) 'counter': counter,
      if (entryId != null) 'entry_id': entryId,
      if (payloadType != null) 'payload_type': payloadType,
      if (originatingHostId != null) 'originating_host_id': originatingHostId,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (requestCount != null) 'request_count': requestCount,
      if (lastRequestedAt != null) 'last_requested_at': lastRequestedAt,
      if (jsonPath != null) 'json_path': jsonPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncSequenceLogCompanion copyWith({
    Value<String>? hostId,
    Value<int>? counter,
    Value<String?>? entryId,
    Value<int>? payloadType,
    Value<String?>? originatingHostId,
    Value<int>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? requestCount,
    Value<DateTime?>? lastRequestedAt,
    Value<String?>? jsonPath,
    Value<int>? rowid,
  }) {
    return SyncSequenceLogCompanion(
      hostId: hostId ?? this.hostId,
      counter: counter ?? this.counter,
      entryId: entryId ?? this.entryId,
      payloadType: payloadType ?? this.payloadType,
      originatingHostId: originatingHostId ?? this.originatingHostId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      requestCount: requestCount ?? this.requestCount,
      lastRequestedAt: lastRequestedAt ?? this.lastRequestedAt,
      jsonPath: jsonPath ?? this.jsonPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hostId.present) {
      map['host_id'] = Variable<String>(hostId.value);
    }
    if (counter.present) {
      map['counter'] = Variable<int>(counter.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (payloadType.present) {
      map['payload_type'] = Variable<int>(payloadType.value);
    }
    if (originatingHostId.present) {
      map['originating_host_id'] = Variable<String>(originatingHostId.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (requestCount.present) {
      map['request_count'] = Variable<int>(requestCount.value);
    }
    if (lastRequestedAt.present) {
      map['last_requested_at'] = Variable<DateTime>(lastRequestedAt.value);
    }
    if (jsonPath.present) {
      map['json_path'] = Variable<String>(jsonPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncSequenceLogCompanion(')
          ..write('hostId: $hostId, ')
          ..write('counter: $counter, ')
          ..write('entryId: $entryId, ')
          ..write('payloadType: $payloadType, ')
          ..write('originatingHostId: $originatingHostId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('requestCount: $requestCount, ')
          ..write('lastRequestedAt: $lastRequestedAt, ')
          ..write('jsonPath: $jsonPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HostActivityTable extends HostActivity
    with TableInfo<$HostActivityTable, HostActivityItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HostActivityTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hostIdMeta = const VerificationMeta('hostId');
  @override
  late final GeneratedColumn<String> hostId = GeneratedColumn<String>(
    'host_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [hostId, lastSeenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'host_activity';
  @override
  VerificationContext validateIntegrity(
    Insertable<HostActivityItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('host_id')) {
      context.handle(
        _hostIdMeta,
        hostId.isAcceptableOrUnknown(data['host_id']!, _hostIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hostIdMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {hostId};
  @override
  HostActivityItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HostActivityItem(
      hostId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_id'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
    );
  }

  @override
  $HostActivityTable createAlias(String alias) {
    return $HostActivityTable(attachedDatabase, alias);
  }
}

class HostActivityItem extends DataClass
    implements Insertable<HostActivityItem> {
  /// The host UUID
  final String hostId;

  /// When we last received a message from this host
  final DateTime lastSeenAt;
  const HostActivityItem({required this.hostId, required this.lastSeenAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['host_id'] = Variable<String>(hostId);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    return map;
  }

  HostActivityCompanion toCompanion(bool nullToAbsent) {
    return HostActivityCompanion(
      hostId: Value(hostId),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory HostActivityItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HostActivityItem(
      hostId: serializer.fromJson<String>(json['hostId']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hostId': serializer.toJson<String>(hostId),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
    };
  }

  HostActivityItem copyWith({String? hostId, DateTime? lastSeenAt}) =>
      HostActivityItem(
        hostId: hostId ?? this.hostId,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );
  HostActivityItem copyWithCompanion(HostActivityCompanion data) {
    return HostActivityItem(
      hostId: data.hostId.present ? data.hostId.value : this.hostId,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HostActivityItem(')
          ..write('hostId: $hostId, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(hostId, lastSeenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HostActivityItem &&
          other.hostId == this.hostId &&
          other.lastSeenAt == this.lastSeenAt);
}

class HostActivityCompanion extends UpdateCompanion<HostActivityItem> {
  final Value<String> hostId;
  final Value<DateTime> lastSeenAt;
  final Value<int> rowid;
  const HostActivityCompanion({
    this.hostId = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HostActivityCompanion.insert({
    required String hostId,
    required DateTime lastSeenAt,
    this.rowid = const Value.absent(),
  }) : hostId = Value(hostId),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<HostActivityItem> custom({
    Expression<String>? hostId,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hostId != null) 'host_id': hostId,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HostActivityCompanion copyWith({
    Value<String>? hostId,
    Value<DateTime>? lastSeenAt,
    Value<int>? rowid,
  }) {
    return HostActivityCompanion(
      hostId: hostId ?? this.hostId,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hostId.present) {
      map['host_id'] = Variable<String>(hostId.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HostActivityCompanion(')
          ..write('hostId: $hostId, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InboundEventQueueTable extends InboundEventQueue
    with TableInfo<$InboundEventQueueTable, InboundEventQueueItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InboundEventQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queueIdMeta = const VerificationMeta(
    'queueId',
  );
  @override
  late final GeneratedColumn<int> queueId = GeneratedColumn<int>(
    'queue_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  @override
  late final GeneratedColumn<String> roomId = GeneratedColumn<String>(
    'room_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originTsMeta = const VerificationMeta(
    'originTs',
  );
  @override
  late final GeneratedColumn<int> originTs = GeneratedColumn<int>(
    'origin_ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _producerMeta = const VerificationMeta(
    'producer',
  );
  @override
  late final GeneratedColumn<String> producer = GeneratedColumn<String>(
    'producer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enqueuedAtMeta = const VerificationMeta(
    'enqueuedAt',
  );
  @override
  late final GeneratedColumn<int> enqueuedAt = GeneratedColumn<int>(
    'enqueued_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextDueAtMeta = const VerificationMeta(
    'nextDueAt',
  );
  @override
  late final GeneratedColumn<int> nextDueAt = GeneratedColumn<int>(
    'next_due_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _leaseUntilMeta = const VerificationMeta(
    'leaseUntil',
  );
  @override
  late final GeneratedColumn<int> leaseUntil = GeneratedColumn<int>(
    'lease_until',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('enqueued'),
  );
  static const VerificationMeta _committedAtMeta = const VerificationMeta(
    'committedAt',
  );
  @override
  late final GeneratedColumn<int> committedAt = GeneratedColumn<int>(
    'committed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _abandonedAtMeta = const VerificationMeta(
    'abandonedAt',
  );
  @override
  late final GeneratedColumn<int> abandonedAt = GeneratedColumn<int>(
    'abandoned_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorReasonMeta = const VerificationMeta(
    'lastErrorReason',
  );
  @override
  late final GeneratedColumn<String> lastErrorReason = GeneratedColumn<String>(
    'last_error_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resurrectionCountMeta = const VerificationMeta(
    'resurrectionCount',
  );
  @override
  late final GeneratedColumn<int> resurrectionCount = GeneratedColumn<int>(
    'resurrection_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _jsonPathMeta = const VerificationMeta(
    'jsonPath',
  );
  @override
  late final GeneratedColumn<String> jsonPath = GeneratedColumn<String>(
    'json_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    queueId,
    eventId,
    roomId,
    originTs,
    producer,
    rawJson,
    enqueuedAt,
    attempts,
    nextDueAt,
    leaseUntil,
    status,
    committedAt,
    abandonedAt,
    lastErrorReason,
    resurrectionCount,
    jsonPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inbound_event_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<InboundEventQueueItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('queue_id')) {
      context.handle(
        _queueIdMeta,
        queueId.isAcceptableOrUnknown(data['queue_id']!, _queueIdMeta),
      );
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(
        _roomIdMeta,
        roomId.isAcceptableOrUnknown(data['room_id']!, _roomIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('origin_ts')) {
      context.handle(
        _originTsMeta,
        originTs.isAcceptableOrUnknown(data['origin_ts']!, _originTsMeta),
      );
    } else if (isInserting) {
      context.missing(_originTsMeta);
    }
    if (data.containsKey('producer')) {
      context.handle(
        _producerMeta,
        producer.isAcceptableOrUnknown(data['producer']!, _producerMeta),
      );
    } else if (isInserting) {
      context.missing(_producerMeta);
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_rawJsonMeta);
    }
    if (data.containsKey('enqueued_at')) {
      context.handle(
        _enqueuedAtMeta,
        enqueuedAt.isAcceptableOrUnknown(data['enqueued_at']!, _enqueuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_enqueuedAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_due_at')) {
      context.handle(
        _nextDueAtMeta,
        nextDueAt.isAcceptableOrUnknown(data['next_due_at']!, _nextDueAtMeta),
      );
    }
    if (data.containsKey('lease_until')) {
      context.handle(
        _leaseUntilMeta,
        leaseUntil.isAcceptableOrUnknown(data['lease_until']!, _leaseUntilMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('committed_at')) {
      context.handle(
        _committedAtMeta,
        committedAt.isAcceptableOrUnknown(
          data['committed_at']!,
          _committedAtMeta,
        ),
      );
    }
    if (data.containsKey('abandoned_at')) {
      context.handle(
        _abandonedAtMeta,
        abandonedAt.isAcceptableOrUnknown(
          data['abandoned_at']!,
          _abandonedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error_reason')) {
      context.handle(
        _lastErrorReasonMeta,
        lastErrorReason.isAcceptableOrUnknown(
          data['last_error_reason']!,
          _lastErrorReasonMeta,
        ),
      );
    }
    if (data.containsKey('resurrection_count')) {
      context.handle(
        _resurrectionCountMeta,
        resurrectionCount.isAcceptableOrUnknown(
          data['resurrection_count']!,
          _resurrectionCountMeta,
        ),
      );
    }
    if (data.containsKey('json_path')) {
      context.handle(
        _jsonPathMeta,
        jsonPath.isAcceptableOrUnknown(data['json_path']!, _jsonPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {queueId};
  @override
  InboundEventQueueItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InboundEventQueueItem(
      queueId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}queue_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      roomId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_id'],
      )!,
      originTs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}origin_ts'],
      )!,
      producer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}producer'],
      )!,
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
      enqueuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}enqueued_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextDueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_due_at'],
      )!,
      leaseUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lease_until'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      committedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}committed_at'],
      ),
      abandonedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}abandoned_at'],
      ),
      lastErrorReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_reason'],
      ),
      resurrectionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resurrection_count'],
      )!,
      jsonPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json_path'],
      ),
    );
  }

  @override
  $InboundEventQueueTable createAlias(String alias) {
    return $InboundEventQueueTable(attachedDatabase, alias);
  }
}

class InboundEventQueueItem extends DataClass
    implements Insertable<InboundEventQueueItem> {
  final int queueId;

  /// Matrix event ID. UNIQUE at the DB level; duplicate inserts are
  /// silently rejected on all ingestion paths.
  final String eventId;

  /// Matrix room ID the event belongs to.
  final String roomId;

  /// `originServerTs` in milliseconds since epoch. Drain order is
  /// ascending on this, then on `queue_id`.
  final int originTs;

  /// Enqueuing producer. Stored as `InboundEventProducer.name` to
  /// survive future enum reshuffling.
  final String producer;

  /// Serialised `Event.toJson()`. Materialised to an `Event` at drain
  /// time; the queue itself never holds SDK objects.
  final String rawJson;

  /// Wall-clock enqueue timestamp (ms since epoch).
  final int enqueuedAt;

  /// Retry counter. Incremented per scheduled retry; capped in
  /// `InboundWorker` to avoid eternal wedges on a single bad event.
  final int attempts;

  /// Earliest time (ms since epoch) at which this entry is eligible
  /// for re-peek. 0 = ready now.
  final int nextDueAt;

  /// Worker lease expiry (ms since epoch). 0 = not leased; peek stamps
  /// this to `now + leaseDuration` atomically. Entries with `lease_until
  /// > now` are not returned by `peekBatchReady`, so crashed-then-
  /// restarted workers do not double-drain until the lease expires.
  final int leaseUntil;

  /// Lifecycle state. One of:
  /// - `enqueued` — just inserted, ready to drain.
  /// - `leased` — worker picked it up; `lease_until > now` protects
  ///   against double-drain.
  /// - `retrying` — apply returned a recoverable failure; `next_due_at`
  ///   holds the backoff.
  /// - `applied` — `commitApplied` succeeded. Row is kept as an
  ///   append-only ledger for traceability; the marker has advanced.
  /// - `abandoned` — max attempts exceeded. Not drainable, but kept so
  ///   a resurrection trigger (attachment signal, journal update,
  ///   user-initiated "retry skipped") can flip it back to
  ///   `enqueued`.
  ///
  /// Stored as text rather than an enum index because the set is
  /// small, readable, and stable across future reorderings.
  final String status;

  /// Wall-clock ms at which `commitApplied` flipped status to
  /// `applied`. NULL for non-applied rows.
  final int? committedAt;

  /// Wall-clock ms at which `markSkipped` flipped status to
  /// `abandoned`. NULL for non-abandoned rows.
  final int? abandonedAt;

  /// Last retry/skip reason (from `RetryReason.name` or
  /// `'permanentSkip'` / `'maxAttempts(...)'`). Diagnostics-only;
  /// resurrection does not gate on this.
  final String? lastErrorReason;

  /// Count of times this row has been flipped from `abandoned` back
  /// to `enqueued`. Guards against thrash: `resurrectByPath` /
  /// `resurrectAll` skip rows whose count exceeds the hard cap so a
  /// truly poison event cannot be resurrected forever.
  final int resurrectionCount;

  /// Derived from the Lotti sync payload (text message content
  /// `jsonPath`) when present. Used by
  /// `AttachmentIndex.pathRecorded` → `resurrectByPath` to wake the
  /// matching abandoned row as soon as the descriptor lands on disk.
  /// NULL when the event type does not carry a `jsonPath`.
  final String? jsonPath;
  const InboundEventQueueItem({
    required this.queueId,
    required this.eventId,
    required this.roomId,
    required this.originTs,
    required this.producer,
    required this.rawJson,
    required this.enqueuedAt,
    required this.attempts,
    required this.nextDueAt,
    required this.leaseUntil,
    required this.status,
    this.committedAt,
    this.abandonedAt,
    this.lastErrorReason,
    required this.resurrectionCount,
    this.jsonPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['queue_id'] = Variable<int>(queueId);
    map['event_id'] = Variable<String>(eventId);
    map['room_id'] = Variable<String>(roomId);
    map['origin_ts'] = Variable<int>(originTs);
    map['producer'] = Variable<String>(producer);
    map['raw_json'] = Variable<String>(rawJson);
    map['enqueued_at'] = Variable<int>(enqueuedAt);
    map['attempts'] = Variable<int>(attempts);
    map['next_due_at'] = Variable<int>(nextDueAt);
    map['lease_until'] = Variable<int>(leaseUntil);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || committedAt != null) {
      map['committed_at'] = Variable<int>(committedAt);
    }
    if (!nullToAbsent || abandonedAt != null) {
      map['abandoned_at'] = Variable<int>(abandonedAt);
    }
    if (!nullToAbsent || lastErrorReason != null) {
      map['last_error_reason'] = Variable<String>(lastErrorReason);
    }
    map['resurrection_count'] = Variable<int>(resurrectionCount);
    if (!nullToAbsent || jsonPath != null) {
      map['json_path'] = Variable<String>(jsonPath);
    }
    return map;
  }

  InboundEventQueueCompanion toCompanion(bool nullToAbsent) {
    return InboundEventQueueCompanion(
      queueId: Value(queueId),
      eventId: Value(eventId),
      roomId: Value(roomId),
      originTs: Value(originTs),
      producer: Value(producer),
      rawJson: Value(rawJson),
      enqueuedAt: Value(enqueuedAt),
      attempts: Value(attempts),
      nextDueAt: Value(nextDueAt),
      leaseUntil: Value(leaseUntil),
      status: Value(status),
      committedAt: committedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(committedAt),
      abandonedAt: abandonedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(abandonedAt),
      lastErrorReason: lastErrorReason == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorReason),
      resurrectionCount: Value(resurrectionCount),
      jsonPath: jsonPath == null && nullToAbsent
          ? const Value.absent()
          : Value(jsonPath),
    );
  }

  factory InboundEventQueueItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InboundEventQueueItem(
      queueId: serializer.fromJson<int>(json['queueId']),
      eventId: serializer.fromJson<String>(json['eventId']),
      roomId: serializer.fromJson<String>(json['roomId']),
      originTs: serializer.fromJson<int>(json['originTs']),
      producer: serializer.fromJson<String>(json['producer']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
      enqueuedAt: serializer.fromJson<int>(json['enqueuedAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextDueAt: serializer.fromJson<int>(json['nextDueAt']),
      leaseUntil: serializer.fromJson<int>(json['leaseUntil']),
      status: serializer.fromJson<String>(json['status']),
      committedAt: serializer.fromJson<int?>(json['committedAt']),
      abandonedAt: serializer.fromJson<int?>(json['abandonedAt']),
      lastErrorReason: serializer.fromJson<String?>(json['lastErrorReason']),
      resurrectionCount: serializer.fromJson<int>(json['resurrectionCount']),
      jsonPath: serializer.fromJson<String?>(json['jsonPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'queueId': serializer.toJson<int>(queueId),
      'eventId': serializer.toJson<String>(eventId),
      'roomId': serializer.toJson<String>(roomId),
      'originTs': serializer.toJson<int>(originTs),
      'producer': serializer.toJson<String>(producer),
      'rawJson': serializer.toJson<String>(rawJson),
      'enqueuedAt': serializer.toJson<int>(enqueuedAt),
      'attempts': serializer.toJson<int>(attempts),
      'nextDueAt': serializer.toJson<int>(nextDueAt),
      'leaseUntil': serializer.toJson<int>(leaseUntil),
      'status': serializer.toJson<String>(status),
      'committedAt': serializer.toJson<int?>(committedAt),
      'abandonedAt': serializer.toJson<int?>(abandonedAt),
      'lastErrorReason': serializer.toJson<String?>(lastErrorReason),
      'resurrectionCount': serializer.toJson<int>(resurrectionCount),
      'jsonPath': serializer.toJson<String?>(jsonPath),
    };
  }

  InboundEventQueueItem copyWith({
    int? queueId,
    String? eventId,
    String? roomId,
    int? originTs,
    String? producer,
    String? rawJson,
    int? enqueuedAt,
    int? attempts,
    int? nextDueAt,
    int? leaseUntil,
    String? status,
    Value<int?> committedAt = const Value.absent(),
    Value<int?> abandonedAt = const Value.absent(),
    Value<String?> lastErrorReason = const Value.absent(),
    int? resurrectionCount,
    Value<String?> jsonPath = const Value.absent(),
  }) => InboundEventQueueItem(
    queueId: queueId ?? this.queueId,
    eventId: eventId ?? this.eventId,
    roomId: roomId ?? this.roomId,
    originTs: originTs ?? this.originTs,
    producer: producer ?? this.producer,
    rawJson: rawJson ?? this.rawJson,
    enqueuedAt: enqueuedAt ?? this.enqueuedAt,
    attempts: attempts ?? this.attempts,
    nextDueAt: nextDueAt ?? this.nextDueAt,
    leaseUntil: leaseUntil ?? this.leaseUntil,
    status: status ?? this.status,
    committedAt: committedAt.present ? committedAt.value : this.committedAt,
    abandonedAt: abandonedAt.present ? abandonedAt.value : this.abandonedAt,
    lastErrorReason: lastErrorReason.present
        ? lastErrorReason.value
        : this.lastErrorReason,
    resurrectionCount: resurrectionCount ?? this.resurrectionCount,
    jsonPath: jsonPath.present ? jsonPath.value : this.jsonPath,
  );
  InboundEventQueueItem copyWithCompanion(InboundEventQueueCompanion data) {
    return InboundEventQueueItem(
      queueId: data.queueId.present ? data.queueId.value : this.queueId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      roomId: data.roomId.present ? data.roomId.value : this.roomId,
      originTs: data.originTs.present ? data.originTs.value : this.originTs,
      producer: data.producer.present ? data.producer.value : this.producer,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      enqueuedAt: data.enqueuedAt.present
          ? data.enqueuedAt.value
          : this.enqueuedAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextDueAt: data.nextDueAt.present ? data.nextDueAt.value : this.nextDueAt,
      leaseUntil: data.leaseUntil.present
          ? data.leaseUntil.value
          : this.leaseUntil,
      status: data.status.present ? data.status.value : this.status,
      committedAt: data.committedAt.present
          ? data.committedAt.value
          : this.committedAt,
      abandonedAt: data.abandonedAt.present
          ? data.abandonedAt.value
          : this.abandonedAt,
      lastErrorReason: data.lastErrorReason.present
          ? data.lastErrorReason.value
          : this.lastErrorReason,
      resurrectionCount: data.resurrectionCount.present
          ? data.resurrectionCount.value
          : this.resurrectionCount,
      jsonPath: data.jsonPath.present ? data.jsonPath.value : this.jsonPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InboundEventQueueItem(')
          ..write('queueId: $queueId, ')
          ..write('eventId: $eventId, ')
          ..write('roomId: $roomId, ')
          ..write('originTs: $originTs, ')
          ..write('producer: $producer, ')
          ..write('rawJson: $rawJson, ')
          ..write('enqueuedAt: $enqueuedAt, ')
          ..write('attempts: $attempts, ')
          ..write('nextDueAt: $nextDueAt, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('status: $status, ')
          ..write('committedAt: $committedAt, ')
          ..write('abandonedAt: $abandonedAt, ')
          ..write('lastErrorReason: $lastErrorReason, ')
          ..write('resurrectionCount: $resurrectionCount, ')
          ..write('jsonPath: $jsonPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    queueId,
    eventId,
    roomId,
    originTs,
    producer,
    rawJson,
    enqueuedAt,
    attempts,
    nextDueAt,
    leaseUntil,
    status,
    committedAt,
    abandonedAt,
    lastErrorReason,
    resurrectionCount,
    jsonPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InboundEventQueueItem &&
          other.queueId == this.queueId &&
          other.eventId == this.eventId &&
          other.roomId == this.roomId &&
          other.originTs == this.originTs &&
          other.producer == this.producer &&
          other.rawJson == this.rawJson &&
          other.enqueuedAt == this.enqueuedAt &&
          other.attempts == this.attempts &&
          other.nextDueAt == this.nextDueAt &&
          other.leaseUntil == this.leaseUntil &&
          other.status == this.status &&
          other.committedAt == this.committedAt &&
          other.abandonedAt == this.abandonedAt &&
          other.lastErrorReason == this.lastErrorReason &&
          other.resurrectionCount == this.resurrectionCount &&
          other.jsonPath == this.jsonPath);
}

class InboundEventQueueCompanion
    extends UpdateCompanion<InboundEventQueueItem> {
  final Value<int> queueId;
  final Value<String> eventId;
  final Value<String> roomId;
  final Value<int> originTs;
  final Value<String> producer;
  final Value<String> rawJson;
  final Value<int> enqueuedAt;
  final Value<int> attempts;
  final Value<int> nextDueAt;
  final Value<int> leaseUntil;
  final Value<String> status;
  final Value<int?> committedAt;
  final Value<int?> abandonedAt;
  final Value<String?> lastErrorReason;
  final Value<int> resurrectionCount;
  final Value<String?> jsonPath;
  const InboundEventQueueCompanion({
    this.queueId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.roomId = const Value.absent(),
    this.originTs = const Value.absent(),
    this.producer = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.enqueuedAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextDueAt = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.status = const Value.absent(),
    this.committedAt = const Value.absent(),
    this.abandonedAt = const Value.absent(),
    this.lastErrorReason = const Value.absent(),
    this.resurrectionCount = const Value.absent(),
    this.jsonPath = const Value.absent(),
  });
  InboundEventQueueCompanion.insert({
    this.queueId = const Value.absent(),
    required String eventId,
    required String roomId,
    required int originTs,
    required String producer,
    required String rawJson,
    required int enqueuedAt,
    this.attempts = const Value.absent(),
    this.nextDueAt = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.status = const Value.absent(),
    this.committedAt = const Value.absent(),
    this.abandonedAt = const Value.absent(),
    this.lastErrorReason = const Value.absent(),
    this.resurrectionCount = const Value.absent(),
    this.jsonPath = const Value.absent(),
  }) : eventId = Value(eventId),
       roomId = Value(roomId),
       originTs = Value(originTs),
       producer = Value(producer),
       rawJson = Value(rawJson),
       enqueuedAt = Value(enqueuedAt);
  static Insertable<InboundEventQueueItem> custom({
    Expression<int>? queueId,
    Expression<String>? eventId,
    Expression<String>? roomId,
    Expression<int>? originTs,
    Expression<String>? producer,
    Expression<String>? rawJson,
    Expression<int>? enqueuedAt,
    Expression<int>? attempts,
    Expression<int>? nextDueAt,
    Expression<int>? leaseUntil,
    Expression<String>? status,
    Expression<int>? committedAt,
    Expression<int>? abandonedAt,
    Expression<String>? lastErrorReason,
    Expression<int>? resurrectionCount,
    Expression<String>? jsonPath,
  }) {
    return RawValuesInsertable({
      if (queueId != null) 'queue_id': queueId,
      if (eventId != null) 'event_id': eventId,
      if (roomId != null) 'room_id': roomId,
      if (originTs != null) 'origin_ts': originTs,
      if (producer != null) 'producer': producer,
      if (rawJson != null) 'raw_json': rawJson,
      if (enqueuedAt != null) 'enqueued_at': enqueuedAt,
      if (attempts != null) 'attempts': attempts,
      if (nextDueAt != null) 'next_due_at': nextDueAt,
      if (leaseUntil != null) 'lease_until': leaseUntil,
      if (status != null) 'status': status,
      if (committedAt != null) 'committed_at': committedAt,
      if (abandonedAt != null) 'abandoned_at': abandonedAt,
      if (lastErrorReason != null) 'last_error_reason': lastErrorReason,
      if (resurrectionCount != null) 'resurrection_count': resurrectionCount,
      if (jsonPath != null) 'json_path': jsonPath,
    });
  }

  InboundEventQueueCompanion copyWith({
    Value<int>? queueId,
    Value<String>? eventId,
    Value<String>? roomId,
    Value<int>? originTs,
    Value<String>? producer,
    Value<String>? rawJson,
    Value<int>? enqueuedAt,
    Value<int>? attempts,
    Value<int>? nextDueAt,
    Value<int>? leaseUntil,
    Value<String>? status,
    Value<int?>? committedAt,
    Value<int?>? abandonedAt,
    Value<String?>? lastErrorReason,
    Value<int>? resurrectionCount,
    Value<String?>? jsonPath,
  }) {
    return InboundEventQueueCompanion(
      queueId: queueId ?? this.queueId,
      eventId: eventId ?? this.eventId,
      roomId: roomId ?? this.roomId,
      originTs: originTs ?? this.originTs,
      producer: producer ?? this.producer,
      rawJson: rawJson ?? this.rawJson,
      enqueuedAt: enqueuedAt ?? this.enqueuedAt,
      attempts: attempts ?? this.attempts,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      leaseUntil: leaseUntil ?? this.leaseUntil,
      status: status ?? this.status,
      committedAt: committedAt ?? this.committedAt,
      abandonedAt: abandonedAt ?? this.abandonedAt,
      lastErrorReason: lastErrorReason ?? this.lastErrorReason,
      resurrectionCount: resurrectionCount ?? this.resurrectionCount,
      jsonPath: jsonPath ?? this.jsonPath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (queueId.present) {
      map['queue_id'] = Variable<int>(queueId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (originTs.present) {
      map['origin_ts'] = Variable<int>(originTs.value);
    }
    if (producer.present) {
      map['producer'] = Variable<String>(producer.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (enqueuedAt.present) {
      map['enqueued_at'] = Variable<int>(enqueuedAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextDueAt.present) {
      map['next_due_at'] = Variable<int>(nextDueAt.value);
    }
    if (leaseUntil.present) {
      map['lease_until'] = Variable<int>(leaseUntil.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (committedAt.present) {
      map['committed_at'] = Variable<int>(committedAt.value);
    }
    if (abandonedAt.present) {
      map['abandoned_at'] = Variable<int>(abandonedAt.value);
    }
    if (lastErrorReason.present) {
      map['last_error_reason'] = Variable<String>(lastErrorReason.value);
    }
    if (resurrectionCount.present) {
      map['resurrection_count'] = Variable<int>(resurrectionCount.value);
    }
    if (jsonPath.present) {
      map['json_path'] = Variable<String>(jsonPath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InboundEventQueueCompanion(')
          ..write('queueId: $queueId, ')
          ..write('eventId: $eventId, ')
          ..write('roomId: $roomId, ')
          ..write('originTs: $originTs, ')
          ..write('producer: $producer, ')
          ..write('rawJson: $rawJson, ')
          ..write('enqueuedAt: $enqueuedAt, ')
          ..write('attempts: $attempts, ')
          ..write('nextDueAt: $nextDueAt, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('status: $status, ')
          ..write('committedAt: $committedAt, ')
          ..write('abandonedAt: $abandonedAt, ')
          ..write('lastErrorReason: $lastErrorReason, ')
          ..write('resurrectionCount: $resurrectionCount, ')
          ..write('jsonPath: $jsonPath')
          ..write(')'))
        .toString();
  }
}

class $QueueMarkersTable extends QueueMarkers
    with TableInfo<$QueueMarkersTable, QueueMarkerItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueueMarkersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  @override
  late final GeneratedColumn<String> roomId = GeneratedColumn<String>(
    'room_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAppliedEventIdMeta =
      const VerificationMeta('lastAppliedEventId');
  @override
  late final GeneratedColumn<String> lastAppliedEventId =
      GeneratedColumn<String>(
        'last_applied_event_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastAppliedTsMeta = const VerificationMeta(
    'lastAppliedTs',
  );
  @override
  late final GeneratedColumn<int> lastAppliedTs = GeneratedColumn<int>(
    'last_applied_ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAppliedCommitSeqMeta =
      const VerificationMeta('lastAppliedCommitSeq');
  @override
  late final GeneratedColumn<int> lastAppliedCommitSeq = GeneratedColumn<int>(
    'last_applied_commit_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    roomId,
    lastAppliedEventId,
    lastAppliedTs,
    lastAppliedCommitSeq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queue_markers';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueueMarkerItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('room_id')) {
      context.handle(
        _roomIdMeta,
        roomId.isAcceptableOrUnknown(data['room_id']!, _roomIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('last_applied_event_id')) {
      context.handle(
        _lastAppliedEventIdMeta,
        lastAppliedEventId.isAcceptableOrUnknown(
          data['last_applied_event_id']!,
          _lastAppliedEventIdMeta,
        ),
      );
    }
    if (data.containsKey('last_applied_ts')) {
      context.handle(
        _lastAppliedTsMeta,
        lastAppliedTs.isAcceptableOrUnknown(
          data['last_applied_ts']!,
          _lastAppliedTsMeta,
        ),
      );
    }
    if (data.containsKey('last_applied_commit_seq')) {
      context.handle(
        _lastAppliedCommitSeqMeta,
        lastAppliedCommitSeq.isAcceptableOrUnknown(
          data['last_applied_commit_seq']!,
          _lastAppliedCommitSeqMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {roomId};
  @override
  QueueMarkerItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueueMarkerItem(
      roomId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_id'],
      )!,
      lastAppliedEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_applied_event_id'],
      ),
      lastAppliedTs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_applied_ts'],
      )!,
      lastAppliedCommitSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_applied_commit_seq'],
      )!,
    );
  }

  @override
  $QueueMarkersTable createAlias(String alias) {
    return $QueueMarkersTable(attachedDatabase, alias);
  }
}

class QueueMarkerItem extends DataClass implements Insertable<QueueMarkerItem> {
  final String roomId;

  /// Last `$`-prefixed (server-assigned) event id applied. Nullable
  /// because early boot has none yet. Placeholder (`lotti-...`) ids
  /// are never written here; they stay in-memory on the worker.
  final String? lastAppliedEventId;

  /// Highest `originServerTs` we have applied and committed. Guarded
  /// by `TimelineEventOrdering.isNewer`; writes only accept
  /// monotonic advancement (F2).
  final int lastAppliedTs;

  /// Monotonic counter incremented on every successful
  /// `commitApplied`. Diagnostic use only.
  final int lastAppliedCommitSeq;
  const QueueMarkerItem({
    required this.roomId,
    this.lastAppliedEventId,
    required this.lastAppliedTs,
    required this.lastAppliedCommitSeq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['room_id'] = Variable<String>(roomId);
    if (!nullToAbsent || lastAppliedEventId != null) {
      map['last_applied_event_id'] = Variable<String>(lastAppliedEventId);
    }
    map['last_applied_ts'] = Variable<int>(lastAppliedTs);
    map['last_applied_commit_seq'] = Variable<int>(lastAppliedCommitSeq);
    return map;
  }

  QueueMarkersCompanion toCompanion(bool nullToAbsent) {
    return QueueMarkersCompanion(
      roomId: Value(roomId),
      lastAppliedEventId: lastAppliedEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAppliedEventId),
      lastAppliedTs: Value(lastAppliedTs),
      lastAppliedCommitSeq: Value(lastAppliedCommitSeq),
    );
  }

  factory QueueMarkerItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueueMarkerItem(
      roomId: serializer.fromJson<String>(json['roomId']),
      lastAppliedEventId: serializer.fromJson<String?>(
        json['lastAppliedEventId'],
      ),
      lastAppliedTs: serializer.fromJson<int>(json['lastAppliedTs']),
      lastAppliedCommitSeq: serializer.fromJson<int>(
        json['lastAppliedCommitSeq'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'roomId': serializer.toJson<String>(roomId),
      'lastAppliedEventId': serializer.toJson<String?>(lastAppliedEventId),
      'lastAppliedTs': serializer.toJson<int>(lastAppliedTs),
      'lastAppliedCommitSeq': serializer.toJson<int>(lastAppliedCommitSeq),
    };
  }

  QueueMarkerItem copyWith({
    String? roomId,
    Value<String?> lastAppliedEventId = const Value.absent(),
    int? lastAppliedTs,
    int? lastAppliedCommitSeq,
  }) => QueueMarkerItem(
    roomId: roomId ?? this.roomId,
    lastAppliedEventId: lastAppliedEventId.present
        ? lastAppliedEventId.value
        : this.lastAppliedEventId,
    lastAppliedTs: lastAppliedTs ?? this.lastAppliedTs,
    lastAppliedCommitSeq: lastAppliedCommitSeq ?? this.lastAppliedCommitSeq,
  );
  QueueMarkerItem copyWithCompanion(QueueMarkersCompanion data) {
    return QueueMarkerItem(
      roomId: data.roomId.present ? data.roomId.value : this.roomId,
      lastAppliedEventId: data.lastAppliedEventId.present
          ? data.lastAppliedEventId.value
          : this.lastAppliedEventId,
      lastAppliedTs: data.lastAppliedTs.present
          ? data.lastAppliedTs.value
          : this.lastAppliedTs,
      lastAppliedCommitSeq: data.lastAppliedCommitSeq.present
          ? data.lastAppliedCommitSeq.value
          : this.lastAppliedCommitSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueueMarkerItem(')
          ..write('roomId: $roomId, ')
          ..write('lastAppliedEventId: $lastAppliedEventId, ')
          ..write('lastAppliedTs: $lastAppliedTs, ')
          ..write('lastAppliedCommitSeq: $lastAppliedCommitSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    roomId,
    lastAppliedEventId,
    lastAppliedTs,
    lastAppliedCommitSeq,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueueMarkerItem &&
          other.roomId == this.roomId &&
          other.lastAppliedEventId == this.lastAppliedEventId &&
          other.lastAppliedTs == this.lastAppliedTs &&
          other.lastAppliedCommitSeq == this.lastAppliedCommitSeq);
}

class QueueMarkersCompanion extends UpdateCompanion<QueueMarkerItem> {
  final Value<String> roomId;
  final Value<String?> lastAppliedEventId;
  final Value<int> lastAppliedTs;
  final Value<int> lastAppliedCommitSeq;
  final Value<int> rowid;
  const QueueMarkersCompanion({
    this.roomId = const Value.absent(),
    this.lastAppliedEventId = const Value.absent(),
    this.lastAppliedTs = const Value.absent(),
    this.lastAppliedCommitSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QueueMarkersCompanion.insert({
    required String roomId,
    this.lastAppliedEventId = const Value.absent(),
    this.lastAppliedTs = const Value.absent(),
    this.lastAppliedCommitSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : roomId = Value(roomId);
  static Insertable<QueueMarkerItem> custom({
    Expression<String>? roomId,
    Expression<String>? lastAppliedEventId,
    Expression<int>? lastAppliedTs,
    Expression<int>? lastAppliedCommitSeq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (roomId != null) 'room_id': roomId,
      if (lastAppliedEventId != null)
        'last_applied_event_id': lastAppliedEventId,
      if (lastAppliedTs != null) 'last_applied_ts': lastAppliedTs,
      if (lastAppliedCommitSeq != null)
        'last_applied_commit_seq': lastAppliedCommitSeq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QueueMarkersCompanion copyWith({
    Value<String>? roomId,
    Value<String?>? lastAppliedEventId,
    Value<int>? lastAppliedTs,
    Value<int>? lastAppliedCommitSeq,
    Value<int>? rowid,
  }) {
    return QueueMarkersCompanion(
      roomId: roomId ?? this.roomId,
      lastAppliedEventId: lastAppliedEventId ?? this.lastAppliedEventId,
      lastAppliedTs: lastAppliedTs ?? this.lastAppliedTs,
      lastAppliedCommitSeq: lastAppliedCommitSeq ?? this.lastAppliedCommitSeq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (lastAppliedEventId.present) {
      map['last_applied_event_id'] = Variable<String>(lastAppliedEventId.value);
    }
    if (lastAppliedTs.present) {
      map['last_applied_ts'] = Variable<int>(lastAppliedTs.value);
    }
    if (lastAppliedCommitSeq.present) {
      map['last_applied_commit_seq'] = Variable<int>(
        lastAppliedCommitSeq.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueueMarkersCompanion(')
          ..write('roomId: $roomId, ')
          ..write('lastAppliedEventId: $lastAppliedEventId, ')
          ..write('lastAppliedTs: $lastAppliedTs, ')
          ..write('lastAppliedCommitSeq: $lastAppliedCommitSeq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SyncDatabase extends GeneratedDatabase {
  _$SyncDatabase(QueryExecutor e) : super(e);
  _$SyncDatabase.connect(DatabaseConnection c) : super.connect(c);
  $SyncDatabaseManager get managers => $SyncDatabaseManager(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncSequenceLogTable syncSequenceLog = $SyncSequenceLogTable(
    this,
  );
  late final $HostActivityTable hostActivity = $HostActivityTable(this);
  late final $InboundEventQueueTable inboundEventQueue =
      $InboundEventQueueTable(this);
  late final $QueueMarkersTable queueMarkers = $QueueMarkersTable(this);
  late final Index idxOutboxStatusPriorityCreatedAt = Index(
    'idx_outbox_status_priority_created_at',
    'CREATE INDEX idx_outbox_status_priority_created_at ON outbox (status, priority, created_at)',
  );
  late final Index idxOutboxActionablePriorityCreatedAt = Index(
    'idx_outbox_actionable_priority_created_at',
    'CREATE INDEX idx_outbox_actionable_priority_created_at ON outbox (priority, created_at) WHERE status IN (0, 3)',
  );
  late final Index idxSyncSequenceLogActionableStatusCreatedAt = Index(
    'idx_sync_sequence_log_actionable_status_created_at',
    'CREATE INDEX idx_sync_sequence_log_actionable_status_created_at ON sync_sequence_log (status, created_at) WHERE status IN (1, 2)',
  );
  late final Index idxSyncSequenceLogActionableStatusUpdatedAt = Index(
    'idx_sync_sequence_log_actionable_status_updated_at',
    'CREATE INDEX idx_sync_sequence_log_actionable_status_updated_at ON sync_sequence_log (status, updated_at) WHERE status IN (1, 2)',
  );
  late final Index idxSyncSequenceLogHostStatus = Index(
    'idx_sync_sequence_log_host_status',
    'CREATE INDEX idx_sync_sequence_log_host_status ON sync_sequence_log (host_id, status)',
  );
  late final Index idxSyncSequenceLogPayloadResolution = Index(
    'idx_sync_sequence_log_payload_resolution',
    'CREATE INDEX idx_sync_sequence_log_payload_resolution ON sync_sequence_log (entry_id, payload_type, status) WHERE entry_id IS NOT NULL',
  );
  late final Index idxSyncSequenceLogHostEntryStatusCounter = Index(
    'idx_sync_sequence_log_host_entry_status_counter',
    'CREATE INDEX idx_sync_sequence_log_host_entry_status_counter ON sync_sequence_log (host_id, entry_id, counter DESC, status) WHERE entry_id IS NOT NULL',
  );
  late final Index idxInboundEventQueueReady = Index(
    'idx_inbound_event_queue_ready',
    'CREATE INDEX idx_inbound_event_queue_ready ON inbound_event_queue (next_due_at, origin_ts, queue_id) WHERE status IN (\'enqueued\', \'retrying\')',
  );
  late final Index idxInboundEventQueueActiveReadyAt = Index(
    'idx_inbound_event_queue_active_ready_at',
    'CREATE INDEX idx_inbound_event_queue_active_ready_at ON inbound_event_queue (next_due_at, lease_until) WHERE status IN (\'enqueued\', \'retrying\', \'leased\')',
  );
  late final Index idxInboundEventQueueRoom = Index(
    'idx_inbound_event_queue_room',
    'CREATE INDEX idx_inbound_event_queue_room ON inbound_event_queue (room_id, origin_ts)',
  );
  late final Index idxInboundEventQueueActiveRoomTs = Index(
    'idx_inbound_event_queue_active_room_ts',
    'CREATE INDEX idx_inbound_event_queue_active_room_ts ON inbound_event_queue (room_id, origin_ts) WHERE status IN (\'enqueued\', \'leased\', \'retrying\')',
  );
  late final Index idxInboundEventQueueAbandonedPath = Index(
    'idx_inbound_event_queue_abandoned_path',
    'CREATE INDEX idx_inbound_event_queue_abandoned_path ON inbound_event_queue (json_path) WHERE status = \'abandoned\'',
  );
  late final Index idxInboundEventQueueAbandonedReason = Index(
    'idx_inbound_event_queue_abandoned_reason',
    'CREATE INDEX idx_inbound_event_queue_abandoned_reason ON inbound_event_queue (last_error_reason) WHERE status = \'abandoned\'',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    outbox,
    syncSequenceLog,
    hostActivity,
    inboundEventQueue,
    queueMarkers,
    idxOutboxStatusPriorityCreatedAt,
    idxOutboxActionablePriorityCreatedAt,
    idxSyncSequenceLogActionableStatusCreatedAt,
    idxSyncSequenceLogActionableStatusUpdatedAt,
    idxSyncSequenceLogHostStatus,
    idxSyncSequenceLogPayloadResolution,
    idxSyncSequenceLogHostEntryStatusCounter,
    idxInboundEventQueueReady,
    idxInboundEventQueueActiveReadyAt,
    idxInboundEventQueueRoom,
    idxInboundEventQueueActiveRoomTs,
    idxInboundEventQueueAbandonedPath,
    idxInboundEventQueueAbandonedReason,
  ];
}

typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> status,
      Value<int> retries,
      required String message,
      required String subject,
      Value<String?> filePath,
      Value<String?> outboxEntryId,
      Value<int?> payloadSize,
      Value<int> priority,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> status,
      Value<int> retries,
      Value<String> message,
      Value<String> subject,
      Value<String?> filePath,
      Value<String?> outboxEntryId,
      Value<int?> payloadSize,
      Value<int> priority,
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

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retries => $composableBuilder(
    column: $table.retries,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outboxEntryId => $composableBuilder(
    column: $table.outboxEntryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payloadSize => $composableBuilder(
    column: $table.payloadSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );
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

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retries => $composableBuilder(
    column: $table.retries,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outboxEntryId => $composableBuilder(
    column: $table.outboxEntryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payloadSize => $composableBuilder(
    column: $table.payloadSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );
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

  GeneratedColumn<String> get outboxEntryId => $composableBuilder(
    column: $table.outboxEntryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get payloadSize => $composableBuilder(
    column: $table.payloadSize,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$SyncDatabase,
          $OutboxTable,
          OutboxItem,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (
            OutboxItem,
            BaseReferences<_$SyncDatabase, $OutboxTable, OutboxItem>,
          ),
          OutboxItem,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$SyncDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int> retries = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> outboxEntryId = const Value.absent(),
                Value<int?> payloadSize = const Value.absent(),
                Value<int> priority = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                retries: retries,
                message: message,
                subject: subject,
                filePath: filePath,
                outboxEntryId: outboxEntryId,
                payloadSize: payloadSize,
                priority: priority,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int> retries = const Value.absent(),
                required String message,
                required String subject,
                Value<String?> filePath = const Value.absent(),
                Value<String?> outboxEntryId = const Value.absent(),
                Value<int?> payloadSize = const Value.absent(),
                Value<int> priority = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                retries: retries,
                message: message,
                subject: subject,
                filePath: filePath,
                outboxEntryId: outboxEntryId,
                payloadSize: payloadSize,
                priority: priority,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
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
      PrefetchHooks Function()
    >;
typedef $$SyncSequenceLogTableCreateCompanionBuilder =
    SyncSequenceLogCompanion Function({
      required String hostId,
      required int counter,
      Value<String?> entryId,
      Value<int> payloadType,
      Value<String?> originatingHostId,
      Value<int> status,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> requestCount,
      Value<DateTime?> lastRequestedAt,
      Value<String?> jsonPath,
      Value<int> rowid,
    });
typedef $$SyncSequenceLogTableUpdateCompanionBuilder =
    SyncSequenceLogCompanion Function({
      Value<String> hostId,
      Value<int> counter,
      Value<String?> entryId,
      Value<int> payloadType,
      Value<String?> originatingHostId,
      Value<int> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> requestCount,
      Value<DateTime?> lastRequestedAt,
      Value<String?> jsonPath,
      Value<int> rowid,
    });

class $$SyncSequenceLogTableFilterComposer
    extends Composer<_$SyncDatabase, $SyncSequenceLogTable> {
  $$SyncSequenceLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hostId => $composableBuilder(
    column: $table.hostId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get counter => $composableBuilder(
    column: $table.counter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payloadType => $composableBuilder(
    column: $table.payloadType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originatingHostId => $composableBuilder(
    column: $table.originatingHostId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<int> get requestCount => $composableBuilder(
    column: $table.requestCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastRequestedAt => $composableBuilder(
    column: $table.lastRequestedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsonPath => $composableBuilder(
    column: $table.jsonPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncSequenceLogTableOrderingComposer
    extends Composer<_$SyncDatabase, $SyncSequenceLogTable> {
  $$SyncSequenceLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hostId => $composableBuilder(
    column: $table.hostId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get counter => $composableBuilder(
    column: $table.counter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payloadType => $composableBuilder(
    column: $table.payloadType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originatingHostId => $composableBuilder(
    column: $table.originatingHostId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<int> get requestCount => $composableBuilder(
    column: $table.requestCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastRequestedAt => $composableBuilder(
    column: $table.lastRequestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsonPath => $composableBuilder(
    column: $table.jsonPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncSequenceLogTableAnnotationComposer
    extends Composer<_$SyncDatabase, $SyncSequenceLogTable> {
  $$SyncSequenceLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hostId =>
      $composableBuilder(column: $table.hostId, builder: (column) => column);

  GeneratedColumn<int> get counter =>
      $composableBuilder(column: $table.counter, builder: (column) => column);

  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<int> get payloadType => $composableBuilder(
    column: $table.payloadType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originatingHostId => $composableBuilder(
    column: $table.originatingHostId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get requestCount => $composableBuilder(
    column: $table.requestCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastRequestedAt => $composableBuilder(
    column: $table.lastRequestedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jsonPath =>
      $composableBuilder(column: $table.jsonPath, builder: (column) => column);
}

class $$SyncSequenceLogTableTableManager
    extends
        RootTableManager<
          _$SyncDatabase,
          $SyncSequenceLogTable,
          SyncSequenceLogItem,
          $$SyncSequenceLogTableFilterComposer,
          $$SyncSequenceLogTableOrderingComposer,
          $$SyncSequenceLogTableAnnotationComposer,
          $$SyncSequenceLogTableCreateCompanionBuilder,
          $$SyncSequenceLogTableUpdateCompanionBuilder,
          (
            SyncSequenceLogItem,
            BaseReferences<
              _$SyncDatabase,
              $SyncSequenceLogTable,
              SyncSequenceLogItem
            >,
          ),
          SyncSequenceLogItem,
          PrefetchHooks Function()
        > {
  $$SyncSequenceLogTableTableManager(
    _$SyncDatabase db,
    $SyncSequenceLogTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncSequenceLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncSequenceLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncSequenceLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hostId = const Value.absent(),
                Value<int> counter = const Value.absent(),
                Value<String?> entryId = const Value.absent(),
                Value<int> payloadType = const Value.absent(),
                Value<String?> originatingHostId = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> requestCount = const Value.absent(),
                Value<DateTime?> lastRequestedAt = const Value.absent(),
                Value<String?> jsonPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncSequenceLogCompanion(
                hostId: hostId,
                counter: counter,
                entryId: entryId,
                payloadType: payloadType,
                originatingHostId: originatingHostId,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                requestCount: requestCount,
                lastRequestedAt: lastRequestedAt,
                jsonPath: jsonPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hostId,
                required int counter,
                Value<String?> entryId = const Value.absent(),
                Value<int> payloadType = const Value.absent(),
                Value<String?> originatingHostId = const Value.absent(),
                Value<int> status = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> requestCount = const Value.absent(),
                Value<DateTime?> lastRequestedAt = const Value.absent(),
                Value<String?> jsonPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncSequenceLogCompanion.insert(
                hostId: hostId,
                counter: counter,
                entryId: entryId,
                payloadType: payloadType,
                originatingHostId: originatingHostId,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                requestCount: requestCount,
                lastRequestedAt: lastRequestedAt,
                jsonPath: jsonPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncSequenceLogTableProcessedTableManager =
    ProcessedTableManager<
      _$SyncDatabase,
      $SyncSequenceLogTable,
      SyncSequenceLogItem,
      $$SyncSequenceLogTableFilterComposer,
      $$SyncSequenceLogTableOrderingComposer,
      $$SyncSequenceLogTableAnnotationComposer,
      $$SyncSequenceLogTableCreateCompanionBuilder,
      $$SyncSequenceLogTableUpdateCompanionBuilder,
      (
        SyncSequenceLogItem,
        BaseReferences<
          _$SyncDatabase,
          $SyncSequenceLogTable,
          SyncSequenceLogItem
        >,
      ),
      SyncSequenceLogItem,
      PrefetchHooks Function()
    >;
typedef $$HostActivityTableCreateCompanionBuilder =
    HostActivityCompanion Function({
      required String hostId,
      required DateTime lastSeenAt,
      Value<int> rowid,
    });
typedef $$HostActivityTableUpdateCompanionBuilder =
    HostActivityCompanion Function({
      Value<String> hostId,
      Value<DateTime> lastSeenAt,
      Value<int> rowid,
    });

class $$HostActivityTableFilterComposer
    extends Composer<_$SyncDatabase, $HostActivityTable> {
  $$HostActivityTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hostId => $composableBuilder(
    column: $table.hostId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HostActivityTableOrderingComposer
    extends Composer<_$SyncDatabase, $HostActivityTable> {
  $$HostActivityTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hostId => $composableBuilder(
    column: $table.hostId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HostActivityTableAnnotationComposer
    extends Composer<_$SyncDatabase, $HostActivityTable> {
  $$HostActivityTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hostId =>
      $composableBuilder(column: $table.hostId, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );
}

class $$HostActivityTableTableManager
    extends
        RootTableManager<
          _$SyncDatabase,
          $HostActivityTable,
          HostActivityItem,
          $$HostActivityTableFilterComposer,
          $$HostActivityTableOrderingComposer,
          $$HostActivityTableAnnotationComposer,
          $$HostActivityTableCreateCompanionBuilder,
          $$HostActivityTableUpdateCompanionBuilder,
          (
            HostActivityItem,
            BaseReferences<
              _$SyncDatabase,
              $HostActivityTable,
              HostActivityItem
            >,
          ),
          HostActivityItem,
          PrefetchHooks Function()
        > {
  $$HostActivityTableTableManager(_$SyncDatabase db, $HostActivityTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HostActivityTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HostActivityTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HostActivityTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hostId = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HostActivityCompanion(
                hostId: hostId,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hostId,
                required DateTime lastSeenAt,
                Value<int> rowid = const Value.absent(),
              }) => HostActivityCompanion.insert(
                hostId: hostId,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HostActivityTableProcessedTableManager =
    ProcessedTableManager<
      _$SyncDatabase,
      $HostActivityTable,
      HostActivityItem,
      $$HostActivityTableFilterComposer,
      $$HostActivityTableOrderingComposer,
      $$HostActivityTableAnnotationComposer,
      $$HostActivityTableCreateCompanionBuilder,
      $$HostActivityTableUpdateCompanionBuilder,
      (
        HostActivityItem,
        BaseReferences<_$SyncDatabase, $HostActivityTable, HostActivityItem>,
      ),
      HostActivityItem,
      PrefetchHooks Function()
    >;
typedef $$InboundEventQueueTableCreateCompanionBuilder =
    InboundEventQueueCompanion Function({
      Value<int> queueId,
      required String eventId,
      required String roomId,
      required int originTs,
      required String producer,
      required String rawJson,
      required int enqueuedAt,
      Value<int> attempts,
      Value<int> nextDueAt,
      Value<int> leaseUntil,
      Value<String> status,
      Value<int?> committedAt,
      Value<int?> abandonedAt,
      Value<String?> lastErrorReason,
      Value<int> resurrectionCount,
      Value<String?> jsonPath,
    });
typedef $$InboundEventQueueTableUpdateCompanionBuilder =
    InboundEventQueueCompanion Function({
      Value<int> queueId,
      Value<String> eventId,
      Value<String> roomId,
      Value<int> originTs,
      Value<String> producer,
      Value<String> rawJson,
      Value<int> enqueuedAt,
      Value<int> attempts,
      Value<int> nextDueAt,
      Value<int> leaseUntil,
      Value<String> status,
      Value<int?> committedAt,
      Value<int?> abandonedAt,
      Value<String?> lastErrorReason,
      Value<int> resurrectionCount,
      Value<String?> jsonPath,
    });

class $$InboundEventQueueTableFilterComposer
    extends Composer<_$SyncDatabase, $InboundEventQueueTable> {
  $$InboundEventQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get queueId => $composableBuilder(
    column: $table.queueId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originTs => $composableBuilder(
    column: $table.originTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get producer => $composableBuilder(
    column: $table.producer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextDueAt => $composableBuilder(
    column: $table.nextDueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get committedAt => $composableBuilder(
    column: $table.committedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get abandonedAt => $composableBuilder(
    column: $table.abandonedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorReason => $composableBuilder(
    column: $table.lastErrorReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resurrectionCount => $composableBuilder(
    column: $table.resurrectionCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsonPath => $composableBuilder(
    column: $table.jsonPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InboundEventQueueTableOrderingComposer
    extends Composer<_$SyncDatabase, $InboundEventQueueTable> {
  $$InboundEventQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get queueId => $composableBuilder(
    column: $table.queueId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originTs => $composableBuilder(
    column: $table.originTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get producer => $composableBuilder(
    column: $table.producer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextDueAt => $composableBuilder(
    column: $table.nextDueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get committedAt => $composableBuilder(
    column: $table.committedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get abandonedAt => $composableBuilder(
    column: $table.abandonedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorReason => $composableBuilder(
    column: $table.lastErrorReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resurrectionCount => $composableBuilder(
    column: $table.resurrectionCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsonPath => $composableBuilder(
    column: $table.jsonPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InboundEventQueueTableAnnotationComposer
    extends Composer<_$SyncDatabase, $InboundEventQueueTable> {
  $$InboundEventQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get queueId =>
      $composableBuilder(column: $table.queueId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get roomId =>
      $composableBuilder(column: $table.roomId, builder: (column) => column);

  GeneratedColumn<int> get originTs =>
      $composableBuilder(column: $table.originTs, builder: (column) => column);

  GeneratedColumn<String> get producer =>
      $composableBuilder(column: $table.producer, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<int> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get nextDueAt =>
      $composableBuilder(column: $table.nextDueAt, builder: (column) => column);

  GeneratedColumn<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get committedAt => $composableBuilder(
    column: $table.committedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get abandonedAt => $composableBuilder(
    column: $table.abandonedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorReason => $composableBuilder(
    column: $table.lastErrorReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resurrectionCount => $composableBuilder(
    column: $table.resurrectionCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jsonPath =>
      $composableBuilder(column: $table.jsonPath, builder: (column) => column);
}

class $$InboundEventQueueTableTableManager
    extends
        RootTableManager<
          _$SyncDatabase,
          $InboundEventQueueTable,
          InboundEventQueueItem,
          $$InboundEventQueueTableFilterComposer,
          $$InboundEventQueueTableOrderingComposer,
          $$InboundEventQueueTableAnnotationComposer,
          $$InboundEventQueueTableCreateCompanionBuilder,
          $$InboundEventQueueTableUpdateCompanionBuilder,
          (
            InboundEventQueueItem,
            BaseReferences<
              _$SyncDatabase,
              $InboundEventQueueTable,
              InboundEventQueueItem
            >,
          ),
          InboundEventQueueItem,
          PrefetchHooks Function()
        > {
  $$InboundEventQueueTableTableManager(
    _$SyncDatabase db,
    $InboundEventQueueTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InboundEventQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InboundEventQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InboundEventQueueTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> queueId = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> roomId = const Value.absent(),
                Value<int> originTs = const Value.absent(),
                Value<String> producer = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<int> enqueuedAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> nextDueAt = const Value.absent(),
                Value<int> leaseUntil = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> committedAt = const Value.absent(),
                Value<int?> abandonedAt = const Value.absent(),
                Value<String?> lastErrorReason = const Value.absent(),
                Value<int> resurrectionCount = const Value.absent(),
                Value<String?> jsonPath = const Value.absent(),
              }) => InboundEventQueueCompanion(
                queueId: queueId,
                eventId: eventId,
                roomId: roomId,
                originTs: originTs,
                producer: producer,
                rawJson: rawJson,
                enqueuedAt: enqueuedAt,
                attempts: attempts,
                nextDueAt: nextDueAt,
                leaseUntil: leaseUntil,
                status: status,
                committedAt: committedAt,
                abandonedAt: abandonedAt,
                lastErrorReason: lastErrorReason,
                resurrectionCount: resurrectionCount,
                jsonPath: jsonPath,
              ),
          createCompanionCallback:
              ({
                Value<int> queueId = const Value.absent(),
                required String eventId,
                required String roomId,
                required int originTs,
                required String producer,
                required String rawJson,
                required int enqueuedAt,
                Value<int> attempts = const Value.absent(),
                Value<int> nextDueAt = const Value.absent(),
                Value<int> leaseUntil = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> committedAt = const Value.absent(),
                Value<int?> abandonedAt = const Value.absent(),
                Value<String?> lastErrorReason = const Value.absent(),
                Value<int> resurrectionCount = const Value.absent(),
                Value<String?> jsonPath = const Value.absent(),
              }) => InboundEventQueueCompanion.insert(
                queueId: queueId,
                eventId: eventId,
                roomId: roomId,
                originTs: originTs,
                producer: producer,
                rawJson: rawJson,
                enqueuedAt: enqueuedAt,
                attempts: attempts,
                nextDueAt: nextDueAt,
                leaseUntil: leaseUntil,
                status: status,
                committedAt: committedAt,
                abandonedAt: abandonedAt,
                lastErrorReason: lastErrorReason,
                resurrectionCount: resurrectionCount,
                jsonPath: jsonPath,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InboundEventQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$SyncDatabase,
      $InboundEventQueueTable,
      InboundEventQueueItem,
      $$InboundEventQueueTableFilterComposer,
      $$InboundEventQueueTableOrderingComposer,
      $$InboundEventQueueTableAnnotationComposer,
      $$InboundEventQueueTableCreateCompanionBuilder,
      $$InboundEventQueueTableUpdateCompanionBuilder,
      (
        InboundEventQueueItem,
        BaseReferences<
          _$SyncDatabase,
          $InboundEventQueueTable,
          InboundEventQueueItem
        >,
      ),
      InboundEventQueueItem,
      PrefetchHooks Function()
    >;
typedef $$QueueMarkersTableCreateCompanionBuilder =
    QueueMarkersCompanion Function({
      required String roomId,
      Value<String?> lastAppliedEventId,
      Value<int> lastAppliedTs,
      Value<int> lastAppliedCommitSeq,
      Value<int> rowid,
    });
typedef $$QueueMarkersTableUpdateCompanionBuilder =
    QueueMarkersCompanion Function({
      Value<String> roomId,
      Value<String?> lastAppliedEventId,
      Value<int> lastAppliedTs,
      Value<int> lastAppliedCommitSeq,
      Value<int> rowid,
    });

class $$QueueMarkersTableFilterComposer
    extends Composer<_$SyncDatabase, $QueueMarkersTable> {
  $$QueueMarkersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastAppliedEventId => $composableBuilder(
    column: $table.lastAppliedEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAppliedTs => $composableBuilder(
    column: $table.lastAppliedTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAppliedCommitSeq => $composableBuilder(
    column: $table.lastAppliedCommitSeq,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QueueMarkersTableOrderingComposer
    extends Composer<_$SyncDatabase, $QueueMarkersTable> {
  $$QueueMarkersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastAppliedEventId => $composableBuilder(
    column: $table.lastAppliedEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAppliedTs => $composableBuilder(
    column: $table.lastAppliedTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAppliedCommitSeq => $composableBuilder(
    column: $table.lastAppliedCommitSeq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QueueMarkersTableAnnotationComposer
    extends Composer<_$SyncDatabase, $QueueMarkersTable> {
  $$QueueMarkersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get roomId =>
      $composableBuilder(column: $table.roomId, builder: (column) => column);

  GeneratedColumn<String> get lastAppliedEventId => $composableBuilder(
    column: $table.lastAppliedEventId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAppliedTs => $composableBuilder(
    column: $table.lastAppliedTs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAppliedCommitSeq => $composableBuilder(
    column: $table.lastAppliedCommitSeq,
    builder: (column) => column,
  );
}

class $$QueueMarkersTableTableManager
    extends
        RootTableManager<
          _$SyncDatabase,
          $QueueMarkersTable,
          QueueMarkerItem,
          $$QueueMarkersTableFilterComposer,
          $$QueueMarkersTableOrderingComposer,
          $$QueueMarkersTableAnnotationComposer,
          $$QueueMarkersTableCreateCompanionBuilder,
          $$QueueMarkersTableUpdateCompanionBuilder,
          (
            QueueMarkerItem,
            BaseReferences<_$SyncDatabase, $QueueMarkersTable, QueueMarkerItem>,
          ),
          QueueMarkerItem,
          PrefetchHooks Function()
        > {
  $$QueueMarkersTableTableManager(_$SyncDatabase db, $QueueMarkersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueueMarkersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueueMarkersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueueMarkersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> roomId = const Value.absent(),
                Value<String?> lastAppliedEventId = const Value.absent(),
                Value<int> lastAppliedTs = const Value.absent(),
                Value<int> lastAppliedCommitSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QueueMarkersCompanion(
                roomId: roomId,
                lastAppliedEventId: lastAppliedEventId,
                lastAppliedTs: lastAppliedTs,
                lastAppliedCommitSeq: lastAppliedCommitSeq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String roomId,
                Value<String?> lastAppliedEventId = const Value.absent(),
                Value<int> lastAppliedTs = const Value.absent(),
                Value<int> lastAppliedCommitSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QueueMarkersCompanion.insert(
                roomId: roomId,
                lastAppliedEventId: lastAppliedEventId,
                lastAppliedTs: lastAppliedTs,
                lastAppliedCommitSeq: lastAppliedCommitSeq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QueueMarkersTableProcessedTableManager =
    ProcessedTableManager<
      _$SyncDatabase,
      $QueueMarkersTable,
      QueueMarkerItem,
      $$QueueMarkersTableFilterComposer,
      $$QueueMarkersTableOrderingComposer,
      $$QueueMarkersTableAnnotationComposer,
      $$QueueMarkersTableCreateCompanionBuilder,
      $$QueueMarkersTableUpdateCompanionBuilder,
      (
        QueueMarkerItem,
        BaseReferences<_$SyncDatabase, $QueueMarkersTable, QueueMarkerItem>,
      ),
      QueueMarkerItem,
      PrefetchHooks Function()
    >;

class $SyncDatabaseManager {
  final _$SyncDatabase _db;
  $SyncDatabaseManager(this._db);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncSequenceLogTableTableManager get syncSequenceLog =>
      $$SyncSequenceLogTableTableManager(_db, _db.syncSequenceLog);
  $$HostActivityTableTableManager get hostActivity =>
      $$HostActivityTableTableManager(_db, _db.hostActivity);
  $$InboundEventQueueTableTableManager get inboundEventQueue =>
      $$InboundEventQueueTableTableManager(_db, _db.inboundEventQueue);
  $$QueueMarkersTableTableManager get queueMarkers =>
      $$QueueMarkersTableTableManager(_db, _db.queueMarkers);
}
