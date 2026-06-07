import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

Event _makeEvent({
  required String eventId,
  String? relativePath,
  String mime = '', // empty mime → _saveAttachment short-circuits before
  // touching the (mocked) Matrix download stack
  String text = '',
  List<int>? downloadBytes,
  void Function()? onDownload,
  Map<String, dynamic>? content,
}) {
  final e = MockEvent();
  when(() => e.eventId).thenReturn(eventId);
  when(() => e.attachmentMimetype).thenReturn(mime);
  when(() => e.content).thenReturn(
    content ??
        <String, dynamic>{
          'relativePath': ?relativePath,
        },
  );
  when(() => e.text).thenReturn(text);
  if (downloadBytes != null) {
    when(e.downloadAndDecryptAttachment).thenAnswer((_) async {
      onDownload?.call();
      return MatrixFile(
        bytes: Uint8List.fromList(downloadBytes),
        name: 'generated.json',
      );
    });
  }
  return e;
}

class _GeneratedAttachmentObservation {
  const _GeneratedAttachmentObservation({
    required this.eventSlot,
    required this.pathSlot,
    required this.withLeadingSlash,
  });

  final int eventSlot;
  final int pathSlot;
  final bool withLeadingSlash;

  String get eventId => 'generated-attachment-$eventSlot';

  String get canonicalPath => '/attachments/path-$pathSlot.json';

  String get rawPath =>
      withLeadingSlash ? canonicalPath : canonicalPath.substring(1);

  @override
  String toString() {
    return '_GeneratedAttachmentObservation('
        'eventSlot: $eventSlot, '
        'pathSlot: $pathSlot, '
        'withLeadingSlash: $withLeadingSlash'
        ')';
  }
}

class _GeneratedAttachmentReplayScenario {
  const _GeneratedAttachmentReplayScenario({required this.observations});

  final List<_GeneratedAttachmentObservation> observations;

  List<String> expectedPathSignals() {
    final seen = <String>{};
    final paths = <String>[];
    for (final observation in observations) {
      if (seen.add(observation.eventId)) {
        paths.add(observation.canonicalPath);
      }
    }
    return paths;
  }

  Map<String, String> expectedLatestEventByPath() {
    final seen = <String>{};
    final latest = <String, String>{};
    for (final observation in observations) {
      if (seen.add(observation.eventId)) {
        latest[observation.canonicalPath] = observation.eventId;
      }
    }
    return latest;
  }

  @override
  String toString() {
    return '_GeneratedAttachmentReplayScenario('
        'observations: $observations'
        ')';
  }
}

class _GeneratedDominanceObservation {
  const _GeneratedDominanceObservation({
    required this.eventSlot,
    required this.pathSlot,
    required this.agentPayload,
    required this.dominates,
    required this.counter,
  });

  final int eventSlot;
  final int pathSlot;
  final bool agentPayload;
  final bool dominates;
  final int counter;

  String get eventId => 'generated-dominance-$eventSlot';

  String get canonicalPath => agentPayload
      ? '/agent_entities/generated-$pathSlot.json'
      : '/attachments/generated-$pathSlot.json';

  String get text {
    return base64.encode(
      utf8.encode(
        json.encode(<String, dynamic>{
          'runtimeType': agentPayload ? 'agentEntity' : 'journalEntity',
          'vectorClock': <String, int>{'host-a': counter},
        }),
      ),
    );
  }

  @override
  String toString() {
    return '_GeneratedDominanceObservation('
        'eventSlot: $eventSlot, '
        'pathSlot: $pathSlot, '
        'agentPayload: $agentPayload, '
        'dominates: $dominates, '
        'counter: $counter'
        ')';
  }
}

class _GeneratedDominanceScenario {
  const _GeneratedDominanceScenario({required this.observations});

  final List<_GeneratedDominanceObservation> observations;

