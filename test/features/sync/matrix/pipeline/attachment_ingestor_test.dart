import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
import 'package:lotti/features/sync/matrix/pipeline/descriptor_catch_up_manager.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class MockEvent extends Mock implements Event {}

class MockDescriptorCatchUpManager extends Mock
    implements DescriptorCatchUpManager {}

class MockMatrixFile extends Mock implements MatrixFile {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  group('descriptor-only mode (no documentsDirectory)', () {
    test(
      'records descriptor, logs observe, updates metrics, and clears pending',
      () async {
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {});

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('e1');
        when(
          () => ev.content,
        ).thenReturn({'relativePath': '/p/a.bin', 'msgtype': 'm.file'});
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.senderId).thenReturn('@other:u');

        final index = AttachmentIndex(logging: logging);
        var liveScanCalls = 0;
        var retryNowCalls = 0;
        final desc = MockDescriptorCatchUpManager();
        when(() => desc.removeIfPresent('/p/a.bin')).thenReturn(true);

        // No documentsDirectory = descriptor-only mode
        final result = await AttachmentIngestor().process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () => liveScanCalls++,
          retryNow: () async => retryNowCalls++,
        );

        // No file written in descriptor-only mode
        expect(result, isFalse);
        // Logs emitted
        verify(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.observe',
          ),
        ).called(greaterThan(0));
        // Pending cleared triggers scan and retry (no media write here)
        expect(liveScanCalls, 1);
        expect(retryNowCalls, 1);
        // AttachmentIndex has the descriptor
        expect(index.find('/p/a.bin'), isNotNull);
      },
    );

    test(
      'no file written without documentsDirectory; clears pending',
      () async {
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {});

        final tmp = Directory.systemTemp.createTempSync('ingestor');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('e2');
        when(
          () => ev.content,
        ).thenReturn({'relativePath': '/media/x.jpg', 'msgtype': 'm.image'});
        when(() => ev.attachmentMimetype).thenReturn('image/jpeg');
        when(() => ev.senderId).thenReturn('@other:u');
        when(
          () => ev.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(2000));

        final index = AttachmentIndex(logging: logging);
        var liveScanCalls = 0;
        final desc = MockDescriptorCatchUpManager();
        when(() => desc.removeIfPresent('/media/x.jpg')).thenReturn(true);

        // No documentsDirectory = descriptor-only mode
        await AttachmentIngestor().process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () => liveScanCalls++,
          retryNow: () async {},
        );
        expect(liveScanCalls, 1); // schedule on descriptor removal only
        expect(File('${tmp.path}/media/x.jpg').existsSync(), isFalse);
      },
    );

    test('removeIfPresent false does not trigger scan/retry', () async {
      final logging = MockLoggingService();
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e5');
      when(() => ev.content).thenReturn({'relativePath': '/p/b.bin'});
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.senderId).thenReturn('@other:u');

      final index = AttachmentIndex();
      var liveScanCalls = 0;
      var retryNowCalls = 0;
      final desc = MockDescriptorCatchUpManager();
      when(() => desc.removeIfPresent('/p/b.bin')).thenReturn(false);

      await AttachmentIngestor().process(
        event: ev,
        logging: logging,
        attachmentIndex: index,
        descriptorCatchUp: desc,
        scheduleLiveScan: () => liveScanCalls++,
        retryNow: () async => retryNowCalls++,
      );

      expect(liveScanCalls, 0);
      expect(retryNowCalls, 0);
    });
  });

  group('queued download mode (scheduleDownload)', () {
    test('queues attachment download and writes file asynchronously', () async {
      final logging = MockLoggingService();
      when(
        () => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      final tmp = Directory.systemTemp.createTempSync('ingestor_queue');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final matrixFile = MockMatrixFile();
      when(
        () => matrixFile.bytes,
      ).thenReturn(Uint8List.fromList(utf8.encode('queued')));
      final downloadCompleter = Completer<MatrixFile>();

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e_queue');
      when(
        () => ev.content,
      ).thenReturn({'relativePath': '/data/queued.json', 'msgtype': 'm.file'});
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.senderId).thenReturn('@other:u');
      when(
        ev.downloadAndDecryptAttachment,
      ).thenAnswer((_) => downloadCompleter.future);

      final index = AttachmentIndex(logging: logging);
      final desc = MockDescriptorCatchUpManager();
      when(() => desc.removeIfPresent('/data/queued.json')).thenReturn(false);

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
        attachmentIndex: index,
        descriptorCatchUp: desc,
        scheduleLiveScan: () {},
        retryNow: () async {},
        scheduleDownload: true,
      );

      expect(result, isFalse);
      expect(File('${tmp.path}/data/queued.json').existsSync(), isFalse);

      downloadCompleter.complete(matrixFile);
      await ingestor.whenIdle();

      final writtenFile = File('${tmp.path}/data/queued.json');
      expect(writtenFile.existsSync(), isTrue);
      expect(writtenFile.readAsStringSync(), 'queued');
    });
  });

  group('eager download mode (with documentsDirectory)', () {
    test('downloads and writes attachment to disk', () async {
      final logging = MockLoggingService();
      when(
        () => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      final tmp = Directory.systemTemp.createTempSync('ingestor_eager');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final testContent = Uint8List.fromList(
        utf8.encode('test attachment content'),
      );
      final matrixFile = MockMatrixFile();
      when(() => matrixFile.bytes).thenReturn(testContent);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e10');
      when(
        () => ev.content,
      ).thenReturn({'relativePath': '/data/test.json', 'msgtype': 'm.file'});
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.senderId).thenReturn('@other:u');
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async => matrixFile);

      final index = AttachmentIndex(logging: logging);
      final desc = MockDescriptorCatchUpManager();
      when(() => desc.removeIfPresent('/data/test.json')).thenReturn(false);

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
        attachmentIndex: index,
        descriptorCatchUp: desc,
        scheduleLiveScan: () {},
        retryNow: () async {},
      );

      expect(result, isTrue);
      final writtenFile = File('${tmp.path}/data/test.json');
      expect(writtenFile.existsSync(), isTrue);
      expect(writtenFile.readAsStringSync(), 'test attachment content');

      // Verify download log was emitted
      verify(
        () => logging.captureEvent(
          any<String>(that: contains('downloading')),
          domain: any<String>(named: 'domain'),
          subDomain: 'attachment.download',
        ),
      ).called(1);

      // Verify write success log was emitted
      verify(
        () => logging.captureEvent(
          any<String>(that: contains('wrote file')),
          domain: any<String>(named: 'domain'),
          subDomain: 'attachment.save',
        ),
      ).called(1);
    });

    test(
      'decompresses gzip-encoded attachments before writing to disk',
      () async {
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {});

        final tmp = Directory.systemTemp.createTempSync('ingestor_gzip');
        addTearDown(() => tmp.deleteSync(recursive: true));

        const originalJson = '{"hello":"world","n":42}';
        final gzippedBytes = Uint8List.fromList(
          gzip.encode(utf8.encode(originalJson)),
        );
        expect(
          gzippedBytes.length,
          isNot(utf8.encode(originalJson).length),
          reason: 'test payload must actually differ once compressed',
        );

        final matrixFile = MockMatrixFile();
        when(() => matrixFile.bytes).thenReturn(gzippedBytes);

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('e_gzip');
        when(() => ev.content).thenReturn({
          'relativePath': '/data/compressed.json',
          'msgtype': 'm.file',
          attachmentEncodingKey: attachmentEncodingGzip,
        });
        when(() => ev.attachmentMimetype).thenReturn('application/gzip');
        when(() => ev.senderId).thenReturn('@other:u');
        when(
          ev.downloadAndDecryptAttachment,
        ).thenAnswer((_) async => matrixFile);

        final index = AttachmentIndex(logging: logging);
        final desc = MockDescriptorCatchUpManager();
        when(
          () => desc.removeIfPresent('/data/compressed.json'),
        ).thenReturn(false);

        final ingestor = AttachmentIngestor(documentsDirectory: tmp);
        final result = await ingestor.process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );

        expect(result, isTrue);
        final written = File('${tmp.path}/data/compressed.json');
        expect(written.existsSync(), isTrue);
        expect(written.readAsStringSync(), originalJson);

        verify(
          () => logging.captureEvent(
            any<String>(that: contains('gzipDecoded')),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.decode',
          ),
        ).called(1);
      },
    );

    test(
      'writes plain bytes when no encoding header is present',
      () async {
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});

        final tmp = Directory.systemTemp.createTempSync('ingestor_plain');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final plainBytes = Uint8List.fromList(utf8.encode('{"ok":true}'));
        final matrixFile = MockMatrixFile();
        when(() => matrixFile.bytes).thenReturn(plainBytes);

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('e_plain');
        when(() => ev.content).thenReturn({
          'relativePath': '/data/plain.json',
          'msgtype': 'm.file',
        });
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.senderId).thenReturn('@other:u');
        when(
          ev.downloadAndDecryptAttachment,
        ).thenAnswer((_) async => matrixFile);

        final index = AttachmentIndex(logging: logging);
        final desc = MockDescriptorCatchUpManager();
        when(() => desc.removeIfPresent('/data/plain.json')).thenReturn(false);

        final ingestor = AttachmentIngestor(documentsDirectory: tmp);
        await ingestor.process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );

        expect(
          File('${tmp.path}/data/plain.json').readAsStringSync(),
          '{"ok":true}',
        );
        verifyNever(
          () => logging.captureEvent(
            any<String>(that: contains('gzipDecoded')),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.decode',
          ),
        );
      },
    );

    test('skips download if file already exists and is non-empty', () async {
      final logging = MockLoggingService();
      when(
        () => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      final tmp = Directory.systemTemp.createTempSync('ingestor_dedupe');
      addTearDown(() => tmp.deleteSync(recursive: true));

      // Pre-create the file
      final existingFile = File('${tmp.path}/data/existing.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('existing content');

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e11');
      when(() => ev.content).thenReturn({
        'relativePath': '/data/existing.json',
        'msgtype': 'm.file',
      });
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.senderId).thenReturn('@other:u');

      final index = AttachmentIndex(logging: logging);
      final desc = MockDescriptorCatchUpManager();
      when(() => desc.removeIfPresent('/data/existing.json')).thenReturn(false);

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
        attachmentIndex: index,
        descriptorCatchUp: desc,
        scheduleLiveScan: () {},
        retryNow: () async {},
      );

      expect(result, isFalse); // No new file written
      expect(existingFile.readAsStringSync(), 'existing content'); // Unchanged

      // Verify download was NOT called
      verifyNever(ev.downloadAndDecryptAttachment);
    });

    test('handles empty bytes gracefully', () async {
      final logging = MockLoggingService();
      when(
        () => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      final tmp = Directory.systemTemp.createTempSync('ingestor_empty');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final matrixFile = MockMatrixFile();
      when(() => matrixFile.bytes).thenReturn(Uint8List(0)); // Empty bytes

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e12');
      when(
        () => ev.content,
      ).thenReturn({'relativePath': '/data/empty.json', 'msgtype': 'm.file'});
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.senderId).thenReturn('@other:u');
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async => matrixFile);

      final index = AttachmentIndex(logging: logging);
      final desc = MockDescriptorCatchUpManager();
      when(() => desc.removeIfPresent('/data/empty.json')).thenReturn(false);

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
        attachmentIndex: index,
        descriptorCatchUp: desc,
        scheduleLiveScan: () {},
        retryNow: () async {},
      );

      expect(result, isFalse); // No file written
      expect(File('${tmp.path}/data/empty.json').existsSync(), isFalse);

      // Verify empty bytes log was emitted
      verify(
        () => logging.captureEvent(
          any<String>(that: contains('emptyBytes')),
          domain: any<String>(named: 'domain'),
          subDomain: 'attachment.download',
        ),
      ).called(1);
    });

    test('handles download exception gracefully', () async {
      final logging = MockLoggingService();
      when(
        () => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      final tmp = Directory.systemTemp.createTempSync('ingestor_error');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e13');
      when(
        () => ev.content,
      ).thenReturn({'relativePath': '/data/error.json', 'msgtype': 'm.file'});
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.senderId).thenReturn('@other:u');
      when(
        ev.downloadAndDecryptAttachment,
      ).thenThrow(Exception('Network error'));

      final index = AttachmentIndex(logging: logging);
      final desc = MockDescriptorCatchUpManager();
      when(() => desc.removeIfPresent('/data/error.json')).thenReturn(false);

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
        attachmentIndex: index,
        descriptorCatchUp: desc,
        scheduleLiveScan: () {},
        retryNow: () async {},
      );

      expect(result, isFalse); // No file written due to error
      expect(File('${tmp.path}/data/error.json').existsSync(), isFalse);

      // Verify exception was logged (not thrown)
      verify(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: 'attachment.save',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test(
      'annotates EMFILE (errno 24) FileSystemException with FD limits',
      () async {
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            level: any<InsightLevel>(named: 'level'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {});

        final tmp = Directory.systemTemp.createTempSync('ingestor_emfile');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('e_emfile');
        when(
          () => ev.content,
        ).thenReturn({
          'relativePath': '/data/emfile.json',
          'msgtype': 'm.file',
        });
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.senderId).thenReturn('@other:u');
        when(ev.downloadAndDecryptAttachment).thenThrow(
          const FileSystemException(
            'Cannot open file',
            '/data/emfile.json',
            OSError('Too many open files', 24),
          ),
        );

        final index = AttachmentIndex(logging: logging);
        final desc = MockDescriptorCatchUpManager();
        when(
          () => desc.removeIfPresent('/data/emfile.json'),
        ).thenReturn(false);

        final ingestor = AttachmentIngestor(documentsDirectory: tmp);
        final result = await ingestor.process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );

        expect(result, isFalse);

        // The EMFILE-specific diagnostic event is emitted at warn level,
        // carrying the current FD limits alongside the path.
        verify(
          () => logging.captureEvent(
            any<String>(that: contains('emfile path=/data/emfile.json')),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.save.emfile',
            level: InsightLevel.warn,
          ),
        ).called(1);

        // The original exception is still logged through captureException.
        verify(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.save',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test('overwrites stale agent entity file instead of deduping', () async {
      final logging = MockLoggingService();
      when(
        () => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      final tmp = Directory.systemTemp.createTempSync('ingestor_agent');
      addTearDown(() => tmp.deleteSync(recursive: true));

      // Pre-create the stale agent entity file
      final staleFile = File('${tmp.path}/agent_entities/change-set-123.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"status":"pending"}');

      final resolvedContent = Uint8List.fromList(
        utf8.encode('{"status":"resolved"}'),
      );
      final matrixFile = MockMatrixFile();
      when(() => matrixFile.bytes).thenReturn(resolvedContent);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e_agent');
      when(() => ev.content).thenReturn({
        'relativePath': '/agent_entities/change-set-123.json',
        'msgtype': 'm.file',
      });
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.senderId).thenReturn('@other:u');
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async => matrixFile);

      final index = AttachmentIndex(logging: logging);
      final desc = MockDescriptorCatchUpManager();
      when(
        () => desc.removeIfPresent('/agent_entities/change-set-123.json'),
      ).thenReturn(false);

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
        attachmentIndex: index,
        descriptorCatchUp: desc,
        scheduleLiveScan: () {},
        retryNow: () async {},
      );

      expect(result, isTrue); // File was re-downloaded
      expect(staleFile.readAsStringSync(), '{"status":"resolved"}');

      // Verify download WAS called despite file existing
      verify(ev.downloadAndDecryptAttachment).called(1);
    });

    test(
      'does not redownload the same agent attachment event when file exists',
      () async {
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {});

        final tmp = Directory.systemTemp.createTempSync(
          'ingestor_agent_repeat',
        );
        addTearDown(() => tmp.deleteSync(recursive: true));

        final matrixFile = MockMatrixFile();
        when(
          () => matrixFile.bytes,
        ).thenReturn(Uint8List.fromList(utf8.encode('{"status":"resolved"}')));

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('e_agent_repeat');
        when(() => ev.content).thenReturn({
          'relativePath': '/agent_entities/repeat.json',
          'msgtype': 'm.file',
        });
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.senderId).thenReturn('@other:u');
        when(
          ev.downloadAndDecryptAttachment,
        ).thenAnswer((_) async => matrixFile);

        final index = AttachmentIndex(logging: logging);
        final desc = MockDescriptorCatchUpManager();
        when(
          () => desc.removeIfPresent('/agent_entities/repeat.json'),
        ).thenReturn(false);

        final ingestor = AttachmentIngestor(documentsDirectory: tmp);

        final firstResult = await ingestor.process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );
        final secondResult = await ingestor.process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );

        expect(firstResult, isTrue);
        expect(secondResult, isFalse);
        expect(
          File('${tmp.path}/agent_entities/repeat.json').readAsStringSync(),
          '{"status":"resolved"}',
        );
        verify(ev.downloadAndDecryptAttachment).called(1);
        verify(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.observe',
          ),
        ).called(1);
      },
    );

    test(
      'repairs the same agent attachment event when the local file is missing',
      () async {
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {});

        final tmp = Directory.systemTemp.createTempSync(
          'ingestor_agent_repair',
        );
        addTearDown(() => tmp.deleteSync(recursive: true));

        final matrixFile = MockMatrixFile();
        when(
          () => matrixFile.bytes,
        ).thenReturn(Uint8List.fromList(utf8.encode('{"status":"resolved"}')));

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('e_agent_repair');
        when(() => ev.content).thenReturn({
          'relativePath': '/agent_entities/repair.json',
          'msgtype': 'm.file',
        });
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.senderId).thenReturn('@other:u');
        when(
          ev.downloadAndDecryptAttachment,
        ).thenAnswer((_) async => matrixFile);

        final index = AttachmentIndex(logging: logging);
        final desc = MockDescriptorCatchUpManager();
        when(
          () => desc.removeIfPresent('/agent_entities/repair.json'),
        ).thenReturn(false);

        final ingestor = AttachmentIngestor(documentsDirectory: tmp);

        final firstResult = await ingestor.process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );

        final localFile = File('${tmp.path}/agent_entities/repair.json');
        expect(localFile.existsSync(), isTrue);
        localFile.deleteSync();

        final secondResult = await ingestor.process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );

        expect(firstResult, isTrue);
        expect(secondResult, isTrue);
        expect(localFile.existsSync(), isTrue);
        verify(ev.downloadAndDecryptAttachment).called(2);
      },
    );

    test(
      'repairs the same agent attachment event when the local file is empty',
      () async {
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {});

        final tmp = Directory.systemTemp.createTempSync(
          'ingestor_agent_empty',
        );
        addTearDown(() => tmp.deleteSync(recursive: true));

        final matrixFile = MockMatrixFile();
        when(
          () => matrixFile.bytes,
        ).thenReturn(Uint8List.fromList(utf8.encode('{"status":"ok"}')));

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('e_agent_empty');
        when(() => ev.content).thenReturn({
          'relativePath': '/agent_entities/empty.json',
          'msgtype': 'm.file',
        });
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.senderId).thenReturn('@other:u');
        when(
          ev.downloadAndDecryptAttachment,
        ).thenAnswer((_) async => matrixFile);

        final index = AttachmentIndex(logging: logging);
        final desc = MockDescriptorCatchUpManager();
        when(
          () => desc.removeIfPresent('/agent_entities/empty.json'),
        ).thenReturn(false);

        final ingestor = AttachmentIngestor(documentsDirectory: tmp);

        final firstResult = await ingestor.process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );

        // Truncate to empty to trigger the empty-file repair path.
        final localFile = File('${tmp.path}/agent_entities/empty.json');
        expect(localFile.existsSync(), isTrue);
        localFile.writeAsStringSync('');

        final secondResult = await ingestor.process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );

        expect(firstResult, isTrue);
        expect(secondResult, isTrue);
        expect(localFile.readAsStringSync(), '{"status":"ok"}');
        verify(ev.downloadAndDecryptAttachment).called(2);
      },
    );

    test('overwrites stale agent link file instead of deduping', () async {
      final logging = MockLoggingService();
      when(
        () => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      final tmp = Directory.systemTemp.createTempSync('ingestor_agent_link');
      addTearDown(() => tmp.deleteSync(recursive: true));

      // Pre-create the stale agent link file
      File('${tmp.path}/agent_links/link-456.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"old":"data"}');

      final newContent = Uint8List.fromList(utf8.encode('{"new":"data"}'));
      final matrixFile = MockMatrixFile();
      when(() => matrixFile.bytes).thenReturn(newContent);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e_agent_link');
      when(() => ev.content).thenReturn({
        'relativePath': '/agent_links/link-456.json',
        'msgtype': 'm.file',
      });
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.senderId).thenReturn('@other:u');
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async => matrixFile);

      final index = AttachmentIndex(logging: logging);
      final desc = MockDescriptorCatchUpManager();
      when(
        () => desc.removeIfPresent('/agent_links/link-456.json'),
      ).thenReturn(false);

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
        attachmentIndex: index,
        descriptorCatchUp: desc,
        scheduleLiveScan: () {},
        retryNow: () async {},
      );

      expect(result, isTrue);
      final writtenFile = File('${tmp.path}/agent_links/link-456.json');
      expect(writtenFile.readAsStringSync(), '{"new":"data"}');

      // Verify download WAS called despite file existing
      verify(ev.downloadAndDecryptAttachment).called(1);
    });

    test('still dedupes non-agent files when they exist', () async {
      final logging = MockLoggingService();
      when(
        () => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      final tmp = Directory.systemTemp.createTempSync('ingestor_journal');
      addTearDown(() => tmp.deleteSync(recursive: true));

      // Pre-create a journal entity file
      final existingFile = File('${tmp.path}/journal_entities/entry-789.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"original":"content"}');

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e_journal');
      when(() => ev.content).thenReturn({
        'relativePath': '/journal_entities/entry-789.json',
        'msgtype': 'm.file',
      });
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.senderId).thenReturn('@other:u');

      final index = AttachmentIndex(logging: logging);
      final desc = MockDescriptorCatchUpManager();
      when(
        () => desc.removeIfPresent('/journal_entities/entry-789.json'),
      ).thenReturn(false);

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
        attachmentIndex: index,
        descriptorCatchUp: desc,
        scheduleLiveScan: () {},
        retryNow: () async {},
      );

      expect(result, isFalse); // Deduped — no re-download
      expect(
        existingFile.readAsStringSync(),
        '{"original":"content"}',
      );
      verifyNever(ev.downloadAndDecryptAttachment);
    });

    test('evicts oldest handled event IDs when capacity is exceeded', () async {
      final logging = MockLoggingService();
      when(
        () => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});

      final index = AttachmentIndex(logging: logging);
      final desc = MockDescriptorCatchUpManager();
      when(() => desc.removeIfPresent(any<String>())).thenReturn(false);

      // Use a tiny capacity so the eviction loop triggers quickly.
      final ingestor = AttachmentIngestor(handledEventCapacity: 2);

      // Process 3 distinct events (capacity=2 so e1 gets evicted).
      for (var i = 1; i <= 3; i++) {
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evict_$i');
        when(
          () => ev.content,
        ).thenReturn({'relativePath': '/path/$i.bin', 'msgtype': 'm.file'});
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.senderId).thenReturn('@other:u');
        await ingestor.process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );
      }

      // Re-process e1 — it should be treated as new because it was evicted.
      final e1Again = MockEvent();
      when(() => e1Again.eventId).thenReturn('evict_1');
      when(
        () => e1Again.content,
      ).thenReturn({'relativePath': '/path/1.bin', 'msgtype': 'm.file'});
      when(() => e1Again.attachmentMimetype).thenReturn('application/json');
      when(() => e1Again.senderId).thenReturn('@other:u');

      await ingestor.process(
        event: e1Again,
        logging: logging,
        attachmentIndex: index,
        descriptorCatchUp: desc,
        scheduleLiveScan: () {},
        retryNow: () async {},
      );

      // Verify e1 was recorded again (the observe log fires for new events).
      // If eviction didn't happen, the second call would skip the record.
      verify(
        () => logging.captureEvent(
          any<String>(that: contains('attachmentEvent id=evict_1')),
          domain: any<String>(named: 'domain'),
          subDomain: 'attachment.observe',
        ),
      ).called(2); // Once on first pass, once after eviction
    });

    test(
      'records descriptor in AttachmentIndex even when download is skipped',
      () async {
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {});

        final tmp = Directory.systemTemp.createTempSync('ingestor_index_dedup');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final matrixFile = MockMatrixFile();
        when(
          () => matrixFile.bytes,
        ).thenReturn(Uint8List.fromList(utf8.encode('data')));

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('e_idx_dedup');
        when(() => ev.content).thenReturn({
          'relativePath': '/data/idx.json',
          'msgtype': 'm.file',
        });
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.senderId).thenReturn('@other:u');
        when(
          ev.downloadAndDecryptAttachment,
        ).thenAnswer((_) async => matrixFile);

        final index = AttachmentIndex(logging: logging);
        final desc = MockDescriptorCatchUpManager();
        when(() => desc.removeIfPresent('/data/idx.json')).thenReturn(false);

        final ingestor = AttachmentIngestor(documentsDirectory: tmp);

        await ingestor.process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );

        final ev2 = MockEvent();
        when(() => ev2.eventId).thenReturn('e_idx_dedup_2');
        when(() => ev2.content).thenReturn({
          'relativePath': '/data/idx.json',
          'msgtype': 'm.file',
        });
        when(() => ev2.attachmentMimetype).thenReturn('application/json');
        when(() => ev2.senderId).thenReturn('@other:u');

        final result2 = await ingestor.process(
          event: ev2,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );

        expect(result2, isFalse);
        verifyNever(ev2.downloadAndDecryptAttachment);

        final recorded = index.find('/data/idx.json');
        expect(recorded, isNotNull);
        expect(recorded!.eventId, 'e_idx_dedup_2');
      },
    );

    test(
      'concurrent process() calls for same path only trigger one save',
      () async {
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {});

        final tmp = Directory.systemTemp.createTempSync('ingestor_concurrent');
        addTearDown(() => tmp.deleteSync(recursive: true));

        // Use a completer to control when the download finishes so both
        // process() calls overlap.
        final downloadCompleter = Completer<MatrixFile>();
        final matrixFile = MockMatrixFile();
        when(
          () => matrixFile.bytes,
        ).thenReturn(Uint8List.fromList(utf8.encode('concurrent-data')));

        final ev1 = MockEvent();
        when(() => ev1.eventId).thenReturn('e_conc_1');
        when(() => ev1.content).thenReturn({
          'relativePath': '/data/conc.json',
          'msgtype': 'm.file',
        });
        when(() => ev1.attachmentMimetype).thenReturn('application/json');
        when(() => ev1.senderId).thenReturn('@other:u');
        var downloadCallCount = 0;
        when(ev1.downloadAndDecryptAttachment).thenAnswer((_) {
          downloadCallCount++;
          return downloadCompleter.future;
        });

        // Second event with a different eventId but the SAME relativePath.
        final ev2 = MockEvent();
        when(() => ev2.eventId).thenReturn('e_conc_2');
        when(() => ev2.content).thenReturn({
          'relativePath': '/data/conc.json',
          'msgtype': 'm.file',
        });
        when(() => ev2.attachmentMimetype).thenReturn('application/json');
        when(() => ev2.senderId).thenReturn('@other:u');
        when(ev2.downloadAndDecryptAttachment).thenAnswer((_) {
          downloadCallCount++;
          return downloadCompleter.future;
        });

        final index = AttachmentIndex(logging: logging);
        final desc = MockDescriptorCatchUpManager();
        when(() => desc.removeIfPresent('/data/conc.json')).thenReturn(false);

        final ingestor = AttachmentIngestor(documentsDirectory: tmp);

        // Launch both process() calls concurrently.
        final future1 = ingestor.process(
          event: ev1,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );
        final future2 = ingestor.process(
          event: ev2,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );

        // Complete the download so both futures can resolve.
        downloadCompleter.complete(matrixFile);
        final results = await Future.wait([future1, future2]);

        // Exactly one should have written the file; the other was blocked by
        // the in-flight guard.
        expect(results.where((r) => r).length, 1);

        final writtenFile = File('${tmp.path}/data/conc.json');
        expect(writtenFile.existsSync(), isTrue);
        expect(writtenFile.readAsStringSync(), 'concurrent-data');

        // Exactly one download should have been triggered across both events,
        // regardless of which process() call won the race.
        expect(downloadCallCount, 1);
      },
    );

    test(
      'unpacks bundle zip and writes each entry to its target path',
      () async {
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {});

        final tmp = Directory.systemTemp.createTempSync('ingestor_bundle');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final entryA = utf8.encode('{"id":"A"}');
        final entryB = utf8.encode('binary-bytes-b');
        final archive = Archive()
          ..addFile(ArchiveFile('text_entries/a.json', entryA.length, entryA))
          ..addFile(ArchiveFile('images/b.jpg', entryB.length, entryB));
        final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));

        final matrixFile = MockMatrixFile();
        when(() => matrixFile.bytes).thenReturn(zipBytes);

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('e_bundle');
        when(() => ev.content).thenReturn({
          'relativePath': '.bundles/abc.zip',
          'msgtype': 'm.file',
          attachmentBundleKey: true,
        });
        when(() => ev.attachmentMimetype).thenReturn('application/zip');
        when(() => ev.senderId).thenReturn('@other:u');
        when(
          ev.downloadAndDecryptAttachment,
        ).thenAnswer((_) async => matrixFile);

        final index = AttachmentIndex(logging: logging);
        final desc = MockDescriptorCatchUpManager();
        when(() => desc.removeIfPresent('.bundles/abc.zip')).thenReturn(false);

        final ingestor = AttachmentIngestor(documentsDirectory: tmp);
        final result = await ingestor.process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );

        expect(result, isTrue);
        expect(
          File('${tmp.path}/text_entries/a.json').readAsStringSync(),
          '{"id":"A"}',
        );
        expect(
          File('${tmp.path}/images/b.jpg').readAsBytesSync(),
          equals(entryB),
        );
        // Outer zip itself must not be written at its .bundles/... path.
        expect(File('${tmp.path}/.bundles/abc.zip').existsSync(), isFalse);
        verify(
          () => logging.captureEvent(
            any<String>(that: contains('bundleUnpacked')),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.bundle.unpack',
          ),
        ).called(1);
      },
    );

    test('blocks path traversal on bundle entry names', () async {
      final logging = MockLoggingService();
      when(
        () => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      final tmp = Directory.systemTemp.createTempSync('ingestor_bundle_tr');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final safeBytes = utf8.encode('safe');
      final badBytes = utf8.encode('pwned');
      final archive = Archive()
        ..addFile(ArchiveFile('safe/ok.txt', safeBytes.length, safeBytes))
        ..addFile(
          ArchiveFile('../../../etc/passwd', badBytes.length, badBytes),
        );
      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      final matrixFile = MockMatrixFile();
      when(() => matrixFile.bytes).thenReturn(zipBytes);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e_bundle_tr');
      when(() => ev.content).thenReturn({
        'relativePath': '.bundles/tr.zip',
        'msgtype': 'm.file',
        attachmentBundleKey: true,
      });
      when(() => ev.attachmentMimetype).thenReturn('application/zip');
      when(() => ev.senderId).thenReturn('@other:u');
      when(
        ev.downloadAndDecryptAttachment,
      ).thenAnswer((_) async => matrixFile);

      final index = AttachmentIndex(logging: logging);
      final desc = MockDescriptorCatchUpManager();
      when(() => desc.removeIfPresent('.bundles/tr.zip')).thenReturn(false);

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
        attachmentIndex: index,
        descriptorCatchUp: desc,
        scheduleLiveScan: () {},
        retryNow: () async {},
      );

      expect(result, isTrue);
      expect(File('${tmp.path}/safe/ok.txt').readAsStringSync(), 'safe');
      // Bad entry must not have escaped the documents directory.
      expect(File('/etc/passwd').readAsStringSync(), isNot(contains('pwned')));
      verify(
        () => logging.captureEvent(
          any<String>(that: contains('pathTraversal.blocked bundleEntry=')),
          domain: any<String>(named: 'domain'),
          subDomain: 'attachment.bundle.entry',
        ),
      ).called(1);
    });

    test(
      'bundle unpack skips entries that already exist for non-agent paths',
      () async {
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});

        final tmp = Directory.systemTemp.createTempSync('ingestor_bundle_dd');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final existing = File('${tmp.path}/text_entries/dup.json')
          ..createSync(recursive: true)
          ..writeAsStringSync('{"existing":true}');

        final entryBytes = utf8.encode('{"new":true}');
        final archive = Archive()
          ..addFile(
            ArchiveFile(
              'text_entries/dup.json',
              entryBytes.length,
              entryBytes,
            ),
          );
        final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));

        final matrixFile = MockMatrixFile();
        when(() => matrixFile.bytes).thenReturn(zipBytes);

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('e_bundle_dd');
        when(() => ev.content).thenReturn({
          'relativePath': '.bundles/dd.zip',
          'msgtype': 'm.file',
          attachmentBundleKey: true,
        });
        when(() => ev.attachmentMimetype).thenReturn('application/zip');
        when(() => ev.senderId).thenReturn('@other:u');
        when(
          ev.downloadAndDecryptAttachment,
        ).thenAnswer((_) async => matrixFile);

        final index = AttachmentIndex(logging: logging);
        final desc = MockDescriptorCatchUpManager();
        when(() => desc.removeIfPresent('.bundles/dd.zip')).thenReturn(false);

        final ingestor = AttachmentIngestor(documentsDirectory: tmp);
        final result = await ingestor.process(
          event: ev,
          logging: logging,
          attachmentIndex: index,
          descriptorCatchUp: desc,
          scheduleLiveScan: () {},
          retryNow: () async {},
        );

        expect(result, isFalse); // nothing new written
        expect(existing.readAsStringSync(), '{"existing":true}'); // unchanged
      },
    );

    test('blocks path traversal attempts', () async {
      final logging = MockLoggingService();
      when(
        () => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      final tmp = Directory.systemTemp.createTempSync('ingestor_traversal');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e14');
      // Attempt path traversal
      when(() => ev.content).thenReturn({
        'relativePath': '/../../../etc/passwd',
        'msgtype': 'm.file',
      });
      when(() => ev.attachmentMimetype).thenReturn('application/octet-stream');
      when(() => ev.senderId).thenReturn('@other:u');

      final index = AttachmentIndex(logging: logging);
      final desc = MockDescriptorCatchUpManager();
      when(
        () => desc.removeIfPresent('/../../../etc/passwd'),
      ).thenReturn(false);

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
        attachmentIndex: index,
        descriptorCatchUp: desc,
        scheduleLiveScan: () {},
        retryNow: () async {},
      );

      expect(result, isFalse); // Blocked

      // Verify path traversal was logged
      verify(
        () => logging.captureEvent(
          any<String>(that: contains('pathTraversal.blocked')),
          domain: any<String>(named: 'domain'),
          subDomain: 'attachment.save',
        ),
      ).called(1);

      // Verify download was NOT called
      verifyNever(ev.downloadAndDecryptAttachment);
    });
  });
}
