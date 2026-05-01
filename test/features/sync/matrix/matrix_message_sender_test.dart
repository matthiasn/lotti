// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, avoid_redundant_argument_values

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class MockRoom extends Mock implements Room {}

class MockDeviceKeys extends Mock implements DeviceKeys {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      MatrixFile(bytes: Uint8List(0), name: 'fallback'),
    );
  });

  late Directory documentsDirectory;
  late MockLoggingService loggingService;
  late MockJournalDb journalDb;
  late MatrixMessageSender sender;
  late MockRoom room;
  late SentEventRegistry sentEventRegistry;

  setUp(() {
    documentsDirectory = Directory.systemTemp.createTempSync(
      'matrix_message_sender_test',
    );
    loggingService = MockLoggingService();
    journalDb = MockJournalDb();
    sentEventRegistry = SentEventRegistry();
    sender = MatrixMessageSender(
      loggingService: loggingService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
      sentEventRegistry: sentEventRegistry,
    );
    room = MockRoom();

    when(
      () => loggingService.captureEvent(
        any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) {});
    when(
      () => loggingService.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => journalDb.getConfigFlag(any<String>()),
    ).thenAnswer((_) async => false);
    when(() => room.id).thenReturn('!room:test');
    when(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).thenAnswer((_) async => 'file-id');
  });

  tearDown(() {
    if (documentsDirectory.existsSync()) {
      documentsDirectory.deleteSync(recursive: true);
    }
  });

  MatrixMessageContext buildContext({
    Room? customRoom,
    List<DeviceKeys>? devices,
  }) {
    return MatrixMessageContext(
      syncRoomId: customRoom?.id ?? '!room:test',
      syncRoom: customRoom ?? room,
      unverifiedDevices: devices ?? const <DeviceKeys>[],
    );
  }

  test('returns false when unverified devices are present', () async {
    final device = MockDeviceKeys();
    final context = buildContext(devices: [device]);

    final result = await sender.sendMatrixMessage(
      message: const SyncMessage.aiConfigDelete(id: 'abc'),
      context: context,
      onSent: (_, _) {},
    );

    expect(result, isFalse);
    verify(
      () => loggingService.captureException(
        any<Object>(),
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      ),
    ).called(1);
  });

  test('returns false when no room id is available', () async {
    const context = MatrixMessageContext(
      syncRoomId: null,
      syncRoom: null,
      unverifiedDevices: <DeviceKeys>[],
    );

    var calls = 0;
    final result = await sender.sendMatrixMessage(
      message: const SyncMessage.aiConfigDelete(id: 'abc'),
      context: context,
      onSent: (_, _) => calls++,
    );

    expect(result, isFalse);
    expect(calls, 0);
    verify(
      () => loggingService.captureEvent(
        configNotFound,
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      ),
    ).called(1);
  });

  test('returns false when room instance missing even with id', () async {
    final result = await sender.sendMatrixMessage(
      message: const SyncMessage.aiConfigDelete(id: 'abc'),
      context: const MatrixMessageContext(
        syncRoomId: '!room:test',
        syncRoom: null,
        unverifiedDevices: <DeviceKeys>[],
      ),
      onSent: (_, _) {},
    );

    expect(result, isFalse);
    verify(
      () => loggingService.captureEvent(
        contains('no room instance available'),
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      ),
    ).called(1);
  });

  test('returns false when text message send returns null', () async {
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((_) async => null);

    final result = await sender.sendMatrixMessage(
      message: const SyncMessage.aiConfigDelete(id: 'abc'),
      context: buildContext(),
      onSent: (_, _) {},
    );

    expect(result, isFalse);
    verify(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).called(1);
    verifyNever(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    );
    expect(sentEventRegistry.length, 0);
  });

  test('registers text event ID in sent registry on success', () async {
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((_) async => r'$text-event-id');

    final result = await sender.sendMatrixMessage(
      message: const SyncMessage.aiConfigDelete(id: 'abc'),
      context: buildContext(),
      onSent: (_, _) {},
    );

    expect(result, isTrue);
    expect(sentEventRegistry.consume(r'$text-event-id'), isTrue);
  });

  test('fills originatingHostId for entry links when missing', () async {
    final vectorClockService = MockVectorClockService();
    when(vectorClockService.getHost).thenAnswer((_) async => 'host-A');
    sentEventRegistry = SentEventRegistry();
    sender = MatrixMessageSender(
      loggingService: loggingService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
      sentEventRegistry: sentEventRegistry,
      vectorClockService: vectorClockService,
    );

    var capturedPayload = '';
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((invocation) async {
      capturedPayload = invocation.positionalArguments.first as String;
      return 'text-id';
    });

    final link = EntryLink.basic(
      id: 'link-1',
      fromId: 'from',
      toId: 'to',
      createdAt: DateTime.utc(2024),
      updatedAt: DateTime.utc(2024),
      vectorClock: const VectorClock({'host-A': 1}),
    );
    final result = await sender.sendMatrixMessage(
      message: SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
      ),
      context: buildContext(),
      onSent: (_, _) {},
    );

    expect(result, isTrue);
    final decoded =
        json.decode(
              utf8.decode(base64.decode(capturedPayload)),
            )
            as Map<String, dynamic>;
    expect(decoded['originatingHostId'], 'host-A');
  });

  test('does not register event ID when text send throws', () async {
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenThrow(Exception('fail'));

    final result = await sender.sendMatrixMessage(
      message: const SyncMessage.aiConfigDelete(id: 'abc'),
      context: buildContext(),
      onSent: (_, _) {},
    );

    expect(result, isFalse);
    expect(sentEventRegistry.length, 0);
  });

  test(
    'gzip-compresses .json attachments when useCompressedJsonAttachmentsFlag '
    'is on',
    () async {
      MatrixFile? capturedFile;
      Map<String, dynamic>? capturedExtra;
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((invocation) async {
        capturedFile = invocation.positionalArguments.first as MatrixFile;
        capturedExtra =
            invocation.namedArguments[#extraContent] as Map<String, dynamic>?;
        return r'$file-event-id';
      });
      when(
        () => room.sendTextEvent(
          any<String>(),
          msgtype: any<String>(named: 'msgtype'),
          parseCommands: any<bool>(named: 'parseCommands'),
          parseMarkdown: any<bool>(named: 'parseMarkdown'),
        ),
      ).thenAnswer((_) async => r'$text-event-id');
      when(
        () => journalDb.getConfigFlag(useCompressedJsonAttachmentsFlag),
      ).thenAnswer((_) async => true);

      final meta = Metadata(
        id: 'compressed-entry',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        updatedAt: DateTime(2024, 3, 15, 10, 30),
        dateFrom: DateTime(2024, 3, 15, 10, 30),
        dateTo: DateTime(2024, 3, 15, 10, 30),
      );
      final entity = JournalEntity.journalEntry(
        meta: meta,
        entryText: EntryText(
          plainText: 'a' * 2000, // make gzip win measurably
        ),
      );
      final jsonPath = relativeEntityPath(entity);
      final rawJson = jsonEncode(entity);
      File('${documentsDirectory.path}$jsonPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(rawJson);

      final result = await sender.sendMatrixMessage(
        message: SyncMessage.journalEntity(
          id: meta.id,
          jsonPath: jsonPath,
          vectorClock: null,
          status: SyncEntryStatus.initial,
        ),
        context: buildContext(),
        onSent: (_, _) {},
      );

      expect(result, isTrue);
      expect(capturedFile, isNotNull);
      expect(capturedExtra, isNotNull);

      expect(capturedExtra![attachmentEncodingKey], attachmentEncodingGzip);
      expect(capturedExtra!['relativePath'], jsonPath);
      expect(capturedFile!.name, endsWith('.json.gz'));

      final uploadedBytes = capturedFile!.bytes;
      expect(
        uploadedBytes.length,
        lessThan(utf8.encode(rawJson).length),
        reason: 'gzipped payload must be smaller than the raw JSON',
      );
      final decompressed = utf8.decode(gzip.decode(uploadedBytes));
      expect(decompressed, rawJson);
    },
  );

  test(
    'leaves .json attachments uncompressed when '
    'useCompressedJsonAttachmentsFlag is off',
    () async {
      MatrixFile? capturedFile;
      Map<String, dynamic>? capturedExtra;
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((invocation) async {
        capturedFile = invocation.positionalArguments.first as MatrixFile;
        capturedExtra =
            invocation.namedArguments[#extraContent] as Map<String, dynamic>?;
        return r'$file-event-id';
      });
      when(
        () => room.sendTextEvent(
          any<String>(),
          msgtype: any<String>(named: 'msgtype'),
          parseCommands: any<bool>(named: 'parseCommands'),
          parseMarkdown: any<bool>(named: 'parseMarkdown'),
        ),
      ).thenAnswer((_) async => r'$text-event-id');
      // Flag defaults to false via the setUp stub; no override here.

      final meta = Metadata(
        id: 'plain-entry',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        updatedAt: DateTime(2024, 3, 15, 10, 30),
        dateFrom: DateTime(2024, 3, 15, 10, 30),
        dateTo: DateTime(2024, 3, 15, 10, 30),
      );
      final entity = JournalEntity.journalEntry(
        meta: meta,
        entryText: const EntryText(plainText: 'plain'),
      );
      final jsonPath = relativeEntityPath(entity);
      final rawJson = jsonEncode(entity);
      File('${documentsDirectory.path}$jsonPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(rawJson);

      final result = await sender.sendMatrixMessage(
        message: SyncMessage.journalEntity(
          id: meta.id,
          jsonPath: jsonPath,
          vectorClock: null,
          status: SyncEntryStatus.initial,
        ),
        context: buildContext(),
        onSent: (_, _) {},
      );

      expect(result, isTrue);
      expect(capturedExtra!.containsKey(attachmentEncodingKey), isFalse);
      expect(capturedFile!.name, isNot(endsWith('.gz')));
      expect(utf8.decode(capturedFile!.bytes), rawJson);
    },
  );

  test('registers file event ID when sending journal payload', () async {
    when(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).thenAnswer((_) async => r'$file-event-id');
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((_) async => r'$text-event-id');

    final meta = Metadata(
      id: 'register-file',
      createdAt: DateTime(2024, 3, 15, 10, 30),
      updatedAt: DateTime(2024, 3, 15, 10, 30),
      dateFrom: DateTime(2024, 3, 15, 10, 30),
      dateTo: DateTime(2024, 3, 15, 10, 30),
    );
    final entity = JournalEntity.journalEntry(
      meta: meta,
      entryText: const EntryText(plainText: 'payload'),
    );
    final jsonPath = relativeEntityPath(entity);
    File('${documentsDirectory.path}$jsonPath')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(entity));

    final result = await sender.sendMatrixMessage(
      message: SyncMessage.journalEntity(
        id: meta.id,
        jsonPath: jsonPath,
        vectorClock: null,
        status: SyncEntryStatus.initial,
      ),
      context: buildContext(),
      onSent: (_, _) {},
    );

    expect(result, isTrue);
    expect(sentEventRegistry.consume(r'$file-event-id'), isTrue);
    expect(sentEventRegistry.consume(r'$text-event-id'), isTrue);
  });

  test('adopts descriptor vector clock when message is stale', () async {
    when(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).thenAnswer((_) async => 'file-id');
    var capturedPayload = '';
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((invocation) async {
      capturedPayload = invocation.positionalArguments.first as String;
      return 'text-id';
    });

    final staleMeta = Metadata(
      id: 'checklist-1',
      createdAt: DateTime(2025, 10, 22, 23, 18, 48),
      updatedAt: DateTime(2025, 10, 22, 23, 18, 49),
      dateFrom: DateTime(2025, 10, 22, 23, 18, 48),
      dateTo: DateTime(2025, 10, 22, 23, 18, 48),
      vectorClock: const VectorClock({'hostA': 402}),
    );
    final staleChecklist = JournalEntity.checklist(
      meta: staleMeta,
      data: const ChecklistData(
        title: 'Todos',
        linkedChecklistItems: <String>[],
        linkedTasks: <String>['task-1'],
      ),
    );
    final path = relativeEntityPath(staleChecklist);
    File('${documentsDirectory.path}$path')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(staleChecklist));

    final context = buildContext();
    final message = SyncMessage.journalEntity(
      id: staleChecklist.meta.id,
      jsonPath: path,
      vectorClock: const VectorClock({'hostA': 425}),
      status: SyncEntryStatus.update,
    );

    final result = await sender.sendMatrixMessage(
      message: message,
      context: context,
      onSent: (_, _) {},
    );

    expect(result, isTrue);
    verify(
      () => loggingService.captureEvent(
        allOf(
          contains('reason=json_mismatch'),
          contains('previous={hostA: 425}'),
          contains('assigned={hostA: 402}'),
        ),
        domain: 'VECTOR_CLOCK',
        subDomain: 'send.adoptJson',
      ),
    ).called(1);
    final decoded =
        json.decode(
              utf8.decode(base64.decode(capturedPayload)),
            )
            as Map<String, dynamic>;
    expect(
      decoded['vectorClock'],
      equals({'hostA': 402}),
    );
  });

  test('uses descriptor snapshot when json changes during send', () async {
    var capturedPayload = '';
    MatrixFile? capturedFile;
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((invocation) async {
      capturedPayload = invocation.positionalArguments.first as String;
      return 'text-id';
    });

    final baseDate = DateTime(2025, 12, 21, 10, 0, 0);
    final initialMeta = Metadata(
      id: 'snapshot-entry',
      createdAt: baseDate,
      updatedAt: baseDate,
      dateFrom: baseDate,
      dateTo: baseDate,
      vectorClock: const VectorClock({'hostA': 1}),
    );
    final updatedMeta = Metadata(
      id: 'snapshot-entry',
      createdAt: baseDate,
      updatedAt: baseDate,
      dateFrom: baseDate,
      dateTo: baseDate,
      vectorClock: const VectorClock({'hostA': 2}),
    );
    final entity = JournalEntity.journalEntry(
      meta: initialMeta,
      entryText: const EntryText(plainText: 'Initial'),
    );
    final updatedEntity = JournalEntity.journalEntry(
      meta: updatedMeta,
      entryText: const EntryText(plainText: 'Updated'),
    );
    final jsonPath = relativeEntityPath(entity);
    final jsonFile = File('${documentsDirectory.path}$jsonPath')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(entity.toJson()));

    when(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).thenAnswer((invocation) async {
      capturedFile = invocation.positionalArguments.first as MatrixFile;
      jsonFile.writeAsStringSync(jsonEncode(updatedEntity.toJson()));
      return 'file-id';
    });

    final result = await sender.sendMatrixMessage(
      message: SyncMessage.journalEntity(
        id: entity.meta.id,
        jsonPath: jsonPath,
        vectorClock: const VectorClock({'hostA': 1}),
        status: SyncEntryStatus.update,
      ),
      context: buildContext(),
      onSent: (_, _) {},
    );

    expect(result, isTrue);
    expect(capturedFile, isNotNull);
    final decodedPayload =
        json.decode(
              utf8.decode(base64.decode(capturedPayload)),
            )
            as Map<String, dynamic>;
    expect(decodedPayload['vectorClock'], equals({'hostA': 1}));

    final uploadedJson =
        json.decode(
              utf8.decode(capturedFile!.bytes),
            )
            as Map<String, dynamic>;
    expect(
      (uploadedJson['meta'] as Map<String, dynamic>)['vectorClock'],
      equals({'hostA': 1}),
    );
  });

  test(
    'keeps message vector clock when descriptor lacks vector clock',
    () async {
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => 'file-id');
      var capturedPayload = '';
      when(
        () => room.sendTextEvent(
          any<String>(),
          msgtype: any<String>(named: 'msgtype'),
          parseCommands: any<bool>(named: 'parseCommands'),
          parseMarkdown: any<bool>(named: 'parseMarkdown'),
        ),
      ).thenAnswer((invocation) async {
        capturedPayload = invocation.positionalArguments.first as String;
        return 'text-id';
      });

      final meta = Metadata(
        id: 'no-json-vc',
        createdAt: DateTime(2024, 3, 15, 10, 31),
        updatedAt: DateTime(2024, 3, 15, 10, 31),
        dateFrom: DateTime(2024, 3, 15, 10, 31),
        dateTo: DateTime(2024, 3, 15, 10, 31),
        vectorClock: null,
      );
      final entity = JournalEntity.journalEntry(
        meta: meta,
        entryText: const EntryText(plainText: 'draft'),
      );
      final jsonPath = relativeEntityPath(entity);
      File('${documentsDirectory.path}$jsonPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(entity.toJson()));

      const messageClock = VectorClock({'hostA': 5});
      final message = SyncMessage.journalEntity(
        id: entity.meta.id,
        jsonPath: jsonPath,
        vectorClock: messageClock,
        status: SyncEntryStatus.update,
      );

      final result = await sender.sendMatrixMessage(
        message: message,
        context: buildContext(),
        onSent: (_, _) {},
      );

      expect(result, isTrue);
      verifyNever(
        () => loggingService.captureEvent(
          any<String>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg.vclockAdjusted',
        ),
      );
      final decoded =
          json.decode(
                utf8.decode(base64.decode(capturedPayload)),
              )
              as Map<String, dynamic>;
      expect(decoded['vectorClock'], messageClock.vclock);
    },
  );

  test(
    'adopts descriptor vector clock when message lacks vector clock',
    () async {
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => 'file-id');
      var capturedPayload = '';
      when(
        () => room.sendTextEvent(
          any<String>(),
          msgtype: any<String>(named: 'msgtype'),
          parseCommands: any<bool>(named: 'parseCommands'),
          parseMarkdown: any<bool>(named: 'parseMarkdown'),
        ),
      ).thenAnswer((invocation) async {
        capturedPayload = invocation.positionalArguments.first as String;
        return 'text-id';
      });

      final meta = Metadata(
        id: 'json-vc',
        createdAt: DateTime(2024, 3, 15, 10, 32),
        updatedAt: DateTime(2024, 3, 15, 10, 32),
        dateFrom: DateTime(2024, 3, 15, 10, 32),
        dateTo: DateTime(2024, 3, 15, 10, 32),
        vectorClock: const VectorClock({'hostA': 7}),
      );
      final entity = JournalEntity.journalEntry(
        meta: meta,
        entryText: const EntryText(plainText: 'descriptor'),
      );
      final jsonPath = relativeEntityPath(entity);
      File('${documentsDirectory.path}$jsonPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(entity.toJson()));

      final message = SyncMessage.journalEntity(
        id: entity.meta.id,
        jsonPath: jsonPath,
        vectorClock: null,
        status: SyncEntryStatus.update,
      );

      final result = await sender.sendMatrixMessage(
        message: message,
        context: buildContext(),
        onSent: (_, _) {},
      );

      expect(result, isTrue);
      verify(
        () => loggingService.captureEvent(
          allOf(
            contains('reason=message_missing'),
            contains('assigned={hostA: 7}'),
          ),
          domain: 'VECTOR_CLOCK',
          subDomain: 'send.adoptJson',
        ),
      ).called(1);
      final decoded =
          json.decode(
                utf8.decode(base64.decode(capturedPayload)),
              )
              as Map<String, dynamic>;
      expect(decoded['vectorClock'], meta.vectorClock?.vclock);
    },
  );

  test('does not adjust when vector clocks are equal', () async {
    when(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).thenAnswer((_) async => 'file-id');
    var capturedPayload = '';
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((invocation) async {
      capturedPayload = invocation.positionalArguments.first as String;
      return 'text-id';
    });

    const clock = VectorClock({'hostA': 3});
    final meta = Metadata(
      id: 'equal-vc',
      createdAt: DateTime(2024, 3, 15, 10, 33),
      updatedAt: DateTime(2024, 3, 15, 10, 33),
      dateFrom: DateTime(2024, 3, 15, 10, 33),
      dateTo: DateTime(2024, 3, 15, 10, 33),
      vectorClock: clock,
    );
    final entity = JournalEntity.journalEntry(
      meta: meta,
      entryText: const EntryText(plainText: 'equal'),
    );
    final jsonPath = relativeEntityPath(entity);
    File('${documentsDirectory.path}$jsonPath')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(entity.toJson()));

    final message = SyncMessage.journalEntity(
      id: entity.meta.id,
      jsonPath: jsonPath,
      vectorClock: clock,
      status: SyncEntryStatus.update,
    );

    final result = await sender.sendMatrixMessage(
      message: message,
      context: buildContext(),
      onSent: (_, _) {},
    );

    expect(result, isTrue);
    verifyNever(
      () => loggingService.captureEvent(
        any<String>(),
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg.vclockAdjusted',
      ),
    );
    final decoded =
        json.decode(
              utf8.decode(base64.decode(capturedPayload)),
            )
            as Map<String, dynamic>;
    expect(decoded['vectorClock'], clock.vclock);
  });

  test(
    'adopts descriptor vector clock when json is newer than message',
    () async {
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => 'file-id');
      var capturedPayload = '';
      when(
        () => room.sendTextEvent(
          any<String>(),
          msgtype: any<String>(named: 'msgtype'),
          parseCommands: any<bool>(named: 'parseCommands'),
          parseMarkdown: any<bool>(named: 'parseMarkdown'),
        ),
      ).thenAnswer((invocation) async {
        capturedPayload = invocation.positionalArguments.first as String;
        return 'text-id';
      });

      const jsonClock = VectorClock({'hostA': 10});
      const messageClock = VectorClock({'hostA': 8});
      final meta = Metadata(
        id: 'json-newer',
        createdAt: DateTime(2024, 3, 15, 10, 34),
        updatedAt: DateTime(2024, 3, 15, 10, 34),
        dateFrom: DateTime(2024, 3, 15, 10, 34),
        dateTo: DateTime(2024, 3, 15, 10, 34),
        vectorClock: jsonClock,
      );
      final entity = JournalEntity.journalEntry(
        meta: meta,
        entryText: const EntryText(plainText: 'json-newer'),
      );
      final jsonPath = relativeEntityPath(entity);
      File('${documentsDirectory.path}$jsonPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(entity.toJson()));

      final message = SyncMessage.journalEntity(
        id: entity.meta.id,
        jsonPath: jsonPath,
        vectorClock: messageClock,
        status: SyncEntryStatus.update,
      );

      final result = await sender.sendMatrixMessage(
        message: message,
        context: buildContext(),
        onSent: (_, _) {},
      );

      expect(result, isTrue);
      verify(
        () => loggingService.captureEvent(
          allOf(
            contains('reason=json_mismatch'),
            contains('previous={hostA: 8}'),
            contains('assigned={hostA: 10}'),
          ),
          domain: 'VECTOR_CLOCK',
          subDomain: 'send.adoptJson',
        ),
      ).called(1);
      final decoded =
          json.decode(
                utf8.decode(base64.decode(capturedPayload)),
              )
              as Map<String, dynamic>;
      expect(decoded['vectorClock'], jsonClock.vclock);
    },
  );

  test(
    'keeps vector clock null when both descriptor and message lack clocks',
    () async {
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => 'file-id');
      var capturedPayload = '';
      when(
        () => room.sendTextEvent(
          any<String>(),
          msgtype: any<String>(named: 'msgtype'),
          parseCommands: any<bool>(named: 'parseCommands'),
          parseMarkdown: any<bool>(named: 'parseMarkdown'),
        ),
      ).thenAnswer((invocation) async {
        capturedPayload = invocation.positionalArguments.first as String;
        return 'text-id';
      });

      final meta = Metadata(
        id: 'null-both',
        createdAt: DateTime(2024, 3, 15, 10, 35),
        updatedAt: DateTime(2024, 3, 15, 10, 35),
        dateFrom: DateTime(2024, 3, 15, 10, 35),
        dateTo: DateTime(2024, 3, 15, 10, 35),
        vectorClock: null,
      );
      final entity = JournalEntity.journalEntry(
        meta: meta,
        entryText: const EntryText(plainText: 'null'),
      );
      final jsonPath = relativeEntityPath(entity);
      File('${documentsDirectory.path}$jsonPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(entity.toJson()));

      final message = SyncMessage.journalEntity(
        id: entity.meta.id,
        jsonPath: jsonPath,
        vectorClock: null,
        status: SyncEntryStatus.initial,
      );

      final result = await sender.sendMatrixMessage(
        message: message,
        context: buildContext(),
        onSent: (_, _) {},
      );

      expect(result, isTrue);
      verifyNever(
        () => loggingService.captureEvent(
          any<String>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg.vclockAdjusted',
        ),
      );
      final decoded =
          json.decode(
                utf8.decode(base64.decode(capturedPayload)),
              )
              as Map<String, dynamic>;
      expect(decoded['vectorClock'], isNull);
    },
  );

  test('logs and returns false when sending text message throws', () async {
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenThrow(Exception('network down'));

    final result = await sender.sendMatrixMessage(
      message: const SyncMessage.aiConfigDelete(id: 'abc'),
      context: buildContext(),
      onSent: (_, _) {},
    );

    expect(result, isFalse);
    verify(
      () => loggingService.captureException(
        any<Object>(),
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).called(1);
  });

  test('sends text message and invokes callback once', () async {
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((_) async => 'event-id');
    when(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).thenAnswer((_) async => 'file-id');

    var calls = 0;
    final result = await sender.sendMatrixMessage(
      message: const SyncMessage.aiConfigDelete(id: 'abc'),
      context: buildContext(),
      onSent: (_, _) => calls++,
    );

    expect(result, isTrue);
    expect(calls, 1);
    verify(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).called(1);
    verifyNever(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    );
  });

  test('skips attachments when resend flag false on update messages', () async {
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((_) async => 'event-id');
    when(
      () => journalDb.getConfigFlag(resendAttachments),
    ).thenAnswer((_) async => false);

    final sampleDate = DateTime.utc(2024, 1, 1);
    final metadata = Metadata(
      id: 'entry',
      createdAt: sampleDate,
      updatedAt: sampleDate,
      dateFrom: sampleDate,
      dateTo: sampleDate,
      vectorClock: VectorClock({'device': 1}),
    );
    final imageData = ImageData(
      capturedAt: sampleDate,
      imageId: 'image-id',
      imageFile: 'image.jpg',
      imageDirectory: '/images/',
    );
    final journalEntity = JournalEntity.journalImage(
      meta: metadata,
      data: imageData,
      entryText: const EntryText(plainText: 'Test'),
    );

    const jsonPath = '/entries/test.json';
    File('${documentsDirectory.path}$jsonPath')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

    final imagePath =
        '${documentsDirectory.path}${imageData.imageDirectory}${imageData.imageFile}';
    File(imagePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(10, 42));

    var callbackCount = 0;
    final result = await sender.sendMatrixMessage(
      message: SyncMessage.journalEntity(
        id: 'entry',
        jsonPath: jsonPath,
        vectorClock: VectorClock({'device': 1}),
        status: SyncEntryStatus.update,
      ),
      context: buildContext(),
      onSent: (_, _) => callbackCount++,
    );

    expect(result, isTrue);
    expect(callbackCount, 1);
    verify(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).called(1);
    final extras = verify(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: captureAny(named: 'extraContent'),
      ),
    ).captured.cast<Map<String, dynamic>>();
    expect(
      extras.map((entry) => entry['relativePath']).toSet(),
      equals({jsonPath}),
    );
  });

  test('sends journal entity attachments without duplicating callback', () async {
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((_) async => 'event-id');
    when(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).thenAnswer((_) async => 'file-id');
    when(
      () => journalDb.getConfigFlag(resendAttachments),
    ).thenAnswer((_) async => true);

    final sampleDate = DateTime.utc(2024, 1, 1);
    final metadata = Metadata(
      id: 'entry',
      createdAt: sampleDate,
      updatedAt: sampleDate,
      dateFrom: sampleDate,
      dateTo: sampleDate,
      vectorClock: VectorClock({'device': 1}),
    );
    final imageData = ImageData(
      capturedAt: sampleDate,
      imageId: 'image-id',
      imageFile: 'image.jpg',
      imageDirectory: '/images/',
    );
    final journalEntity = JournalEntity.journalImage(
      meta: metadata,
      data: imageData,
      entryText: const EntryText(plainText: 'Test'),
    );

    const jsonPath = '/entries/test.json';
    File('${documentsDirectory.path}$jsonPath')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

    final imagePath =
        '${documentsDirectory.path}${imageData.imageDirectory}${imageData.imageFile}';
    File(imagePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(10, 42));

    var callbackCount = 0;
    final result = await sender.sendMatrixMessage(
      message: SyncMessage.journalEntity(
        id: 'entry',
        jsonPath: jsonPath,
        vectorClock: VectorClock({'device': 1}),
        status: SyncEntryStatus.initial,
      ),
      context: buildContext(),
      onSent: (_, _) => callbackCount++,
    );

    expect(result, isTrue);
    expect(callbackCount, 1);
    verify(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).called(1);
    final extras = verify(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: captureAny(named: 'extraContent'),
      ),
    ).captured.cast<Map<String, dynamic>>();
    final extraPaths = extras
        .map((entry) => entry['relativePath'] as String?)
        .whereType<String>()
        .toSet();
    expect(extraPaths, contains(jsonPath));
    expect(extraPaths.any((path) => path.endsWith('image.jpg')), isTrue);
  });

  test('returns false when uploading json attachment fails', () async {
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((_) async => 'event-id');
    when(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).thenAnswer((_) async => null);

    final metadata = Metadata(
      id: 'entry',
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
      dateFrom: DateTime.utc(2024, 1, 1),
      dateTo: DateTime.utc(2024, 1, 1),
      vectorClock: VectorClock({'device': 1}),
    );

    final journalEntity = JournalEntity.journalEntry(
      meta: metadata,
      entryText: const EntryText(plainText: 'Test'),
    );

    const jsonPath = '/entries/test.json';
    File('${documentsDirectory.path}$jsonPath')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

    final result = await sender.sendMatrixMessage(
      message: SyncMessage.journalEntity(
        id: 'entry',
        jsonPath: jsonPath,
        vectorClock: VectorClock({'device': 1}),
        status: SyncEntryStatus.initial,
      ),
      context: buildContext(),
      onSent: (_, _) {},
    );

    expect(result, isFalse);
    verify(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).called(1);
  });

  test('uses basename for matrix file uploads', () async {
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((_) async => 'event-id');
    MatrixFile? capturedFile;
    when(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).thenAnswer((invocation) async {
      capturedFile = invocation.positionalArguments.first as MatrixFile;
      return 'file-id';
    });

    final metadata = Metadata(
      id: 'entry',
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
      dateFrom: DateTime.utc(2024, 1, 1),
      dateTo: DateTime.utc(2024, 1, 1),
      vectorClock: VectorClock({'device': 1}),
    );

    final journalEntity = JournalEntity.journalEntry(
      meta: metadata,
      entryText: const EntryText(plainText: 'Test'),
    );

    const jsonPath = '/entries/test.json';
    File('${documentsDirectory.path}$jsonPath')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

    final result = await sender.sendMatrixMessage(
      message: SyncMessage.journalEntity(
        id: 'entry',
        jsonPath: jsonPath,
        vectorClock: VectorClock({'device': 1}),
        status: SyncEntryStatus.initial,
      ),
      context: buildContext(),
      onSent: (_, _) {},
    );

    expect(result, isTrue);
    expect(capturedFile, isNotNull);
    expect(capturedFile!.name, 'test.json');
  });

  test('returns false when journal entity json cannot be decoded', () async {
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((_) async => 'event-id');
    when(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).thenAnswer((_) async => 'file-id');

    const jsonPath = '/entries/bad.json';
    File('${documentsDirectory.path}$jsonPath')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"invalid": "json"'); // missing closing brace

    final result = await sender.sendMatrixMessage(
      message: SyncMessage.journalEntity(
        id: 'entry',
        jsonPath: jsonPath,
        vectorClock: VectorClock({'device': 1}),
        status: SyncEntryStatus.initial,
      ),
      context: buildContext(),
      onSent: (_, _) {},
    );

    expect(result, isFalse);
    verify(
      () => loggingService.captureException(
        any<Object>(),
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg.decode',
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).called(1);
    verify(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).called(1);
  });

  test(
    'resends audio attachment when resend flag true on update status',
    () async {
      when(
        () => room.sendTextEvent(
          any<String>(),
          msgtype: any<String>(named: 'msgtype'),
          parseCommands: any<bool>(named: 'parseCommands'),
          parseMarkdown: any<bool>(named: 'parseMarkdown'),
        ),
      ).thenAnswer((_) async => 'event-id');
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => 'file-id');
      when(
        () => journalDb.getConfigFlag(resendAttachments),
      ).thenAnswer((_) async => true);

      final sampleDate = DateTime.utc(2024, 1, 1);
      final metadata = Metadata(
        id: 'entry',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        dateFrom: sampleDate,
        dateTo: sampleDate,
        vectorClock: VectorClock({'device': 1}),
      );
      final audioData = AudioData(
        dateFrom: sampleDate,
        dateTo: sampleDate,
        audioFile: 'audio.m4a',
        audioDirectory: '/audio/',
        duration: const Duration(seconds: 1),
      );
      final journalAudio = JournalEntity.journalAudio(
        meta: metadata,
        data: audioData,
      );

      const jsonPath = '/entries/audio.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalAudio.toJson()));

      final audioPath =
          '${documentsDirectory.path}${audioData.audioDirectory}${audioData.audioFile}';
      File(audioPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(10, 1));

      final audioEntity = SyncMessage.journalEntity(
        id: 'entry',
        jsonPath: jsonPath,
        vectorClock: VectorClock({'device': 1}),
        status: SyncEntryStatus.update,
      );

      var callbackCount = 0;
      final result = await sender.sendMatrixMessage(
        message: audioEntity,
        context: buildContext(),
        onSent: (_, _) => callbackCount++,
      );

      expect(result, isTrue);
      expect(callbackCount, 1);
      final capturedExtras = verify(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: captureAny(named: 'extraContent'),
        ),
      ).captured.cast<Map<String, dynamic>>();
      final capturedPaths = capturedExtras
          .map((entry) => entry['relativePath'] as String?)
          .whereType<String>()
          .toSet();
      expect(capturedPaths, contains(jsonPath));
      expect(capturedPaths.any((path) => path.endsWith('audio.m4a')), isTrue);
    },
  );

  test('rethrows file send failures after logging', () async {
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((_) async => 'event-id');
    when(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).thenAnswer((_) => Future<String?>.error(Exception('network error')));

    final metadata = Metadata(
      id: 'entry',
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
      dateFrom: DateTime.utc(2024, 1, 1),
      dateTo: DateTime.utc(2024, 1, 1),
    );

    final journalEntity = JournalEntity.journalEntry(
      meta: metadata,
      entryText: const EntryText(plainText: 'Test'),
    );

    const jsonPath = '/entries/test.json';
    File('${documentsDirectory.path}$jsonPath')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

    var callbackCount = 0;
    await expectLater(
      sender.sendMatrixMessage(
        message: SyncMessage.journalEntity(
          id: 'entry',
          jsonPath: jsonPath,
          vectorClock: VectorClock({'device': 1}),
          status: SyncEntryStatus.initial,
        ),
        context: buildContext(),
        onSent: (_, _) => callbackCount++,
      ),
      completion(isFalse),
    );

    expect(callbackCount, 0);
  });

  test('skips missing attachment file gracefully', () async {
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((_) async => 'event-id');
    when(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).thenAnswer((_) async => 'file-id');
    when(
      () => journalDb.getConfigFlag(resendAttachments),
    ).thenAnswer((_) async => true);

    final sampleDate = DateTime.utc(2024, 1, 1);
    final metadata = Metadata(
      id: 'entry',
      createdAt: sampleDate,
      updatedAt: sampleDate,
      dateFrom: sampleDate,
      dateTo: sampleDate,
      vectorClock: VectorClock({'device': 1}),
    );
    final imageData = ImageData(
      capturedAt: sampleDate,
      imageId: 'missing-image',
      imageFile: 'missing.jpg',
      imageDirectory: '/images/',
    );

    final journalEntity = JournalEntity.journalImage(
      meta: metadata,
      data: imageData,
      entryText: const EntryText(plainText: 'Missing attachment'),
    );

    const jsonPath = '/entries/missing.json';
    File('${documentsDirectory.path}$jsonPath')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

    final result = await sender.sendMatrixMessage(
      message: SyncMessage.journalEntity(
        id: 'entry',
        jsonPath: jsonPath,
        vectorClock: VectorClock({'device': 1}),
        status: SyncEntryStatus.initial,
      ),
      context: buildContext(),
      onSent: (_, _) {},
    );

    // Missing files are skipped gracefully — the journal entity is still sent
    expect(result, isTrue);
    verify(
      () => loggingService.captureEvent(
        any<String>(
          that: contains('skipping missing file'),
        ),
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      ),
    ).called(1);
    // The JSON file is still sent as a file event, only the image is skipped
    verify(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).called(1);
  });

  group('sendJournalEntityPayloadForTesting', () {
    test('sends json and attachments successfully', () async {
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => 'file-id');
      when(
        () => journalDb.getConfigFlag(resendAttachments),
      ).thenAnswer((_) async => true);

      final sampleDate = DateTime.utc(2024, 1, 1);
      final metadata = Metadata(
        id: 'entry',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        dateFrom: sampleDate,
        dateTo: sampleDate,
        vectorClock: VectorClock({'device': 1}),
      );
      final imageData = ImageData(
        capturedAt: sampleDate,
        imageId: 'image-id',
        imageFile: 'image.jpg',
        imageDirectory: '/images/',
      );
      final journalEntity = JournalEntity.journalImage(
        meta: metadata,
        data: imageData,
        entryText: const EntryText(plainText: 'Test'),
      );

      const jsonPath = '/entries/payload.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      final imagePath =
          '${documentsDirectory.path}${imageData.imageDirectory}${imageData.imageFile}';
      File(imagePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(10, 42));

      final message =
          SyncMessage.journalEntity(
                id: 'entry',
                jsonPath: jsonPath,
                vectorClock: VectorClock({'device': 1}),
                status: SyncEntryStatus.initial,
              )
              as SyncJournalEntity;

      final result = await sender.sendJournalEntityPayloadForTesting(
        room: room,
        message: message,
      );

      expect(result, isNotNull);
      expect(result!.vectorClock, equals(VectorClock({'device': 1})));
      verify(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).called(greaterThanOrEqualTo(2));
    });

    test('propagates failure when attachment upload fails', () async {
      final responses = <String?>['json-id', null];
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => responses.removeAt(0));
      when(
        () => journalDb.getConfigFlag(resendAttachments),
      ).thenAnswer((_) async => true);

      final sampleDate = DateTime.utc(2024, 1, 1);
      final metadata = Metadata(
        id: 'entry',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        dateFrom: sampleDate,
        dateTo: sampleDate,
        vectorClock: VectorClock({'device': 1}),
      );
      final imageData = ImageData(
        capturedAt: sampleDate,
        imageId: 'image-id',
        imageFile: 'image.jpg',
        imageDirectory: '/images/',
      );
      final journalEntity = JournalEntity.journalImage(
        meta: metadata,
        data: imageData,
        entryText: const EntryText(plainText: 'Test'),
      );

      const jsonPath = '/entries/failing.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      final imagePath =
          '${documentsDirectory.path}${imageData.imageDirectory}${imageData.imageFile}';
      File(imagePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(10, 42));

      final message =
          SyncMessage.journalEntity(
                id: 'entry',
                jsonPath: jsonPath,
                vectorClock: VectorClock({'device': 1}),
                status: SyncEntryStatus.initial,
              )
              as SyncJournalEntity;

      final result = await sender.sendJournalEntityPayloadForTesting(
        room: room,
        message: message,
      );

      expect(result, isNull);
    });
  });

  group('enrichAndUploadAgentPayloadForTesting', () {
    test('uploads entity file and strips inline payload', () async {
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => 'file-id');

      final entity = AgentDomainEntity.agent(
        id: 'agent-1',
        agentId: 'agent-1',
        kind: 'task_agent',
        displayName: 'Test',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      const relativePath = '/agent_entities/agent-1.json';
      File('${documentsDirectory.path}$relativePath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(entity.toJson()));

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
        jsonPath: relativePath,
      );

      final result = await sender.enrichAndUploadAgentPayloadForTesting(
        room: room,
        message: message,
      );

      expect(result, isA<SyncAgentEntity>());
      final entityResult = result! as SyncAgentEntity;
      expect(entityResult.agentEntity, isNull);
      expect(entityResult.jsonPath, relativePath);
      expect(entityResult.status, SyncEntryStatus.update);

      final extras = verify(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: captureAny(named: 'extraContent'),
        ),
      ).captured.cast<Map<String, dynamic>>();
      expect(extras.first['relativePath'], relativePath);
    });

    test('returns null when entity has no jsonPath and no inline', () async {
      const message = SyncMessage.agentEntity(
        status: SyncEntryStatus.update,
      );

      final result = await sender.enrichAndUploadAgentPayloadForTesting(
        room: room,
        message: message,
      );

      expect(result, isNull);
      verifyNever(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      );
    });

    test('returns null when entity file read fails', () async {
      final entity = AgentDomainEntity.agent(
        id: 'agent-missing',
        agentId: 'agent-missing',
        kind: 'task_agent',
        displayName: 'Test',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
        jsonPath: '/agent_entities/agent-missing.json',
      );

      final result = await sender.enrichAndUploadAgentPayloadForTesting(
        room: room,
        message: message,
      );

      expect(result, isNull);
      verify(
        () => loggingService.captureException(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg.agentEntity',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('returns null when entity file upload fails', () async {
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => null);

      final entity = AgentDomainEntity.agent(
        id: 'agent-fail',
        agentId: 'agent-fail',
        kind: 'task_agent',
        displayName: 'Test',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      const relativePath = '/agent_entities/agent-fail.json';
      File('${documentsDirectory.path}$relativePath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(entity.toJson()));

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
        jsonPath: relativePath,
      );

      final result = await sender.enrichAndUploadAgentPayloadForTesting(
        room: room,
        message: message,
      );

      expect(result, isNull);
    });

    test('uploads link file and preserves inline payload', () async {
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => 'file-id');

      final link = AgentLink.basic(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'state-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      const relativePath = '/agent_links/link-1.json';
      File('${documentsDirectory.path}$relativePath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(link.toJson()));

      final message = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
        jsonPath: relativePath,
      );

      final result = await sender.enrichAndUploadAgentPayloadForTesting(
        room: room,
        message: message,
      );

      expect(result, isA<SyncAgentLink>());
      final linkResult = result! as SyncAgentLink;
      expect(linkResult.agentLink, isNotNull);
      expect(linkResult.jsonPath, relativePath);
      expect(linkResult.status, SyncEntryStatus.update);
    });

    test('returns null when link has no jsonPath and no inline', () async {
      const message = SyncMessage.agentLink(
        status: SyncEntryStatus.update,
      );

      final result = await sender.enrichAndUploadAgentPayloadForTesting(
        room: room,
        message: message,
      );

      expect(result, isNull);
      verifyNever(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      );
    });

    test('passes through non-agent messages unchanged', () async {
      const message = SyncMessage.aiConfigDelete(id: 'abc');

      final result = await sender.enrichAndUploadAgentPayloadForTesting(
        room: room,
        message: message,
      );

      expect(result, same(message));
    });

    test(
      'uploads bundle file from inline payload and strips children',
      () async {
        when(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        ).thenAnswer((_) async => 'file-id');

        final entity = AgentDomainEntity.agentState(
          id: 'state-bundle',
          agentId: 'agent-bundle',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'host-A': 1}),
        );
        final message = SyncMessage.agentBundle(
          agentId: 'agent-bundle',
          wakeRunKey: 'run-bundle',
          entities: [
            SyncMessage.agentEntity(
                  status: SyncEntryStatus.update,
                  agentEntity: entity,
                )
                as SyncAgentEntity,
          ],
        );

        final result = await sender.enrichAndUploadAgentPayloadForTesting(
          room: room,
          message: message,
        );

        expect(result, isA<SyncAgentBundle>());
        final bundleResult = result! as SyncAgentBundle;
        // Inline children stripped — receiver fetches the file by jsonPath.
        expect(bundleResult.entities, isEmpty);
        expect(bundleResult.links, isEmpty);
        expect(bundleResult.jsonPath, '/agent_bundles/run-bundle.json');

        // The bundle JSON was written to disk under the wakeRunKey path
        // before upload, by the legacy-payload codepath that uses
        // pathBuilder=relativeAgentBundlePath. Decode it to catch
        // regressions in _savePayloadToDisk / inline-encode.
        final file = File(
          '${documentsDirectory.path}/agent_bundles/run-bundle.json',
        );
        expect(file.existsSync(), isTrue);
        final onDisk =
            SyncMessage.fromJson(
                  json.decode(file.readAsStringSync()) as Map<String, dynamic>,
                )
                as SyncAgentBundle;
        expect(onDisk.agentId, 'agent-bundle');
        expect(onDisk.wakeRunKey, 'run-bundle');
        // The on-disk file carries the original inline child (the Matrix
        // text event is what gets stripped down to a descriptor).
        expect(onDisk.entities, hasLength(1));
        expect(onDisk.entities.single.agentEntity?.id, 'state-bundle');
        expect(onDisk.jsonPath, isNull);
      },
    );

    test('returns null when bundle has no jsonPath and no children', () async {
      const message = SyncMessage.agentBundle(
        agentId: 'agent-empty',
        wakeRunKey: 'run-empty',
      );

      final result = await sender.enrichAndUploadAgentPayloadForTesting(
        room: room,
        message: message,
      );

      expect(result, isNull);
      verifyNever(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      );
    });
  });

  group('ensureOriginatingHostIdForTesting', () {
    test('seeds bundle and child originatingHostId from local host', () async {
      final vectorClockService = MockVectorClockService();
      when(vectorClockService.getHost).thenAnswer((_) async => 'host-Z');
      sentEventRegistry = SentEventRegistry();
      sender = MatrixMessageSender(
        loggingService: loggingService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        sentEventRegistry: sentEventRegistry,
        vectorClockService: vectorClockService,
      );

      final entity = AgentDomainEntity.agentState(
        id: 'state-seed',
        agentId: 'agent-seed',
        revision: 1,
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: const VectorClock({'host-Z': 1}),
      );
      final link = AgentLink.basic(
        id: 'link-seed',
        fromId: 'agent-seed',
        toId: 'state-seed',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: const VectorClock({'host-Z': 2}),
      );
      // Children with NO originatingHostId — must inherit from bundle/host.
      final message = SyncMessage.agentBundle(
        agentId: 'agent-seed',
        wakeRunKey: 'run-seed',
        entities: [
          SyncMessage.agentEntity(
                status: SyncEntryStatus.update,
                agentEntity: entity,
              )
              as SyncAgentEntity,
        ],
        links: [
          SyncMessage.agentLink(
                status: SyncEntryStatus.update,
                agentLink: link,
              )
              as SyncAgentLink,
        ],
      );

      final result = await sender.ensureOriginatingHostIdForTesting(message);

      final bundle = result as SyncAgentBundle;
      expect(bundle.originatingHostId, 'host-Z');
      expect(bundle.entities.single.originatingHostId, 'host-Z');
      expect(bundle.links.single.originatingHostId, 'host-Z');
    });

    test(
      'preserves existing bundle originatingHostId, fills only null children',
      () async {
        final vectorClockService = MockVectorClockService();
        when(vectorClockService.getHost).thenAnswer((_) async => 'host-Z');
        sentEventRegistry = SentEventRegistry();
        sender = MatrixMessageSender(
          loggingService: loggingService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          sentEventRegistry: sentEventRegistry,
          vectorClockService: vectorClockService,
        );

        final entity = AgentDomainEntity.agentState(
          id: 'state-preserve',
          agentId: 'agent-preserve',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'remote': 1}),
        );
        final message = SyncMessage.agentBundle(
          agentId: 'agent-preserve',
          wakeRunKey: 'run-preserve',
          // Bundle already carries an explicit origin — must not be
          // overwritten by the local host.
          originatingHostId: 'remote',
          entities: [
            // Child already has an origin — must stay.
            SyncMessage.agentEntity(
                  status: SyncEntryStatus.update,
                  agentEntity: entity,
                  originatingHostId: 'other',
                )
                as SyncAgentEntity,
          ],
        );

        final result = await sender.ensureOriginatingHostIdForTesting(message);

        final bundle = result as SyncAgentBundle;
        expect(bundle.originatingHostId, 'remote');
        expect(bundle.entities.single.originatingHostId, 'other');
      },
    );
  });

  group('legacy agent messages without jsonPath', () {
    test('enriches legacy SyncAgentEntity with jsonPath and uploads', () async {
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => 'file-id');

      var capturedPayload = '';
      when(
        () => room.sendTextEvent(
          any<String>(),
          msgtype: any<String>(named: 'msgtype'),
          parseCommands: any<bool>(named: 'parseCommands'),
          parseMarkdown: any<bool>(named: 'parseMarkdown'),
        ),
      ).thenAnswer((invocation) async {
        capturedPayload = invocation.positionalArguments.first as String;
        return 'text-id';
      });

      final entity = AgentDomainEntity.agent(
        id: 'legacy-agent',
        agentId: 'legacy-agent',
        kind: 'task_agent',
        displayName: 'Legacy',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      // Legacy message: has inline entity but no jsonPath
      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );

      final result = await sender.sendMatrixMessage(
        message: message,
        context: buildContext(),
        onSent: (_, _) {},
      );

      expect(result, isTrue);

      // File was uploaded
      verify(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).called(1);

      // Text event strips inline entity (file-only for large payloads)
      final decoded =
          json.decode(
                utf8.decode(base64.decode(capturedPayload)),
              )
              as Map<String, dynamic>;
      expect(decoded['agentEntity'], isNull);
      expect(decoded['jsonPath'], '/agent_entities/legacy-agent.json');
    });

    test('returns false when agent entity upload fails', () async {
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => null);

      final entity = AgentDomainEntity.agent(
        id: 'fail-agent',
        agentId: 'fail-agent',
        kind: 'task_agent',
        displayName: 'Fail',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );

      final result = await sender.sendMatrixMessage(
        message: message,
        context: buildContext(),
        onSent: (_, _) {},
      );

      expect(result, isFalse);
      verifyNever(
        () => room.sendTextEvent(
          any<String>(),
          msgtype: any<String>(named: 'msgtype'),
          parseCommands: any<bool>(named: 'parseCommands'),
          parseMarkdown: any<bool>(named: 'parseMarkdown'),
        ),
      );
    });

    test('returns false when agent link upload fails', () async {
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => null);

      final link = AgentLink.basic(
        id: 'fail-link',
        fromId: 'agent-1',
        toId: 'state-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );

      final result = await sender.sendMatrixMessage(
        message: message,
        context: buildContext(),
        onSent: (_, _) {},
      );

      expect(result, isFalse);
      verifyNever(
        () => room.sendTextEvent(
          any<String>(),
          msgtype: any<String>(named: 'msgtype'),
          parseCommands: any<bool>(named: 'parseCommands'),
          parseMarkdown: any<bool>(named: 'parseMarkdown'),
        ),
      );
    });

    test('enriches legacy SyncAgentLink with jsonPath and uploads', () async {
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => 'file-id');

      var capturedPayload = '';
      when(
        () => room.sendTextEvent(
          any<String>(),
          msgtype: any<String>(named: 'msgtype'),
          parseCommands: any<bool>(named: 'parseCommands'),
          parseMarkdown: any<bool>(named: 'parseMarkdown'),
        ),
      ).thenAnswer((invocation) async {
        capturedPayload = invocation.positionalArguments.first as String;
        return 'text-id';
      });

      final link = AgentLink.basic(
        id: 'legacy-link',
        fromId: 'agent-1',
        toId: 'state-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      // Legacy message: has inline link but no jsonPath
      final message = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );

      final result = await sender.sendMatrixMessage(
        message: message,
        context: buildContext(),
        onSent: (_, _) {},
      );

      expect(result, isTrue);

      verify(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).called(1);

      final decoded =
          json.decode(
                utf8.decode(base64.decode(capturedPayload)),
              )
              as Map<String, dynamic>;
      expect(decoded['agentLink'], isNotNull);
      expect(decoded['jsonPath'], '/agent_links/legacy-link.json');
    });
  });

  group('SyncOutboxBundle delivery', () {
    SyncOutboxBundle bundleWith(int childCount) {
      return SyncOutboxBundle(
        children: [
          for (var i = 1; i <= childCount; i++)
            SyncMessage.aiConfigDelete(id: 'cfg-$i'),
        ],
      );
    }

    setUp(() {
      // Default: no journal entity children in the bundle, so the bulk
      // lookup is never called. Stub it conservatively so any unexpected
      // invocation fails loudly via the assertion below rather than a
      // mocktail "missing stub" surprise.
      when(
        () => journalDb.journalEntityMapForIds(any<Iterable<String>>()),
      ).thenAnswer((_) async => const <String, JournalEntity>{});
    });

    /// Decodes the gzipped manifest bytes captured from a `sendFileEvent`
    /// call so a test can assert against the actual on-the-wire payload.
    Map<String, dynamic> decodeManifestFromUpload(MatrixFile uploaded) {
      final raw = gzip.decode(uploaded.bytes);
      return json.decode(utf8.decode(raw)) as Map<String, dynamic>;
    }

    test(
      'sendOutboxBundlePayloadForTesting uploads a single gzipped manifest '
      'event under /outbox_bundles/<uuid>.json and returns a stripped '
      'bundle whose jsonPath references it. The wire upload display name '
      'gets `.gz` appended (matching the `_sendFile` convention for '
      'compressed agent payloads); the canonical compression signal is '
      'still the encoding header so the relativePath stays `.json` and '
      "matches the receiver's post-decode on-disk cache content. The "
      'manifest carries one envelope record per child — no per-child file '
      'events, no temp files on disk.',
      () async {
        final bundle = bundleWith(3);
        MatrixFile? capturedFile;
        Map<String, dynamic>? capturedExtra;
        when(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        ).thenAnswer((inv) async {
          capturedFile = inv.positionalArguments.first as MatrixFile;
          capturedExtra =
              inv.namedArguments[#extraContent] as Map<String, dynamic>?;
          return r'$bundle-file-id';
        });

        final stripped = await sender.sendOutboxBundlePayloadForTesting(
          room: room,
          message: bundle,
        );

        expect(stripped, isNotNull);
        expect(stripped!.children, isEmpty);
        expect(stripped.jsonPath, startsWith('/outbox_bundles/'));
        expect(stripped.jsonPath, endsWith('.json'));
        expect(capturedFile!.name, endsWith('.json.gz'));

        // Disk is untouched — the bundle exists only in the upload bytes
        // and the matrix room; no /outbox_bundles/ directory is created.
        expect(
          Directory('${documentsDirectory.path}/outbox_bundles').existsSync(),
          isFalse,
        );

        // One file event went out, tagged as gzip-encoded JSON.
        verify(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        ).called(1);
        expect(capturedExtra?['relativePath'], stripped.jsonPath);
        expect(capturedExtra?[attachmentEncodingKey], attachmentEncodingGzip);

        // The uploaded bytes ungzip into a v1 manifest with one entry per
        // child, envelopes round-trip through SyncMessage.fromJson.
        final manifest = decodeManifestFromUpload(capturedFile!);
        expect(manifest['version'], 1);
        final entries = manifest['entries'] as List;
        expect(entries, hasLength(3));
        for (var i = 0; i < entries.length; i++) {
          final record = entries[i] as Map<String, dynamic>;
          final envelopeJson = record['envelope'] as Map<String, dynamic>;
          final envelope = SyncMessage.fromJson(envelopeJson);
          expect(envelope, isA<SyncAiConfigDelete>());
          expect((envelope as SyncAiConfigDelete).id, 'cfg-${i + 1}');
          // aiConfigDelete is inline-only — no separate `payload`.
          expect(record.containsKey('payload'), isFalse);
        }
      },
    );

    test(
      'sendOutboxBundlePayloadForTesting embeds the JournalEntity body from '
      'the database for every SyncJournalEntity child and reconciles the '
      "envelope's vector clock against the DB version — exactly the "
      'reconcile path used for individually-delivered entities, just '
      'aggregated into a single bulk DB read.',
      () async {
        const entityVc = VectorClock({'host-A': 7});
        const messageVc = VectorClock({'host-A': 5});
        final entity = JournalEntry(
          meta: Metadata(
            id: 'entry-1',
            createdAt: DateTime.utc(2026, 1, 2),
            updatedAt: DateTime.utc(2026, 1, 2),
            dateFrom: DateTime.utc(2026, 1, 2),
            dateTo: DateTime.utc(2026, 1, 2),
            vectorClock: entityVc,
          ),
          entryText: const EntryText(plainText: 'from db'),
        );
        when(
          () => journalDb.journalEntityMapForIds(any<Iterable<String>>()),
        ).thenAnswer((inv) async {
          final ids = (inv.positionalArguments.first as Iterable<String>)
              .toSet();
          expect(ids, {'entry-1'});
          return {'entry-1': entity};
        });

        MatrixFile? capturedFile;
        when(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        ).thenAnswer((inv) async {
          capturedFile = inv.positionalArguments.first as MatrixFile;
          return r'$bundle-file-id';
        });

        final bundle = SyncOutboxBundle(
          children: [
            SyncMessage.journalEntity(
              id: 'entry-1',
              jsonPath: '/journal/2026-01-02/entry-1.entry.json',
              vectorClock: messageVc,
              status: SyncEntryStatus.update,
            ),
          ],
        );

        final stripped = await sender.sendOutboxBundlePayloadForTesting(
          room: room,
          message: bundle,
        );

        expect(stripped, isNotNull);
        verify(
          () => journalDb.journalEntityMapForIds(any<Iterable<String>>()),
        ).called(1);

        final manifest = decodeManifestFromUpload(capturedFile!);
        final entries = manifest['entries'] as List;
        expect(entries, hasLength(1));
        final record = entries.single as Map<String, dynamic>;

        final envelope = SyncMessage.fromJson(
          record['envelope'] as Map<String, dynamic>,
        );
        expect(envelope, isA<SyncJournalEntity>());
        // VC reconciled to the DB version, with the message's stale VC and
        // the DB's current VC both folded into coveredVectorClocks.
        final reconciled = envelope as SyncJournalEntity;
        expect(reconciled.vectorClock, entityVc);
        expect(
          reconciled.coveredVectorClocks,
          containsAll([messageVc, entityVc]),
        );

        // The entity body is inlined under `payload`, round-trips back to
        // the same JournalEntity the DB returned.
        final payloadJson = record['payload'] as Map<String, dynamic>;
        final roundTripped = JournalEntity.fromJson(payloadJson);
        expect(roundTripped.meta.id, entity.meta.id);
        expect(roundTripped.meta.vectorClock, entityVc);
      },
    );

    test(
      'sendOutboxBundlePayloadForTesting returns null for an empty bundle '
      '(no IO performed; logged once)',
      () async {
        final result = await sender.sendOutboxBundlePayloadForTesting(
          room: room,
          message: const SyncOutboxBundle(children: []),
        );

        expect(result, isNull);
        verifyNever(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        );
        verify(
          () => loggingService.captureEvent(
            'skipping empty outboxBundle send',
            domain: 'MATRIX_SERVICE',
            subDomain: 'sendMatrixMsg',
          ),
        ).called(1);
      },
    );

    test(
      'sendOutboxBundlePayloadForTesting returns null when the upload fails '
      '— the caller (sendMatrixMessage) treats this as a transport-level '
      'failure and propagates it up to OutboxProcessor.markRetryBatch',
      () async {
        when(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        ).thenAnswer((_) async => null);

        final result = await sender.sendOutboxBundlePayloadForTesting(
          room: room,
          message: bundleWith(2),
        );

        expect(result, isNull);
      },
    );

    test(
      'sendMatrixMessage returns false when the outboxBundle upload fails — '
      'the failure is traced and the text event is never sent',
      () async {
        when(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => room.sendTextEvent(
            any<String>(),
            msgtype: any<String>(named: 'msgtype'),
            parseCommands: any<bool>(named: 'parseCommands'),
            parseMarkdown: any<bool>(named: 'parseMarkdown'),
          ),
        ).thenAnswer((_) async => r'$should-not-be-called');

        final result = await sender.sendMatrixMessage(
          message: bundleWith(3),
          context: buildContext(),
          onSent: (_, _) {},
        );

        expect(result, isFalse);
        verifyNever(
          () => room.sendTextEvent(
            any<String>(),
            msgtype: any<String>(named: 'msgtype'),
            parseCommands: any<bool>(named: 'parseCommands'),
            parseMarkdown: any<bool>(named: 'parseMarkdown'),
          ),
        );
      },
    );

    test(
      'sendMatrixMessage with a SyncOutboxBundle uploads the manifest, '
      'sends a stripped text event referencing it, and registers BOTH the '
      'file and text event IDs in the sent registry',
      () async {
        when(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        ).thenAnswer((_) async => r'$bundle-file-id');
        String? capturedPayload;
        when(
          () => room.sendTextEvent(
            any<String>(),
            msgtype: any<String>(named: 'msgtype'),
            parseCommands: any<bool>(named: 'parseCommands'),
            parseMarkdown: any<bool>(named: 'parseMarkdown'),
          ),
        ).thenAnswer((inv) async {
          capturedPayload = inv.positionalArguments.first as String;
          return r'$bundle-text-id';
        });

        final bundle = bundleWith(4);
        final result = await sender.sendMatrixMessage(
          message: bundle,
          context: buildContext(),
          onSent: (_, _) {},
        );

        expect(result, isTrue);
        expect(sentEventRegistry.length, 2);

        // The text event no longer carries inline children — they live in
        // the manifest referenced by jsonPath.
        final decoded =
            json.decode(
                  utf8.decode(base64.decode(capturedPayload!)),
                )
                as Map<String, dynamic>;
        expect(decoded['runtimeType'], 'outboxBundle');
        expect(decoded['jsonPath'], startsWith('/outbox_bundles/'));
        expect(decoded['jsonPath'], endsWith('.json'));
        expect(decoded['children'], isEmpty);
      },
    );

    test(
      'aborts the bundle and returns null when a SyncJournalEntity child '
      'has no DB row — silently dropping that one child while the others '
      'apply would let the bundle ack with a missing entity (permanent '
      'data loss); the failed bundle drops to the standard retry/cap path',
      () async {
        when(
          () => journalDb.journalEntityMapForIds(any<Iterable<String>>()),
        ).thenAnswer((_) async => const <String, JournalEntity>{});

        final bundle = SyncOutboxBundle(
          children: [
            SyncMessage.journalEntity(
              id: 'orphaned-id',
              jsonPath: '/journal/2026-04-25/orphaned-id.entry.json',
              vectorClock: const VectorClock({'host-A': 1}),
              status: SyncEntryStatus.update,
            ),
          ],
        );

        final result = await sender.sendOutboxBundlePayloadForTesting(
          room: room,
          message: bundle,
        );

        expect(result, isNull);
        verifyNever(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        );
        verify(
          () => loggingService.captureException(
            any<Object>(
              that: isA<String>().having(
                (msg) => msg,
                'message',
                contains('outboxBundle aborting'),
              ),
            ),
            domain: 'MATRIX_SERVICE',
            subDomain: 'sendMatrixMsg.outboxBundle.missingEntity',
          ),
        ).called(1);
      },
    );

    test(
      'reconciles a SyncEntryLink child by merging entryLink.vectorClock '
      'into coveredVectorClocks (and filling originatingHostId) — bundled '
      'and unbundled entry-link sequencing must stay identical so '
      "recordReceivedEntryLink's gap detection works the same way for "
      'both delivery shapes',
      () async {
        const linkVc = VectorClock({'host-A': 9});
        final linkChild = SyncMessage.entryLink(
          entryLink: EntryLink.basic(
            id: 'link-1',
            fromId: 'from',
            toId: 'to',
            createdAt: DateTime.utc(2026, 4, 25),
            updatedAt: DateTime.utc(2026, 4, 25),
            vectorClock: linkVc,
          ),
          status: SyncEntryStatus.initial,
        );

        MatrixFile? capturedFile;
        when(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        ).thenAnswer((inv) async {
          capturedFile = inv.positionalArguments.first as MatrixFile;
          return r'$file-id';
        });

        final stripped = await sender.sendOutboxBundlePayloadForTesting(
          room: room,
          message: SyncOutboxBundle(children: [linkChild]),
        );

        expect(stripped, isNotNull);
        final manifestBytes = gzip.decode(capturedFile!.bytes);
        final manifest =
            json.decode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
        final entry =
            (manifest['entries'] as List).single as Map<String, dynamic>;
        final envelopeJson = entry['envelope'] as Map<String, dynamic>;
        final reconstructed = SyncMessage.fromJson(envelopeJson);
        expect(reconstructed, isA<SyncEntryLink>());
        final link = reconstructed as SyncEntryLink;
        // entryLink.vectorClock now lives in coveredVectorClocks — exactly
        // what the standalone entry-link send path does in
        // sendMatrixMessage. Bundled deliveries used to skip this step.
        expect(link.coveredVectorClocks, contains(linkVc));
      },
    );
  });
}
