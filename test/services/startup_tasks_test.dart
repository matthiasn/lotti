import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/startup_tasks.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  group('StartupTasks', () {
    test('settle with nothing tracked completes immediately', () async {
      await expectLater(StartupTasks().settle(), completes);
    });

    test('settle waits for tracked work', () async {
      final tasks = StartupTasks();
      var done = false;
      final gate = Completer<void>();
      tasks.track(gate.future.then((_) => done = true));

      final settling = tasks.settle();
      gate.complete();
      await settling;

      expect(done, isTrue);
    });

    test('a failing tracked task is logged, and settle completes', () async {
      await getIt.reset();
      addTearDown(getIt.reset);
      final domainLogger = MockDomainLogger();
      when(
        () => domainLogger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});
      getIt.registerSingleton<DomainLogger>(domainLogger);

      final tasks = StartupTasks()
        ..track(Future<void>.error(StateError('startup boom')));

      await expectLater(tasks.settle(), completes);
      verify(
        () => domainLogger.error(
          LogDomain.general,
          any<Object>(that: isStateError),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'startupTasks',
        ),
      ).called(1);
    });

    test('settle abandons work past the bound instead of hanging', () {
      fakeAsync((async) {
        final tasks = StartupTasks()..track(Completer<void>().future);
        var settled = false;
        tasks.settle().then((_) => settled = true);

        async
          ..elapse(const Duration(seconds: 6))
          ..flushMicrotasks();

        expect(settled, isTrue);
      });
    });
  });
}
