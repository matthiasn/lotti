import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

enum _GeneratedAttachmentOperationKind { record, find }

enum _GeneratedAttachmentEventIdMode { valid, empty, throws }

enum _GeneratedAttachmentPathMode {
  noSlash,
  withSlash,
  empty,
  missing,
  nonString,
  contentThrows,
}

class _GeneratedAttachmentOperation {
  const _GeneratedAttachmentOperation({
    required this.kind,
    required this.eventIdMode,
    required this.pathMode,
    required this.slot,
  });

  final _GeneratedAttachmentOperationKind kind;
  final _GeneratedAttachmentEventIdMode eventIdMode;
  final _GeneratedAttachmentPathMode pathMode;
  final int slot;

  String get eventId => 'event-${slot % 5}';

  String get noSlashPath => 'generated/${slot % 4}.json';

  String get queryPath {
    switch (pathMode) {
      case _GeneratedAttachmentPathMode.noSlash:
        return noSlashPath;
      case _GeneratedAttachmentPathMode.withSlash:
        return '/$noSlashPath';
      case _GeneratedAttachmentPathMode.empty:
        return '';
      case _GeneratedAttachmentPathMode.missing:
      case _GeneratedAttachmentPathMode.nonString:
      case _GeneratedAttachmentPathMode.contentThrows:
        return 'missing/${slot % 4}.json';
    }
  }

  String? get recordPath {
    switch (pathMode) {
      case _GeneratedAttachmentPathMode.noSlash:
        return noSlashPath;
      case _GeneratedAttachmentPathMode.withSlash:
        return '/$noSlashPath';
      case _GeneratedAttachmentPathMode.empty:
        return '';
      case _GeneratedAttachmentPathMode.missing:
      case _GeneratedAttachmentPathMode.nonString:
      case _GeneratedAttachmentPathMode.contentThrows:
        return null;
    }
  }

  String? get recordEventId {
    switch (eventIdMode) {
      case _GeneratedAttachmentEventIdMode.valid:
        return eventId;
      case _GeneratedAttachmentEventIdMode.empty:
      case _GeneratedAttachmentEventIdMode.throws:
        return null;
    }
  }

  String? get canonicalRecordPath {
    final path = recordPath;
    if (path == null || path.isEmpty) return null;
    return path.startsWith('/') ? path : '/$path';
  }

  String? get noSlashRecordPath {
    final path = recordPath;
    if (path == null || path.isEmpty) return null;
    return path.startsWith('/') ? path.substring(1) : path;
  }

  @override
  String toString() {
    return '_GeneratedAttachmentOperation('
        'kind: $kind, '
        'eventIdMode: $eventIdMode, '
        'pathMode: $pathMode, '
        'slot: $slot'
        ')';
  }
}

class _GeneratedAttachmentScenario {
  const _GeneratedAttachmentScenario({required this.operations});

  final List<_GeneratedAttachmentOperation> operations;

  @override
  String toString() => '_GeneratedAttachmentScenario(operations: $operations)';
}

class _ExpectedAttachmentIndex {
  final _byPath = <String, Event>{};
  final _seenEventIds = <String>{};
  final emittedPaths = <String>[];

  bool record(_GeneratedAttachmentOperation operation, Event event) {
    final canonical = operation.canonicalRecordPath;
    final noSlash = operation.noSlashRecordPath;
    if (canonical == null || noSlash == null) return false;

    final eventId = operation.recordEventId;
    if (eventId != null && !_seenEventIds.add(eventId)) {
      return false;
    }

    _byPath[canonical] = event;
    _byPath[noSlash] = event;
    emittedPaths.add(canonical);
    return true;
  }

  Event? find(String relativePath) {
    final alt = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : '/$relativePath';
    return _byPath[relativePath] ?? _byPath[alt];
  }
}

