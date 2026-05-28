// ignore_for_file: cascade_invocations

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/smart_journal_entity_loader.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  String stripLeadingSlashes(String s) =>
      s.replaceFirst(RegExp(r'^[\\/]+'), '');

  late MockLoggingService loggingService;

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(Uri.parse('mxc://placeholder'));
  });

  group('SmartJournalEntityLoader media ensure', () {
    late Directory tempDir;

    setUp(() async {
      loggingService = MockLoggingService();
      stubLoggingService(loggingService);
      await getIt.reset();
      getIt.allowReassignment = true;
      tempDir = await Directory.systemTemp.createTemp('smart_loader_test');
      getIt.registerSingleton<Directory>(tempDir);
    });

    tearDown(() async {
      await getIt.reset();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'fetches JSON when no VC and file missing via AttachmentIndex',
      () async {
        const relJson = '/text_entries/2024-01-01/abc.text.json';
        final index = AttachmentIndex();
        final ev = MockEvent();
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final entity = JournalEntry(
          meta: Metadata(
            id: 'abc',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          entryText: const EntryText(plainText: 'hello'),
        );
        final jsonBytes = utf8.encode(jsonEncode(entity.toJson()));
        when(ev.downloadAndDecryptAttachment).thenAnswer(
          (_) async => MatrixFile(
            bytes: Uint8List.fromList(jsonBytes),
            name: 'abc.text.json',
          ),
        );
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );

        final loaded = await loader.load(jsonPath: relJson);
        expect(
          loaded.maybeMap(
            journalEntry: (j) => j.entryText?.plainText,
            orElse: () => null,
          ),
          'hello',
        );

        final docDir = getIt<Directory>().path;
        final normalized = stripLeadingSlashes(relJson);
        final f = File(path.join(docDir, normalized));
        expect(f.existsSync(), isTrue);
        expect(f.lengthSync(), greaterThan(0));
      },
    );

    test('fetches JSON when no VC and file exists but is empty', () async {
      const relJson = '/text_entries/2024-01-01/empty_file.text.json';
      final normalized = stripLeadingSlashes(relJson);
      final targetFile = File(path.join(tempDir.path, normalized));
      await targetFile.create(recursive: true);
      expect(targetFile.existsSync(), isTrue);
      expect(targetFile.lengthSync(), 0);

      final entity = JournalEntry(
        meta: Metadata(
          id: 'empty_file',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        entryText: const EntryText(plainText: 'refetched'),
      );
      final jsonBytes = utf8.encode(jsonEncode(entity.toJson()));

      final index = AttachmentIndex();
      final ev = MockEvent();
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content).thenReturn({'relativePath': relJson});
      when(ev.downloadAndDecryptAttachment).thenAnswer(
        (_) async => MatrixFile(
          bytes: Uint8List.fromList(jsonBytes),
          name: 'empty_file.text.json',
        ),
      );
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );

      final loaded = await loader.load(jsonPath: relJson);
      expect(
        loaded.maybeMap(
          journalEntry: (j) => j.entryText?.plainText,
          orElse: () => null,
        ),
        'refetched',
      );

      expect(targetFile.lengthSync(), greaterThan(0));
    });

    test('ensures missing image media via AttachmentIndex', () async {
      final image = JournalImage(
        meta: Metadata(
          id: 'img-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        data: ImageData(
          imageId: 'img-1',
          imageDirectory: '/images/2024-01-01/',
          imageFile: 'picture.jpg',
          capturedAt: DateTime(2024, 3, 15),
        ),
      );
      final relJson = '${getRelativeImagePath(image)}.json';
      final jsonPathImg = path.join(tempDir.path, stripLeadingSlashes(relJson));
      final jsonFile = File(jsonPathImg);
      await jsonFile.create(recursive: true);
      await jsonFile.writeAsString(jsonEncode(image.toJson()));

      final relMedia = getRelativeImagePath(image);
      final mediaPathImg = path.join(
        tempDir.path,
        stripLeadingSlashes(relMedia),
      );
      final mediaFile = File(mediaPathImg);
      expect(mediaFile.existsSync(), isFalse);

      final index = AttachmentIndex();
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('evt-img-empty');
      when(() => ev.attachmentMimetype).thenReturn('image/jpeg');
      when(() => ev.content).thenReturn({'relativePath': relMedia});
      when(ev.downloadAndDecryptAttachment).thenAnswer(
        (_) async => MatrixFile(
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'picture.jpg',
        ),
      );
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      final loaded = await loader.load(jsonPath: relJson);

      expect(loaded.meta.id, 'img-1');
      expect(mediaFile.existsSync(), isTrue);
      expect(mediaFile.lengthSync(), greaterThan(0));
      verify(ev.downloadAndDecryptAttachment).called(1);
    });

    test(
      'image media ensure logs and registers pending on empty bytes',
      () async {
        final fixedDate = DateTime(2024, 3, 15);
        final image = JournalImage(
          meta: Metadata(
            id: 'img-empty',
            createdAt: fixedDate,
            updatedAt: fixedDate,
            dateFrom: fixedDate,
            dateTo: fixedDate,
          ),
          data: ImageData(
            imageId: 'img-empty',
            imageDirectory: '/images/2024-01-01/',
            imageFile: 'empty.jpg',
            capturedAt: fixedDate,
          ),
        );
        final relJson = '${getRelativeImagePath(image)}.json';
        final jsonPathImg = path.join(
          tempDir.path,
          stripLeadingSlashes(relJson),
        );
        File(jsonPathImg)
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(image.toJson()));

        final relMedia = getRelativeImagePath(image);
        final index = AttachmentIndex();
        final ev = MockEvent();
        when(() => ev.attachmentMimetype).thenReturn('image/jpeg');
        when(() => ev.content).thenReturn({'relativePath': relMedia});
        when(
          ev.downloadAndDecryptAttachment,
        ).thenAnswer((_) async => MatrixFile(bytes: Uint8List(0), name: 'x'));
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );
        String? pendingPath;
        loader.onMissingDescriptorPath = (path) => pendingPath = path;
        final loaded = await loader.load(jsonPath: relJson);
        expect(loaded.meta.id, image.meta.id);
        expect(pendingPath, relMedia);
        verify(
          () => loggingService.captureException(
            any<Object>(),
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetchMedia',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test('purges cached media and retries after empty bytes', () async {
      final fixedDate = DateTime(2024, 3, 15);
      final image = JournalImage(
        meta: Metadata(
          id: 'img-empty-retry',
          createdAt: fixedDate,
          updatedAt: fixedDate,
          dateFrom: fixedDate,
          dateTo: fixedDate,
        ),
        data: ImageData(
          imageId: 'img-empty-retry',
          imageDirectory: '/images/2024-01-01/',
          imageFile: 'retry.jpg',
          capturedAt: fixedDate,
        ),
      );
      final relJson = '${getRelativeImagePath(image)}.json';
      final jsonPathImg = path.join(
        tempDir.path,
        stripLeadingSlashes(relJson),
      );
      File(jsonPathImg)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(image.toJson()));

      final relMedia = getRelativeImagePath(image);
      final mediaFile = File(
        path.join(tempDir.path, stripLeadingSlashes(relMedia)),
      );
      final index = AttachmentIndex();
      final ev = MockEvent();
      final room = MockRoom();
      final client = MockMatrixClient();
      final database = MockMatrixDatabase();
      final mediaUri = Uri.parse('mxc://server/img-empty-retry');
      when(() => ev.eventId).thenReturn('evt-img-empty-retry');
      when(() => ev.attachmentMimetype).thenReturn('image/jpeg');
      when(() => ev.content).thenReturn({'relativePath': relMedia});
      when(() => ev.room).thenReturn(room);
      when(() => room.client).thenReturn(client);
      when(() => client.database).thenReturn(database);
      when(ev.attachmentOrThumbnailMxcUrl).thenReturn(mediaUri);
      when(() => database.deleteFile(mediaUri)).thenAnswer((_) async => true);
      var downloads = 0;
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
        downloads++;
        return MatrixFile(
          bytes: downloads == 1 ? Uint8List(0) : Uint8List.fromList([1, 2, 3]),
          name: 'retry.jpg',
        );
      });
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      final loaded = await loader.load(jsonPath: relJson);

      expect(loaded.meta.id, image.meta.id);
      expect(downloads, 2);
      expect(mediaFile.existsSync(), isTrue);
      verify(() => database.deleteFile(mediaUri)).called(1);
      verify(
        () => loggingService.captureEvent(
          contains('smart.media.empty_bytes.refresh path=$relMedia'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetchMedia',
        ),
      ).called(1);
    });

    test(
      'media empty-bytes retry surfaces error when deleteFile on the cached '
      'MXC throws — purge cannot recover, so the second attempt is skipped '
      'and the empty-bytes failure is logged through the purge subDomain',
      () async {
        final fixedDate = DateTime(2024, 3, 15);
        final image = JournalImage(
          meta: Metadata(
            id: 'img-delete-throws',
            createdAt: fixedDate,
            updatedAt: fixedDate,
            dateFrom: fixedDate,
            dateTo: fixedDate,
          ),
          data: ImageData(
            imageId: 'img-delete-throws',
            imageDirectory: '/images/2024-01-01/',
            imageFile: 'delete_throws.jpg',
            capturedAt: fixedDate,
          ),
        );
        final relJson = '${getRelativeImagePath(image)}.json';
        final jsonPathImg = path.join(
          tempDir.path,
          stripLeadingSlashes(relJson),
        );
        File(jsonPathImg)
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(image.toJson()));

        final relMedia = getRelativeImagePath(image);
        final index = AttachmentIndex();
        final ev = MockEvent();
        final room = MockRoom();
        final client = MockMatrixClient();
        final database = MockMatrixDatabase();
        final mediaUri = Uri.parse('mxc://server/img-delete-throws');
        when(() => ev.eventId).thenReturn('evt-img-delete-throws');
        when(() => ev.attachmentMimetype).thenReturn('image/jpeg');
        when(() => ev.content).thenReturn({'relativePath': relMedia});
        when(() => ev.room).thenReturn(room);
        when(() => room.client).thenReturn(client);
        when(() => client.database).thenReturn(database);
        when(ev.attachmentOrThumbnailMxcUrl).thenReturn(mediaUri);
        when(
          () => database.deleteFile(mediaUri),
        ).thenThrow(Exception('db purge failed'));
        var downloads = 0;
        when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
          downloads++;
          return MatrixFile(bytes: Uint8List(0), name: 'delete_throws.jpg');
        });
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );
        String? pendingPath;
        loader.onMissingDescriptorPath = (path) => pendingPath = path;
        await loader.load(jsonPath: relJson);

        // First download empty → purge throws → purged=false → outer catch
        // surfaces the empty-bytes error without a second download attempt.
        expect(downloads, 1);
        expect(pendingPath, relMedia);
        verify(
          () => loggingService.captureException(
            any<Object>(),
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetchMedia.purge',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test(
      'media empty-bytes retry surfaces error when second download is still '
      'empty — purge succeeded but a refresh did not repopulate the bytes',
      () async {
        final fixedDate = DateTime(2024, 3, 15);
        final image = JournalImage(
          meta: Metadata(
            id: 'img-empty-twice',
            createdAt: fixedDate,
            updatedAt: fixedDate,
            dateFrom: fixedDate,
            dateTo: fixedDate,
          ),
          data: ImageData(
            imageId: 'img-empty-twice',
            imageDirectory: '/images/2024-01-01/',
            imageFile: 'empty_twice.jpg',
            capturedAt: fixedDate,
          ),
        );
        final relJson = '${getRelativeImagePath(image)}.json';
        final jsonPathImg = path.join(
          tempDir.path,
          stripLeadingSlashes(relJson),
        );
        File(jsonPathImg)
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(image.toJson()));

        final relMedia = getRelativeImagePath(image);
        final index = AttachmentIndex();
        final ev = MockEvent();
        final room = MockRoom();
        final client = MockMatrixClient();
        final database = MockMatrixDatabase();
        final mediaUri = Uri.parse('mxc://server/img-empty-twice');
        when(() => ev.eventId).thenReturn('evt-img-empty-twice');
        when(() => ev.attachmentMimetype).thenReturn('image/jpeg');
        when(() => ev.content).thenReturn({'relativePath': relMedia});
        when(() => ev.room).thenReturn(room);
        when(() => room.client).thenReturn(client);
        when(() => client.database).thenReturn(database);
        when(ev.attachmentOrThumbnailMxcUrl).thenReturn(mediaUri);
        when(
          () => database.deleteFile(mediaUri),
        ).thenAnswer((_) async => true);
        var downloads = 0;
        when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
          downloads++;
          return MatrixFile(bytes: Uint8List(0), name: 'empty_twice.jpg');
        });
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );
        String? pendingPath;
        loader.onMissingDescriptorPath = (path) => pendingPath = path;
        await loader.load(jsonPath: relJson);

        expect(downloads, 2);
        expect(pendingPath, relMedia);
        // Both attempts saw empty bytes → purge runs twice.
        verify(() => database.deleteFile(mediaUri)).called(2);
        verify(
          () => loggingService.captureException(
            any<Object>(
              that: isA<FileSystemException>().having(
                (e) => e.message,
                'message',
                contains('empty attachment bytes'),
              ),
            ),
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetchMedia',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
        verify(
          () => loggingService.captureEvent(
            contains('smart.media.empty_bytes.refresh path=$relMedia'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetchMedia',
          ),
        ).called(1);
      },
    );

    test('no-VC JSON fetch logs and throws on empty bytes', () async {
      const relJson = '/text_entries/2024-02-01/empty.text.json';
      final index = AttachmentIndex();
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('evt-json-empty');
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content).thenReturn({'relativePath': relJson});
      when(
        ev.downloadAndDecryptAttachment,
      ).thenAnswer((_) async => MatrixFile(bytes: Uint8List(0), name: 'x'));
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      await expectLater(
        loader.load(jsonPath: relJson),
        throwsA(isA<FileSystemException>()),
      );
      verify(
        () => loggingService.captureException(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetchJson.noVc',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test(
      'loads entity and registers pending image media when descriptor not indexed',
      () async {
        final fixedDate = DateTime(2024, 3, 15);
        final image = JournalImage(
          meta: Metadata(
            id: 'img-2',
            createdAt: fixedDate,
            updatedAt: fixedDate,
            dateFrom: fixedDate,
            dateTo: fixedDate,
          ),
          data: ImageData(
            imageId: 'img-2',
            imageDirectory: '/images/2024-01-01/',
            imageFile: 'missing.jpg',
            capturedAt: fixedDate,
          ),
        );
        final relJson = '${getRelativeImagePath(image)}.json';
        final jsonPathMissing = path.join(
          tempDir.path,
          stripLeadingSlashes(relJson),
        );
        final createdJson = File(jsonPathMissing)
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(image.toJson()));
        expect(createdJson.existsSync(), isTrue);

        final index = AttachmentIndex(logging: loggingService);
        String? pendingPath;
        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );
        loader.onMissingDescriptorPath = (path) => pendingPath = path;
        final loaded = await loader.load(jsonPath: relJson);
        expect(loaded.meta.id, image.meta.id);
        expect(pendingPath, getRelativeImagePath(image));
        verify(
          () => loggingService.captureEvent(
            contains('smart.media.miss path=${getRelativeImagePath(image)}'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetchMedia',
          ),
        ).called(1);
      },
    );

    test(
      'logs SmartLoader.localRead on non-FileSystemException local failure',
      () async {
        // Write a malformed JSON file so readEntityFromJson throws a
        // FormatException (not a FileSystemException) — that takes the
        // generic catch branch in load(), which logs to SmartLoader.localRead.
        const relJson = '/text_entries/2024-01-01/corrupt.text.json';
        final normalized = stripLeadingSlashes(relJson);
        final f = File(path.join(tempDir.path, normalized));
        await f.create(recursive: true);
        await f.writeAsString('{this is not json');

        final index = AttachmentIndex();
        final ev = MockEvent();
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final replacement = JournalEntry(
          meta: Metadata(
            id: 'corrupt',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            vectorClock: const VectorClock({'n': 1}),
          ),
          entryText: const EntryText(plainText: 'recovered'),
        );
        when(ev.downloadAndDecryptAttachment).thenAnswer(
          (_) async => MatrixFile(
            bytes: Uint8List.fromList(
              jsonEncode(replacement.toJson()).codeUnits,
            ),
            name: 'corrupt.text.json',
          ),
        );
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );

        final loaded = await loader.load(
          jsonPath: relJson,
          incomingVectorClock: const VectorClock({'n': 1}),
        );

        expect(loaded.meta.id, 'corrupt');
        verify(
          () => loggingService.captureException(
            any<Object>(),
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.localRead',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test(
      'no-VC path: throws and logs smart.fetch.miss(noVc) when descriptor not indexed',
      () async {
        const relJson = '/text_entries/2024-01-01/no_descriptor.text.json';
        final index = AttachmentIndex(logging: loggingService);
        when(
          () => loggingService.captureEvent(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );

        await expectLater(
          loader.load(jsonPath: relJson),
          throwsA(isA<FileSystemException>()),
        );
        verify(
          () => loggingService.captureEvent(
            contains('smart.fetch.miss(noVc) path=$relJson'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetch',
          ),
        ).called(1);
      },
    );

    test(
      'skips media fetch when image file already exists with content',
      () async {
        final fixedDate = DateTime(2024, 3, 15);
        final image = JournalImage(
          meta: Metadata(
            id: 'img-present',
            createdAt: fixedDate,
            updatedAt: fixedDate,
            dateFrom: fixedDate,
            dateTo: fixedDate,
          ),
          data: ImageData(
            imageId: 'img-present',
            imageDirectory: '/images/2024-01-01/',
            imageFile: 'present.jpg',
            capturedAt: fixedDate,
          ),
        );
        final relJson = '${getRelativeImagePath(image)}.json';
        File(path.join(tempDir.path, stripLeadingSlashes(relJson)))
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(image.toJson()));

        // Pre-create the media file with real content so the early-return
        // branch in _ensureMediaFile fires (lengthSync > 0).
        final relMedia = getRelativeImagePath(image);
        final mediaFile =
            File(
                path.join(tempDir.path, stripLeadingSlashes(relMedia)),
              )
              ..createSync(recursive: true)
              ..writeAsBytesSync([1, 2, 3, 4]);

        final index = AttachmentIndex();
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-img-present');
        when(() => ev.attachmentMimetype).thenReturn('image/jpeg');
        when(() => ev.content).thenReturn({'relativePath': relMedia});
        when(ev.downloadAndDecryptAttachment).thenAnswer(
          (_) async => MatrixFile(
            bytes: Uint8List.fromList([9, 9, 9]),
            name: 'present.jpg',
          ),
        );
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );

        final loaded = await loader.load(jsonPath: relJson);

        expect(loaded.meta.id, 'img-present');
        expect(mediaFile.lengthSync(), 4); // unchanged
        verifyNever(ev.downloadAndDecryptAttachment);
      },
    );

    test('ensures missing audio media via AttachmentIndex', () async {
      final audio = JournalAudio(
        meta: Metadata(
          id: 'aud-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        data: AudioData(
          audioDirectory: '/audio/2024-01-01/',
          audioFile: 'clip.aac',
          duration: const Duration(seconds: 1),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
      );
      final relJson = '${AudioUtils.getRelativeAudioPath(audio)}.json';
      final jsonPathAud = path.join(tempDir.path, stripLeadingSlashes(relJson));
      File(jsonPathAud)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(audio.toJson()));

      final relMedia = AudioUtils.getRelativeAudioPath(audio);
      final mediaPathAud = path.join(
        tempDir.path,
        stripLeadingSlashes(relMedia),
      );
      final mediaFile = File(mediaPathAud);
      expect(mediaFile.existsSync(), isFalse);

      final index = AttachmentIndex();
      final ev = MockEvent();
      when(() => ev.attachmentMimetype).thenReturn('audio/aac');
      when(() => ev.content).thenReturn({'relativePath': relMedia});
      when(ev.downloadAndDecryptAttachment).thenAnswer(
        (_) async => MatrixFile(
          bytes: Uint8List.fromList([9, 9, 9]),
          name: 'clip.aac',
        ),
      );
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      final loaded = await loader.load(jsonPath: relJson);

      expect(loaded.meta.id, 'aud-1');
      expect(mediaFile.existsSync(), isTrue);
      expect(mediaFile.lengthSync(), greaterThan(0));
      verify(ev.downloadAndDecryptAttachment).called(1);
    });

    test('returns local entity when incoming VC is equal or older', () async {
      const localVc = VectorClock({'a': 2});
      final entity = JournalEntry(
        meta: Metadata(
          id: 'vc-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          vectorClock: localVc,
        ),
        entryText: const EntryText(plainText: 'local'),
      );
      const relJson = '/text_entries/2024-01-01/vc-1.text.json';
      final jsonPath = path.join(tempDir.path, stripLeadingSlashes(relJson));
      File(jsonPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(entity.toJson()));

      final index = AttachmentIndex();
      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );

      final loaded = await loader.load(
        jsonPath: relJson,
        incomingVectorClock: const VectorClock({'a': 2}),
      );
      expect(
        loaded.maybeMap(
          journalEntry: (j) => j.entryText?.plainText,
          orElse: () => null,
        ),
        'local',
      );
    });

    test('VC path: index miss throws and logs fetch.miss', () async {
      const relJson = '/text_entries/2024-01-01/missing.text.json';
      final index = AttachmentIndex(logging: loggingService);
      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      when(
        () => loggingService.captureEvent(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});
      await expectLater(
        loader.load(
          jsonPath: relJson,
          incomingVectorClock: const VectorClock({'n': 1}),
        ),
        throwsA(isA<FileSystemException>()),
      );
      verify(
        () => loggingService.captureEvent(
          contains('smart.fetch.miss path=$relJson'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('purges cached descriptor and refreshes stale download', () async {
      const relJson = '/text_entries/2024-01-01/stale.text.json';
      final index = AttachmentIndex(logging: loggingService);
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('evt-stale');
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content).thenReturn({'relativePath': relJson});
      final room = MockRoom();
      final client = MockMatrixClient();
      final database = MockMatrixDatabase();
      when(() => ev.room).thenReturn(room);
      when(() => room.client).thenReturn(client);
      when(() => client.database).thenReturn(database);
      final descriptorUri = Uri.parse('mxc://server/file');
      when(ev.attachmentOrThumbnailMxcUrl).thenReturn(descriptorUri);
      when(
        () => database.deleteFile(descriptorUri),
      ).thenAnswer((_) async => true);

      final stale = JournalEntry(
        meta: Metadata(
          id: 'stale-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'n': 1}),
        ),
        entryText: const EntryText(plainText: 'old'),
      );
      final fresh = JournalEntry(
        meta: Metadata(
          id: stale.meta.id,
          createdAt: stale.meta.createdAt,
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: stale.meta.dateFrom,
          dateTo: stale.meta.dateTo,
          vectorClock: const VectorClock({'n': 2}),
        ),
        entryText: const EntryText(plainText: 'fresh'),
      );
      final staleBytes = Uint8List.fromList(
        jsonEncode(stale.toJson()).codeUnits,
      );
      final freshBytes = Uint8List.fromList(
        jsonEncode(fresh.toJson()).codeUnits,
      );
      var calls = 0;
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
        calls++;
        return MatrixFile(
          bytes: calls == 1 ? staleBytes : freshBytes,
          name: 'entry.json',
        );
      });
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      var purges = 0;
      loader.onCachePurge = () => purges++;

      final loaded = await loader.load(
        jsonPath: relJson,
        incomingVectorClock: const VectorClock({'n': 2}),
      );

      expect(loaded.meta.id, fresh.meta.id);
      expect(calls, 2);
      verify(() => database.deleteFile(descriptorUri)).called(1);
      expect(purges, 1);
      verify(
        () => loggingService.captureEvent(
          contains('smart.fetch.stale_vc path=$relJson'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
      verify(
        () => loggingService.captureEvent(
          contains('smart.fetch.stale_vc.refresh path=$relJson'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
      final saved = File(
        path.join(
          getIt<Directory>().path,
          stripLeadingSlashes(relJson),
        ),
      );
      expect(saved.existsSync(), isTrue);
    });

    test('purges cached descriptor and retries after empty bytes', () async {
      const relJson = '/text_entries/2024-01-01/empty_first.text.json';
      final index = AttachmentIndex(logging: loggingService);
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('evt-empty-first');
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content).thenReturn({'relativePath': relJson});
      final room = MockRoom();
      final client = MockMatrixClient();
      final database = MockMatrixDatabase();
      final descriptorUri = Uri.parse('mxc://server/empty-first');
      when(() => ev.room).thenReturn(room);
      when(() => room.client).thenReturn(client);
      when(() => client.database).thenReturn(database);
      when(ev.attachmentOrThumbnailMxcUrl).thenReturn(descriptorUri);
      when(
        () => database.deleteFile(descriptorUri),
      ).thenAnswer((_) async => true);

      final fresh = JournalEntry(
        meta: Metadata(
          id: 'empty-first',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'n': 2}),
        ),
        entryText: const EntryText(plainText: 'fresh after empty'),
      );
      var downloads = 0;
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
        downloads++;
        return MatrixFile(
          bytes: downloads == 1
              ? Uint8List(0)
              : Uint8List.fromList(jsonEncode(fresh.toJson()).codeUnits),
          name: 'entry.json',
        );
      });
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      var purges = 0;
      loader.onCachePurge = () => purges++;

      final loaded = await loader.load(
        jsonPath: relJson,
        incomingVectorClock: const VectorClock({'n': 2}),
      );

      expect(loaded.meta.id, fresh.meta.id);
      expect(downloads, 2);
      expect(purges, 1);
      verify(() => database.deleteFile(descriptorUri)).called(1);
      verify(
        () => loggingService.captureEvent(
          contains('smart.fetch.empty_bytes.refresh path=$relJson'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('throws when descriptor remains stale after refresh', () async {
      const relJson = '/text_entries/2024-01-01/staler.text.json';
      final index = AttachmentIndex(logging: loggingService);
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('evt-staler');
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content).thenReturn({'relativePath': relJson});
      final room = MockRoom();
      final client = MockMatrixClient();
      final database = MockMatrixDatabase();
      when(() => ev.room).thenReturn(room);
      when(() => room.client).thenReturn(client);
      when(() => client.database).thenReturn(database);
      final descriptorUri = Uri.parse('mxc://server/old');
      when(ev.attachmentOrThumbnailMxcUrl).thenReturn(descriptorUri);
      when(
        () => database.deleteFile(descriptorUri),
      ).thenAnswer((_) async => true);

      final stale = JournalEntry(
        meta: Metadata(
          id: 'stale-2',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'n': 1}),
        ),
        entryText: const EntryText(plainText: 'older'),
      );
      final staleBytes = Uint8List.fromList(
        jsonEncode(stale.toJson()).codeUnits,
      );
      var calls = 0;
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
        calls++;
        return MatrixFile(bytes: staleBytes, name: 'entry.json');
      });
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      var purges = 0;
      loader.onCachePurge = () => purges++;

      await expectLater(
        () => loader.load(
          jsonPath: relJson,
          incomingVectorClock: const VectorClock({'n': 3}),
        ),
        throwsA(
          isA<FileSystemException>().having(
            (e) => e.message,
            'message',
            contains('after refresh'),
          ),
        ),
      );
      expect(calls, 2);
      expect(purges, 1);
      verify(
        () => loggingService.captureEvent(
          contains('smart.fetch.stale_vc.pending path=$relJson'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('trips circuit breaker after repeated stale descriptors', () async {
      const relJson = '/text_entries/2024-01-01/always_stale.text.json';
      final index = AttachmentIndex(logging: loggingService);
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('evt-stale-loop');
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content).thenReturn({'relativePath': relJson});
      final room = MockRoom();
      final client = MockMatrixClient();
      final database = MockMatrixDatabase();
      when(() => ev.room).thenReturn(room);
      when(() => room.client).thenReturn(client);
      when(() => client.database).thenReturn(database);
      final descriptorUri = Uri.parse('mxc://server/always-stale');
      when(ev.attachmentOrThumbnailMxcUrl).thenReturn(descriptorUri);
      when(
        () => database.deleteFile(descriptorUri),
      ).thenAnswer((_) async => true);
      when(
        () => loggingService.captureEvent(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});

      final stale = JournalEntry(
        meta: Metadata(
          id: 'stale-loop',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'n': 1}),
        ),
        entryText: const EntryText(plainText: 'stale'),
      );
      final staleBytes = Uint8List.fromList(
        jsonEncode(stale.toJson()).codeUnits,
      );
      var downloads = 0;
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
        downloads++;
        return MatrixFile(
          bytes: staleBytes,
          name: 'entry.json',
        );
      });
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      var purges = 0;
      loader.onCachePurge = () => purges++;

      Future<void> attemptLoad() => loader.load(
        jsonPath: relJson,
        incomingVectorClock: const VectorClock({'n': 3}),
      );

      await expectLater(attemptLoad(), throwsA(isA<FileSystemException>()));
      await expectLater(attemptLoad(), throwsA(isA<FileSystemException>()));
      await expectLater(
        attemptLoad(),
        throwsA(
          isA<FileSystemException>().having(
            (error) => error.message,
            'message',
            contains('circuit breaker'),
          ),
        ),
      );

      expect(downloads, 5);
      expect(purges, 2);
      verify(() => database.deleteFile(descriptorUri)).called(2);
      verify(
        () => loggingService.captureEvent(
          contains('smart.fetch.stale_vc.breaker path=$relJson'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    group('SmartLoader circuit breaker cleanup -', () {
      test(
        'clears failure count on success after prior stale retries',
        () async {
          const relJson = '/text_entries/2024-01-01/reset.text.json';
          final index = AttachmentIndex(logging: loggingService);
          final ev = MockEvent();
          when(() => ev.eventId).thenReturn('evt-reset');
          when(() => ev.attachmentMimetype).thenReturn('application/json');
          when(() => ev.content).thenReturn({'relativePath': relJson});
          final room = MockRoom();
          final client = MockMatrixClient();
          final database = MockMatrixDatabase();
          when(() => ev.room).thenReturn(room);
          when(() => room.client).thenReturn(client);
          when(() => client.database).thenReturn(database);
          final descriptorUri = Uri.parse('mxc://server/reset');
          when(ev.attachmentOrThumbnailMxcUrl).thenReturn(descriptorUri);
          when(
            () => database.deleteFile(descriptorUri),
          ).thenAnswer((_) async => true);
          when(
            () => loggingService.captureEvent(
              any<Object>(),
              domain: any(named: 'domain'),
              subDomain: any(named: 'subDomain'),
            ),
          ).thenAnswer((_) {});

          final staleOne = JournalEntry(
            meta: Metadata(
              id: 'reset',
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              vectorClock: const VectorClock({'n': 1}),
            ),
            entryText: const EntryText(plainText: 'stale-1'),
          );
          final freshOne = staleOne.copyWith(
            entryText: const EntryText(plainText: 'fresh-1'),
            meta: staleOne.meta.copyWith(
              vectorClock: const VectorClock({'n': 2}),
              updatedAt: DateTime(2024, 3, 15),
            ),
          );
          final staleTwo = staleOne.copyWith(
            entryText: const EntryText(plainText: 'stale-2'),
            meta: staleOne.meta.copyWith(
              vectorClock: const VectorClock({'n': 2}),
              updatedAt: DateTime(2024, 3, 15),
            ),
          );
          final freshTwo = staleOne.copyWith(
            entryText: const EntryText(plainText: 'fresh-2'),
            meta: staleOne.meta.copyWith(
              vectorClock: const VectorClock({'n': 3}),
              updatedAt: DateTime(2024, 3, 15),
            ),
          );

          var downloads = 0;
          when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
            downloads++;
            final entry = switch (downloads) {
              1 => staleOne,
              2 => freshOne,
              3 => staleTwo,
              _ => freshTwo,
            };
            return MatrixFile(
              bytes: Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
              name: 'entry.json',
            );
          });
          index.record(ev);

          final loader = SmartJournalEntityLoader(
            attachmentIndex: index,
            loggingService: loggingService,
          );
          var purges = 0;
          loader.onCachePurge = () => purges++;

          final first = await loader.load(
            jsonPath: relJson,
            incomingVectorClock: const VectorClock({'n': 2}),
          );
          expect(first.entryText?.plainText, 'fresh-1');

          final second = await loader.load(
            jsonPath: relJson,
            incomingVectorClock: const VectorClock({'n': 3}),
          );
          expect(second.entryText?.plainText, 'fresh-2');

          expect(downloads, 4);
          expect(purges, 2);
          verify(() => database.deleteFile(descriptorUri)).called(2);
        },
      );

      test('maintains separate failure counts by jsonPath', () async {
        const relJsonA = '/text_entries/2024-01-01/a.text.json';
        const relJsonB = '/text_entries/2024-01-01/b.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final evA = MockEvent();
        final evB = MockEvent();
        when(() => evA.eventId).thenReturn('evt-a');
        when(() => evB.eventId).thenReturn('evt-b');
        when(() => evA.attachmentMimetype).thenReturn('application/json');
        when(() => evB.attachmentMimetype).thenReturn('application/json');
        when(() => evA.content).thenReturn({'relativePath': relJsonA});
        when(() => evB.content).thenReturn({'relativePath': relJsonB});
        final roomA = MockRoom();
        final roomB = MockRoom();
        final clientA = MockMatrixClient();
        final clientB = MockMatrixClient();
        final database = MockMatrixDatabase();
        when(() => evA.room).thenReturn(roomA);
        when(() => roomA.client).thenReturn(clientA);
        when(() => clientA.database).thenReturn(database);
        when(() => evB.room).thenReturn(roomB);
        when(() => roomB.client).thenReturn(clientB);
        when(() => clientB.database).thenReturn(database);
        final uriA = Uri.parse('mxc://server/a');
        final uriB = Uri.parse('mxc://server/b');
        when(evA.attachmentOrThumbnailMxcUrl).thenReturn(uriA);
        when(evB.attachmentOrThumbnailMxcUrl).thenReturn(uriB);
        when(() => database.deleteFile(uriA)).thenAnswer((_) async => true);
        when(() => database.deleteFile(uriB)).thenAnswer((_) async => true);
        when(
          () => loggingService.captureEvent(
            any<Object>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});

        JournalEntry buildEntry(String id, int clock, String text) {
          return JournalEntry(
            meta: Metadata(
              id: id,
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              vectorClock: VectorClock({'n': clock}),
            ),
            entryText: EntryText(plainText: text),
          );
        }

        var downloadsA = 0;
        when(evA.downloadAndDecryptAttachment).thenAnswer((_) async {
          downloadsA++;
          final entry = downloadsA == 1
              ? buildEntry('a', 1, 'stale-a')
              : buildEntry('a', 2, 'fresh-a');
          return MatrixFile(
            bytes: Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
            name: 'a.json',
          );
        });

        var downloadsB = 0;
        when(evB.downloadAndDecryptAttachment).thenAnswer((_) async {
          downloadsB++;
          final entry = downloadsB == 1
              ? buildEntry('b', 1, 'stale-b')
              : buildEntry('b', 2, 'fresh-b');
          return MatrixFile(
            bytes: Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
            name: 'b.json',
          );
        });

        index
          ..record(evA)
          ..record(evB);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );
        var purges = 0;
        loader.onCachePurge = () => purges++;

        final loadedA = await loader.load(
          jsonPath: relJsonA,
          incomingVectorClock: const VectorClock({'n': 2}),
        );
        final loadedB = await loader.load(
          jsonPath: relJsonB,
          incomingVectorClock: const VectorClock({'n': 2}),
        );

        expect(loadedA.entryText?.plainText, 'fresh-a');
        expect(loadedB.entryText?.plainText, 'fresh-b');
        expect(purges, 2);
        verify(() => database.deleteFile(uriA)).called(1);
        verify(() => database.deleteFile(uriB)).called(1);
      });
    });

    group('SmartLoader cache purge edge cases -', () {
      test('onCachePurge not invoked when descriptor lacks MXC', () async {
        const relJson = '/text_entries/2024-01-01/no_mxc.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-no-mxc');
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final room = MockRoom();
        final client = MockMatrixClient();
        final database = MockMatrixDatabase();
        when(() => ev.room).thenReturn(room);
        when(() => room.client).thenReturn(client);
        when(() => client.database).thenReturn(database);
        when(ev.attachmentOrThumbnailMxcUrl).thenReturn(null);
        when(
          () => loggingService.captureEvent(
            any<Object>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});

        final stale = JournalEntry(
          meta: Metadata(
            id: 'no-mxc',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            vectorClock: const VectorClock({'n': 1}),
          ),
          entryText: const EntryText(plainText: 'stale'),
        );
        final fresh = stale.copyWith(
          entryText: const EntryText(plainText: 'fresh'),
          meta: stale.meta.copyWith(
            vectorClock: const VectorClock({'n': 2}),
            updatedAt: DateTime(2024, 3, 15),
          ),
        );
        var downloads = 0;
        when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
          downloads++;
          final entry = downloads == 1 ? stale : fresh;
          return MatrixFile(
            bytes: Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
            name: 'entry.json',
          );
        });
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );
        var purges = 0;
        loader.onCachePurge = () => purges++;

        final loaded = await loader.load(
          jsonPath: relJson,
          incomingVectorClock: const VectorClock({'n': 2}),
        );

        expect(loaded.entryText?.plainText, 'fresh');
        expect(purges, 0);
        verifyNever(() => database.deleteFile(any<Uri>()));
      });

      test('onCachePurge not invoked when deleteFile throws', () async {
        const relJson = '/text_entries/2024-01-01/delete_error.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-delete-error');
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final room = MockRoom();
        final client = MockMatrixClient();
        final database = MockMatrixDatabase();
        when(() => ev.room).thenReturn(room);
        when(() => room.client).thenReturn(client);
        when(() => client.database).thenReturn(database);
        final descriptorUri = Uri.parse('mxc://server/delete-error');
        when(ev.attachmentOrThumbnailMxcUrl).thenReturn(descriptorUri);
        when(
          () => database.deleteFile(descriptorUri),
        ).thenThrow(Exception('db failure'));
        when(
          () => loggingService.captureEvent(
            any<Object>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});
        when(
          () => loggingService.captureException(
            any<Object>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {});

        final stale = JournalEntry(
          meta: Metadata(
            id: 'delete-error',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            vectorClock: const VectorClock({'n': 1}),
          ),
          entryText: const EntryText(plainText: 'stale'),
        );
        final fresh = stale.copyWith(
          entryText: const EntryText(plainText: 'fresh'),
          meta: stale.meta.copyWith(
            vectorClock: const VectorClock({'n': 2}),
            updatedAt: DateTime(2024, 3, 15),
          ),
        );
        var downloads = 0;
        when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
          downloads++;
          final entry = downloads == 1 ? stale : fresh;
          return MatrixFile(
            bytes: Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
            name: 'entry.json',
          );
        });
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );
        var purges = 0;
        loader.onCachePurge = () => purges++;

        final loaded = await loader.load(
          jsonPath: relJson,
          incomingVectorClock: const VectorClock({'n': 2}),
        );

        expect(loaded.entryText?.plainText, 'fresh');
        expect(purges, 0);
        verify(() => database.deleteFile(descriptorUri)).called(1);
        verify(
          () => loggingService.captureException(
            any<Object>(),
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.purge',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('SmartLoader vector clock edge cases -', () {
      test(
        'succeeds when incoming VC is null but descriptor VC is present',
        () async {
          const relJson = '/text_entries/2024-01-02/vc_present.text.json';
          final index = AttachmentIndex(logging: loggingService);
          final ev = MockEvent();
          when(() => ev.eventId).thenReturn('evt-vc-present');
          when(() => ev.attachmentMimetype).thenReturn('application/json');
          when(() => ev.content).thenReturn({'relativePath': relJson});
          final entry = JournalEntry(
            meta: Metadata(
              id: 'vc-present',
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              vectorClock: const VectorClock({'n': 5}),
            ),
            entryText: const EntryText(plainText: 'descriptor with vc'),
          );
          when(ev.downloadAndDecryptAttachment).thenAnswer(
            (_) async => MatrixFile(
              bytes: Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
              name: 'entry.json',
            ),
          );
          index.record(ev);

          final loader = SmartJournalEntityLoader(
            attachmentIndex: index,
            loggingService: loggingService,
          );

          final loaded = await loader.load(jsonPath: relJson);
          expect(loaded.meta.vectorClock, const VectorClock({'n': 5}));
          expect(loaded.entryText?.plainText, 'descriptor with vc');
        },
      );

      test(
        'throws when descriptor lacks VC but incoming VC provided',
        () async {
          const relJson = '/text_entries/2024-01-03/missing_vc.text.json';
          final index = AttachmentIndex(logging: loggingService);
          final ev = MockEvent();
          when(() => ev.eventId).thenReturn('evt-missing-vc');
          when(() => ev.attachmentMimetype).thenReturn('application/json');
          when(() => ev.content).thenReturn({'relativePath': relJson});
          final entry = JournalEntry(
            meta: Metadata(
              id: 'missing-vc',
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
            ),
            entryText: const EntryText(plainText: 'descriptor missing vc'),
          );
          when(ev.downloadAndDecryptAttachment).thenAnswer(
            (_) async => MatrixFile(
              bytes: Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
              name: 'entry.json',
            ),
          );
          index.record(ev);

          final loader = SmartJournalEntityLoader(
            attachmentIndex: index,
            loggingService: loggingService,
          );

          await expectLater(
            loader.load(
              jsonPath: relJson,
              incomingVectorClock: const VectorClock({'n': 1}),
            ),
            throwsA(
              isA<FileSystemException>().having(
                (error) => error.message,
                'message',
                contains('missing attachment vector clock'),
              ),
            ),
          );
        },
      );

      test('succeeds when both incoming and descriptor VCs are null', () async {
        const relJson = '/text_entries/2024-01-04/both_null.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-both-null');
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final entry = JournalEntry(
          meta: Metadata(
            id: 'both-null',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          entryText: const EntryText(plainText: 'both null'),
        );
        when(ev.downloadAndDecryptAttachment).thenAnswer(
          (_) async => MatrixFile(
            bytes: Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
            name: 'entry.json',
          ),
        );
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );

        final loaded = await loader.load(jsonPath: relJson);
        expect(loaded.meta.vectorClock, isNull);
        expect(loaded.entryText?.plainText, 'both null');
      });
    });

    group('SmartLoader error handling -', () {
      test('throws when refreshed descriptor returns empty bytes', () async {
        const relJson = '/text_entries/2024-01-05/empty_second.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-empty-second');
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final room = MockRoom();
        final client = MockMatrixClient();
        final database = MockMatrixDatabase();
        when(() => ev.room).thenReturn(room);
        when(() => room.client).thenReturn(client);
        when(() => client.database).thenReturn(database);
        final descriptorUri = Uri.parse('mxc://server/empty-second');
        when(ev.attachmentOrThumbnailMxcUrl).thenReturn(descriptorUri);
        when(
          () => database.deleteFile(descriptorUri),
        ).thenAnswer((_) async => true);

        final stale = JournalEntry(
          meta: Metadata(
            id: 'empty-second',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            vectorClock: const VectorClock({'n': 1}),
          ),
          entryText: const EntryText(plainText: 'stale'),
        );

        var calls = 0;
        when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            return MatrixFile(
              bytes: Uint8List.fromList(jsonEncode(stale.toJson()).codeUnits),
              name: 'entry.json',
            );
          }
          return MatrixFile(bytes: Uint8List(0), name: 'entry.json');
        });
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );

        await expectLater(
          loader.load(
            jsonPath: relJson,
            incomingVectorClock: const VectorClock({'n': 2}),
          ),
          throwsA(
            isA<FileSystemException>().having(
              (error) => error.message,
              'message',
              contains('empty attachment bytes'),
            ),
          ),
        );
        verify(() => database.deleteFile(descriptorUri)).called(2);
        verify(
          () => loggingService.captureException(
            any<Object>(),
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetchJson',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      });

      test('logs and rethrows when descriptor JSON is invalid', () async {
        const relJson = '/text_entries/2024-01-06/invalid_json.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-invalid-json');
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final room = MockRoom();
        final client = MockMatrixClient();
        final database = MockMatrixDatabase();
        when(() => ev.room).thenReturn(room);
        when(() => room.client).thenReturn(client);
        when(() => client.database).thenReturn(database);
        when(
          ev.attachmentOrThumbnailMxcUrl,
        ).thenReturn(Uri.parse('mxc://server/invalid-json'));
        when(() => database.deleteFile(any())).thenAnswer((_) async => true);

        when(ev.downloadAndDecryptAttachment).thenAnswer(
          (_) async => MatrixFile(
            bytes: Uint8List.fromList('{not-json'.codeUnits),
            name: 'entry.json',
          ),
        );
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );

        await expectLater(
          loader.load(
            jsonPath: relJson,
            incomingVectorClock: const VectorClock({'n': 1}),
          ),
          throwsA(isA<FormatException>()),
        );
        verify(
          () => loggingService.captureException(
            any<Object>(),
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetchJson',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    test('no-VC path: does not fetch when file exists and non-empty', () async {
      const relJson = '/text_entries/2024-01-01/present.text.json';
      final entity = JournalEntry(
        meta: Metadata(
          id: 'present-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        entryText: const EntryText(plainText: 'present'),
      );
      final jsonPath = path.join(tempDir.path, stripLeadingSlashes(relJson));
      File(jsonPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(entity.toJson()));

      var downloads = 0;
      final index = AttachmentIndex();
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('evt-present');
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
        downloads++;
        return MatrixFile(bytes: Uint8List.fromList(const []), name: 'x');
      });
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content).thenReturn({'relativePath': relJson});
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      final loaded = await loader.load(jsonPath: relJson);
      expect(
        loaded.maybeMap(
          journalEntry: (j) => j.entryText?.plainText,
          orElse: () => null,
        ),
        'present',
      );
      expect(downloads, 0);
    });
  });
}
