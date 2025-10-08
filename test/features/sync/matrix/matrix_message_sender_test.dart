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

  test('throws when unverified devices are present', () async {
    final device = MockDeviceKeys();
    final context = buildContext(devices: [device]);

    expect(
      () => sender.sendMatrixMessage(
        message: const SyncMessage.aiConfigDelete(id: 'abc'),
        context: context,
        onSent: () {},
      ),
      throwsA(isA<Exception>()),
    );
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

  test('sends text message and invokes callback once', () async {
    when(
      () => room.sendTextEvent(
        any<String>(),
        msgtype: any<String>(named: 'msgtype'),
        parseCommands: any<bool>(named: 'parseCommands'),
        parseMarkdown: any<bool>(named: 'parseMarkdown'),
      ),
    ).thenAnswer((_) async => 'event-id');

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
    verify(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).called(2);
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
    ).thenAnswer((_) => Future< String?>.error(Exception('network error')));

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
    expect(
      () => sender.sendMatrixMessage(
        message: SyncMessage.journalEntity(
          id: 'entry',
          jsonPath: jsonPath,
          vectorClock: VectorClock({'device': 1}),
          status: SyncEntryStatus.initial,
        ),
        context: buildContext(),
        onSent: () => callbackCount++,
      ),
      throwsA(isA<Exception>()),
    );

    expect(callbackCount, 0);
  });
}