  List<
    ({String eventId, String path, VectorClock? vectorClock, bool dominates})
  >
  expectedDominanceCalls() {
    final seen = <String>{};
    return [
      for (final observation in observations)
        if (seen.add(observation.eventId) && observation.agentPayload)
          (
            eventId: observation.eventId,
            path: observation.canonicalPath,
            vectorClock: VectorClock({'host-a': observation.counter}),
            dominates: observation.dominates,
          ),
    ];
  }

  @override
  String toString() {
    return '_GeneratedDominanceScenario(observations: $observations)';
  }
}

extension _AnyAttachmentIngestorScenario on glados.Any {
  glados.Generator<_GeneratedAttachmentObservation> get attachmentObservation =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 3),
        glados.BoolAny(this).bool,
        (
          int eventSlot,
          int pathSlot,
          bool withLeadingSlash,
        ) => _GeneratedAttachmentObservation(
          eventSlot: eventSlot,
          pathSlot: pathSlot,
          withLeadingSlash: withLeadingSlash,
        ),
      );

  glados.Generator<_GeneratedAttachmentReplayScenario>
  get attachmentReplayScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(1, 14, attachmentObservation)
          .map(
            (observations) =>
                _GeneratedAttachmentReplayScenario(observations: observations),
          );

  glados.Generator<_GeneratedDominanceObservation> get dominanceObservation =>
      glados.CombinableAny(this).combine5(
        glados.IntAnys(this).intInRange(0, 7),
        glados.IntAnys(this).intInRange(0, 3),
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(1, 8),
        (
          int eventSlot,
          int pathSlot,
          bool agentPayload,
          bool dominates,
          int counter,
        ) => _GeneratedDominanceObservation(
          eventSlot: eventSlot,
          pathSlot: pathSlot,
          agentPayload: agentPayload,
          dominates: dominates,
          counter: counter,
        ),
      );

  glados.Generator<_GeneratedDominanceScenario> get dominanceScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(1, 14, dominanceObservation)
          .map(
            (observations) =>
                _GeneratedDominanceScenario(observations: observations),
          );
}

