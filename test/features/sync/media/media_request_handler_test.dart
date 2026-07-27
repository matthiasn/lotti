import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/media/media_request_handler.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockJournalDb journalDb;
  late MockOutboxService outboxService;
  late MockVectorClockService vectorClockService;
  late MockDomainLogger loggingService;
  late Directory documentsDirectory;
  late List<SyncJournalEntity> answers;
  late MediaRequestHandler handler;

  final sampleDate = DateTime.utc(2024);

  JournalEntity imageEntry(String id) => JournalEntity.journalImage(
    meta: Metadata(
      id: id,
      createdAt: sampleDate,
      updatedAt: sampleDate,
      dateFrom: sampleDate,
      dateTo: sampleDate,
      vectorClock: const VectorClock({'host-b': 3}),
    ),
    data: ImageData(
      capturedAt: sampleDate,
      imageId: 'img-$id',
      imageFile: '$id.jpg',
      imageDirectory: '/images/',
    ),
  );

  JournalEntity audioEntry(String id) => JournalEntity.journalAudio(
    meta: Metadata(
      id: id,
      createdAt: sampleDate,
      updatedAt: sampleDate,
      dateFrom: sampleDate,
      dateTo: sampleDate,
      vectorClock: const VectorClock({'host-b': 4}),
    ),
    data: AudioData(
      dateFrom: sampleDate,
      dateTo: sampleDate,
      audioFile: '$id.aac',
      audioDirectory: '/audio/2024-01-01/',
      duration: const Duration(seconds: 5),
    ),
  );

  JournalEntity textEntry(String id) => JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: sampleDate,
      updatedAt: sampleDate,
      dateFrom: sampleDate,
      dateTo: sampleDate,
      vectorClock: const VectorClock({'host-b': 5}),
    ),
    entryText: const EntryText(plainText: 'no media'),
  );

  void writeBlob(String relativePath, {int bytes = 12}) {
    File('${documentsDirectory.path}$relativePath')
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(bytes, 7));
  }

  void haveEntities(Map<String, JournalEntity> entities) {
    when(
      () => journalDb.journalEntityMapForIds(any<Iterable<String>>()),
    ).thenAnswer((_) async => entities);
  }

  setUp(() {
    journalDb = MockJournalDb();
    outboxService = MockOutboxService();
    vectorClockService = MockVectorClockService();
    loggingService = MockDomainLogger();
    documentsDirectory = Directory.systemTemp.createTempSync(
      'media_request_handler_test',
    );
    answers = [];

    when(() => vectorClockService.getHost()).thenAnswer((_) async => 'host-b');
    when(() => outboxService.enqueueMessage(any())).thenAnswer((
      invocation,
    ) async {
      final message = invocation.positionalArguments.first as SyncMessage;
      if (message is SyncJournalEntity) answers.add(message);
    });
    when(
      () => loggingService.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) {});

    handler = MediaRequestHandler(
      journalDb: journalDb,
      outboxService: outboxService,
      vectorClockService: vectorClockService,
      documentsDirectory: documentsDirectory,
      loggingService: loggingService,
    );
  });

  tearDown(() {
    if (documentsDirectory.existsSync()) {
      documentsDirectory.deleteSync(recursive: true);
    }
  });

  test('answers with the entry and its blob attached', () async {
    haveEntities({'img-1': imageEntry('img-1'), 'aud-1': audioEntry('aud-1')});
    writeBlob('/images/img-1.jpg');
    writeBlob('/audio/2024-01-01/aud-1.aac');

    await handler.handleMediaRequest(
      const SyncMessage.mediaRequest(
            entryIds: ['img-1', 'aud-1'],
            requesterId: 'host-a',
          )
          as SyncMediaRequest,
    );

    expect(answers.map((a) => a.id), ['img-1', 'aud-1']);
    // The whole point: without this the answer is JSON the requester already
    // has, and the blob it is actually missing never moves.
    expect(
      answers.every((a) => a.includeAttachments ?? false),
      isTrue,
      reason: 'the answer must force the blob onto an update send',
    );
    expect(answers.first.status, SyncEntryStatus.update);
  });

  test("ignores this device's own broadcast", () async {
    haveEntities({'img-1': imageEntry('img-1')});
    writeBlob('/images/img-1.jpg');

    await handler.handleMediaRequest(
      const SyncMessage.mediaRequest(
            entryIds: ['img-1'],
            // Same host as vectorClockService.getHost().
            requesterId: 'host-b',
          )
          as SyncMediaRequest,
    );

    expect(answers, isEmpty);
    verifyNever(() => journalDb.journalEntityMapForIds(any()));
  });

  test('stays silent for entries this device cannot help with', () async {
    haveEntities({
      // Known, but the blob is missing here too — answering would upload
      // nothing while the requester believes it was served.
      'no-blob': imageEntry('no-blob'),
      // Known, but empty on disk: the signature of an interrupted download.
      'empty-blob': imageEntry('empty-blob'),
      // Known, but carries no media at all.
      'text-1': textEntry('text-1'),
      // 'unknown' is absent from the map entirely.
    });
    writeBlob('/images/empty-blob.jpg', bytes: 0);

    await handler.handleMediaRequest(
      const SyncMessage.mediaRequest(
            entryIds: ['no-blob', 'empty-blob', 'text-1', 'unknown'],
            requesterId: 'host-a',
          )
          as SyncMediaRequest,
    );

    expect(answers, isEmpty);
  });

  test('bounds the work one request can demand', () async {
    final entities = <String, JournalEntity>{};
    for (var i = 0; i < 10; i++) {
      entities['e-$i'] = imageEntry('e-$i');
      writeBlob('/images/e-$i.jpg');
    }
    haveEntities(entities);

    final boundedHandler = MediaRequestHandler(
      journalDb: journalDb,
      outboxService: outboxService,
      vectorClockService: vectorClockService,
      documentsDirectory: documentsDirectory,
      loggingService: loggingService,
      maxEntriesPerRequest: 3,
    );

    await boundedHandler.handleMediaRequest(
      SyncMessage.mediaRequest(
            entryIds: [for (var i = 0; i < 10; i++) 'e-$i'],
            requesterId: 'host-a',
          )
          as SyncMediaRequest,
    );

    expect(
      answers.map((a) => a.id),
      ['e-0', 'e-1', 'e-2'],
      reason:
          'a malformed or hostile request must not be able to make this '
          'device upload its whole media library at once',
    );
  });
}
