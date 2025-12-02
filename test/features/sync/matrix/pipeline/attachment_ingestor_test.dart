import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockEvent extends Mock implements Event {}

class MockLoggingService extends Mock implements LoggingService {}

class MockMatrixFile extends Mock implements MatrixFile {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  group('descriptor-only mode (no documentsDirectory)', () {
    test('logs observe event when relativePath is present', () async {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenReturn(null);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e1');
      when(() => ev.content)
          .thenReturn({'relativePath': '/p/a.bin', 'msgtype': 'm.file'});
      when(() => ev.attachmentMimetype).thenReturn('application/json');

      // No documentsDirectory = descriptor-only mode (no download)
      final result = await const AttachmentIngestor().process(
        event: ev,
        logging: logging,
      );

      // No file written in descriptor-only mode
      expect(result, isFalse);
      // Logs emitted
      verify(() => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.observe',
          )).called(greaterThan(0));
    });

    test('returns false when no relativePath', () async {
      final logging = MockLoggingService();

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e2');
      when(() => ev.content).thenReturn({'msgtype': 'm.text'});

      final result = await const AttachmentIngestor().process(
        event: ev,
        logging: logging,
      );

      expect(result, isFalse);
      verifyNever(() => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.observe',
          ));
    });
  });

  group('download mode (with documentsDirectory)', () {
    test('downloads and saves attachment when relativePath present', () async {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenReturn(null);

      final tmp = Directory.systemTemp.createTempSync('ingestor');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e3');
      when(() => ev.content)
          .thenReturn({'relativePath': '/media/x.jpg', 'msgtype': 'm.image'});
      when(() => ev.attachmentMimetype).thenReturn('image/jpeg');

      // Simulated download
      final fileBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      final mockFile = MockMatrixFile();
      when(() => mockFile.bytes).thenReturn(fileBytes);
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async => mockFile);

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
      );

      expect(result, isTrue);
      final savedFile = File('${tmp.path}/media/x.jpg');
      expect(savedFile.existsSync(), isTrue);
      expect(savedFile.readAsBytesSync(), equals(fileBytes));
    });

    test('skips download when file already exists', () async {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenReturn(null);

      final tmp = Directory.systemTemp.createTempSync('ingestor');
      addTearDown(() => tmp.deleteSync(recursive: true));

      // Pre-create file
      final mediaDir = Directory('${tmp.path}/media')
        ..createSync(recursive: true);
      File('${mediaDir.path}/existing.jpg').writeAsBytesSync([1, 2, 3]);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e4');
      when(() => ev.content).thenReturn(
          {'relativePath': '/media/existing.jpg', 'msgtype': 'm.image'});
      when(() => ev.attachmentMimetype).thenReturn('image/jpeg');

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
      );

      // No new file written since it already exists
      expect(result, isFalse);
      // downloadAndDecryptAttachment should NOT be called
      verifyNever(ev.downloadAndDecryptAttachment);
    });

    test('blocks path traversal attacks', () async {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenReturn(null);

      final tmp = Directory.systemTemp.createTempSync('ingestor');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e5');
      when(() => ev.content).thenReturn(
          {'relativePath': '../../../etc/passwd', 'msgtype': 'm.file'});
      when(() => ev.attachmentMimetype).thenReturn('text/plain');

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
      );

      // Path traversal should be blocked
      expect(result, isFalse);
      verify(() => logging.captureEvent(
            any<String>(that: contains('pathTraversal.blocked')),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.save',
          )).called(1);
    });

    test('handles empty attachment bytes', () async {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenReturn(null);

      final tmp = Directory.systemTemp.createTempSync('ingestor');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e6');
      when(() => ev.content).thenReturn(
          {'relativePath': '/media/empty.bin', 'msgtype': 'm.file'});
      when(() => ev.attachmentMimetype).thenReturn('application/octet-stream');

      // Empty bytes
      final mockFile = MockMatrixFile();
      when(() => mockFile.bytes).thenReturn(Uint8List(0));
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async => mockFile);

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
      );

      expect(result, isFalse);
      verify(() => logging.captureEvent(
            any<String>(that: contains('emptyBytes')),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.download',
          )).called(1);
    });

    test('handles download exception gracefully', () async {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenReturn(null);
      when(() => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          )).thenAnswer((_) async {});

      final tmp = Directory.systemTemp.createTempSync('ingestor');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e7');
      when(() => ev.content)
          .thenReturn({'relativePath': '/media/fail.bin', 'msgtype': 'm.file'});
      when(() => ev.attachmentMimetype).thenReturn('application/octet-stream');
      when(ev.downloadAndDecryptAttachment)
          .thenThrow(Exception('network error'));

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
      );

      // Should return false but not throw
      expect(result, isFalse);
      verify(() => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.save',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          )).called(1);
    });

    test('returns false when no mimetype', () async {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenReturn(null);

      final tmp = Directory.systemTemp.createTempSync('ingestor');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e8');
      when(() => ev.content).thenReturn(
          {'relativePath': '/media/nomime.bin', 'msgtype': 'm.file'});
      when(() => ev.attachmentMimetype).thenReturn('');

      final ingestor = AttachmentIngestor(documentsDirectory: tmp);
      final result = await ingestor.process(
        event: ev,
        logging: logging,
      );

      expect(result, isFalse);
      verifyNever(ev.downloadAndDecryptAttachment);
    });
  });
}