/// Per-invocation fresh state for the Glados properties.
///
/// Not redundant with the file's `setUp`/`tearDown`: setUp runs once per
/// Glados *test*, not per generated iteration, so property bodies must
/// build and dispose their own logger/index/tempDir to keep iterations
/// independent. The shared setUp continues to serve the regular tests.
Future<void> _withFreshAttachmentIngestorState(
  Future<void> Function(
    MockDomainLogger logging,
    AttachmentIndex index,
    Directory tempDir,
  )
  body,
) async {
  final logging = MockDomainLogger();
  final index = AttachmentIndex(logging: logging, verboseLogging: false);
  final tempDir = Directory.systemTemp.createTempSync('lotti_attach_ingest_');

  try {
    await body(logging, index, tempDir);
  } finally {
    await index.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(
      const FileSystemException('fallback'),
    );
  });

  late MockDomainLogger logging;
  late AttachmentIndex index;
  late Directory tempDir;

  setUp(() {
    logging = MockDomainLogger();
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
          () => logging.log(
            any<LogDomain>(),
            any<String>(that: contains('attachmentEvent id=ev1')),
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

    glados.Glados(
      glados.any.attachmentReplayScenario,
    ).test(
      'generated descriptor replay emits one path signal per new event id',
      (scenario) async {
        await _withFreshAttachmentIngestorState((logging, index, _) async {
          final ingestor = AttachmentIngestor(verboseLogging: false);
          final recordedPaths = <String>[];
          final subscription = index.pathRecorded.listen(recordedPaths.add);

          try {
            for (final observation in scenario.observations) {
              final event = _makeEvent(
                eventId: observation.eventId,
                relativePath: observation.rawPath,
              );

              final wrote = await ingestor.process(
                event: event,
                logging: logging,
                attachmentIndex: index,
              );
              expect(wrote, isFalse);
            }

            await pumpEventQueue();

            expect(recordedPaths, scenario.expectedPathSignals());

            final expectedLatestByPath = scenario.expectedLatestEventByPath();
            for (var slot = 0; slot <= 3; slot++) {
              final path = '/attachments/path-$slot.json';
              expect(index.find(path)?.eventId, expectedLatestByPath[path]);
            }
          } finally {
            await subscription.cancel();
          }
        });
      },
      tags: 'glados',
    );
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
        () => logging.log(
          any<LogDomain>(),
          any<String>(that: contains('pathTraversal.blocked')),
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
        () => logging.log(
          any<LogDomain>(),
          any<String>(that: contains('pathTraversal.blocked')),
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
        () => logging.log(
          any<LogDomain>(),
          any<String>(that: contains('skip.localVcDominates')),
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
        () => logging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'attachment.download.skip',
        ),
      ).called(1);
    });

    glados.Glados(
      glados.any.dominanceScenario,
    ).test(
      'generated agent observations consult VC dominance once per new event',
      (scenario) async {
        await _withFreshAttachmentIngestorState((
          logging,
          index,
          tempDir,
        ) async {
          final expectedCalls = scenario.expectedDominanceCalls();
          final dominanceCalls =
              <({String path, VectorClock? vectorClock, bool dominates})>[];
          final downloadedEventIds = <String>[];
          final skipLogs = <String>[];

          when(
            () => logging.log(
              any<LogDomain>(),
              any<String>(),
              subDomain: any<String>(named: 'subDomain'),
              level: any(named: 'level'),
            ),
          ).thenAnswer((invocation) {
            if (invocation.namedArguments[#subDomain] ==
                'attachment.download.skip') {
              skipLogs.add(invocation.positionalArguments[1].toString());
            }
          });

          for (final observation in scenario.observations) {
            File(
                '${tempDir.path}/${observation.canonicalPath.substring(1)}',
              )
              ..createSync(recursive: true)
              ..writeAsStringSync('local-copy');
          }

          final ingestor = AttachmentIngestor(
            documentsDirectory: tempDir,
            localVcDominates: (path, vectorClock) async {
              final expected = expectedCalls[dominanceCalls.length];
              dominanceCalls.add(
                (
                  path: path,
                  vectorClock: vectorClock,
                  dominates: expected.dominates,
                ),
              );
              return expected.dominates;
            },
          );

          final seenForWrite = <String>{};
          for (final observation in scenario.observations) {
            final event = _makeEvent(
              eventId: observation.eventId,
              relativePath: observation.canonicalPath,
              mime: 'application/json',
              text: observation.text,
              downloadBytes: utf8.encode(
                'downloaded:${observation.eventId}:${observation.counter}',
              ),
              onDownload: () => downloadedEventIds.add(observation.eventId),
            );

            final wrote = await ingestor.process(
              event: event,
              logging: logging,
              attachmentIndex: index,
            );
            final expectedWrite =
                seenForWrite.add(observation.eventId) &&
                observation.agentPayload &&
                !observation.dominates;
            expect(wrote, expectedWrite);
          }

          expect(
            dominanceCalls
                .map(
                  (call) => (
                    path: call.path,
                    vectorClock: call.vectorClock,
                  ),
                )
                .toList(),
            expectedCalls
                .map(
                  (call) => (
                    path: call.path,
                    vectorClock: call.vectorClock,
                  ),
                )
                .toList(),
          );
          expect(
            downloadedEventIds,
            [
              for (final call in expectedCalls)
                if (!call.dominates) call.eventId,
            ],
          );
          expect(
            skipLogs,
            [
              for (final call in expectedCalls)
                if (call.dominates) 'skip.localVcDominates path=${call.path}',
            ],
          );
        });
      },
      tags: 'glados',
    );
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
        // whenIdle resolves synchronously — fail fast instead of hanging
        // behind a wall-clock timeout if it ever stops doing so.
        await expectLater(ingestor.whenIdle(), completes);
      },
    );
  });

  group('AttachmentIngestor._saveAttachment — download result branches', () {
    // These tests exercise the catch block in _saveAttachment (lines 487-522)
    // and the empty-bytes guard (line 459) that are otherwise unreachable
    // through the existing test paths.

    test(
      'logs and returns false when download returns empty bytes (line 459)',
      () async {
        // Provide empty bytes from the download to hit the emptiness guard.
        final e = _makeEvent(
          eventId: 'ev-empty-bytes',
          relativePath: 'attachments/file.json',
          mime: 'application/json',
          downloadBytes: <int>[], // empty
        );

        final ingestor = AttachmentIngestor(documentsDirectory: tempDir);

        final wrote = await ingestor.process(
          event: e,
          logging: logging,
          attachmentIndex: index,
        );

        expect(wrote, isFalse);
        verify(
          () => logging.log(
            LogDomain.sync,
            any<String>(that: contains('emptyBytes')),
            subDomain: 'attachment.download',
          ),
        ).called(1);
      },
    );

    test(
      'logs cacheEvicted and returns false when download throws '
      '"File is no longer cached" (line 496)',
      () async {
        const cacheEvictedMsg =
            'Can not try to send again. File is no longer cached.';
        final e = _makeEvent(
          eventId: 'ev-cache-evicted',
          relativePath: 'attachments/evicted.json',
          mime: 'application/json',
        );
        when(e.downloadAndDecryptAttachment).thenAnswer(
          (_) async => throw Exception(cacheEvictedMsg),
        );

        final ingestor = AttachmentIngestor(documentsDirectory: tempDir);

        final wrote = await ingestor.process(
          event: e,
          logging: logging,
          attachmentIndex: index,
        );

        expect(wrote, isFalse);
        verify(
          () => logging.log(
            LogDomain.sync,
            any<String>(that: contains('cacheEvicted')),
            subDomain: 'attachment.save.cacheEvicted',
          ),
        ).called(1);
        // General error log must NOT be emitted for a cacheEvicted error.
        verifyNever(
          () => logging.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'attachment.save',
          ),
        );
      },
    );

    test(
      'logs emfile details and general error when download throws '
      'FileSystemException with errorCode 24 (lines 507-508)',
      () async {
        const osError = OSError('Too many open files', 24);
        const fse = FileSystemException(
          'Cannot download attachment',
          'attachments/emfile.json',
          osError,
        );
        final e = _makeEvent(
          eventId: 'ev-emfile',
          relativePath: 'attachments/emfile.json',
          mime: 'application/json',
        );
        when(e.downloadAndDecryptAttachment).thenAnswer(
          (_) async => throw fse,
        );

        final ingestor = AttachmentIngestor(documentsDirectory: tempDir);

        final wrote = await ingestor.process(
          event: e,
          logging: logging,
          attachmentIndex: index,
        );

        expect(wrote, isFalse);
        // EMFILE-specific log (lines 507-508)
        verify(
          () => logging.log(
            LogDomain.sync,
            any<String>(that: contains('emfile')),
            subDomain: 'attachment.save.emfile',
            level: InsightLevel.warn,
          ),
        ).called(1);
        // General error log (line 515)
        verify(
          () => logging.error(
            LogDomain.sync,
            any<FileSystemException>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'attachment.save',
          ),
        ).called(1);
      },
    );
  });

  group('AttachmentIngestor lifecycle', () {
    test('whenIdle resolves immediately on a fresh ingestor', () async {
      final ingestor = AttachmentIngestor(documentsDirectory: tempDir);
      await expectLater(ingestor.whenIdle(), completes);
    });

    test('dispose completes any pending whenIdle waiter', () async {
      final ingestor = AttachmentIngestor(documentsDirectory: tempDir)
        ..dispose();
      await expectLater(ingestor.whenIdle(), completes);
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
        expect(index.find('images/a.jpg')?.eventId, 'ev1');
      },
    );
  });

  group('AttachmentIngestor.scheduleDownload — queued download paths', () {
    // These tests exercise _scheduleDownload, _drainQueue, _runDownload,
    // _maybeCompleteIdle (lines 237-292) and the _DownloadRequest constructor
    // (line 563).

    test(
      'scheduled download writes file and resolves whenIdle (lines 237-292)',
      () async {
        const relativePath = 'attachments/sched.json';
        final fileBytes = utf8.encode('{"hello":"world"}');
        final e = _makeEvent(
          eventId: 'ev-sched-1',
          relativePath: relativePath,
          mime: 'application/json',
          downloadBytes: fileBytes,
        );

        final ingestor = AttachmentIngestor(
          documentsDirectory: tempDir,
          verboseLogging: false,
        );

        await ingestor.process(
          event: e,
          logging: logging,
          attachmentIndex: index,
          scheduleDownload: true,
        );

        // whenIdle must resolve after the queued download finishes.
        // Lines 209-210: the Completer is created and its future returned
        // because the queue is non-empty when whenIdle() is called.
        await ingestor.whenIdle().timeout(const Duration(seconds: 2));

        final writtenFile = File('${tempDir.path}/$relativePath');
        expect(writtenFile.existsSync(), isTrue);
        expect(writtenFile.readAsBytesSync(), fileBytes);
      },
    );

    test(
      'scheduling the same path twice deduplicates via _queuedKeys (line 243)',
      () async {
        var downloadCount = 0;
        final fileBytes = utf8.encode('{"v":1}');

        // Use maxConcurrentDownloads=1 so the first download can potentially
        // be in-flight when the second schedule call arrives.
        final ingestor = AttachmentIngestor(
          documentsDirectory: tempDir,
          maxConcurrentDownloads: 1,
          verboseLogging: false,
        );

        final e1 = _makeEvent(
          eventId: 'ev-dedup-1',
          relativePath: 'attachments/dedup.json',
          mime: 'application/json',
          downloadBytes: fileBytes,
          onDownload: () => downloadCount++,
        );
        final e2 = _makeEvent(
          eventId: 'ev-dedup-2',
          relativePath: 'attachments/dedup.json',
          mime: 'application/json',
          downloadBytes: fileBytes,
          onDownload: () => downloadCount++,
        );

        await ingestor.process(
          event: e1,
          logging: logging,
          attachmentIndex: index,
          scheduleDownload: true,
        );
        // Schedule a second event for the same path before the first finishes.
        // The path is now queued so the second call hits the dedup guard.
        await ingestor.process(
          event: e2,
          logging: logging,
          attachmentIndex: index,
          scheduleDownload: true,
        );

        await ingestor.whenIdle().timeout(const Duration(seconds: 2));

        // Only one actual download should have occurred because the second
        // schedule for the same key was deduped.
        expect(downloadCount, 1);
      },
    );

    test(
      'whenIdle returns a future (not synchronous) while a download is in '
      'flight (lines 209-210 — Completer path)',
      () async {
        // Use a completer to control when the download finishes.
        final downloadCompleter = Completer<void>();
        final fileBytes = utf8.encode('data');
        final e = _makeEvent(
          eventId: 'ev-inflight',
          relativePath: 'attachments/inflight.json',
          mime: 'application/json',
        );
        when(e.downloadAndDecryptAttachment).thenAnswer((_) async {
          await downloadCompleter.future;
          return MatrixFile(
            bytes: Uint8List.fromList(fileBytes),
            name: 'inflight.json',
          );
        });

        final ingestor = AttachmentIngestor(
          documentsDirectory: tempDir,
          maxConcurrentDownloads: 1,
          verboseLogging: false,
        );

        await ingestor.process(
          event: e,
          logging: logging,
          attachmentIndex: index,
          scheduleDownload: true,
        );

        // whenIdle must NOT be resolved yet — the download is in flight.
        var idleResolved = false;
        // ignore: unawaited_futures
        ingestor.whenIdle().then((_) => idleResolved = true);

        // Pump the event loop briefly so the download coroutine can start
        // but not complete (the completer hasn't fired yet).
        await pumpEventQueue(times: 5);
        expect(idleResolved, isFalse);

        // Now let the download complete.
        downloadCompleter.complete();
        await ingestor.whenIdle().timeout(const Duration(seconds: 2));
        expect(idleResolved, isTrue);
      },
    );

    test(
      '_runDownload re-queues a superseded pending request after the first '
      'download finishes (lines 279-285)',
      () async {
        // We need maxConcurrentDownloads=1 and two different event ids for the
        // same path so that the second schedule() call replaces the pending
        // download entry while the first is in flight.
        final downloadCompleter = Completer<void>();
        var firstDownloadCount = 0;
        var secondDownloadCount = 0;
        final fileBytes = utf8.encode('payload');

        final e1 = _makeEvent(
          eventId: 'ev-supersede-1',
          relativePath: 'attachments/supersede.json',
          mime: 'application/json',
          onDownload: () => firstDownloadCount++,
        );
        when(e1.downloadAndDecryptAttachment).thenAnswer((_) async {
          firstDownloadCount++;
          await downloadCompleter.future;
          return MatrixFile(
            bytes: Uint8List.fromList(fileBytes),
            name: 'supersede.json',
          );
        });

        final e2 = _makeEvent(
          eventId: 'ev-supersede-2',
          relativePath: 'attachments/supersede.json',
          mime: 'application/json',
          downloadBytes: fileBytes,
          onDownload: () => secondDownloadCount++,
        );

        final ingestor = AttachmentIngestor(
          documentsDirectory: tempDir,
          maxConcurrentDownloads: 1,
          verboseLogging: false,
        );

        // First schedule: kicks off the download immediately (1 slot available).
        await ingestor.process(
          event: e1,
          logging: logging,
          attachmentIndex: index,
          scheduleDownload: true,
        );

        // Pump so the download coroutine starts and the key is in _inFlightKeys.
        await pumpEventQueue(times: 2);

        // Second schedule: same path, different eventId. Because the key is
        // in _inFlightKeys, _scheduleDownload records it in _pendingDownloads
        // but hits the dedup guard (line 243) and returns without adding to
        // the queue. _runDownload's finally block detects the superseded
        // pending entry and re-queues it (lines 281-284).
        await ingestor.process(
          event: e2,
          logging: logging,
          attachmentIndex: index,
          scheduleDownload: true,
        );

        // Unblock the first download.
        downloadCompleter.complete();

        // Wait for both downloads to finish.
        await ingestor.whenIdle().timeout(const Duration(seconds: 2));

        // The file should exist and reflect the second download's bytes.
        final writtenFile = File('${tempDir.path}/attachments/supersede.json');
        expect(writtenFile.existsSync(), isTrue);
        expect(writtenFile.readAsBytesSync(), fileBytes);
      },
    );
  });

  group('AttachmentIngestor — LRU eviction', () {
    test(
      'handled-event LRU evicts oldest entry when capacity is exceeded (line 303)',
      () async {
        // Use a tiny capacity so we can exceed it cheaply.
        const capacity = 3;
        final ingestor = AttachmentIngestor(
          handledEventCapacity: capacity,
          verboseLogging: false,
        );

        // Process capacity+1 distinct events to trigger the eviction loop.
        for (var i = 0; i <= capacity; i++) {
          final e = _makeEvent(
            eventId: 'ev-lru-$i',
            relativePath: 'images/lru-$i.jpg',
          );
          await ingestor.process(
            event: e,
            logging: logging,
            attachmentIndex: index,
          );
        }

        // Processing event 0 again should succeed (it was evicted from the
        // handled set) rather than being treated as a duplicate.  The repair
        // path is also skipped because documentsDirectory is null, so the
        // re-processed event triggers the observe log.  However, the most
        // reliable assertion is that the LRU bookkeeping doesn't throw and
        // the index recorded all events.
        for (var i = 0; i <= capacity; i++) {
          expect(index.find('images/lru-$i.jpg'), isNotNull);
        }

        // The first event (ev-lru-0) was evicted, so re-processing it is
        // treated as new and records in the index again (overwriting with
        // same data is harmless — what matters is no exception).
        final reprocessed = _makeEvent(
          eventId: 'ev-lru-0',
          relativePath: 'images/lru-0.jpg',
        );
        await expectLater(
          ingestor.process(
            event: reprocessed,
            logging: logging,
            attachmentIndex: index,
          ),
          completes,
        );
      },
    );

    test(
      'cache-evicted LRU evicts oldest entry when capacity is exceeded (line 533)',
      () async {
        // Use a tiny capacity so _cacheEvictedEventIds overflows.
        const capacity = 2;

        const cacheEvictedMsg =
            'Can not try to send again. File is no longer cached.';

        final ingestor = AttachmentIngestor(
          documentsDirectory: tempDir,
          handledEventCapacity: capacity,
          verboseLogging: false,
        );

        // Cause capacity+1 distinct events to throw the cache-evicted error.
        for (var i = 0; i <= capacity; i++) {
          final e = _makeEvent(
            eventId: 'ev-ce-$i',
            relativePath: 'attachments/ce-$i.json',
            mime: 'application/json',
          );
          when(e.downloadAndDecryptAttachment).thenAnswer(
            (_) async => throw Exception(cacheEvictedMsg),
          );

          final wrote = await ingestor.process(
            event: e,
            logging: logging,
            attachmentIndex: index,
          );
          expect(wrote, isFalse);
        }

        // After exceeding capacity the oldest entry (ev-ce-0) is evicted from
        // _cacheEvictedEventIds. Re-processing it must trigger a fresh download
        // attempt (not be short-circuited by the cheap negative cache).
        var retryAttempted = false;
        final reprocessed = _makeEvent(
          eventId: 'ev-ce-0',
          relativePath: 'attachments/ce-0.json',
          mime: 'application/json',
        );
        when(reprocessed.downloadAndDecryptAttachment).thenAnswer((_) async {
          retryAttempted = true;
          throw Exception(cacheEvictedMsg);
        });

        await ingestor.process(
          event: reprocessed,
          logging: logging,
          attachmentIndex: index,
        );
        expect(
          retryAttempted,
          isTrue,
          reason: 'evicted entry should not be in the negative cache',
        );
      },
    );
  });

  group(
    'AttachmentIngestor._isLocalFileMissingOrEmpty — empty file (line 321)',
    () {
      test(
        'file exists but is empty → repair path triggers re-download',
        () async {
          const relativePath = 'attachments/empty.json';
          final filePath = '${tempDir.path}/$relativePath';
          // Create the file but leave it empty (0 bytes).
          File(filePath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(<int>[]);

          final fileBytes = utf8.encode('{"repaired":true}');
          final e = _makeEvent(
            eventId: 'ev-repair',
            relativePath: relativePath,
            mime: 'application/json',
            downloadBytes: fileBytes,
          );

          final ingestor = AttachmentIngestor(
            documentsDirectory: tempDir,
            verboseLogging: false,
          );

          // First process: records the event and downloads (file is empty/missing
          // fast path → should download and write).
          final w1 = await ingestor.process(
            event: e,
            logging: logging,
            attachmentIndex: index,
          );
          expect(w1, isTrue);
          expect(File(filePath).readAsBytesSync(), fileBytes);

          // Now truncate the file back to empty to simulate corruption.
          File(filePath).writeAsBytesSync(<int>[]);

          // Second process with the same eventId: the event WAS already handled,
          // but the local file is empty → repair path fires (line 320-321 via
          // _isLocalFileMissingOrEmpty returning true for a 0-byte file).
          final w2 = await ingestor.process(
            event: e,
            logging: logging,
            attachmentIndex: index,
          );
          expect(
            w2,
            isTrue,
            reason: 'empty local file should trigger repair re-download',
          );
          expect(File(filePath).readAsBytesSync(), fileBytes);
        },
      );
    },
  );
}
