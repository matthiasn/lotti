import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/recent_searches/domain/recent_search.dart';
import 'package:lotti/features/recent_searches/state/recent_searches_controller.dart';
import 'package:lotti/features/recent_searches/state/recent_searches_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

const RecentSearchSurface _tasks = RecentSearchSurface.tasks;
const RecentSearchSurface _habits = RecentSearchSurface.habits;
const Duration _settle = RecentSearchesController.settleWindow;
const _justShort = Duration(milliseconds: 1999);
const _tick = Duration(milliseconds: 1);

RecentSearch _search(RecentSearchSurface surface, String query) =>
    RecentSearch(surface: surface, query: query);

/// The controller's own timers still running. Riverpod schedules zero-length
/// housekeeping timers of its own in the same zone, so a bare
/// `pendingTimers` count would assert on the framework, not on the settle
/// windows these tests are about.
int _settleTimers(FakeAsync async) =>
    async.pendingTimers.where((timer) => timer.duration == _settle).length;

/// A controller over a mocked store and a flag stream the test owns.
///
/// Built inside the test's `fakeAsync` zone, so the settle timers it creates
/// run on the fake clock.
class _Bench {
  _Bench(
    FakeAsync async, {
    Stream<bool>? flag,
    Future<List<RecentSearch>> Function()? load,
    Future<void> Function()? save,
  }) {
    when(repository.load).thenAnswer((_) => (load ?? () async => [])());
    when(
      () => repository.save(any()),
    ).thenAnswer((_) => (save ?? () async {})());
    container = ProviderContainer(
      overrides: [
        recentSearchesRepositoryProvider.overrideWithValue(repository),
        loggingServiceProvider.overrideWithValue(logging),
        configFlagProvider(
          enableMobileSidebarNavigationFlag,
        ).overrideWith((ref) => flag ?? Stream.value(true)),
      ],
    );
    // Hold the provider the way the sidebar does, then let the flag's first
    // value and the stored list arrive.
    container.listen(recentSearchesControllerProvider, (_, _) {});
    async.flushMicrotasks();
  }

  final repository = MockRecentSearchesRepository();
  final logging = MockLoggingService();
  late final ProviderContainer container;

  RecentSearchesController get controller =>
      container.read(recentSearchesControllerProvider.notifier);

  List<RecentSearch> get state =>
      container.read(recentSearchesControllerProvider);

  /// Every list handed to the store so far, oldest write first.
  List<List<RecentSearch>> get saved => verify(
    () => repository.save(captureAny()),
  ).captured.cast<List<RecentSearch>>();

  void expectNothingSaved() => verifyNever(() => repository.save(any()));

  /// Checks that [times] storage failures of [subDomain] were reported since
  /// the last check — mocktail counts each call toward one check only.
  void expectReported(String subDomain, int times) {
    void report() => logging.captureException(
      any<dynamic>(),
      domain: 'RecentSearchesController',
      subDomain: subDomain,
      stackTrace: any<dynamic>(named: 'stackTrace'),
      level: any(named: 'level'),
      type: any(named: 'type'),
    );
    if (times == 0) {
      verifyNever(report);
    } else {
      verify(report).called(times);
    }
  }
}

