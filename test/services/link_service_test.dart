import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/link_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../widget_test_utils.dart' show setUpTestGetIt, tearDownTestGetIt;

enum _GeneratedLinkOperationKind {
  linkFrom,
  linkTo,
  createLink,
  elapseShort,
  elapsePastReset,
}

typedef _GeneratedLinkPair = ({String fromId, String toId});

class _GeneratedLinkOperation {
  const _GeneratedLinkOperation({
    required this.kind,
    required this.seed,
  });

  final _GeneratedLinkOperationKind kind;
  final int seed;

  String get fromId => 'from-${seed % 5}';

  String get toId => 'to-${seed % 7}';

  Duration get elapsedDuration {
    return switch (kind) {
      _GeneratedLinkOperationKind.elapseShort => Duration(
        seconds: seed % 119,
      ),
      _GeneratedLinkOperationKind.elapsePastReset =>
        LinkService.linkResetDuration + const Duration(milliseconds: 1),
      _ => Duration.zero,
    };
  }

  @override
  String toString() {
    return '_GeneratedLinkOperation(kind: $kind, seed: $seed)';
  }
}

class _GeneratedLinkScenario {
  const _GeneratedLinkScenario({required this.operations});

  final List<_GeneratedLinkOperation> operations;

  @override
  String toString() {
    return '_GeneratedLinkScenario(operations: $operations)';
  }
}

class _GeneratedLinkModel {
  String? linkFromId;
  String? linkToId;
  Duration elapsed = Duration.zero;
  final resetTimes = <Duration>[];
  final calls = <_GeneratedLinkPair>[];

  void linkFrom(String id) {
    linkFromId = id;
    _createLinkIfReady();
  }

  void linkTo(String id) {
    linkToId = id;
    _createLinkIfReady();
  }

  void createLink() {
    _createLinkIfReady();
  }

  void elapse(Duration duration) {
    final target = elapsed + duration;
    if (resetTimes.any((resetTime) => resetTime <= target)) {
      linkFromId = null;
      linkToId = null;
      resetTimes.removeWhere((resetTime) => resetTime <= target);
    }
    elapsed = target;
  }

  void _createLinkIfReady() {
    final fromId = linkFromId;
    final toId = linkToId;
    if (fromId == null || toId == null) return;

    calls.add((fromId: fromId, toId: toId));
    resetTimes.add(elapsed + LinkService.linkResetDuration);
  }
}

extension _AnyGeneratedLinkScenario on glados.Any {
  glados.Generator<_GeneratedLinkOperationKind> get linkOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedLinkOperationKind.values);

  glados.Generator<_GeneratedLinkOperation> get linkOperation =>
      glados.CombinableAny(this).combine2(
        linkOperationKind,
        glados.IntAnys(this).intInRange(0, 10000),
        (_GeneratedLinkOperationKind kind, int seed) =>
            _GeneratedLinkOperation(kind: kind, seed: seed),
      );

  glados.Generator<_GeneratedLinkScenario> get linkScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(0, 35, linkOperation)
          .map(
            (operations) => _GeneratedLinkScenario(operations: operations),
          );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LinkService Tests', () {
    late MockPersistenceLogic mockPersistenceLogic;
    late LinkService linkService;

    setUp(() async {
      mockPersistenceLogic = MockPersistenceLogic();

      // Central GetIt harness with this file's PersistenceLogic mock on top.
      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<PersistenceLogic>(mockPersistenceLogic);
        },
      );

      linkService = LinkService();

      // Stub HapticFeedback to avoid platform channel dependency under fake time
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });

      messenger.setMockMethodCallHandler(SystemChannels.platform, (
        methodCall,
      ) async {
        if (methodCall.method == 'HapticFeedback.vibrate') {
          return null;
        }
        return null;
      });
    });

    tearDown(tearDownTestGetIt);

    glados.Glados(
      glados.any.linkScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('matches generated linking sequence invariants', (scenario) {
      fakeAsync((async) {
        reset(mockPersistenceLogic);
        final service = LinkService();
        final actualCalls = <_GeneratedLinkPair>[];
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((invocation) async {
          actualCalls.add((
            fromId: invocation.namedArguments[#fromId] as String,
            toId: invocation.namedArguments[#toId] as String,
          ));
          return true;
        });

        final model = _GeneratedLinkModel();

        for (final operation in scenario.operations) {
          switch (operation.kind) {
            case _GeneratedLinkOperationKind.linkFrom:
              service.linkFrom(operation.fromId);
              model.linkFrom(operation.fromId);
              async.flushMicrotasks();
            case _GeneratedLinkOperationKind.linkTo:
              service.linkTo(operation.toId);
              model.linkTo(operation.toId);
              async.flushMicrotasks();
            case _GeneratedLinkOperationKind.createLink:
              unawaited(service.createLink());
              model.createLink();
              async.flushMicrotasks();
            case _GeneratedLinkOperationKind.elapseShort:
            case _GeneratedLinkOperationKind.elapsePastReset:
              async.elapse(operation.elapsedDuration);
              model.elapse(operation.elapsedDuration);
              async.flushMicrotasks();
          }
        }

        async
          ..elapse(const Duration(minutes: 3))
          ..flushMicrotasks();

        expect(actualCalls, model.calls, reason: scenario.toString());
      });
    }, tags: 'glados');

    test('createLink does nothing when both IDs are null', () async {
      await linkService.createLink();

      verifyNever(
        () => mockPersistenceLogic.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
        ),
      );
    });

    test('createLink does nothing when only linkFromId is set', () {
      fakeAsync((async) {
        linkService.linkFrom('from-id');

        async.flushMicrotasks();

        verifyNever(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        );
      });
    });

    test('createLink creates link when both IDs are set via linkTo', () {
      fakeAsync((async) {
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        linkService.linkFrom('from-id');
        async.flushMicrotasks();

        linkService.linkTo('to-id');
        async.flushMicrotasks();

        verify(
          () => mockPersistenceLogic.createLink(
            fromId: 'from-id',
            toId: 'to-id',
          ),
        ).called(1);
      });
    });

    test('createLink creates link when both IDs are set via linkFrom', () {
      fakeAsync((async) {
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        linkService.linkTo('to-id');
        async.flushMicrotasks();

        linkService.linkFrom('from-id');
        async.flushMicrotasks();

        verify(
          () => mockPersistenceLogic.createLink(
            fromId: 'from-id',
            toId: 'to-id',
          ),
        ).called(1);
      });
    });
  });
}
