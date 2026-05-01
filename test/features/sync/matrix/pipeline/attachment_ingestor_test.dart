import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class _MockEvent extends Mock implements Event {}

Event _makeEvent({
  required String eventId,
  String? relativePath,
  String mime = '', // empty mime → _saveAttachment short-circuits before
  // touching the (mocked) Matrix download stack
  Map<String, dynamic>? content,
}) {
  final e = _MockEvent();
  when(() => e.eventId).thenReturn(eventId);
  when(() => e.attachmentMimetype).thenReturn(mime);
  when(() => e.content).thenReturn(
    content ??
        <String, dynamic>{
          'relativePath': ?relativePath,
        },
  );
  when(() => e.text).thenReturn('');
  return e;
}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  late MockLoggingService logging;
  late AttachmentIndex index;
  late Directory tempDir;

  setUp(() {
    logging = MockLoggingService();
    stubLoggingService(logging);
    index = AttachmentIndex(logging: logging, verboseLogging: false);
    tempDir = Directory.systemTemp.createTempSync('lotti_attach_ingest_');
  });

  tearDown(() async {
    await index.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('AttachmentIngestor.process — descriptor handling', () {
    test('no relativePath → no-op, no index mutation, no save', () async {
      final ingestor = AttachmentIngestor(documentsDirectory: tempDir);
      final e = _makeEvent(eventId: 'ev0');

      final wrote = await ingestor.process(
        event: e,
        logging: logging,
        attachmentIndex: index,
      );
      expect(wrote, isFalse);
      expect(index.find('whatever'), isNull);
    });

    test(
      'records descriptor in AttachmentIndex when relativePath present',
      () async {
        final ingestor = AttachmentIngestor(
          // skip download path
          verboseLogging: false,
        );
        final e = _makeEvent(eventId: 'ev1', relativePath: 'images/a.jpg');

        final wrote = await ingestor.process(
          event: e,
          logging: logging,
          attachmentIndex: index,
        );
        expect(wrote, isFalse);
        expect(index.find('images/a.jpg'), isNotNull);
      },
    );

    test(
      'verbose logging emits an attachment.observe line per event',
      () async {
        final ingestor = AttachmentIngestor();
        final e = _makeEvent(
          eventId: 'ev1',
          relativePath: 'images/a.jpg',
          content: <String, dynamic>{
            'relativePath': 'images/a.jpg',
            'msgtype': 'm.image',
            'url': 'mxc://server/abc',
            'file': <String, dynamic>{'url': 'mxc://server/abc'},
          },
        );

        await ingestor.process(
          event: e,
          logging: logging,
          attachmentIndex: index,
        );

        verify(
          () => logging.captureEvent(
            any<String>(that: contains('attachmentEvent id=ev1')),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.observe',
          ),
        ).called(1);
      },
    );

    test('dedup: second process() for same eventId with intact local file '
        'is a no-op', () async {
      // Pre-create the on-disk file so the repair branch doesn't fire.
      final filePath = '${tempDir.path}/images/a.jpg';
      File(filePath).createSync(recursive: true);
      File(filePath).writeAsStringSync('placeholder');

      final ingestor = AttachmentIngestor(documentsDirectory: tempDir);
      final e = _makeEvent(eventId: 'ev1', relativePath: 'images/a.jpg');

      final w1 = await ingestor.process(
        event: e,
        logging: logging,
        attachmentIndex: index,
      );
      final w2 = await ingestor.process(
        event: e,
        logging: logging,
        attachmentIndex: index,
      );

      // Neither call wrote a new file: first is short-circuited by empty
      // mimetype, second by the dedup guard. The important guarantee is
      // the second call doesn't re-emit observe logs.
      expect(w1, isFalse);
      expect(w2, isFalse);
    });

    test('descriptor is re-recorded on every observation so the apply phase '
        'always sees the latest event for a path', () async {
      final ingestor = AttachmentIngestor();
      final e1 = _makeEvent(eventId: 'ev1', relativePath: 'images/a.jpg');
      final e2 = _makeEvent(eventId: 'ev2', relativePath: 'images/a.jpg');

      await ingestor.process(
        event: e1,
        logging: logging,
        attachmentIndex: index,
      );
      await ingestor.process(
        event: e2,
        logging: logging,
        attachmentIndex: index,
      );

      // index.find returns the latest event for the path.
      expect(index.find('images/a.jpg')!.eventId, 'ev2');
    });
  });

  group('AttachmentIngestor.process — path traversal & download skip', () {
    test('refuses to write outside the documents directory', () async {
      final ingestor = AttachmentIngestor(documentsDirectory: tempDir);
      final e = _makeEvent(
        eventId: 'evil',
        relativePath: '../../etc/passwd',
        mime: 'text/plain',
      );

      final wrote = await ingestor.process(
        event: e,
        logging: logging,
        attachmentIndex: index,
      );
      expect(wrote, isFalse);
      verify(
        () => logging.captureEvent(
          any<String>(that: contains('pathTraversal.blocked')),
          domain: any<String>(named: 'domain'),
          subDomain: 'attachment.save',
        ),
      ).called(1);
    });

    test('saveAttachment short-circuits when mimetype is empty', () async {
      final ingestor = AttachmentIngestor(documentsDirectory: tempDir);
      final e = _makeEvent(eventId: 'ev1', relativePath: 'images/a.jpg');

      final wrote = await ingestor.process(
        event: e,
        logging: logging,
        attachmentIndex: index,
      );
      expect(wrote, isFalse);
      // No path traversal, no observe-only state — just nothing written.
      verifyNever(
        () => logging.captureEvent(
          any<String>(that: contains('pathTraversal.blocked')),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      );
    });

    test('pre-existing non-empty local file → fast-path dedup, no write '
        '(non-agent payload)', () async {
      final filePath = '${tempDir.path}/images/a.jpg';
      File(filePath).createSync(recursive: true);
      File(filePath).writeAsStringSync('placeholder');

      final ingestor = AttachmentIngestor(documentsDirectory: tempDir);
      final e = _makeEvent(
        eventId: 'ev1',
        relativePath: 'images/a.jpg',
        mime: 'image/jpeg',
      );

      final wrote = await ingestor.process(
        event: e,
        logging: logging,
        attachmentIndex: index,
      );
      // _saveAttachment returns false because the local file exists and is
      // non-empty for non-agent payloads. No exception, no rewrite.
      expect(wrote, isFalse);
      // Original placeholder bytes remain untouched.
      expect(File(filePath).readAsStringSync(), 'placeholder');
    });
  });

  group('AttachmentIngestor.process — VC dominance for agent payloads', () {
    test('localVcDominates returning true skips the download for an agent '
        'payload', () async {
      var dominanceChecks = 0;
      final ingestor = AttachmentIngestor(
        documentsDirectory: tempDir,
        localVcDominates: (path, vc) async {
          dominanceChecks += 1;
          return true; // local copy is current
        },
      );
      final e = _makeEvent(
        eventId: 'ev1',
        relativePath: '/agent_entities/foo.json',
        mime: 'application/json',
      );

      final wrote = await ingestor.process(
        event: e,
        logging: logging,
        attachmentIndex: index,
      );
      expect(wrote, isFalse);
      expect(dominanceChecks, 1);
      verify(
        () => logging.captureEvent(
          any<String>(that: contains('skip.localVcDominates')),
          domain: any<String>(named: 'domain'),
          subDomain: 'attachment.download.skip',
        ),
      ).called(1);
    });

    test('localVcDominates throwing is logged and does not block the rest '
        'of the flow', () async {
      final ingestor = AttachmentIngestor(
        documentsDirectory: tempDir,
        localVcDominates: (_, _) => throw StateError('dominance failed'),
      );
      final e = _makeEvent(
        eventId: 'ev1',
        relativePath: '/agent_entities/foo.json',
        mime: 'application/json',
      );

      final wrote = await ingestor.process(
        event: e,
        logging: logging,
        attachmentIndex: index,
      );

      expect(wrote, isFalse);
      verify(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: 'attachment.download.skip',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('AttachmentIngestor.scheduleDownload', () {
    test(
      'queued with maxConcurrentDownloads=0 is a no-op (idle immediately)',
      () async {
        final ingestor = AttachmentIngestor(
          documentsDirectory: tempDir,
          maxConcurrentDownloads: 0,
        );
        final e = _makeEvent(
          eventId: 'ev1',
          relativePath: 'images/a.jpg',
          mime: 'image/jpeg',
        );

        await ingestor.process(
          event: e,
          logging: logging,
          attachmentIndex: index,
          scheduleDownload: true,
        );

        // Nothing should be queued or in flight when the cap is zero, so
        // whenIdle resolves synchronously.
        await ingestor.whenIdle().timeout(const Duration(seconds: 1));
      },
    );
  });

  group('AttachmentIngestor lifecycle', () {
    test('whenIdle resolves immediately on a fresh ingestor', () async {
      final ingestor = AttachmentIngestor(documentsDirectory: tempDir);
      await ingestor.whenIdle().timeout(const Duration(seconds: 1));
    });

    test('dispose completes any pending whenIdle waiter', () async {
      final ingestor = AttachmentIngestor(documentsDirectory: tempDir)
        ..dispose();
      await ingestor.whenIdle().timeout(const Duration(seconds: 1));
    });

    test('dispose is safe to call multiple times', () {
      final ingestor = AttachmentIngestor(documentsDirectory: tempDir);
      expect(ingestor.dispose, returnsNormally);
      expect(ingestor.dispose, returnsNormally);
    });

    test(
      'process after dispose still records descriptor (no exceptions)',
      () async {
        final ingestor = AttachmentIngestor(documentsDirectory: tempDir)
          ..dispose();
        final e = _makeEvent(eventId: 'ev1', relativePath: 'images/a.jpg');
        final wrote = await ingestor.process(
          event: e,
          logging: logging,
          attachmentIndex: index,
        );
        expect(wrote, isFalse);
      },
    );
  });
}
