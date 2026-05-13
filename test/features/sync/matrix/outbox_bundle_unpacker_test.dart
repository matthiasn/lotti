import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/outbox_bundle_unpacker.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

PreparedSyncEvent _preparedFor(Event event, SyncMessage msg) =>
    PreparedSyncEvent.forTesting(event: event, syncMessage: msg);

enum _GeneratedBundleChildOutcome {
  ok,
  nested,
  nonIoThrow,
  ioThrow,
}

class _GeneratedBundleChild {
  const _GeneratedBundleChild({
    required this.index,
    required this.outcome,
  });

  final int index;
  final _GeneratedBundleChildOutcome outcome;

  String get id => 'generated-child-$index';

  SyncMessage get syncMessage {
    switch (outcome) {
      case _GeneratedBundleChildOutcome.nested:
        return const SyncOutboxBundle(children: []);
      case _GeneratedBundleChildOutcome.ok:
      case _GeneratedBundleChildOutcome.nonIoThrow:
      case _GeneratedBundleChildOutcome.ioThrow:
        return SyncMessage.aiConfigDelete(id: id);
    }
  }

  @override
  String toString() {
    return '_GeneratedBundleChild(index: $index, outcome: $outcome)';
  }
}

class _GeneratedBundleScenario {
  const _GeneratedBundleScenario({required this.children});

  final List<_GeneratedBundleChild> children;

  List<String> expectedPrepareIdsBeforeIo() {
    final ids = <String>[];
    for (final child in children) {
      switch (child.outcome) {
        case _GeneratedBundleChildOutcome.ok:
          ids.add(child.id);
        case _GeneratedBundleChildOutcome.nested:
        case _GeneratedBundleChildOutcome.nonIoThrow:
          break;
        case _GeneratedBundleChildOutcome.ioThrow:
          return ids;
      }
    }
    return ids;
  }

  List<String> expectedApplyIdsBeforeIo() {
    final ids = <String>[];
    for (final child in children) {
      switch (child.outcome) {
        case _GeneratedBundleChildOutcome.ok:
        case _GeneratedBundleChildOutcome.nested:
          ids.add(child.id);
        case _GeneratedBundleChildOutcome.nonIoThrow:
          break;
        case _GeneratedBundleChildOutcome.ioThrow:
          return ids;
      }
    }
    return ids;
  }

  bool get throwsIo => children.any(
    (child) => child.outcome == _GeneratedBundleChildOutcome.ioThrow,
  );

  @override
  String toString() => '_GeneratedBundleScenario(children: $children)';
}

extension _AnyOutboxBundleScenario on glados.Any {
  glados.Generator<_GeneratedBundleChildOutcome> get bundleChildOutcome =>
      glados.AnyUtils(this).choose(_GeneratedBundleChildOutcome.values);

