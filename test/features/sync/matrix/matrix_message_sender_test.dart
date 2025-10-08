// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, avoid_redundant_argument_values

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockRoom extends Mock implements Room {}

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalDb extends Mock implements JournalDb {}

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

  setUp(() {
    documentsDirectory = Directory.systemTemp.createTempSync(
      'matrix_message_sender_test',
    );
    loggingService = MockLoggingService();
    journalDb = MockJournalDb();
    sender = MatrixMessageSender(
      loggingService: loggingService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
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
    ).thenAnswer((_) {});
    when(() => journalDb.getConfigFlag(any<String>()))
        .thenAnswer((_) async => false);
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
      onSent: () {},
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
      onSent: () => calls++,
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
      onSent: () {},
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
      onSent: () {},
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
  });

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
      onSent: () {},
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
      onSent: () => calls++,
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
    when(() => journalDb.getConfigFlag(resendAttachments))
        .thenAnswer((_) async => false);

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
      onSent: () => callbackCount++,
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

  test('sends journal entity attachments without duplicating callback',
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
    when(() => journalDb.getConfigFlag(resendAttachments))
        .thenAnswer((_) async => true);

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
      onSent: () => callbackCount++,
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
      onSent: () {},
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
      onSent: () {},
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
      onSent: () {},
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

  test('resends audio attachment when resend flag true on update status',
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
    when(() => journalDb.getConfigFlag(resendAttachments))
        .thenAnswer((_) async => true);

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
      onSent: () => callbackCount++,
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
  });

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
        onSent: () => callbackCount++,
      ),
      completion(isFalse),
    );

    expect(callbackCount, 0);
  });

  test('returns false when attachment file is missing', () async {
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
    when(() => journalDb.getConfigFlag(resendAttachments))
        .thenAnswer((_) async => true);

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
      onSent: () {},
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
}
