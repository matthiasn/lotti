import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/matrix_payload_sender.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

/// Direct unit coverage for [MatrixPayloadSender]. The owning
/// `MatrixMessageSender` exercises the higher-level payload methods through its
/// `*ForTesting` seams; this file targets the leaf upload primitive
/// ([MatrixPayloadSender.sendFile]) and public payload methods directly so the
/// collaborator is covered without going through the sender wrapper.
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
        expect(sentEventRegistry.consume('uploaded-event'), isTrue);
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

  group('sendJournalEntityPayload missing JSON recovery', () {
    const message = SyncJournalEntity(
      id: 'recovery-entry',
      jsonPath: '/entries/recovery.json',
      vectorClock: VectorClock({'hostA': 2}),
      status: SyncEntryStatus.update,
    );

    JournalEntity entity({VectorClock? clock, bool deleted = false}) {
      final date = DateTime.utc(2024, 3, 15);
      return JournalEntity.journalEntry(
        meta: Metadata(
          id: message.id,
          createdAt: date,
          updatedAt: date,
          dateFrom: date,
          dateTo: date,
          deletedAt: deleted ? date : null,
          vectorClock: clock,
        ),
      );
    }

    void stubRecovery(JournalEntity? recovered) {
      when(
        () => journalDb.journalEntityMapForIdsIncludingDeleted([message.id]),
      ).thenAnswer((_) async => {message.id: ?recovered});
      when(
        () => journalDb.getConfigFlag(resendAttachments),
      ).thenAnswer((_) async => false);
    }

    for (final deleted in [false, true]) {
      test(
        'recovers missing JSON from DB including deleted=$deleted',
        () async {
          final recovered = entity(
            clock: const VectorClock({'hostA': 3}),
            deleted: deleted,
          );
          stubRecovery(recovered);
          MatrixFile? uploaded;
          when(
            () => room.sendFileEvent(
              any<MatrixFile>(),
              extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
            ),
          ).thenAnswer((invocation) async {
            uploaded = invocation.positionalArguments.first as MatrixFile;
            return 'recovered-upload';
          });
          final result = await payloadSender.sendJournalEntityPayload(
            room: room,
            message: message,
          );
          expect(result?.attachmentEventId, 'recovered-upload');
          expect(result?.vectorClock, recovered.meta.vectorClock);
          expect(result?.coveredVectorClocks, contains(message.vectorClock));
          expect(
            JournalEntity.fromJson(
              jsonDecode(utf8.decode(gzip.decode(uploaded!.bytes)))
                  as Map<String, dynamic>,
            ),
            recovered,
          );
          expect(
            File('${documentsDirectory.path}${message.jsonPath}').existsSync(),
            isFalse,
            reason: 'Recovery must not recreate a reclaimed sidecar.',
          );
        },
      );
    }

    for (final clock in <VectorClock?>[
      null,
      const VectorClock({'hostA': 1}),
      const VectorClock({'hostA': 1, 'hostB': 3}),
    ]) {
      test(
        'does not acknowledge a missing queued version from DB clock $clock',
        () async {
          stubRecovery(entity(clock: clock));
          final result = await payloadSender.sendJournalEntityPayload(
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
          verify(
            () => journalDb.journalEntityMapForIdsIncludingDeleted(
              [message.id],
            ),
          ).called(1);
        },
      );
    }

    test('checks covered clocks as well as the queued version', () async {
      stubRecovery(entity(clock: const VectorClock({'hostA': 3})));
      final merged = message.copyWith(
        coveredVectorClocks: const [
          VectorClock({'hostB': 1}),
        ],
      );
      expect(
        await payloadSender.sendJournalEntityPayload(
          room: room,
          message: merged,
        ),
        isNull,
      );
      verifyNever(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      );
      verify(
        () => journalDb.journalEntityMapForIdsIncludingDeleted([message.id]),
      ).called(1);
    });

    test('keeps genuinely absent payloads retryable', () async {
      stubRecovery(null);
      expect(
        await payloadSender.sendJournalEntityPayload(
          room: room,
          message: message,
        ),
        isNull,
      );
      verify(
        () => journalDb.journalEntityMapForIdsIncludingDeleted(
          [message.id],
        ),
      ).called(1);
      verifyNever(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      );
    });

    test('does not use DB fallback for other filesystem failures', () async {
      Directory(
        '${documentsDirectory.path}${message.jsonPath}',
      ).createSync(recursive: true);
      expect(
        await payloadSender.sendJournalEntityPayload(
          room: room,
          message: message,
        ),
        isNull,
      );
      verifyNever(
        () => journalDb.journalEntityMapForIdsIncludingDeleted(any()),
      );
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
      expect(result!.attachmentEventId, 'event-1');
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

  group('sendOutboxBundlePayload attachments', () {
    test('embeds a soft-deleted journal tombstone in the manifest', () async {
      final deletedAt = DateTime.utc(2026, 8);
      final tombstone = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'deleted-child',
          createdAt: deletedAt.subtract(const Duration(minutes: 2)),
          updatedAt: deletedAt,
          dateFrom: deletedAt.subtract(const Duration(minutes: 2)),
          dateTo: deletedAt.subtract(const Duration(minutes: 1)),
          deletedAt: deletedAt,
        ),
        entryText: const EntryText(plainText: 'deleted payload'),
      );
      when(
        () => journalDb.journalEntityMapForIdsIncludingDeleted(
          any<Iterable<String>>(),
        ),
      ).thenAnswer((_) async => {'deleted-child': tombstone});

      MatrixFile? uploadedManifest;
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((invocation) async {
        uploadedManifest = invocation.positionalArguments.first as MatrixFile;
        return 'manifest-event';
      });

      final result = await payloadSender.sendOutboxBundlePayload(
        room: room,
        message: const SyncOutboxBundle(
          children: [
            SyncMessage.journalEntity(
              id: 'deleted-child',
              jsonPath: '/journal/deleted-child.json',
              vectorClock: null,
              status: SyncEntryStatus.update,
            ),
          ],
          jsonPath: '/outbox_bundles/deleted-child.json',
        ),
      );

      expect(result, isNotNull);
      expect(result!.attachmentEventId, 'manifest-event');
      final manifest =
          json.decode(
                utf8.decode(gzip.decode(uploadedManifest!.bytes)),
              )
              as Map<String, dynamic>;
      final record =
          (manifest['entries'] as List).single as Map<String, dynamic>;
      final payload = JournalEntity.fromJson(
        record['payload'] as Map<String, dynamic>,
      );
      expect(payload.meta.id, 'deleted-child');
      expect(payload.meta.deletedAt, deletedAt);
      verify(
        () => journalDb.journalEntityMapForIdsIncludingDeleted(
          any<Iterable<String>>(),
        ),
      ).called(1);
    });

    test(
      'replaces unsafe bundle paths before uploading the manifest',
      () async {
        final uploadedPaths = <String>[];
        when(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        ).thenAnswer((invocation) async {
          final extra =
              invocation.namedArguments[#extraContent] as Map<String, dynamic>;
          uploadedPaths.add(extra['relativePath'] as String);
          return 'manifest-event-${uploadedPaths.length}';
        });

        const unsafePaths = [
          '/journal/2026-04-25/evil.entry.json',
          '/outbox_bundles/../escape.json',
        ];
        final returnedPaths = <String>[];

        for (final unsafePath in unsafePaths) {
          final result = await payloadSender.sendOutboxBundlePayload(
            room: room,
            message: SyncOutboxBundle(
              children: const [SyncMessage.aiConfigDelete(id: 'cfg-1')],
              jsonPath: unsafePath,
            ),
          );

          expect(result, isNotNull, reason: unsafePath);
          expect(result!.jsonPath, startsWith('/outbox_bundles/'));
          expect(result.jsonPath, endsWith('.json'));
          expect(result.jsonPath, isNot(unsafePath));
          returnedPaths.add(result.jsonPath!);
        }

        expect(uploadedPaths, returnedPaths);
        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: contains(
                'rejecting outboxBundle jsonPath outside /outbox_bundles/',
              ),
            ),
            subDomain: 'sendMatrixMsg.outboxBundle.write',
          ),
        ).called(unsafePaths.length);
      },
    );

    // Media rows are supposed to be excluded from bundles at claim time
    // (`filePath != null` makes a row travel alone), so this path is defence
    // in depth for rows enqueued by a build that had not yet moved the
    // attachment decision to enqueue time. A manifest carries JSON only, so
    // without it such a child's blob would vanish with no error anywhere.

    /// Builds an image and an audio entity, writes their blobs, and returns
    /// the relativePath of every file event the bundle send uploads.
    Future<({List<String> uploaded, SyncOutboxBundle? result})> sendBundle({
      required bool includeAttachments,
      bool uploadSucceeds = true,
    }) async {
      final sampleDate = DateTime.utc(2024);
      final image = JournalEntity.journalImage(
        meta: Metadata(
          id: 'img-child',
          createdAt: sampleDate,
          updatedAt: sampleDate,
          dateFrom: sampleDate,
          dateTo: sampleDate,
          vectorClock: const VectorClock({'hostA': 1}),
        ),
        data: ImageData(
          capturedAt: sampleDate,
          imageId: 'img-1',
          imageFile: 'child.jpg',
          imageDirectory: '/images/',
        ),
      );
      final audio = JournalEntity.journalAudio(
        meta: Metadata(
          id: 'audio-child',
          createdAt: sampleDate,
          updatedAt: sampleDate,
          dateFrom: sampleDate,
          dateTo: sampleDate,
          vectorClock: const VectorClock({'hostA': 2}),
        ),
        data: AudioData(
          dateFrom: sampleDate,
          dateTo: sampleDate,
          audioFile: 'child.aac',
          audioDirectory: '/audio/2024-01-01/',
          duration: const Duration(seconds: 3),
        ),
      );
      final text = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'text-child',
          createdAt: sampleDate,
          updatedAt: sampleDate,
          dateFrom: sampleDate,
          dateTo: sampleDate,
          vectorClock: const VectorClock({'hostA': 3}),
        ),
        entryText: const EntryText(plainText: 'no media here'),
      );

      File('${documentsDirectory.path}/images/child.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(8, 1));
      File('${documentsDirectory.path}/audio/2024-01-01/child.aac')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(9, 2));

      when(
        () => journalDb.journalEntityMapForIdsIncludingDeleted(
          any<Iterable<String>>(),
        ),
      ).thenAnswer(
        (_) async => {
          'img-child': image,
          'audio-child': audio,
          'text-child': text,
        },
      );
      when(
        () => journalDb.getConfigFlag(resendAttachments),
      ).thenAnswer((_) async => false);

      final uploaded = <String>[];
      when(
        () => room.sendFileEvent(
          any<MatrixFile>(),
          extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
        ),
      ).thenAnswer((invocation) async {
        final extra =
            invocation.namedArguments[#extraContent] as Map<String, dynamic>?;
        final path = extra?['relativePath'] as String? ?? '';
        uploaded.add(path);
        // Only the media uploads are failed when asked; the manifest upload
        // is never reached in that case anyway.
        return uploadSucceeds ? 'event-${uploaded.length}' : null;
      });

      SyncJournalEntity child(String id, String jsonPath) =>
          SyncMessage.journalEntity(
                id: id,
                jsonPath: jsonPath,
                vectorClock: null,
                status: SyncEntryStatus.update,
                includeAttachments: includeAttachments ? true : null,
              )
              as SyncJournalEntity;

      final result = await payloadSender.sendOutboxBundlePayload(
        room: room,
        message:
            SyncMessage.outboxBundle(
                  children: [
                    child('img-child', '/entries/img-child.json'),
                    child('audio-child', '/entries/audio-child.json'),
                    child('text-child', '/entries/text-child.json'),
                  ],
                  jsonPath: '/outbox_bundles/bundle-1.json',
                )
                as SyncOutboxBundle,
      );
      return (uploaded: uploaded, result: result);
    }

    test("uploads each media child's blob before the manifest", () async {
      final sent = await sendBundle(includeAttachments: true);

      expect(sent.result, isNotNull);
      expect(
        sent.uploaded,
        [
          '/images/child.jpg',
          '/audio/2024-01-01/child.aac',
          '/outbox_bundles/bundle-1.json',
        ],
        reason:
            'both blobs must reach the room, and before the manifest that '
            'references them — a text-only child adds no upload',
      );
    });

    test('a bundle of ordinary updates uploads the manifest alone', () async {
      final sent = await sendBundle(includeAttachments: false);

      expect(sent.result, isNotNull);
      expect(sent.uploaded, ['/outbox_bundles/bundle-1.json']);
    });

    test('a failed blob upload fails the whole bundle', () async {
      final sent = await sendBundle(
        includeAttachments: true,
        uploadSucceeds: false,
      );

      // Returning null drops the send into the standard retry path. Acking
      // the bundle here would leave peers permanently without the blob.
      expect(sent.result, isNull);
      expect(
        sent.uploaded,
        ['/images/child.jpg'],
        reason:
            'the send must abort on the first failure, not push the '
            'manifest that claims those entries were delivered',
      );
    });
  });

  group('enrichAndUploadAgentPayload restores a reclaimed sidecar', () {
    test('rebuilds it for the upload, then removes it again', () async {
      // Sidecar reclamation can take a file while a row referencing it is
      // still queued: a hard delete and a pending send race by design. The
      // restore path used to run only when jsonPath was null, so a declared
      // path with a missing file failed a read that could never succeed and
      // the row retried until it aged out.
      final entity = makeTestCapture(id: 'entity-1');
      final relativePath = relativeAgentEntityPath('entity-1');
      final file = File('${documentsDirectory.path}$relativePath');
      expect(
        file.existsSync(),
        isFalse,
        reason: 'The reclaimed sidecar is exactly what is missing.',
      );

      when(
        () => room.sendFileEvent(
          any(),
          extraContent: any(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => 'evt-1');

      await payloadSender.enrichAndUploadAgentPayload(
        room: room,
        message: SyncMessage.agentEntity(
          agentEntity: entity,
          jsonPath: relativePath,
          status: SyncEntryStatus.update,
        ),
      );

      expect(
        file.existsSync(),
        isFalse,
        reason:
            'Rebuilt for the upload, then removed again — leaving it would '
            'undo the reclamation that deleted it and keep the data readable.',
      );
    });

    test(
      'a jsonPath that escapes the documents directory is refused',
      () async {
        // jsonPath arrives on synced messages, so it is untrusted, and joinAll
        // drops empty segments but keeps '..'. The restore path *writes*, so
        // an escaping path would create a file outside the documents
        // directory — which is why the target must NOT exist beforehand.
        final outside = File('${documentsDirectory.parent.path}/escaped.json');
        expect(outside.existsSync(), isFalse);
        addTearDown(() {
          if (outside.existsSync()) outside.deleteSync();
        });

        final result = await payloadSender.enrichAndUploadAgentPayload(
          room: room,
          message: SyncMessage.agentEntity(
            agentEntity: makeTestCapture(id: 'entity-esc'),
            jsonPath: '/../escaped.json',
            status: SyncEntryStatus.update,
          ),
        );

        expect(result, isNull);
        expect(
          outside.existsSync(),
          isFalse,
          reason: 'The restore must not write outside the documents directory.',
        );
      },
    );

    test('a failed upload does not leave the rebuilt file behind', () async {
      // The row is retried, and the retry would find the file present, leave
      // restoredForThisSend false, and never remove it — so one failed attempt
      // would permanently undo the reclamation.
      final entity = makeTestCapture(id: 'entity-fail');
      final relativePath = relativeAgentEntityPath('entity-fail');
      final file = File('${documentsDirectory.path}$relativePath');
      expect(file.existsSync(), isFalse);

      when(
        () => room.sendFileEvent(
          any(),
          extraContent: any(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => null);

      final result = await payloadSender.enrichAndUploadAgentPayload(
        room: room,
        message: SyncMessage.agentEntity(
          agentEntity: entity,
          jsonPath: relativePath,
          status: SyncEntryStatus.update,
        ),
      );

      expect(result, isNull);
      expect(file.existsSync(), isFalse);
    });

    test('a sidecar it did not rebuild is left alone', () async {
      final entity = makeTestCapture(id: 'entity-2');
      final relativePath = relativeAgentEntityPath('entity-2');
      final file = File('${documentsDirectory.path}$relativePath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('{"already":"here"}');

      when(
        () => room.sendFileEvent(
          any(),
          extraContent: any(named: 'extraContent'),
        ),
      ).thenAnswer((_) async => 'evt-2');

      await payloadSender.enrichAndUploadAgentPayload(
        room: room,
        message: SyncMessage.agentEntity(
          agentEntity: entity,
          jsonPath: relativePath,
          status: SyncEntryStatus.update,
        ),
      );

      expect(
        file.existsSync(),
        isTrue,
        reason: 'The normal path must not start deleting live sidecars.',
      );
    });

    test(
      'uploads the claimed inline generation when the sidecar is newer',
      () async {
        final claimed = makeTestCapture(
          id: 'entity-race',
          transcript: 'claimed generation',
          vectorClock: const VectorClock({'host-A': 3}),
        );
        final newer = makeTestCapture(
          id: 'entity-race',
          transcript: 'newer sidecar generation',
          vectorClock: const VectorClock({'host-A': 30}),
        );
        final relativePath = relativeAgentEntityPath('entity-race');
        final sidecar = File('${documentsDirectory.path}$relativePath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(newer.toJson()));

        MatrixFile? uploadedFile;
        when(
          () => room.sendFileEvent(
            any<MatrixFile>(),
            extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
          ),
        ).thenAnswer((invocation) async {
          uploadedFile = invocation.positionalArguments.single as MatrixFile;
          return 'claimed-generation-event';
        });

        final result = await payloadSender.enrichAndUploadAgentPayload(
          room: room,
          message: SyncMessage.agentEntity(
            agentEntity: claimed,
            jsonPath: relativePath,
            status: SyncEntryStatus.update,
          ),
        );

        expect(result, isA<SyncAgentEntity>());
        final envelope = result! as SyncAgentEntity;
        expect(envelope.attachmentEventId, 'claimed-generation-event');
        final uploaded = AgentDomainEntity.fromJson(
          jsonDecode(utf8.decode(gzip.decode(uploadedFile!.bytes)))
              as Map<String, dynamic>,
        );
        expect(uploaded, claimed);
        expect(
          AgentDomainEntity.fromJson(
            jsonDecode(sidecar.readAsStringSync()) as Map<String, dynamic>,
          ),
          newer,
          reason: 'The send must not rewrite the newer canonical sidecar.',
        );
      },
    );
  });
}