  glados.Generator<_GeneratedBundleScenario> get outboxBundleScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(
            0,
            10,
            bundleChildOutcome,
          )
          .map(
            (outcomes) => _GeneratedBundleScenario(
              children: [
                for (var index = 0; index < outcomes.length; index++)
                  _GeneratedBundleChild(index: index, outcome: outcomes[index]),
              ],
            ),
          );
}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  late MockLoggingService logging;
  late MockEvent event;
  late List<String> traces;
  late OutboxBundleUnpacker unpacker;

  setUp(() {
    logging = MockLoggingService();
    event = MockEvent();
    traces = <String>[];
    when(
      () => logging.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});

    unpacker = OutboxBundleUnpacker(
      loggingService: logging,
      trace: (msg, {subDomain}) => traces.add('$subDomain: $msg'),
    );
  });

  group('prepare', () {
    test(
      'returns the resolved bundle with one prepared child per inline child '
      'in declaration order — bundles preserve outbox ordering on the '
      'receiver side',
      () async {
        const bundle = SyncOutboxBundle(
          children: [
            SyncMessage.aiConfigDelete(id: 'cfg-1'),
            SyncMessage.aiConfigDelete(id: 'cfg-2'),
            SyncMessage.aiConfigDelete(id: 'cfg-3'),
          ],
        );

        final result = await unpacker.prepare(
          event: event,
          msg: bundle,
          resolveSidecar: (_) async {
            fail('sidecar resolution must not run when children are inline');
          },
          prepareChild: (e, m) async => _preparedFor(e, m),
        );

        expect(result, isNotNull);
        final ids = result!.children
            .map((c) => (c.syncMessage as SyncAiConfigDelete).id)
            .toList();
        expect(ids, ['cfg-1', 'cfg-2', 'cfg-3']);
      },
    );

    test(
      'reads the sidecar attachment when the inline children list is empty '
      '— this is the file-backed delivery path used in production for '
      'every non-empty outbox bundle',
      () async {
        const stripped = SyncOutboxBundle(
          children: [],
          jsonPath: '/outbox_bundles/abc-123.json',
        );
        const fullBundle = SyncOutboxBundle(
          children: [
            SyncMessage.aiConfigDelete(id: 'from-disk'),
          ],
          jsonPath: '/outbox_bundles/abc-123.json',
        );

        final result = await unpacker.prepare(
          event: event,
          msg: stripped,
          resolveSidecar: (jsonPath) async {
            expect(jsonPath, '/outbox_bundles/abc-123.json');
            return fullBundle;
          },
          prepareChild: (e, m) async => _preparedFor(e, m),
        );

        expect(result, isNotNull);
        expect(result!.children, hasLength(1));
        expect(
          (result.children.single.syncMessage as SyncAiConfigDelete).id,
          'from-disk',
        );
      },
    );

    test(
      'returns null when the sidecar resolver yields null (download miss '
      'or decode failure) — apply will skip the bundle entirely instead '
      'of recording a partial pass',
      () async {
        const stripped = SyncOutboxBundle(
          children: [],
          jsonPath: '/outbox_bundles/missing.json',
        );

        final result = await unpacker.prepare(
          event: event,
          msg: stripped,
          resolveSidecar: (_) async => null,
          prepareChild: (e, m) async {
            fail('prepareChild must not run when sidecar resolution fails');
          },
        );

        expect(result, isNull);
      },
    );

    test(
      'rethrows FileSystemException raised by a child prepare so the '
      'pipeline can retry the whole bundle later — partial application '
      'would leave gaps in the sequence log',
      () async {
        const bundle = SyncOutboxBundle(
          children: [
            SyncMessage.aiConfigDelete(id: 'will-fail'),
          ],
        );

        await expectLater(
          unpacker.prepare(
            event: event,
            msg: bundle,
            resolveSidecar: (_) async => bundle,
            prepareChild: (_, _) async =>
                throw const FileSystemException('descriptor not yet available'),
          ),
          throwsA(isA<FileSystemException>()),
        );
        verifyNever(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        );
      },
    );

    test(
      'a non-FileSystemException raised by a single child is logged and '
      'skipped; surrounding children still get prepared — per-child fault '
      'isolation matches the contract for individually-delivered messages',
      () async {
        const bundle = SyncOutboxBundle(
          children: [
            SyncMessage.aiConfigDelete(id: 'before'),
            SyncMessage.aiConfigDelete(id: 'boom'),
            SyncMessage.aiConfigDelete(id: 'after'),
          ],
        );

        final result = await unpacker.prepare(
          event: event,
          msg: bundle,
          resolveSidecar: (_) async => bundle,
          prepareChild: (e, m) async {
            final id = (m as SyncAiConfigDelete).id;
            if (id == 'boom') throw StateError('child blew up');
            return _preparedFor(e, m);
          },
        );

        expect(result, isNotNull);
        final ids = result!.children
            .map((c) => (c.syncMessage as SyncAiConfigDelete).id)
            .toList();
        expect(ids, ['before', 'after']);
        verify(
          () => logging.captureException(
            any<Object>(that: isA<StateError>()),
            domain: 'MATRIX_SERVICE',
            subDomain: 'processor.resolve.outboxBundle.child',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test(
      'a nested SyncOutboxBundle child is logged and skipped — defensive '
      'guard against tampered/legacy payloads (the sender forbids nesting '
      'at construction time)',
      () async {
        const bundle = SyncOutboxBundle(
          children: [
            SyncMessage.aiConfigDelete(id: 'good'),
            SyncOutboxBundle(children: []),
            SyncMessage.aiConfigDelete(id: 'also-good'),
          ],
        );

        final result = await unpacker.prepare(
          event: event,
          msg: bundle,
          resolveSidecar: (_) async => bundle,
          prepareChild: (e, m) async => _preparedFor(e, m),
        );

        expect(result, isNotNull);
        final ids = result!.children
            .map((c) => (c.syncMessage as SyncAiConfigDelete).id)
            .toList();
        expect(ids, ['good', 'also-good']);
        // Trace breadcrumb identifies the skipped nested child.
        expect(
          traces.any(
            (t) => t.contains('nested bundles are not supported'),
          ),
          isTrue,
        );
      },
    );

    glados.Glados(
      glados.any.outboxBundleScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'generated child outcomes preserve prepare order and IO rethrow',
      (scenario) async {
        final bundle = SyncOutboxBundle(
          children: [for (final child in scenario.children) child.syncMessage],
        );
        final preparedIds = <String>[];
        final prepareFuture = unpacker.prepare(
          event: event,
          msg: bundle,
          resolveSidecar: (_) async => bundle,
          prepareChild: (e, m) async {
            final id = (m as SyncAiConfigDelete).id;
            final generated = scenario.children.singleWhere(
              (child) => child.id == id,
            );
            switch (generated.outcome) {
              case _GeneratedBundleChildOutcome.ok:
                preparedIds.add(id);
                return _preparedFor(e, m);
              case _GeneratedBundleChildOutcome.nonIoThrow:
                throw StateError('generated child failure');
              case _GeneratedBundleChildOutcome.ioThrow:
                throw const FileSystemException('generated child io');
              case _GeneratedBundleChildOutcome.nested:
                fail('nested bundle children must not be prepared');
            }
          },
        );

        if (scenario.throwsIo) {
          await expectLater(prepareFuture, throwsA(isA<FileSystemException>()));
          expect(preparedIds, scenario.expectedPrepareIdsBeforeIo());
        } else {
          final prepared = await prepareFuture;
          expect(
            prepared!.children
                .map((child) => (child.syncMessage as SyncAiConfigDelete).id)
                .toList(),
            scenario.expectedPrepareIdsBeforeIo(),
          );
        }
      },
      tags: 'glados',
    );
  });

  group('apply', () {
    test(
      'iterates children in order and dispatches each through applyChild — '
      'preserves the bundle ordering exactly as on the wire',
      () async {
        final bundle = PreparedOutboxSyncBundle(
          children: [
            _preparedFor(event, const SyncMessage.aiConfigDelete(id: 'a')),
            _preparedFor(event, const SyncMessage.aiConfigDelete(id: 'b')),
            _preparedFor(event, const SyncMessage.aiConfigDelete(id: 'c')),
          ],
        );

        final applied = <String>[];
        await unpacker.apply(
          bundle: bundle,
          applyChild: (child) async {
            applied.add((child.syncMessage as SyncAiConfigDelete).id);
          },
        );

        expect(applied, ['a', 'b', 'c']);
      },
    );

    test(
      'a child that throws is logged and skipped; the rest of the bundle '
      'still applies — no rollback, no rethrow',
      () async {
        final bundle = PreparedOutboxSyncBundle(
          children: [
            _preparedFor(event, const SyncMessage.aiConfigDelete(id: 'before')),
            _preparedFor(event, const SyncMessage.aiConfigDelete(id: 'boom')),
            _preparedFor(event, const SyncMessage.aiConfigDelete(id: 'after')),
          ],
        );

        final applied = <String>[];
        await unpacker.apply(
          bundle: bundle,
          applyChild: (child) async {
            final id = (child.syncMessage as SyncAiConfigDelete).id;
            if (id == 'boom') throw StateError('apply boom');
            applied.add(id);
          },
        );

        expect(applied, ['before', 'after']);
        verify(
          () => logging.captureException(
            any<Object>(that: isA<StateError>()),
            domain: 'MATRIX_SERVICE',
            subDomain: 'processor.apply.outboxBundle.child',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test(
      'rethrows IOException raised by a child apply so the pipeline can '
      'retry the whole bundle — already-applied earlier children stay '
      'applied (idempotent under VC dedup on the receiver), so a '
      'redelivery is safe',
      () async {
        final bundle = PreparedOutboxSyncBundle(
          children: [
            _preparedFor(event, const SyncMessage.aiConfigDelete(id: 'first')),
            _preparedFor(event, const SyncMessage.aiConfigDelete(id: 'fail')),
            _preparedFor(event, const SyncMessage.aiConfigDelete(id: 'never')),
          ],
        );

        final applied = <String>[];
        await expectLater(
          unpacker.apply(
            bundle: bundle,
            applyChild: (child) async {
              final id = (child.syncMessage as SyncAiConfigDelete).id;
              if (id == 'fail') {
                throw const FileSystemException('descriptor missing');
              }
              applied.add(id);
            },
          ),
          throwsA(isA<FileSystemException>()),
        );
        // The first child applied successfully before the rethrow; the
        // child after the failure is not reached on this pass.
        expect(applied, ['first']);
        verifyNever(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        );
      },
    );

    test(
      'an empty bundle is a no-op — applyChild is never invoked, no log '
      'spam, returns cleanly',
      () async {
        var calls = 0;
        await unpacker.apply(
          bundle: PreparedOutboxSyncBundle(children: const []),
          applyChild: (_) async {
            calls++;
          },
        );

        expect(calls, 0);
        verifyNever(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        );
      },
    );

    glados.Glados(
      glados.any.outboxBundleScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'generated child outcomes preserve apply order and IO rethrow',
      (scenario) async {
        final children = [
          for (final child in scenario.children)
            _preparedFor(event, SyncMessage.aiConfigDelete(id: child.id)),
        ];
        final applied = <String>[];
        final applyFuture = unpacker.apply(
          bundle: PreparedOutboxSyncBundle(children: children),
          applyChild: (child) async {
            final id = (child.syncMessage as SyncAiConfigDelete).id;
            final generated = scenario.children.singleWhere(
              (candidate) => candidate.id == id,
            );
            switch (generated.outcome) {
              case _GeneratedBundleChildOutcome.ok:
              case _GeneratedBundleChildOutcome.nested:
                applied.add(id);
              case _GeneratedBundleChildOutcome.nonIoThrow:
                throw StateError('generated apply failure');
              case _GeneratedBundleChildOutcome.ioThrow:
                throw const FileSystemException('generated apply io');
            }
          },
        );

        if (scenario.throwsIo) {
          await expectLater(applyFuture, throwsA(isA<FileSystemException>()));
        } else {
          await applyFuture;
        }
        expect(applied, scenario.expectedApplyIdsBeforeIo());
      },
      tags: 'glados',
    );
  });
}
