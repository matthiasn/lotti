import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e1');
      when(() => ev.content)
          .thenReturn({'relativePath': '/p/a.bin', 'msgtype': 'm.file'});
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
      verify(() => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.observe',
          )).called(greaterThan(0));
      // Pending cleared triggers scan and retry (no media write here)
      expect(liveScanCalls, 1);
      expect(retryNowCalls, 1);
      // AttachmentIndex has the descriptor
      expect(index.find('/p/a.bin'), isNotNull);
    });

    test('no file written without documentsDirectory; clears pending',
        () async {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      final tmp = Directory.systemTemp.createTempSync('ingestor');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e2');
      when(() => ev.content)
          .thenReturn({'relativePath': '/media/x.jpg', 'msgtype': 'm.image'});
      when(() => ev.attachmentMimetype).thenReturn('image/jpeg');
      when(() => ev.senderId).thenReturn('@other:u');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2000));

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
    });

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
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      final tmp = Directory.systemTemp.createTempSync('ingestor_queue');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final matrixFile = MockMatrixFile();
      when(() => matrixFile.bytes)
          .thenReturn(Uint8List.fromList(utf8.encode('queued')));
      final downloadCompleter = Completer<MatrixFile>();

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e_queue');
      when(() => ev.content).thenReturn(
          {'relativePath': '/data/queued.json', 'msgtype': 'm.file'});
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.senderId).thenReturn('@other:u');
      when(ev.downloadAndDecryptAttachment)
          .thenAnswer((_) => downloadCompleter.future);

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
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      final tmp = Directory.systemTemp.createTempSync('ingestor_eager');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final testContent =
          Uint8List.fromList(utf8.encode('test attachment content'));
      final matrixFile = MockMatrixFile();
      when(() => matrixFile.bytes).thenReturn(testContent);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e10');
      when(() => ev.content)
          .thenReturn({'relativePath': '/data/test.json', 'msgtype': 'm.file'});
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
      verify(() => logging.captureEvent(
            any<String>(that: contains('downloading')),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.download',
          )).called(1);

      // Verify write success log was emitted
      verify(() => logging.captureEvent(
            any<String>(that: contains('wrote file')),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.save',
          )).called(1);
    });

    test('skips download if file already exists and is non-empty', () async {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      final tmp = Directory.systemTemp.createTempSync('ingestor_dedupe');
      addTearDown(() => tmp.deleteSync(recursive: true));

      // Pre-create the file
      final existingFile = File('${tmp.path}/data/existing.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('existing content');

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e11');
      when(() => ev.content).thenReturn(
          {'relativePath': '/data/existing.json', 'msgtype': 'm.file'});
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
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      final tmp = Directory.systemTemp.createTempSync('ingestor_empty');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final matrixFile = MockMatrixFile();
      when(() => matrixFile.bytes).thenReturn(Uint8List(0)); // Empty bytes

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e12');
      when(() => ev.content).thenReturn(
          {'relativePath': '/data/empty.json', 'msgtype': 'm.file'});
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
      verify(() => logging.captureEvent(
            any<String>(that: contains('emptyBytes')),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.download',
          )).called(1);
    });

    test('handles download exception gracefully', () async {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      final tmp = Directory.systemTemp.createTempSync('ingestor_error');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e13');
      when(() => ev.content).thenReturn(
          {'relativePath': '/data/error.json', 'msgtype': 'm.file'});
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.senderId).thenReturn('@other:u');
      when(ev.downloadAndDecryptAttachment)
          .thenThrow(Exception('Network error'));

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
      verify(() => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.save',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          )).called(1);
    });

    test('overwrites stale agent entity file instead of deduping', () async {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      final tmp = Directory.systemTemp.createTempSync('ingestor_agent');
      addTearDown(() => tmp.deleteSync(recursive: true));

      // Pre-create the stale agent entity file
      final staleFile = File('${tmp.path}/agent_entities/change-set-123.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"status":"pending"}');

      final resolvedContent =
          Uint8List.fromList(utf8.encode('{"status":"resolved"}'));
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
      when(() => desc.removeIfPresent('/agent_entities/change-set-123.json'))
          .thenReturn(false);

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

    test('overwrites stale agent link file instead of deduping', () async {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

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
      when(() => desc.removeIfPresent('/agent_links/link-456.json'))
          .thenReturn(false);

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
    });

    test('still dedupes non-agent files when they exist', () async {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

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
      when(() => desc.removeIfPresent('/journal_entities/entry-789.json'))
          .thenReturn(false);

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

    test('blocks path traversal attempts', () async {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      final tmp = Directory.systemTemp.createTempSync('ingestor_traversal');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e14');
      // Attempt path traversal
      when(() => ev.content).thenReturn(
          {'relativePath': '/../../../etc/passwd', 'msgtype': 'm.file'});
      when(() => ev.attachmentMimetype).thenReturn('application/octet-stream');
      when(() => ev.senderId).thenReturn('@other:u');

      final index = AttachmentIndex(logging: logging);
      final desc = MockDescriptorCatchUpManager();
      when(() => desc.removeIfPresent('/../../../etc/passwd'))
          .thenReturn(false);

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
      verify(() => logging.captureEvent(
            any<String>(that: contains('pathTraversal.blocked')),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.save',
          )).called(1);

      // Verify download was NOT called
      verifyNever(ev.downloadAndDecryptAttachment);
    });
  });
}
