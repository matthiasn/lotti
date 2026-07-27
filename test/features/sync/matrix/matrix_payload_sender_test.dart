import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/matrix_payload_sender.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// Direct unit coverage for [MatrixPayloadSender]. The owning
/// `MatrixMessageSender` exercises the higher-level payload methods through its
/// `*ForTesting` seams; this file targets the leaf upload primitive
/// ([MatrixPayloadSender.sendFile]) and the standalone path-safety predicate so
/// the collaborator is covered without going through the sender wrapper.
void main() {
  setUpAll(() {
    registerFallbackValue(MatrixFile(bytes: Uint8List(0), name: 'fallback'));
  });

  late Directory documentsDirectory;
  late MockDomainLogger loggingService;
  late MockJournalDb journalDb;
  late SentEventRegistry sentEventRegistry;
  late MockRoom room;
  late MatrixPayloadSender payloadSender;

  setUp(() {
    documentsDirectory = Directory.systemTemp.createTempSync(
      'matrix_payload_sender_test',
    );
    loggingService = MockDomainLogger();
    journalDb = MockJournalDb();
    sentEventRegistry = SentEventRegistry();
    room = MockRoom();
    payloadSender = MatrixPayloadSender(
      loggingService: loggingService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
      sentEventRegistry: sentEventRegistry,
    );

    when(
      () => loggingService.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) {});
    when(
      () => loggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
    when(() => room.id).thenReturn('!room:test');
  });

  tearDown(() {
    if (documentsDirectory.existsSync()) {
      documentsDirectory.deleteSync(recursive: true);
    }
  });

  group('sendFile', () {
    test(
      'uploads provided bytes and registers the returned event id',
      () async {
        when(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        ).thenAnswer((_) async => 'uploaded-event');

        final ok = await payloadSender.sendFile(
          room: room,
          fullPath: '${documentsDirectory.path}/note.txt',
          relativePath: 'note.txt',
          bytes: Uint8List.fromList([1, 2, 3]),
        );

        expect(ok, isTrue);
        expect(
          sentEventRegistry.debugSource('uploaded-event'),
          SentEventSource.file,
        );
      },
    );

    test(
      'gzip-compresses .json payloads and tags the encoding header',
      () async {
        Map<String, dynamic>? capturedExtra;
        MatrixFile? capturedFile;
        when(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        ).thenAnswer((invocation) async {
          capturedFile = invocation.positionalArguments.first as MatrixFile;
          capturedExtra =
              invocation.namedArguments[const Symbol('extraContent')]
                  as Map<String, dynamic>;
          return 'json-event';
        });

        final ok = await payloadSender.sendFile(
          room: room,
          fullPath: '${documentsDirectory.path}/entry.json',
          relativePath: 'entry.json',
          bytes: Uint8List.fromList(
            List<int>.generate(64, (i) => i % 256),
          ),
        );

        expect(ok, isTrue);
        expect(capturedFile!.name, endsWith('.gz'));
        expect(capturedExtra, containsPair('relativePath', 'entry.json'));
        expect(
          capturedExtra,
          containsPair(attachmentEncodingKey, attachmentEncodingGzip),
        );
      },
    );

    test(
      'returns true and skips upload when a non-bytes file is missing',
      () async {
        final ok = await payloadSender.sendFile(
          room: room,
          fullPath: '${documentsDirectory.path}/does_not_exist.bin',
          relativePath: 'does_not_exist.bin',
        );

        expect(ok, isTrue);
        verifyNever(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        );
      },
    );

    test(
      'returns false and does not register when upload yields null',
      () async {
        when(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        ).thenAnswer((_) async => null);

        final ok = await payloadSender.sendFile(
          room: room,
          fullPath: '${documentsDirectory.path}/note.txt',
          relativePath: 'note.txt',
          bytes: Uint8List.fromList([9]),
        );

        expect(ok, isFalse);
      },
    );

    test('returns false and logs when the SDK throws', () async {
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenThrow(Exception('network'));

      final ok = await payloadSender.sendFile(
        room: room,
        fullPath: '${documentsDirectory.path}/note.txt',
        relativePath: 'note.txt',
        bytes: Uint8List.fromList([9]),
      );

      expect(ok, isFalse);
      verify(
        () => loggingService.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'sendMatrixMsg',
        ),
      ).called(1);
    });
  });

  group('sendJournalEntityPayload attachments', () {
    /// Writes an image entry's JSON payload and its 12-byte blob under the
    /// documents directory, and returns the relative paths of every file event
    /// the sender uploads for [message].
    Future<List<String>> uploadedPathsFor(SyncJournalEntity message) async {
      final sampleDate = DateTime.utc(2024);
      final entity = JournalEntity.journalImage(
        meta: Metadata(
          id: message.id,
          createdAt: sampleDate,
          updatedAt: sampleDate,
          dateFrom: sampleDate,
          dateTo: sampleDate,
          vectorClock: message.vectorClock,
        ),
        data: ImageData(
          capturedAt: sampleDate,
          imageId: 'img-${message.id}',
          imageFile: '${message.id}.jpg',
          imageDirectory: '/images/',
        ),
      );

      File('${documentsDirectory.path}${message.jsonPath}')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(entity.toJson()));
      File('${documentsDirectory.path}/images/${message.id}.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(12, 7));

      final uploaded = <String>[];
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((invocation) async {
        final extra =
            invocation.namedArguments[#extraContent] as Map<String, dynamic>?;
        uploaded.add(extra?['relativePath'] as String? ?? '');
        return 'event-${uploaded.length}';
      });

      final result = await payloadSender.sendJournalEntityPayload(
        room: room,
        message: message,
      );
      expect(result, isNotNull, reason: 'the send must succeed');
      return uploaded;
    }

    // Regression: the sender used to derive the attachment decision from the
    // status alone, so a re-sync or backfill re-send (necessarily `update`)
    // uploaded the JSON and left the blob behind.
    test('an update opting in uploads the blob alongside the JSON', () async {
      when(
        () => journalDb.getConfigFlag(resendAttachments),
      ).thenAnswer((_) async => false);

      final uploaded = await uploadedPathsFor(
        const SyncMessage.journalEntity(
              id: 'resend',
              jsonPath: '/entries/resend.json',
              vectorClock: VectorClock({'hostA': 1}),
              status: SyncEntryStatus.update,
              includeAttachments: true,
            )
            as SyncJournalEntity,
      );

      expect(uploaded, ['/entries/resend.json', '/images/resend.jpg']);
    });

    test('an ordinary update uploads the JSON only', () async {
      when(
        () => journalDb.getConfigFlag(resendAttachments),
      ).thenAnswer((_) async => false);

      final uploaded = await uploadedPathsFor(
        const SyncMessage.journalEntity(
              id: 'edit',
              jsonPath: '/entries/edit.json',
              vectorClock: VectorClock({'hostA': 1}),
              status: SyncEntryStatus.update,
            )
            as SyncJournalEntity,
      );

      expect(uploaded, ['/entries/edit.json']);
    });
  });

  group('debugIsSafeOutboxBundlePath', () {
    test('accepts well-formed outbox-bundle paths', () {
      expect(
        MatrixPayloadSender.debugIsSafeOutboxBundlePath(
          '/outbox_bundles/abc.json',
        ),
        isTrue,
      );
    });

    test(
      'rejects paths outside the outbox-bundles prefix or with traversal',
      () {
        expect(
          MatrixPayloadSender.debugIsSafeOutboxBundlePath('/elsewhere/x.json'),
          isFalse,
        );
        expect(
          MatrixPayloadSender.debugIsSafeOutboxBundlePath(
            '/outbox_bundles/../escape.json',
          ),
          isFalse,
        );
      },
    );
  });
}
