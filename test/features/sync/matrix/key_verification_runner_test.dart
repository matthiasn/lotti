import 'dart:async';
import 'dart:collection';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
// No internal SDK controllers in tests
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

// ignore_for_file: cascade_invocations, unnecessary_lambdas

class _MockKeyVerification extends Mock implements KeyVerification {}

class _MockDeviceKeys extends Mock implements DeviceKeys {}

enum _GeneratedVerificationStepKind {
  ready,
  key,
  doneStep,
  cancelStep,
  customStep,
}

class _GeneratedVerificationTransition {
  const _GeneratedVerificationTransition({
    required this.kind,
    required this.isDone,
    required this.slot,
  });

  final _GeneratedVerificationStepKind kind;
  final bool isDone;
  final int slot;

  String? get sdkStep {
    switch (kind) {
      case _GeneratedVerificationStepKind.ready:
        return null;
      case _GeneratedVerificationStepKind.key:
        return 'm.key.verification.key';
      case _GeneratedVerificationStepKind.doneStep:
        return EventTypes.KeyVerificationDone;
      case _GeneratedVerificationStepKind.cancelStep:
        return 'm.key.verification.cancel';
      case _GeneratedVerificationStepKind.customStep:
        return 'generated.verification.step.$slot';
    }
  }

  String get runnerStep => sdkStep ?? '';

  bool get isTerminal =>
      isDone ||
      sdkStep == EventTypes.KeyVerificationDone ||
      sdkStep == 'm.key.verification.cancel';

  KeyVerificationEmoji get emoji => KeyVerificationEmoji((slot % 6) + 1);

  @override
  String toString() {
    return '_GeneratedVerificationTransition('
        'kind: $kind, '
        'isDone: $isDone, '
        'slot: $slot'
        ')';
  }
}

class _GeneratedVerificationScenario {
  const _GeneratedVerificationScenario(this.transitions);

  final List<_GeneratedVerificationTransition> transitions;

  @override
  String toString() => '_GeneratedVerificationScenario($transitions)';
}

extension _AnyGeneratedVerificationScenario on glados.Any {
  glados.Generator<_GeneratedVerificationStepKind> get verificationStepKind =>
      glados.AnyUtils(this).choose(_GeneratedVerificationStepKind.values);

  glados.Generator<_GeneratedVerificationTransition>
  get verificationTransition => glados.CombinableAny(this).combine3(
    verificationStepKind,
    glados.BoolAny(this).bool,
    glados.IntAnys(this).intInRange(0, 24),
    (
      _GeneratedVerificationStepKind kind,
      bool isDone,
      int slot,
    ) => _GeneratedVerificationTransition(
      kind: kind,
      isDone: isDone,
      slot: slot,
    ),
  );

  glados.Generator<_GeneratedVerificationScenario> get verificationScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(1, 12, verificationTransition)
          .map(_GeneratedVerificationScenario.new);
}