extension _AnyGeneratedAttachmentScenario on glados.Any {
  glados.Generator<_GeneratedAttachmentOperationKind>
  get attachmentOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedAttachmentOperationKind.values);

  glados.Generator<_GeneratedAttachmentEventIdMode> get attachmentEventIdMode =>
      glados.AnyUtils(this).choose(_GeneratedAttachmentEventIdMode.values);

  glados.Generator<_GeneratedAttachmentPathMode> get attachmentPathMode =>
      glados.AnyUtils(this).choose(_GeneratedAttachmentPathMode.values);

  glados.Generator<_GeneratedAttachmentOperation> get attachmentOperation =>
      glados.CombinableAny(this).combine4(
        attachmentOperationKind,
        attachmentEventIdMode,
        attachmentPathMode,
        glados.IntAnys(this).intInRange(0, 8),
        (
          _GeneratedAttachmentOperationKind kind,
          _GeneratedAttachmentEventIdMode eventIdMode,
          _GeneratedAttachmentPathMode pathMode,
          int slot,
        ) => _GeneratedAttachmentOperation(
          kind: kind,
          eventIdMode: eventIdMode,
          pathMode: pathMode,
          slot: slot,
        ),
      );

  glados.Generator<_GeneratedAttachmentScenario> get attachmentScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(1, 36, attachmentOperation)
          .map(
            (operations) =>
                _GeneratedAttachmentScenario(operations: operations),
          );
}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  Event makeEvent({
    required String eventId,
    required String relativePath,
    String mime = 'image/jpeg',
  }) {
    final e = MockEvent();
    when(() => e.eventId).thenReturn(eventId);
    when(() => e.attachmentMimetype).thenReturn(mime);
    when(() => e.content).thenReturn({'relativePath': relativePath});
    return e;
  }

  test(
    'record is idempotent per eventId — repeat observations are no-ops '
    'and emit no log',
    () {
      final logging = MockDomainLogger();
      final index = AttachmentIndex(logging: logging);
      final e = makeEvent(eventId: 'ev1', relativePath: 'images/a.jpg');

      expect(index.record(e), isTrue);
      expect(index.record(e), isFalse);
      expect(index.record(e), isFalse);

      verify(
        () => logging.log(
          any<LogDomain>(),
          any<String>(that: contains('attachmentIndex.record')),
          subDomain: 'attachmentIndex.record',
        ),
      ).called(1);
    },
  );

  test(
    'verboseLogging: false suppresses per-event record/find lines without '
    'changing behaviour',
    () {
      final logging = MockDomainLogger();
      final index = AttachmentIndex(logging: logging, verboseLogging: false);
      final e = makeEvent(eventId: 'ev1', relativePath: 'images/a.jpg');

      expect(index.record(e), isTrue);
      expect(index.record(e), isFalse);
      expect(index.find('images/a.jpg'), isNotNull);
      expect(index.find('images/missing.jpg'), isNull);

      verifyNever(
        () => logging.log(
          any<LogDomain>(),
          any<String>(that: contains('attachmentIndex.')),
          subDomain: any<String>(named: 'subDomain'),
        ),
      );
    },
  );

  test(
    'record does not thrash when multiple events share one relativePath — '
    'each eventId logs exactly once regardless of interleaving',
    () {
      final logging = MockDomainLogger();
      final index = AttachmentIndex(logging: logging);
      final a = makeEvent(eventId: 'A', relativePath: 'audio/x.m4a');
      final b = makeEvent(eventId: 'B', relativePath: 'audio/x.m4a');

      // Interleave observations like catch-up + live-scan would.
      expect(index.record(a), isTrue);
      expect(index.record(b), isTrue);
      expect(index.record(a), isFalse);
      expect(index.record(b), isFalse);
      expect(index.record(a), isFalse);
      expect(index.record(b), isFalse);

      verify(
        () => logging.log(
          any<LogDomain>(),
          any<String>(that: contains('attachmentIndex.record')),
          subDomain: 'attachmentIndex.record',
        ),
      ).called(2);
    },
  );

  test('record and find works with and without leading slash', () {
    final logging = MockDomainLogger();
    final index = AttachmentIndex(logging: logging);
    final e = MockEvent();
    when(() => e.attachmentMimetype).thenReturn('image/jpeg');
    when(() => e.content).thenReturn({'relativePath': 'images/a.jpg'});
    when(() => e.eventId).thenReturn('ev1');

    index.record(e);

    // Hit with slash
    final hit1 = index.find('/images/a.jpg');
    expect(hit1, isNotNull);
    // Hit without slash
    final hit2 = index.find('images/a.jpg');
    expect(hit2, isNotNull);

    // Miss logs a miss
    final miss = index.find('/images/missing.jpg');
    expect(miss, isNull);
    verify(
      () => logging.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: 'attachmentIndex.find',
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  test(
    'pathRecorded stream emits the canonical (leading-slash) path on '
    'each first-time record so subscribers — notably the queue '
    'coordinator — can react the moment an attachment JSON lands',
    () async {
      final logging = MockDomainLogger();
      final index = AttachmentIndex(logging: logging);
      final paths = <String>[];
      final sub = index.pathRecorded.listen(paths.add);

      final e1 = MockEvent();
      when(() => e1.attachmentMimetype).thenReturn('image/jpeg');
      when(() => e1.content).thenReturn({'relativePath': 'images/a.jpg'});
      when(() => e1.eventId).thenReturn('ev1');
      index.record(e1);

      // Even when the caller passes a path without a leading slash,
      // the stream should emit the canonical `/images/a.jpg` form so
      // subscribers have a single shape to match against.
      await pumpEventQueue();
      expect(paths, ['/images/a.jpg']);

      // Idempotency guard: re-observing the same event does not
      // re-emit on the stream. Different event id, same path, only
      // updates the `_byPath` slot — still a mutation, still a
      // signal.
      index.record(e1);
      final e2 = MockEvent();
      when(() => e2.attachmentMimetype).thenReturn('image/jpeg');
      when(() => e2.content).thenReturn({'relativePath': 'images/a.jpg'});
      when(() => e2.eventId).thenReturn('ev2');
      index.record(e2);

      await pumpEventQueue();
      expect(paths, ['/images/a.jpg', '/images/a.jpg']);

      await sub.cancel();
      await index.dispose();
    },
  );

  test(
    'dispose closes the pathRecorded stream so app shutdown / test '
    'teardown does not leak the broadcast controller',
    () async {
      final index = AttachmentIndex(logging: MockDomainLogger());
      var done = false;
      final sub = index.pathRecorded.listen(
        (_) {},
        onDone: () => done = true,
      );
      await index.dispose();
      await sub.cancel();
      expect(done, isTrue);
    },
  );

  glados.Glados(
    glados.any.attachmentScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test(
    'generated record/find sequences preserve idempotency and path aliases',
    (scenario) async {
      final index = AttachmentIndex(
        logging: MockDomainLogger(),
        verboseLogging: false,
      );
      final model = _ExpectedAttachmentIndex();
      final emitted = <String>[];
      final sub = index.pathRecorded.listen(emitted.add);

      Event makeGeneratedEvent(_GeneratedAttachmentOperation operation) {
        final event = MockEvent();
        when(() => event.attachmentMimetype).thenReturn('application/json');
        switch (operation.eventIdMode) {
          case _GeneratedAttachmentEventIdMode.valid:
            when(() => event.eventId).thenReturn(operation.eventId);
          case _GeneratedAttachmentEventIdMode.empty:
            when(() => event.eventId).thenReturn('');
          case _GeneratedAttachmentEventIdMode.throws:
            when(() => event.eventId).thenThrow(StateError('missing event id'));
        }
        switch (operation.pathMode) {
          case _GeneratedAttachmentPathMode.noSlash:
          case _GeneratedAttachmentPathMode.withSlash:
          case _GeneratedAttachmentPathMode.empty:
            when(
              () => event.content,
            ).thenReturn({'relativePath': operation.recordPath});
          case _GeneratedAttachmentPathMode.missing:
            when(() => event.content).thenReturn(<String, dynamic>{});
          case _GeneratedAttachmentPathMode.nonString:
            when(() => event.content).thenReturn({'relativePath': 42});
          case _GeneratedAttachmentPathMode.contentThrows:
            when(() => event.content).thenThrow(StateError('no content'));
        }
        return event;
      }

      try {
        for (final operation in scenario.operations) {
          switch (operation.kind) {
            case _GeneratedAttachmentOperationKind.record:
              final event = makeGeneratedEvent(operation);
              expect(
                index.record(event),
                model.record(operation, event),
                reason: '$scenario\n$operation',
              );
              await Future<void>.value();
            case _GeneratedAttachmentOperationKind.find:
              expect(
                index.find(operation.queryPath),
                same(model.find(operation.queryPath)),
                reason: '$scenario\n$operation',
              );
          }
        }
        await Future<void>.value();
        expect(emitted, model.emittedPaths, reason: '$scenario');
      } finally {
        await sub.cancel();
        await index.dispose();
      }
    },
    tags: 'glados',
  );
}
