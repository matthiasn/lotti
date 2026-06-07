import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/actor/verification_handler.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

enum _GeneratedVerificationDirection {
  incoming,
  outgoing,
}

enum _GeneratedVerificationStep {
  request,
  ready,
  key,
}

enum _GeneratedVerificationEmojiMode {
  empty,
  one,
  two,
  throws,
}

class _GeneratedVerificationObservation {
  const _GeneratedVerificationObservation({
    required this.step,
    required this.done,
    required this.canceled,
    required this.emojiMode,
  });

  final _GeneratedVerificationStep step;
  final bool done;
  final bool canceled;
  final _GeneratedVerificationEmojiMode emojiMode;

  String get wireStep {
    return switch (step) {
      _GeneratedVerificationStep.request => 'm.key.verification.request',
      _GeneratedVerificationStep.ready => 'm.key.verification.ready',
      _GeneratedVerificationStep.key => 'm.key.verification.key',
    };
  }

  List<KeyVerificationEmoji> get emojis {
    return switch (emojiMode) {
      _GeneratedVerificationEmojiMode.empty => <KeyVerificationEmoji>[],
      _GeneratedVerificationEmojiMode.one => <KeyVerificationEmoji>[
        KeyVerificationEmoji(1),
      ],
      _GeneratedVerificationEmojiMode.two => <KeyVerificationEmoji>[
        KeyVerificationEmoji(1),
        KeyVerificationEmoji(2),
      ],
      _GeneratedVerificationEmojiMode.throws => <KeyVerificationEmoji>[],
    };
  }

  List<String> get visibleEmojis {
    if (step != _GeneratedVerificationStep.key ||
        emojiMode == _GeneratedVerificationEmojiMode.throws) {
      return const <String>[];
    }
    return emojis.map((emoji) => emoji.emoji).toList(growable: false);
  }

  String get emojiKey => visibleEmojis.join('|');

  bool get terminal => done || canceled;

  @override
  String toString() {
    return '_GeneratedVerificationObservation('
        'step: $step, '
        'done: $done, '
        'canceled: $canceled, '
        'emojiMode: $emojiMode'
        ')';
  }
}

class _GeneratedVerificationEvent {
  const _GeneratedVerificationEvent({
    required this.direction,
    required this.observation,
  });

  final _GeneratedVerificationDirection direction;
  final _GeneratedVerificationObservation observation;

  String get wireDirection => switch (direction) {
    _GeneratedVerificationDirection.incoming => 'incoming',
    _GeneratedVerificationDirection.outgoing => 'outgoing',
  };
}

class _GeneratedVerificationScenario {
  const _GeneratedVerificationScenario({
    required this.direction,
    required this.initial,
    required this.updates,
  });

  final _GeneratedVerificationDirection direction;
  final _GeneratedVerificationObservation initial;
  final List<_GeneratedVerificationObservation> updates;

  String get wireDirection => switch (direction) {
    _GeneratedVerificationDirection.incoming => 'incoming',
    _GeneratedVerificationDirection.outgoing => 'outgoing',
  };

  List<_GeneratedVerificationEvent> expectedEvents() {
    final expected = <_GeneratedVerificationEvent>[
      _GeneratedVerificationEvent(direction: direction, observation: initial),
    ];
    if (initial.terminal) {
      return expected;
    }

    var lastStep = initial.wireStep;
    var lastDone = initial.done;
    var lastCanceled = initial.canceled;
    var lastEmojis = initial.emojiKey;
    var active = true;

    for (final update in updates) {
      if (!active) {
        break;
      }
      final changed =
          lastStep != update.wireStep ||
          lastDone != update.done ||
          lastCanceled != update.canceled ||
          lastEmojis != update.emojiKey;
      if (changed) {
        expected.add(
          _GeneratedVerificationEvent(
            direction: direction,
            observation: update,
          ),
        );
        lastStep = update.wireStep;
        lastDone = update.done;
        lastCanceled = update.canceled;
        lastEmojis = update.emojiKey;
      }
      if (update.terminal) {
        active = false;
      }
    }

    return expected;
  }

