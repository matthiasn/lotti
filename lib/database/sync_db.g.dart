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

class $SyncSequenceLogTable extends SyncSequenceLog
    with TableInfo<$SyncSequenceLogTable, SyncSequenceLogItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncSequenceLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hostIdMeta = const VerificationMeta('hostId');
  @override
  late final GeneratedColumn<String> hostId = GeneratedColumn<String>(
      'host_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _counterMeta =
      const VerificationMeta('counter');
  @override
  late final GeneratedColumn<int> counter = GeneratedColumn<int>(
      'counter', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _entryIdMeta =
      const VerificationMeta('entryId');
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
      'entry_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _payloadTypeMeta =
      const VerificationMeta('payloadType');
  @override
  late final GeneratedColumn<int> payloadType = GeneratedColumn<int>(
      'payload_type', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: Constant(SyncSequencePayloadType.journalEntity.index));
  static const VerificationMeta _originatingHostIdMeta =
      const VerificationMeta('originatingHostId');
  @override
  late final GeneratedColumn<String> originatingHostId =
      GeneratedColumn<String>('originating_host_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: Constant(SyncSequenceStatus.received.index));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _requestCountMeta =
      const VerificationMeta('requestCount');
  @override
  late final GeneratedColumn<int> requestCount = GeneratedColumn<int>(
      'request_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastRequestedAtMeta =
      const VerificationMeta('lastRequestedAt');
  @override
  late final GeneratedColumn<DateTime> lastRequestedAt =
      GeneratedColumn<DateTime>('last_requested_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
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
        lastRequestedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_sequence_log';
  @override
  VerificationContext validateIntegrity(
      Insertable<SyncSequenceLogItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('host_id')) {
      context.handle(_hostIdMeta,
          hostId.isAcceptableOrUnknown(data['host_id']!, _hostIdMeta));
    } else if (isInserting) {
      context.missing(_hostIdMeta);
    }
    if (data.containsKey('counter')) {
      context.handle(_counterMeta,
          counter.isAcceptableOrUnknown(data['counter']!, _counterMeta));
    } else if (isInserting) {
      context.missing(_counterMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(_entryIdMeta,
          entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta));
    }
    if (data.containsKey('payload_type')) {
      context.handle(
          _payloadTypeMeta,
          payloadType.isAcceptableOrUnknown(
              data['payload_type']!, _payloadTypeMeta));
    }
    if (data.containsKey('originating_host_id')) {
      context.handle(
          _originatingHostIdMeta,
          originatingHostId.isAcceptableOrUnknown(
              data['originating_host_id']!, _originatingHostIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
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
    if (data.containsKey('request_count')) {
      context.handle(
          _requestCountMeta,
          requestCount.isAcceptableOrUnknown(
              data['request_count']!, _requestCountMeta));
    }
    if (data.containsKey('last_requested_at')) {
      context.handle(
          _lastRequestedAtMeta,
          lastRequestedAt.isAcceptableOrUnknown(
              data['last_requested_at']!, _lastRequestedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {hostId, counter};
  @override
  SyncSequenceLogItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncSequenceLogItem(
      hostId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}host_id'])!,
      counter: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}counter'])!,
      entryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entry_id']),
      payloadType: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}payload_type'])!,
      originatingHostId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}originating_host_id']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      requestCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}request_count'])!,
      lastRequestedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_requested_at']),
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
  const SyncSequenceLogItem(
      {required this.hostId,
      required this.counter,
      this.entryId,
      required this.payloadType,
      this.originatingHostId,
      required this.status,
      required this.createdAt,
      required this.updatedAt,
      required this.requestCount,
      this.lastRequestedAt});
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
    );
  }

  factory SyncSequenceLogItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncSequenceLogItem(
      hostId: serializer.fromJson<String>(json['hostId']),
      counter: serializer.fromJson<int>(json['counter']),
      entryId: serializer.fromJson<String?>(json['entryId']),
      payloadType: serializer.fromJson<int>(json['payloadType']),
      originatingHostId:
          serializer.fromJson<String?>(json['originatingHostId']),
      status: serializer.fromJson<int>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      requestCount: serializer.fromJson<int>(json['requestCount']),
      lastRequestedAt: serializer.fromJson<DateTime?>(json['lastRequestedAt']),
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
    };
  }

  SyncSequenceLogItem copyWith(
          {String? hostId,
          int? counter,
          Value<String?> entryId = const Value.absent(),
          int? payloadType,
          Value<String?> originatingHostId = const Value.absent(),
          int? status,
          DateTime? createdAt,
          DateTime? updatedAt,
          int? requestCount,
          Value<DateTime?> lastRequestedAt = const Value.absent()}) =>
      SyncSequenceLogItem(
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
      );
  SyncSequenceLogItem copyWithCompanion(SyncSequenceLogCompanion data) {
    return SyncSequenceLogItem(
      hostId: data.hostId.present ? data.hostId.value : this.hostId,
      counter: data.counter.present ? data.counter.value : this.counter,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      payloadType:
          data.payloadType.present ? data.payloadType.value : this.payloadType,
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
          ..write('lastRequestedAt: $lastRequestedAt')
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
      lastRequestedAt);
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
          other.lastRequestedAt == this.lastRequestedAt);
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
    this.rowid = const Value.absent(),
  })  : hostId = Value(hostId),
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
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncSequenceLogCompanion copyWith(
      {Value<String>? hostId,
      Value<int>? counter,
      Value<String?>? entryId,
      Value<int>? payloadType,
      Value<String?>? originatingHostId,
      Value<int>? status,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? requestCount,
      Value<DateTime?>? lastRequestedAt,
      Value<int>? rowid}) {
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
      'host_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastSeenAtMeta =
      const VerificationMeta('lastSeenAt');
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
      'last_seen_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [hostId, lastSeenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'host_activity';
  @override
  VerificationContext validateIntegrity(Insertable<HostActivityItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('host_id')) {
      context.handle(_hostIdMeta,
          hostId.isAcceptableOrUnknown(data['host_id']!, _hostIdMeta));
    } else if (isInserting) {
      context.missing(_hostIdMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
          _lastSeenAtMeta,
          lastSeenAt.isAcceptableOrUnknown(
              data['last_seen_at']!, _lastSeenAtMeta));
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
      hostId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}host_id'])!,
      lastSeenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen_at'])!,
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

  factory HostActivityItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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
      lastSeenAt:
          data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
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
  })  : hostId = Value(hostId),
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

  HostActivityCompanion copyWith(
      {Value<String>? hostId, Value<DateTime>? lastSeenAt, Value<int>? rowid}) {
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

abstract class _$SyncDatabase extends GeneratedDatabase {
  _$SyncDatabase(QueryExecutor e) : super(e);
  _$SyncDatabase.connect(DatabaseConnection c) : super.connect(c);
  $SyncDatabaseManager get managers => $SyncDatabaseManager(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncSequenceLogTable syncSequenceLog =
      $SyncSequenceLogTable(this);
  late final $HostActivityTable hostActivity = $HostActivityTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [outbox, syncSequenceLog, hostActivity];
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
typedef $$SyncSequenceLogTableCreateCompanionBuilder = SyncSequenceLogCompanion
    Function({
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
  Value<int> rowid,
});
typedef $$SyncSequenceLogTableUpdateCompanionBuilder = SyncSequenceLogCompanion
    Function({
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
      column: $table.hostId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get counter => $composableBuilder(
      column: $table.counter, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entryId => $composableBuilder(
      column: $table.entryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get payloadType => $composableBuilder(
      column: $table.payloadType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originatingHostId => $composableBuilder(
      column: $table.originatingHostId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get requestCount => $composableBuilder(
      column: $table.requestCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastRequestedAt => $composableBuilder(
      column: $table.lastRequestedAt,
      builder: (column) => ColumnFilters(column));
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
      column: $table.hostId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get counter => $composableBuilder(
      column: $table.counter, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entryId => $composableBuilder(
      column: $table.entryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get payloadType => $composableBuilder(
      column: $table.payloadType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originatingHostId => $composableBuilder(
      column: $table.originatingHostId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get requestCount => $composableBuilder(
      column: $table.requestCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastRequestedAt => $composableBuilder(
      column: $table.lastRequestedAt,
      builder: (column) => ColumnOrderings(column));
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
      column: $table.payloadType, builder: (column) => column);

  GeneratedColumn<String> get originatingHostId => $composableBuilder(
      column: $table.originatingHostId, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get requestCount => $composableBuilder(
      column: $table.requestCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastRequestedAt => $composableBuilder(
      column: $table.lastRequestedAt, builder: (column) => column);
}

class $$SyncSequenceLogTableTableManager extends RootTableManager<
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
      BaseReferences<_$SyncDatabase, $SyncSequenceLogTable, SyncSequenceLogItem>
    ),
    SyncSequenceLogItem,
    PrefetchHooks Function()> {
  $$SyncSequenceLogTableTableManager(
      _$SyncDatabase db, $SyncSequenceLogTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncSequenceLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncSequenceLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncSequenceLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
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
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncSequenceLogCompanion(
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
            rowid: rowid,
          ),
          createCompanionCallback: ({
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
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncSequenceLogCompanion.insert(
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
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncSequenceLogTableProcessedTableManager = ProcessedTableManager<
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
      BaseReferences<_$SyncDatabase, $SyncSequenceLogTable, SyncSequenceLogItem>
    ),
    SyncSequenceLogItem,
    PrefetchHooks Function()>;
typedef $$HostActivityTableCreateCompanionBuilder = HostActivityCompanion
    Function({
  required String hostId,
  required DateTime lastSeenAt,
  Value<int> rowid,
});
typedef $$HostActivityTableUpdateCompanionBuilder = HostActivityCompanion
    Function({
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
      column: $table.hostId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnFilters(column));
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
      column: $table.hostId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnOrderings(column));
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
      column: $table.lastSeenAt, builder: (column) => column);
}

class $$HostActivityTableTableManager extends RootTableManager<
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
      BaseReferences<_$SyncDatabase, $HostActivityTable, HostActivityItem>
    ),
    HostActivityItem,
    PrefetchHooks Function()> {
  $$HostActivityTableTableManager(_$SyncDatabase db, $HostActivityTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HostActivityTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HostActivityTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HostActivityTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> hostId = const Value.absent(),
            Value<DateTime> lastSeenAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HostActivityCompanion(
            hostId: hostId,
            lastSeenAt: lastSeenAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String hostId,
            required DateTime lastSeenAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              HostActivityCompanion.insert(
            hostId: hostId,
            lastSeenAt: lastSeenAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HostActivityTableProcessedTableManager = ProcessedTableManager<
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
      BaseReferences<_$SyncDatabase, $HostActivityTable, HostActivityItem>
    ),
    HostActivityItem,
    PrefetchHooks Function()>;

class $SyncDatabaseManager {
  final _$SyncDatabase _db;
  $SyncDatabaseManager(this._db);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncSequenceLogTableTableManager get syncSequenceLog =>
      $$SyncSequenceLogTableTableManager(_db, _db.syncSequenceLog);
  $$HostActivityTableTableManager get hostActivity =>
      $$HostActivityTableTableManager(_db, _db.hostActivity);
}