void main() {
  setUpAll(registerAllFallbackValues);

  group('RecentSearchesController loading', () {
    test('starts from the stored list', () {
      fakeAsync((async) {
        final stored = [_search(_tasks, 'fish feeder')];
        final bench = _Bench(async, load: () async => stored);
        addTearDown(bench.container.dispose);

        expect(bench.state, stored);
      });
    });

    test('never reads the store while the flag is off', () {
      fakeAsync((async) {
        final bench = _Bench(async, flag: Stream.value(false));
        addTearDown(bench.container.dispose);

        bench.controller.noteQuery(_tasks, 'penguin');
        unawaited(bench.controller.record(_tasks, 'penguin'));
        async.elapse(_settle);

        // Every search field in the app calls in here, so with the
        // experiment off this must cost nothing — not even a settings read.
        verifyNever(bench.repository.load);
        expect(bench.state, isEmpty);
      });
    });

    test('reads the store once, however many callers need the list', () {
      fakeAsync((async) {
        final bench = _Bench(async);
        addTearDown(bench.container.dispose);

        unawaited(bench.controller.record(_tasks, 'fish'));
        unawaited(bench.controller.record(_habits, 'run'));
        unawaited(bench.controller.clear());
        async.flushMicrotasks();

        verify(bench.repository.load).called(1);
      });
    });

    test('loads the history when the flag turns on later', () {
      fakeAsync((async) {
        final flag = StreamController<bool>();
        final stored = [_search(_tasks, 'fish feeder')];
        final bench = _Bench(
          async,
          flag: flag.stream,
          load: () async => stored,
        );
        addTearDown(bench.container.dispose);
        flag.add(false);
        async.flushMicrotasks();
        expect(bench.state, isEmpty);

        flag.add(true);
        async.flushMicrotasks();

        expect(bench.state, stored);
        unawaited(flag.close());
      });
    });

    test('a record that beats the load still lands on top of the history', () {
      fakeAsync((async) {
        final load = Completer<List<RecentSearch>>();
        final bench = _Bench(async, load: () => load.future);
        addTearDown(bench.container.dispose);

        unawaited(bench.controller.record(_habits, 'run'));
        async.flushMicrotasks();
        bench.expectNothingSaved();

        load.complete([_search(_tasks, 'fish')]);
        async.flushMicrotasks();

        expect(bench.state, [_search(_habits, 'run'), _search(_tasks, 'fish')]);
        expect(bench.saved.single, bench.state);
      });
    });
  });

  group('RecentSearchesController.noteQuery', () {
    test('records a query only once it has rested for the settle window', () {
      fakeAsync((async) {
        final bench = _Bench(async);
        addTearDown(bench.container.dispose);

        bench.controller.noteQuery(_tasks, 'penguin');
        async.elapse(_justShort);
        expect(bench.state, isEmpty);

        async.elapse(_tick);
        expect(bench.state, [_search(_tasks, 'penguin')]);
        expect(bench.saved.single, [_search(_tasks, 'penguin')]);
      });
    });

    test('a run of keystrokes records the text that was left standing', () {
      fakeAsync((async) {
        final bench = _Bench(async);
        addTearDown(bench.container.dispose);

        for (final typed in ['p', 'pe', 'pen', 'peng', 'penguin']) {
          bench.controller.noteQuery(_tasks, typed);
          async.elapse(const Duration(milliseconds: 300));
        }
        async.elapse(_settle);

        expect(bench.state, [_search(_tasks, 'penguin')]);
        expect(bench.saved, hasLength(1));
      });
    });

    test('clearing the field inside the window abandons the search', () {
      fakeAsync((async) {
        final bench = _Bench(async);
        addTearDown(bench.container.dispose);

        bench.controller
          ..noteQuery(_tasks, 'penguin')
          ..noteQuery(_tasks, '');
        async.elapse(_settle);

        expect(bench.state, isEmpty);
        expect(_settleTimers(async), 0);
        bench.expectNothingSaved();
      });
    });

    test('each surface settles on its own clock', () {
      fakeAsync((async) {
        final bench = _Bench(async);
        addTearDown(bench.container.dispose);

        bench.controller.noteQuery(_tasks, 'fish');
        async.elapse(const Duration(seconds: 1));
        bench.controller.noteQuery(_habits, 'run');

        async.elapse(const Duration(seconds: 1));
        expect(bench.state, [_search(_tasks, 'fish')]);

        async.elapse(const Duration(seconds: 1));
        expect(bench.state, [_search(_habits, 'run'), _search(_tasks, 'fish')]);
      });
    });

    test('times nothing while the flag is off', () {
      fakeAsync((async) {
        final bench = _Bench(async, flag: Stream.value(false));
        addTearDown(bench.container.dispose);

        bench.controller.noteQuery(_tasks, 'penguin');

        expect(_settleTimers(async), 0);
        async.elapse(_settle);
        expect(bench.state, isEmpty);
        bench.expectNothingSaved();
      });
    });

    test('drops what was settling when the flag turns off', () {
      fakeAsync((async) {
        final flag = StreamController<bool>();
        final bench = _Bench(async, flag: flag.stream);
        addTearDown(bench.container.dispose);
        flag.add(true);
        async.flushMicrotasks();

        bench.controller.noteQuery(_tasks, 'penguin');
        flag.add(false);
        async.flushMicrotasks();

        expect(_settleTimers(async), 0);
        async.elapse(_settle);
        expect(bench.state, isEmpty);
        unawaited(flag.close());
      });
    });

    // A query can be typed before the flag has reported at all; the timer
    // runs and the decision is taken with whatever is known when it fires.
    for (final flagValue in [true, false]) {
      test('a query noted before the flag reports is decided by '
          'flag=$flagValue', () {
        fakeAsync((async) {
          final flag = StreamController<bool>();
          final bench = _Bench(async, flag: flag.stream);
          addTearDown(bench.container.dispose);

          bench.controller.noteQuery(_tasks, 'penguin');
          expect(_settleTimers(async), 1);
          flag.add(flagValue);
          async
            ..flushMicrotasks()
            ..elapse(_settle);

          expect(
            bench.state,
            flagValue ? [_search(_tasks, 'penguin')] : isEmpty,
          );
          unawaited(flag.close());
        });
      });
    }

    test('treats a failing flag read as off', () {
      fakeAsync((async) {
        final bench = _Bench(
          async,
          flag: Stream<bool>.error(StateError('no database')),
        );
        addTearDown(bench.container.dispose);

        bench.controller.noteQuery(_tasks, 'penguin');

        expect(_settleTimers(async), 0);
      });
    });
  });

  group('RecentSearchesController.record', () {
    test('records at once and supersedes what was still settling', () {
      fakeAsync((async) {
        final bench = _Bench(async);
        addTearDown(bench.container.dispose);

        bench.controller.noteQuery(_tasks, 'peng');
        unawaited(bench.controller.record(_tasks, 'penguin'));
        async.flushMicrotasks();

        expect(bench.state, [_search(_tasks, 'penguin')]);
        expect(_settleTimers(async), 0);
        async.elapse(_settle);
        expect(bench.saved, hasLength(1));
      });
    });

    test('writes nothing for a query too short to remember', () {
      fakeAsync((async) {
        final bench = _Bench(async);
        addTearDown(bench.container.dispose);

        unawaited(bench.controller.record(_tasks, ' p '));
        async.flushMicrotasks();

        expect(bench.state, isEmpty);
        bench.expectNothingSaved();
      });
    });

    test('records nothing when the flag turns off while the stored list is '
        'still loading', () {
      fakeAsync((async) {
        final flag = StreamController<bool>();
        final load = Completer<List<RecentSearch>>();
        final bench = _Bench(async, flag: flag.stream, load: () => load.future);
        addTearDown(bench.container.dispose);
        flag.add(true);
        async.flushMicrotasks();

        // The submit passes the flag check, then waits on the slow read…
        unawaited(bench.controller.record(_tasks, 'penguin'));
        async.flushMicrotasks();
        // …during which the user switches the sidebar off.
        flag.add(false);
        async.flushMicrotasks();

        load.complete([_search(_tasks, 'fish')]);
        async.flushMicrotasks();

        expect(bench.state, [_search(_tasks, 'fish')]);
        bench.expectNothingSaved();
        unawaited(flag.close());
      });
    });

    test('does nothing while the flag is off', () {
      fakeAsync((async) {
        final bench = _Bench(async, flag: Stream.value(false));
        addTearDown(bench.container.dispose);

        unawaited(bench.controller.record(_tasks, 'penguin'));
        async.flushMicrotasks();

        expect(bench.state, isEmpty);
        bench.expectNothingSaved();
      });
    });

    for (final flagValue in [true, false]) {
      test('a submit that beats the flag waits for flag=$flagValue', () {
        fakeAsync((async) {
          final flag = StreamController<bool>();
          final bench = _Bench(async, flag: flag.stream);
          addTearDown(bench.container.dispose);

          unawaited(bench.controller.record(_tasks, 'penguin'));
          async.flushMicrotasks();
          expect(bench.state, isEmpty);

          flag.add(flagValue);
          async.flushMicrotasks();

          expect(
            bench.state,
            flagValue ? [_search(_tasks, 'penguin')] : isEmpty,
          );
          unawaited(flag.close());
        });
      });
    }
  });

  group('RecentSearchesController.clear', () {
    test('empties the list and the store, and drops what was settling', () {
      fakeAsync((async) {
        final bench = _Bench(
          async,
          load: () async => [_search(_tasks, 'fish')],
        );
        addTearDown(bench.container.dispose);

        bench.controller.noteQuery(_habits, 'run');
        unawaited(bench.controller.clear());
        async.flushMicrotasks();

        expect(bench.state, isEmpty);
        expect(bench.saved.single, isEmpty);
        expect(_settleTimers(async), 0);
      });
    });
  });

  // Every call reaches the controller unawaited from a search field, so a
  // storage failure that escaped would be an uncaught error per settled
  // search — which is also what fails these tests if one does.
  group('RecentSearchesController write ordering', () {
    test('a clear issued while a record is still being written waits for '
        'it, so the cleared search is not stored after all', () {
      fakeAsync((async) {
        final bench = _Bench(async);
        addTearDown(bench.container.dispose);
        final firstWrite = Completer<void>();
        final writes = <List<RecentSearch>>[];
        when(() => bench.repository.save(any())).thenAnswer((invocation) {
          writes.add(
            invocation.positionalArguments.single as List<RecentSearch>,
          );
          return writes.length == 1 ? firstWrite.future : Future.value();
        });

        unawaited(bench.controller.record(_tasks, 'penguin'));
        async.flushMicrotasks();
        unawaited(bench.controller.clear());
        async.flushMicrotasks();

        // The record's write is still in flight: the clear has not reached
        // the store, whose cache could otherwise answer it without writing.
        expect(writes, [
          [_search(_tasks, 'penguin')],
        ]);
        expect(bench.state, isEmpty);

        firstWrite.complete();
        async.flushMicrotasks();

        // Last write wins, in the order the user acted.
        expect(writes, [
          [_search(_tasks, 'penguin')],
          <RecentSearch>[],
        ]);
      });
    });

    test('a failed write does not hold up the next one', () {
      fakeAsync((async) {
        final bench = _Bench(async);
        addTearDown(bench.container.dispose);
        var calls = 0;
        when(() => bench.repository.save(any())).thenAnswer((_) async {
          calls++;
          if (calls == 1) throw StateError('settings store locked');
        });

        unawaited(bench.controller.record(_tasks, 'penguin'));
        unawaited(bench.controller.clear());
        async.flushMicrotasks();

        expect(calls, 2);
        bench.expectReported('save', 1);
      });
    });

    test('a write queued behind another still lands after the container is '
        'gone', () {
      fakeAsync((async) {
        final bench = _Bench(async);
        final firstWrite = Completer<void>();
        var calls = 0;
        when(() => bench.repository.save(any())).thenAnswer((_) {
          calls++;
          return calls == 1 ? firstWrite.future : Future.value();
        });

        unawaited(bench.controller.record(_tasks, 'penguin'));
        async.flushMicrotasks();
        unawaited(bench.controller.clear());
        async.flushMicrotasks();
        bench.container.dispose();

        firstWrite.complete();
        async.flushMicrotasks();

        // The clear was asked for while the app was alive; it must not be
        // lost because the notifier went away before its turn came.
        expect(calls, 2);
      });
    });
  });

  group('RecentSearchesController storage failures', () {
    test('a failed read is reported and read again by the next caller, and '
        'a search made meanwhile is dropped rather than written over the '
        'unread history', () {
      fakeAsync((async) {
        var reads = 0;
        final bench = _Bench(
          async,
          load: () async {
            reads++;
            if (reads < 3) throw StateError('settings store locked');
            return [_search(_tasks, 'fish')];
          },
        );
        addTearDown(bench.container.dispose);
        expect(reads, 1);
        bench.expectReported('load', 1);

        unawaited(bench.controller.record(_habits, 'run'));
        async.flushMicrotasks();

        expect(reads, 2);
        bench
          ..expectReported('load', 1)
          ..expectNothingSaved();
        expect(bench.state, isEmpty);

        // Once the store answers, the history is back and recording resumes.
        unawaited(bench.controller.record(_habits, 'walk'));
        async.flushMicrotasks();

        expect(reads, 3);
        expect(bench.state, [
          _search(_habits, 'walk'),
          _search(_tasks, 'fish'),
        ]);
        expect(bench.saved.single, bench.state);
      });
    });

    test('a failed write is reported, and the list keeps the search', () {
      fakeAsync((async) {
        final bench = _Bench(
          async,
          save: () async => throw StateError('disk full'),
        );
        addTearDown(bench.container.dispose);

        unawaited(bench.controller.record(_tasks, 'penguin'));
        async.flushMicrotasks();

        expect(bench.state, [_search(_tasks, 'penguin')]);
        bench.expectReported('save', 1);
      });
    });

    test('a clear goes ahead when the stored list cannot be read', () {
      fakeAsync((async) {
        final bench = _Bench(
          async,
          load: () async => throw StateError('settings store locked'),
        );
        addTearDown(bench.container.dispose);

        unawaited(bench.controller.clear());
        async.flushMicrotasks();

        expect(bench.state, isEmpty);
        expect(bench.saved.single, isEmpty);
        // The flag's read and the clear's own.
        bench.expectReported('load', 2);
      });
    });

    test('a submit whose flag read fails is dropped, as the listener drops '
        'a failing flag', () {
      fakeAsync((async) {
        final flag = StreamController<bool>();
        final bench = _Bench(async, flag: flag.stream);
        addTearDown(bench.container.dispose);

        unawaited(bench.controller.record(_tasks, 'penguin'));
        async.flushMicrotasks();
        flag.addError(StateError('no database'));
        async.flushMicrotasks();

        expect(bench.state, isEmpty);
        bench.expectNothingSaved();
        verifyNever(bench.repository.load);
        unawaited(flag.close());
      });
    });

    test('a read that fails after the container is gone reports nothing', () {
      fakeAsync((async) {
        final load = Completer<List<RecentSearch>>();
        final bench = _Bench(async, load: () => load.future);
        async.flushMicrotasks();

        bench.container.dispose();
        load.completeError(StateError('settings store locked'));
        async.flushMicrotasks();

        bench.expectReported('load', 0);
      });
    });
  });

  group('RecentSearchesController disposal', () {
    test('cancels every settle timer', () {
      fakeAsync((async) {
        final bench = _Bench(async);
        bench.controller
          ..noteQuery(_tasks, 'fish')
          ..noteQuery(_habits, 'run');
        expect(_settleTimers(async), 2);

        bench.container.dispose();

        expect(_settleTimers(async), 0);
      });
    });

    // Each of these awaits the stored list; the container going away while
    // they wait must end them quietly rather than write to a dead notifier.
    final awaiters = <String, void Function(RecentSearchesController)>{
      'the initial load': (_) {},
      'a record': (controller) =>
          unawaited(controller.record(_tasks, 'penguin')),
      'a clear': (controller) => unawaited(controller.clear()),
    };
    for (final MapEntry(key: description, value: start) in awaiters.entries) {
      test('$description that outlives the container writes nothing', () {
        fakeAsync((async) {
          final load = Completer<List<RecentSearch>>();
          final bench = _Bench(async, load: () => load.future);
          start(bench.controller);
          async.flushMicrotasks();

          bench.container.dispose();
          load.complete([_search(_tasks, 'fish')]);
          async.flushMicrotasks();

          bench.expectNothingSaved();
        });
      });
    }

    test('a submit still waiting for the flag ends with the container', () {
      fakeAsync((async) {
        final flag = StreamController<bool>();
        final bench = _Bench(async, flag: flag.stream);
        final controller = bench.controller;

        var settled = false;
        unawaited(
          controller
              .record(_tasks, 'penguin')
              .then((_) => settled = true, onError: (_) => settled = true),
        );
        async.flushMicrotasks();
        bench.container.dispose();
        flag.add(true);
        async.flushMicrotasks();

        bench.expectNothingSaved();
        expect(settled, isTrue);
        unawaited(flag.close());
      });
    });
  });
}