  bool get expectedActive {
    if (initial.terminal) {
      return false;
    }
    for (final update in updates) {
      if (update.terminal) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() {
    return '_GeneratedVerificationScenario('
        'direction: $direction, '
        'initial: $initial, '
        'updates: $updates'
        ')';
  }
}

extension _AnyGeneratedVerificationScenario on glados.Any {
  glados.Generator<_GeneratedVerificationDirection> get verificationDirection =>
      glados.AnyUtils(this).choose(_GeneratedVerificationDirection.values);

  glados.Generator<_GeneratedVerificationStep> get verificationStep =>
      glados.AnyUtils(this).choose(_GeneratedVerificationStep.values);

  glados.Generator<_GeneratedVerificationEmojiMode> get verificationEmojiMode =>
      glados.AnyUtils(this).choose(_GeneratedVerificationEmojiMode.values);

  glados.Generator<_GeneratedVerificationObservation>
  get verificationObservation => glados.CombinableAny(this).combine4(
    verificationStep,
    glados.BoolAny(this).bool,
    glados.BoolAny(this).bool,
    verificationEmojiMode,
    (
      _GeneratedVerificationStep step,
      bool done,
      bool canceled,
      _GeneratedVerificationEmojiMode emojiMode,
    ) => _GeneratedVerificationObservation(
      step: step,
      done: done,
      canceled: canceled,
      emojiMode: emojiMode,
    ),
  );

  glados.Generator<_GeneratedVerificationScenario> get verificationScenario =>
      glados.CombinableAny(this).combine3(
        verificationDirection,
        verificationObservation,
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 10, verificationObservation),
        (
          _GeneratedVerificationDirection direction,
          _GeneratedVerificationObservation initial,
          List<_GeneratedVerificationObservation> updates,
        ) => _GeneratedVerificationScenario(
          direction: direction,
          initial: initial,
          updates: updates,
        ),
      );
}

class _VerificationProbe {
  _VerificationProbe(this.observation) {
    when(() => verification.lastStep).thenAnswer((_) => observation.wireStep);
    when(() => verification.isDone).thenAnswer((_) => observation.done);
    when(() => verification.canceled).thenAnswer((_) => observation.canceled);
    when(() => verification.sasEmojis).thenAnswer((_) {
      if (observation.emojiMode == _GeneratedVerificationEmojiMode.throws) {
        throw StateError('generated emoji failure');
      }
      return observation.emojis;
    });
    when(() => verification.onUpdate).thenAnswer((_) => _previousOnUpdate);
    when(() => verification.onUpdate = any()).thenAnswer((invocation) {
      currentOnUpdate =
          invocation.positionalArguments.first as void Function()?;
      return null;
    });
    when(verification.cancel).thenAnswer((_) async {});
  }

  final verification = MockKeyVerification();

  void _previousOnUpdate() {}

  _GeneratedVerificationObservation observation;
  void Function()? currentOnUpdate;

