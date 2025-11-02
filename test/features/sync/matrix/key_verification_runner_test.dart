import 'dart:async';
import 'dart:collection';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
// No internal SDK controllers in tests
import 'package:mocktail/mocktail.dart';

// ignore_for_file: cascade_invocations, unnecessary_lambdas

class _MockKeyVerification extends Mock implements KeyVerification {}

class _MockLoggingService extends Mock implements LoggingService {}

class _MockMatrixService extends Mock implements MatrixService {}

class _MockClient extends Mock implements Client {}

class _MockDeviceKeys extends Mock implements DeviceKeys {}

void main() {
  group('KeyVerificationRunner', () {
    test('publishes emoji state changes and stops when verification completes',
        () {
      final controller =
          StreamController<KeyVerificationRunner>.broadcast(sync: true);
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
        when(() => verification.sasEmojis)
            .thenReturn([KeyVerificationEmoji(3)]);

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
    });

    test('delegates accept and cancel actions to the key verification object',
        () {
      final controller =
          StreamController<KeyVerificationRunner>.broadcast(sync: true);
      addTearDown(controller.close);

      fakeAsync((async) {
        final verification = _MockKeyVerification();
        when(() => verification.acceptVerification())
            .thenAnswer((_) => Future<void>.value());
        when(() => verification.acceptSas())
            .thenAnswer((_) => Future<void>.value());
        when(() => verification.cancel())
            .thenAnswer((_) => Future<void>.value());

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
    });
  });

  group('listenForKeyVerificationRequests', () {
    late _MockMatrixService service;
    late _MockLoggingService loggingService;
    late _MockClient client;
    late StreamController<KeyVerificationRunner> runnerController;
    late StreamController<KeyVerification> requestController;
    late StreamController<KeyVerification> requestCachedController;

    setUp(() {
      service = _MockMatrixService();
      loggingService = _MockLoggingService();
      client = _MockClient();
      runnerController =
          StreamController<KeyVerificationRunner>.broadcast(sync: true);
      requestController =
          StreamController<KeyVerification>.broadcast(sync: true);

      when(
        () => loggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenReturn(null);

      when(() => service.client).thenReturn(client);
      requestCachedController =
          StreamController<KeyVerification>.broadcast(sync: true);
      when(() => client.onKeyVerificationRequest.stream)
          .thenAnswer((_) => requestCachedController.stream);
      when(() => service.incomingKeyVerificationRunnerController)
          .thenReturn(runnerController);
      when(() => service.incomingKeyVerificationController)
          .thenReturn(requestController);
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

      await listenForKeyVerificationRequests(
        service: service,
        loggingService: loggingService,
        requests: requestCachedController.stream,
      );

      final request = _MockKeyVerification();
      when(() => request.lastStep).thenReturn(null);
      when(() => request.sasEmojis).thenReturn([]);
      when(() => request.deviceId).thenReturn('device-123');

      requestCachedController.add(request);
      await Future<void>(() {});

      expect(assignedRunner, isNotNull);
      expect(assignedRunner!.name, 'Incoming KeyVerificationRunner');
      expect(emittedRunners, isNotEmpty);

      final collectedRequests = <KeyVerification>[];
      requestController.stream.listen(collectedRequests.add);
      requestCachedController.add(request);
      await Future<void>(() {});
      expect(collectedRequests, isNotEmpty);

      assignedRunner?.stopTimer();
    });

    test('logs exceptions when listener wiring fails', () async {
      when(() => service.client).thenThrow(Exception('unavailable'));

      await listenForKeyVerificationRequests(
        service: service,
        loggingService: loggingService,
      );

      verify(
        () => loggingService.captureException(
          any<dynamic>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'listen',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('verifyMatrixDevice', () {
    test('starts verification and publishes runner state', () async {
      final service = _MockMatrixService();
      final deviceKeys = _MockDeviceKeys();
      final verification = _MockKeyVerification();
      final runnerController =
          StreamController<KeyVerificationRunner>.broadcast(sync: true);

      when(() => service.keyVerificationController)
          .thenReturn(runnerController);
      KeyVerificationRunner? latestRunner;
      when(() => service.keyVerificationRunner = any()).thenAnswer(
        (invocation) {
          latestRunner =
              invocation.positionalArguments.first as KeyVerificationRunner;
          return null;
        },
      );
      when(() => deviceKeys.startVerification())
          .thenAnswer((_) async => verification);
      when(() => verification.lastStep).thenReturn(null);
      when(() => verification.sasEmojis).thenReturn([]);

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