void main() {
  group('KeyVerificationRunner', () {
    test(
      'publishes emoji state changes and stops when verification completes',
      () {
        final controller = StreamController<KeyVerificationRunner>.broadcast(
          sync: true,
        );
        addTearDown(controller.close);

        fakeAsync((async) {
          final verification = _MockKeyVerification();
          final steps = Queue<String?>.from([
            null,
            'm.key.verification.key',
            EventTypes.KeyVerificationDone,
          ]);
          String? lastStep;
          when(() => verification.lastStep).thenAnswer((_) {
            if (steps.isNotEmpty) {
              lastStep = steps.removeFirst();
            }
            return lastStep;
          });
          final doneStates = Queue<bool>.from([false, false, true]);
          var lastDone = false;
          when(() => verification.isDone).thenAnswer((_) {
            if (doneStates.isNotEmpty) {
              lastDone = doneStates.removeFirst();
            }
            return lastDone;
          });
          when(
            () => verification.sasEmojis,
          ).thenReturn([KeyVerificationEmoji(3)]);

          final emitted = <KeyVerificationRunner>[];
          controller.stream.listen(emitted.add);

          final runner = KeyVerificationRunner(
            verification,
            controller: controller,
            name: 'Test runner',
          );

          expect(runner.lastStep, '');
          expect(emitted, isNotEmpty);

          async.elapse(const Duration(milliseconds: 100));
          expect(runner.lastStep, 'm.key.verification.key');
          expect(runner.emojis?.first.number, 3);

          async.elapse(const Duration(milliseconds: 100));
          expect(runner.lastStep, EventTypes.KeyVerificationDone);

          final emissionCount = emitted.length;
          async.elapse(const Duration(milliseconds: 500));
          expect(emitted.length, emissionCount);
          runner.stopTimer();
        });
      },
    );

    test(
      'invokes completion callback exactly once when done state changes',
      () {
        final controller = StreamController<KeyVerificationRunner>.broadcast(
          sync: true,
        );
        addTearDown(controller.close);

        fakeAsync((async) {
          final verification = _MockKeyVerification();
          when(
            () => verification.lastStep,
          ).thenReturn('m.key.verification.key');
          final doneStates = Queue<bool>.from([false, true, true, true]);
          var currentDone = false;
          when(() => verification.isDone).thenAnswer((_) {
            if (doneStates.isNotEmpty) {
              currentDone = doneStates.removeFirst();
            }
            return currentDone;
          });

          var callbackCount = 0;
          final runner = KeyVerificationRunner(
            verification,
            controller: controller,
            name: 'Completion runner',
            onCompleted: (_) async {
              callbackCount++;
            },
          );

          expect(callbackCount, 0);
          async.elapse(const Duration(milliseconds: 150));
          async.flushMicrotasks();
          expect(callbackCount, 1);

          async.elapse(const Duration(milliseconds: 500));
          async.flushMicrotasks();
          expect(callbackCount, 1);

          runner.stopTimer();
        });
      },
    );

    glados.Glados(
      glados.any.verificationScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'generated SDK updates publish only real state changes and restore '
      'the previous handler at terminal states',
      (scenario) {
        final controller = StreamController<KeyVerificationRunner>.broadcast(
          sync: true,
        );
        addTearDown(controller.close);

        fakeAsync((async) {
          final verification = _MockKeyVerification();
          String? currentStep;
          var currentDone = false;
          var currentEmojis = [KeyVerificationEmoji(1)];
          void Function()? assignedOnUpdate;
          var previousCalls = 0;
          void previousOnUpdate() {
            previousCalls++;
          }

          assignedOnUpdate = previousOnUpdate;
          when(() => verification.lastStep).thenAnswer((_) => currentStep);
          when(() => verification.isDone).thenAnswer((_) => currentDone);
          when(() => verification.sasEmojis).thenAnswer((_) => currentEmojis);
          when(() => verification.onUpdate).thenAnswer((_) => assignedOnUpdate);
          when(() => verification.onUpdate = any()).thenAnswer((invocation) {
            assignedOnUpdate =
                invocation.positionalArguments.first as void Function()?;
            return null;
          });

          final emittedSteps = <String>[];
          controller.stream.listen(
            (runner) => emittedSteps.add(runner.lastStep),
          );
          final completions = <String>[];
          final runner = KeyVerificationRunner(
            verification,
            controller: controller,
            name: 'Generated runner',
            onCompleted: (source) {
              completions.add(source);
              return Future<void>.value();
            },
          );

          final expectedSteps = <String>[''];
          var modelStep = '';
          var modelDone = false;
          var stopped = false;
          KeyVerificationEmoji? expectedEmoji;
          var expectedPreviousCalls = 0;
          var expectedCompletions = 0;

          for (final transition in scenario.transitions) {
            if (stopped) break;

            currentStep = transition.sdkStep;
            currentDone = transition.isDone;
            currentEmojis = [transition.emoji];

            final oldStep = modelStep;
            assignedOnUpdate?.call();
            expectedPreviousCalls++;

            final changed =
                transition.runnerStep != modelStep ||
                transition.isDone != modelDone;
            if (changed) {
              modelStep = transition.runnerStep;
              modelDone = transition.isDone;
              expectedSteps.add(modelStep);
              if (oldStep != modelStep &&
                  modelStep == 'm.key.verification.key') {
                expectedEmoji = transition.emoji;
              }
            }

            if (modelDone && expectedCompletions == 0) {
              expectedCompletions = 1;
            }

            if (transition.isTerminal) {
              stopped = true;
            }
          }

          expect(emittedSteps, expectedSteps, reason: '$scenario');
          expect(runner.lastStep, modelStep, reason: '$scenario');
          expect(previousCalls, expectedPreviousCalls, reason: '$scenario');
          expect(completions, hasLength(expectedCompletions));
          if (expectedCompletions == 1) {
            expect(completions.single, 'Generated runner');
          }

          if (expectedEmoji != null) {
            expect(runner.emojis, hasLength(1));
            expect(runner.emojis!.single.number, expectedEmoji.number);
          } else {
            expect(runner.emojis, isNull);
          }

          if (stopped) {
            expect(identical(assignedOnUpdate, previousOnUpdate), isTrue);
          } else {
            expect(identical(assignedOnUpdate, previousOnUpdate), isFalse);
            runner.stopTimer();
          }

          async.flushMicrotasks();
        });
      },
      tags: 'glados',
    );

    test(
      'delegates accept and cancel actions to the key verification object',
      () {
        final controller = StreamController<KeyVerificationRunner>.broadcast(
          sync: true,
        );
        addTearDown(controller.close);

        fakeAsync((async) {
          final verification = _MockKeyVerification();
          when(
            () => verification.acceptVerification(),
          ).thenAnswer((_) => Future<void>.value());
          when(
            () => verification.acceptSas(),
          ).thenAnswer((_) => Future<void>.value());
          when(
            () => verification.cancel(),
          ).thenAnswer((_) => Future<void>.value());
          when(() => verification.isDone).thenReturn(false);

          var callCount = 0;
          final steps = ['initial', 'step-1', 'step-2'];
          when(() => verification.lastStep).thenAnswer((_) {
            final index = callCount;
            callCount++;
            if (index < steps.length) {
              return steps[index];
            }
            return steps.last;
          });

          final runner = KeyVerificationRunner(
            verification,
            controller: controller,
            name: 'Action runner',
          );

          runner.acceptVerification();
          runner.acceptEmojiVerification();

          final callCountBeforeCancel = callCount;
          runner.cancelVerification();

          verifyInOrder([
            () => verification.acceptVerification(),
            () => verification.acceptSas(),
            () => verification.cancel(),
          ]);

          async.elapse(const Duration(milliseconds: 300));
          expect(callCount, callCountBeforeCancel);
          runner.stopTimer();
        });
      },
    );
  });

  group('listenForKeyVerificationRequestsWithSubscription', () {
    late MockMatrixService service;
    late MockDomainLogger loggingService;
    late MockMatrixClient client;
    late StreamController<KeyVerificationRunner> runnerController;
    late StreamController<KeyVerification> requestController;
    late StreamController<KeyVerification> requestCachedController;

    setUp(() {
      service = MockMatrixService();
      loggingService = MockDomainLogger();
      client = MockMatrixClient();
      runnerController = StreamController<KeyVerificationRunner>.broadcast(
        sync: true,
      );
      requestController = StreamController<KeyVerification>.broadcast(
        sync: true,
      );

      when(
        () => loggingService.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});

      when(() => service.client).thenReturn(client);
      requestCachedController = StreamController<KeyVerification>.broadcast(
        sync: true,
      );
      when(
        () => client.onKeyVerificationRequest.stream,
      ).thenAnswer((_) => requestCachedController.stream);
      when(
        () => service.incomingKeyVerificationRunnerController,
      ).thenReturn(runnerController);
      when(
        () => service.incomingKeyVerificationController,
      ).thenReturn(requestController);
    });

    tearDown(() async {
      await runnerController.close();
      await requestController.close();
      await requestCachedController.close();
    });

    test('creates runners and forwards incoming requests', () async {
      final emittedRunners = <KeyVerificationRunner>[];
      runnerController.stream.listen(emittedRunners.add);

      KeyVerificationRunner? assignedRunner;
      when(() => service.incomingKeyVerificationRunner = any()).thenAnswer(
        (invocation) {
          assignedRunner =
              invocation.positionalArguments.first as KeyVerificationRunner;
          return null;
        },
      );

      await listenForKeyVerificationRequestsWithSubscription(
        service: service,
        loggingService: loggingService,
        requests: requestCachedController.stream,
      );

      final request = _MockKeyVerification();
      when(() => request.lastStep).thenReturn(null);
      when(() => request.sasEmojis).thenReturn([]);
      when(() => request.deviceId).thenReturn('device-123');
      when(() => request.isDone).thenReturn(false);

      requestCachedController.add(request);
      await Future<void>.delayed(Duration.zero);

      expect(assignedRunner, isNotNull);
      expect(assignedRunner!.name, 'Incoming KeyVerificationRunner');
      expect(emittedRunners, isNotEmpty);

      final collectedRequests = <KeyVerification>[];
      requestController.stream.listen(collectedRequests.add);
      requestCachedController.add(request);
      await Future<void>.delayed(Duration.zero);
      expect(collectedRequests, isNotEmpty);

      assignedRunner?.stopTimer();
    });

    test('logs exceptions when listener wiring fails', () async {
      when(() => service.client).thenThrow(Exception('unavailable'));

      await listenForKeyVerificationRequestsWithSubscription(
        service: service,
        loggingService: loggingService,
      );

      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'listen',
        ),
      ).called(1);
    });
  });

  group('KeyVerificationRunner - SDK onUpdate forwarding', () {
    test('forwards SDK onUpdate to the previous handler', () {
      final controller = StreamController<KeyVerificationRunner>.broadcast(
        sync: true,
      );
      addTearDown(controller.close);

      fakeAsync((async) {
        final verification = _MockKeyVerification();
        void Function()? capturedOnUpdate;
        void Function()? storedOnUpdate;
        when(() => verification.lastStep).thenReturn(null);
        when(() => verification.isDone).thenReturn(false);
        when(() => verification.onUpdate).thenAnswer((_) => storedOnUpdate);

        var previousCalled = false;
        storedOnUpdate = () {
          previousCalled = true;
        };

        // Capture the onUpdate that KeyVerificationRunner sets
        when(() => verification.onUpdate = any()).thenAnswer((invocation) {
          final next = invocation.positionalArguments.first as void Function()?;
          capturedOnUpdate = next;
          storedOnUpdate = next;
          return null;
        });

        final runner = KeyVerificationRunner(
          verification,
          controller: controller,
          name: 'Forward test',
        );

        // Simulate SDK calling onUpdate
        capturedOnUpdate?.call();

        expect(previousCalled, isTrue);
        runner.stopTimer();
      });
    });

    test('cancel step stops the timer', () {
      final controller = StreamController<KeyVerificationRunner>.broadcast(
        sync: true,
      );
      addTearDown(controller.close);

      fakeAsync((async) {
        final verification = _MockKeyVerification();
        final steps = Queue<String?>.from([
          null,
          'm.key.verification.cancel',
        ]);
        String? lastStep;
        when(() => verification.lastStep).thenAnswer((_) {
          if (steps.isNotEmpty) {
            lastStep = steps.removeFirst();
          }
          return lastStep;
        });
        when(() => verification.isDone).thenReturn(false);

        final emitted = <KeyVerificationRunner>[];
        controller.stream.listen(emitted.add);

        final runner = KeyVerificationRunner(
          verification,
          controller: controller,
          name: 'Cancel test',
        );

        async.elapse(const Duration(milliseconds: 100));
        expect(runner.lastStep, 'm.key.verification.cancel');

        // Timer should be stopped; no more emissions after this
        final emissionCount = emitted.length;
        async.elapse(const Duration(milliseconds: 500));
        expect(emitted.length, emissionCount);

        runner.stopTimer();
      });
    });
  });

  group('verifyMatrixDevice', () {
    test('starts verification and publishes runner state', () async {
      final service = MockMatrixService();
      final deviceKeys = _MockDeviceKeys();
      final verification = _MockKeyVerification();
      final runnerController =
          StreamController<KeyVerificationRunner>.broadcast(sync: true);

      when(
        () => service.keyVerificationController,
      ).thenReturn(runnerController);
      KeyVerificationRunner? latestRunner;
      when(() => service.keyVerificationRunner = any()).thenAnswer(
        (invocation) {
          latestRunner =
              invocation.positionalArguments.first as KeyVerificationRunner;
          return null;
        },
      );
      when(
        () => deviceKeys.startVerification(),
      ).thenAnswer((_) async => verification);
      when(() => verification.lastStep).thenReturn(null);
      when(() => verification.sasEmojis).thenReturn([]);
      when(() => verification.isDone).thenReturn(false);

      final emittedRunners = <KeyVerificationRunner>[];
      runnerController.stream.listen(emittedRunners.add);

      await verifyMatrixDevice(
        deviceKeys: deviceKeys,
        service: service,
      );

      verify(() => deviceKeys.startVerification()).called(1);
      expect(emittedRunners, isNotEmpty);

      final runner = emittedRunners.first;
      expect(runner.name, 'Outgoing KeyVerificationRunner');
      runner.stopTimer();
      latestRunner?.stopTimer();

      await runnerController.close();
    });
  });
}