  void apply(_GeneratedVerificationObservation next) {
    observation = next;
    currentOnUpdate?.call();
  }
}

void main() {
  group('VerificationHandler', () {
    glados.Glados(
      glados.any.verificationScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'generated verification observations emit only modelled state changes',
      (scenario) async {
        final events = <Map<String, Object?>>[];
        final probe = _VerificationProbe(scenario.initial);
        final handler = VerificationHandler(
          onStateChanged: events.add,
          pollInterval: const Duration(days: 1),
        );

        try {
          switch (scenario.direction) {
            case _GeneratedVerificationDirection.incoming:
              handler.trackIncoming(probe.verification);
            case _GeneratedVerificationDirection.outgoing:
              handler.trackOutgoing(probe.verification);
          }

          scenario.updates.forEach(probe.apply);

          final expected = scenario.expectedEvents();
          expect(events, hasLength(expected.length));
          for (var index = 0; index < expected.length; index++) {
            final actual = events[index];
            final expectedEvent = expected[index];
            expect(actual['event'], 'verificationState');
            expect(actual['direction'], expectedEvent.wireDirection);
            expect(actual['step'], expectedEvent.observation.wireStep);
            expect(actual['isDone'], expectedEvent.observation.done);
            expect(actual['isCanceled'], expectedEvent.observation.canceled);
            expect(actual['emojis'], expectedEvent.observation.visibleEmojis);
          }

          final snapshot = handler.snapshot();
          switch (scenario.direction) {
            case _GeneratedVerificationDirection.incoming:
              expect(snapshot['hasIncoming'], scenario.expectedActive);
              expect(snapshot['hasOutgoing'], isFalse);
            case _GeneratedVerificationDirection.outgoing:
              expect(snapshot['hasOutgoing'], scenario.expectedActive);
              expect(snapshot['hasIncoming'], isFalse);
          }
        } finally {
          await handler.dispose();
        }
      },
      tags: 'glados',
    );

    test('tracks incoming verification and emits events', () {
      final events = <Map<String, Object?>>[];
      final verification = MockKeyVerification();
      final onUpdateHistory = <void Function()?>[];

      void previousOnUpdate() {}
      when(
        () => verification.lastStep,
      ).thenReturn('m.key.verification.request');
      when(() => verification.isDone).thenReturn(false);
      when(() => verification.canceled).thenReturn(false);
      when(() => verification.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
      when(() => verification.onUpdate).thenAnswer((_) => previousOnUpdate);
      when(() => verification.onUpdate = any()).thenAnswer((invocation) {
        final next = invocation.positionalArguments.first as void Function()?;
        onUpdateHistory.add(next);
        return null;
      });
      when(verification.cancel).thenAnswer(
        (_) async => Future<void>.value(),
      );

      final handler = VerificationHandler(
        onStateChanged: events.add,
        pollInterval: Duration.zero,
      );
      addTearDown(handler.dispose);

      handler.trackIncoming(verification);

      expect(handler.snapshot()['hasIncoming'], isTrue);
      expect(events, hasLength(1));
      expect(events.last['event'], 'verificationState');
      expect(events.last['direction'], 'incoming');
      expect(events.last['step'], 'm.key.verification.request');
      expect(events.last['isDone'], isFalse);
      expect(onUpdateHistory, isNotEmpty);
    });

    test('emits updates when verification step changes', () {
      final events = <Map<String, Object?>>[];
      final verification = MockKeyVerification();

      var done = false;
      var step = 'm.key.verification.ready';

      void Function()? capturedOnUpdate;
      when(() => verification.lastStep).thenAnswer((_) => step);
      when(() => verification.isDone).thenAnswer((_) => done);
      when(() => verification.canceled).thenReturn(false);
      when(
        () => verification.sasEmojis,
      ).thenAnswer((_) => <KeyVerificationEmoji>[]);
      when(() => verification.onUpdate).thenAnswer((_) => capturedOnUpdate);
      when(() => verification.onUpdate = any()).thenAnswer((invocation) {
        capturedOnUpdate =
            invocation.positionalArguments.first as void Function()?;
        return null;
      });
      when(verification.cancel).thenAnswer(
        (_) async => Future<void>.value(),
      );

      final handler = VerificationHandler(
        onStateChanged: events.add,
        pollInterval: Duration.zero,
      );
      addTearDown(handler.dispose);

      handler.trackIncoming(verification);
      expect(events, hasLength(1));

      step = 'm.key.verification.key';
      capturedOnUpdate?.call();
      expect(events, hasLength(2));
      expect(events.last['step'], 'm.key.verification.key');

      done = true;
      capturedOnUpdate?.call();
      expect(events, hasLength(3));
      expect(events.last['isDone'], isTrue);
      expect(handler.snapshot()['hasIncoming'], isFalse);
    });

    test('acceptVerification requires active incoming verification', () async {
      final verification = MockKeyVerification();
      final handler = VerificationHandler(
        onStateChanged: (_) {},
        pollInterval: Duration.zero,
      );
      addTearDown(handler.dispose);

      when(
        verification.acceptVerification,
      ).thenAnswer((_) async => Future<void>.value());
      when(() => verification.lastStep).thenReturn('m.key.verification.ready');
      when(() => verification.isDone).thenReturn(false);
      when(() => verification.canceled).thenReturn(false);
      when(() => verification.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
      when(() => verification.onUpdate).thenReturn(null);
      when(() => verification.onUpdate = any()).thenReturn(null);
      when(verification.cancel).thenAnswer(
        (_) async => Future<void>.value(),
      );

      await expectLater(
        handler.acceptVerification,
        throwsA(
          predicate(
            (Object e) =>
                e is StateError &&
                e.message == 'No incoming verification to accept',
          ),
        ),
      );

      handler.trackIncoming(verification);
      await handler.acceptVerification();
      verify(verification.acceptVerification).called(1);
    });

    test('acceptSas requires an active verification', () async {
      final handler = VerificationHandler(
        onStateChanged: (_) {},
        pollInterval: Duration.zero,
      );
      addTearDown(handler.dispose);

      await expectLater(
        handler.acceptSas,
        throwsA(
          predicate(
            (Object e) =>
                e is StateError &&
                e.message == 'No active verification for acceptSas',
          ),
        ),
      );

      final verification = MockKeyVerification();
      when(verification.acceptSas).thenAnswer((_) async {});
      when(() => verification.lastStep).thenReturn('m.key.verification.key');
      when(() => verification.isDone).thenReturn(false);
      when(() => verification.canceled).thenReturn(false);
      when(() => verification.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
      when(() => verification.onUpdate).thenReturn(null);
      when(() => verification.onUpdate = any()).thenReturn(null);
      when(verification.cancel).thenAnswer(
        (_) async => Future<void>.value(),
      );

      handler.trackIncoming(verification);
      await handler.acceptSas();
      verify(verification.acceptSas).called(1);
    });

    test('cancel clears active verifications and restores callbacks', () async {
      final events = <Map<String, Object?>>[];
      final incoming = MockKeyVerification();
      final outgoing = MockKeyVerification();

      void Function()? incomingPrevious;
      void Function()? incomingCurrent;
      void Function()? outgoingPrevious;
      void Function()? outgoingCurrent;

      when(() => incoming.lastStep).thenReturn('m.key.verification.ready');
      when(() => incoming.isDone).thenReturn(false);
      when(() => incoming.canceled).thenReturn(false);
      when(() => incoming.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
      when(incoming.cancel).thenAnswer((_) async => Future<void>.value());
      incomingPrevious = () {};
      when(() => incoming.onUpdate).thenAnswer((_) => incomingPrevious);
      when(() => incoming.onUpdate = any()).thenAnswer((invocation) {
        incomingCurrent =
            invocation.positionalArguments.first as void Function()?;
        return null;
      });

      when(() => outgoing.lastStep).thenReturn('m.key.verification.ready');
      when(() => outgoing.isDone).thenReturn(false);
      when(() => outgoing.canceled).thenReturn(false);
      when(() => outgoing.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
      when(outgoing.cancel).thenAnswer((_) async => Future<void>.value());
      outgoingPrevious = () {};
      when(() => outgoing.onUpdate).thenAnswer((_) => outgoingPrevious);
      when(() => outgoing.onUpdate = any()).thenAnswer((invocation) {
        outgoingCurrent =
            invocation.positionalArguments.first as void Function()?;
        return null;
      });

      final handler = VerificationHandler(
        onStateChanged: events.add,
        pollInterval: Duration.zero,
      );
      addTearDown(handler.dispose);

      handler
        ..trackIncoming(incoming)
        ..trackOutgoing(outgoing);

      expect(handler.snapshot()['hasIncoming'], isTrue);
      expect(handler.snapshot()['hasOutgoing'], isTrue);

      await handler.cancel();

      expect(handler.snapshot()['hasIncoming'], isFalse);
      expect(handler.snapshot()['hasOutgoing'], isFalse);
      expect(incomingCurrent, same(incomingPrevious));
      expect(outgoingCurrent, same(outgoingPrevious));
      verify(incoming.cancel).called(1);
      verify(outgoing.cancel).called(1);
      expect(events, isNotEmpty);
    });

    test('dispose cancels tracked outgoing verification', () async {
      final outgoing = MockKeyVerification();

      when(() => outgoing.lastStep).thenReturn('m.key.verification.ready');
      when(() => outgoing.isDone).thenReturn(false);
      when(() => outgoing.canceled).thenReturn(false);
      when(() => outgoing.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
      when(() => outgoing.onUpdate).thenReturn(null);
      when(() => outgoing.onUpdate = any()).thenReturn(null);
      when(outgoing.cancel).thenAnswer((_) async => Future<void>.value());

      final handler = VerificationHandler(
        onStateChanged: (_) {},
        pollInterval: Duration.zero,
      )..trackOutgoing(outgoing);
      await handler.dispose();

      verify(outgoing.cancel).called(1);
      expect(handler.snapshot()['hasOutgoing'], isFalse);
    });

    test(
      'outgoing completion clears outgoing state and invokes previous update',
      () {
        final events = <Map<String, Object?>>[];
        final outgoing = MockKeyVerification();

        var done = false;
        var previousCalled = false;
        void Function()? capturedOnUpdate;

        when(() => outgoing.lastStep).thenReturn('m.key.verification.key');
        when(() => outgoing.isDone).thenAnswer((_) => done);
        when(() => outgoing.canceled).thenReturn(false);
        when(() => outgoing.sasEmojis).thenReturn(<KeyVerificationEmoji>[
          KeyVerificationEmoji(1),
        ]);
        when(() => outgoing.onUpdate).thenAnswer(
          (_) => () {
            previousCalled = true;
          },
        );
        when(() => outgoing.onUpdate = any()).thenAnswer((invocation) {
          capturedOnUpdate =
              invocation.positionalArguments.first as void Function()?;
          return null;
        });
        when(outgoing.cancel).thenAnswer((_) async => Future<void>.value());

        final handler = VerificationHandler(
          onStateChanged: events.add,
          pollInterval: Duration.zero,
        );
        addTearDown(handler.dispose);

        handler.trackOutgoing(outgoing);
        expect(events.last['emojis'], isNotEmpty);

        done = true;
        capturedOnUpdate?.call();

        expect(previousCalled, isTrue);
        expect(handler.snapshot()['hasOutgoing'], isFalse);
      },
    );

    test('emoji serialization is guarded when sasEmojis throws', () {
      final events = <Map<String, Object?>>[];
      final outgoing = MockKeyVerification();

      when(() => outgoing.lastStep).thenReturn('m.key.verification.key');
      when(() => outgoing.isDone).thenReturn(false);
      when(() => outgoing.canceled).thenReturn(false);
      when(() => outgoing.sasEmojis).thenThrow(Exception('sas failed'));
      when(() => outgoing.onUpdate).thenReturn(null);
      when(() => outgoing.onUpdate = any()).thenReturn(null);
      when(outgoing.cancel).thenAnswer((_) async => Future<void>.value());

      final handler = VerificationHandler(
        onStateChanged: events.add,
        pollInterval: Duration.zero,
      );
      addTearDown(handler.dispose);

      handler.trackOutgoing(outgoing);
      expect(events.last['emojis'], isEmpty);
      expect(handler.snapshot()['outgoingEmojis'], isEmpty);
    });
  });

  group('periodic poll timer', () {
    test(
      'the Timer.periodic path emits when state changes between poll ticks',
      () {
        fakeAsync((async) {
          final events = <Map<String, Object?>>[];
          final verification = MockKeyVerification();

          var step = 'm.key.verification.request';
          when(() => verification.lastStep).thenAnswer((_) => step);
          when(() => verification.isDone).thenReturn(false);
          when(() => verification.canceled).thenReturn(false);
          when(
            () => verification.sasEmojis,
          ).thenAnswer((_) => <KeyVerificationEmoji>[]);
          when(() => verification.onUpdate).thenAnswer((_) => null);
          when(() => verification.onUpdate = any()).thenAnswer((_) {
            return;
          });
          when(verification.cancel).thenAnswer((_) async {});

          final handler = VerificationHandler(
            onStateChanged: events.add,
          )..trackIncoming(verification);
          expect(events, hasLength(1)); // forced initial emission

          // No change between ticks → the poll emits nothing.
          async.elapse(const Duration(milliseconds: 100));
          expect(events, hasLength(1));

          // Mutate the step WITHOUT firing onUpdate — only the periodic
          // poll can observe this, proving the Timer.periodic branch.
          step = 'm.key.verification.ready';
          async.elapse(const Duration(milliseconds: 100));
          expect(events, hasLength(2));
          expect(events.last['step'], 'm.key.verification.ready');

          handler.dispose();
          async.flushTimers();
        });
      },
    );
  });
}
